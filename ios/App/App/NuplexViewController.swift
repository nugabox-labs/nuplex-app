import Capacitor
import UIKit
import WebKit

/**
 셸 브릿지를 원격 페이지에 주입하는 뷰 컨트롤러.

 웹뷰가 원격 도메인(nuplex 웹)으로 이동하면 로컬 페이지의 JS 는 사라진다.
 그래서 window.NuplexNative 는 네이티브가 문서 시작 시점에 직접 넣어야 한다.
 주입할 스크립트 원본은 shell/public/nuplex-bridge.js 하나이며,
 빌드 → cap sync 를 거쳐 앱 번들의 public/ 안으로 들어온다.

 계약: docs/BRIDGE_CONTRACT.md
 */
class NuplexViewController: CAPBridgeViewController {

    private static let messageHandlerName = "nuplexShell"

    /// AppDelegate 가 웹뷰의 쿠키 저장소에 닿아야 한다(푸시 토큰 등록).
    /// 화면이 하나뿐인 앱이라 마지막으로 만들어진 것이 곧 현재 화면이다.
    private(set) static weak var current: NuplexViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        Self.current = self

        // 화면 왼쪽 끝에서 스와이프하면 뒤로 간다. iOS 사용자가 브라우저에서 늘 쓰는
        // 동작이라 없으면 "뒤로 갈 방법이 없는 앱" 이 된다 — Android 와 달리 iOS 에는
        // 하드웨어 뒤로가기가 없다.
        webView?.allowsBackForwardNavigationGestures = true

        installNavigationProxy()
    }

    /**
     웹 로드 실패를 우리 오프라인 화면으로 돌린다.

     Capacitor 가 웹뷰의 navigationDelegate 를 쥐고 있어서 그냥 override 할 수 없다.
     그래서 프록시를 끼운다 — 실패 두 가지만 가로채고 나머지 호출은 원래 델리게이트로
     그대로 넘긴다. 그냥 두면 로드 실패 시 빈 화면이 남는다(설계 명세 §9.4).
     */
    private var navigationProxy: NuplexNavigationProxy?

    private func installNavigationProxy() {
        guard let webView, let original = webView.navigationDelegate else { return }
        let proxy = NuplexNavigationProxy(target: original) { [weak self] error in
            self?.loadOfflineScreen(reason: error)
        }
        navigationProxy = proxy
        webView.navigationDelegate = proxy
    }

    private func loadOfflineScreen(reason: Error) {
        // 사용자가 이동을 취소한 것뿐이면 화면을 바꾸지 않는다.
        guard (reason as NSError).code != NSURLErrorCancelled else { return }

        NSLog("[Nuplex] 웹 로드 실패 → 오프라인 화면으로: \(reason.localizedDescription)")

        // 웹이 죽은 동안 도착한 푸시 라우트를 밀어넣지 않도록 준비 상태를 되돌린다.
        NuplexPush.reset()

        guard let offline = Bundle.main.url(
            forResource: "offline", withExtension: "html", subdirectory: "public") else { return }
        DispatchQueue.main.async { [weak self] in
            self?.webView?.loadFileURL(
                offline, allowingReadAccessTo: offline.deletingLastPathComponent())
        }
    }

    /**
     푸시 라우트로 이동한다.

     route 는 경로 문자열이다. 도메인은 셸이 붙인다 — 도메인이 바뀌어도 이미 발송된
     알림이 깨지지 않게 하기 위함이다(docs/PUSH_PAYLOAD.md).
     */
    func navigate(toRoute route: String) {
        let urlString = NuplexPreferences.webBaseUrl + route
        guard let url = URL(string: urlString) else {
            NSLog("[Nuplex] 잘못된 푸시 라우트: \(urlString)")
            return
        }
        NSLog("[Nuplex] 푸시 라우트로 이동: \(urlString)")
        DispatchQueue.main.async { [weak self] in
            self?.webView?.load(URLRequest(url: url))
        }
    }

    /// 주입된 스크립트의 Promise 를 푼다. 웹뷰 평가는 메인 스레드에서만 안전하다.
    func resolve(callId: Int, payload: Any?) {
        guard callId != 0 else { return }  // fire-and-forget 호출
        let json = NuplexBridgeAPI.jsonLiteral(payload)
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript("window.__nuplexBridgeResolve(\(callId), \(json));")
        }
    }
}

/// WKScriptMessageHandler 를 뷰 컨트롤러와 분리한다. 컨트롤러가 강하게 잡히면
/// userContentController 가 컨트롤러를 붙들어 순환 참조가 된다.
private class NuplexMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var controller: NuplexViewController?

    init(controller: NuplexViewController) {
        self.controller = controller
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let method = body["method"] as? String
        else { return }

        let callId = body["id"] as? Int ?? 0
        let args = body["args"] as? [String: Any] ?? [:]

        NuplexBridgeAPI.handle(method: method, args: args, controller: controller) { [weak controller] payload in
            controller?.resolve(callId: callId, payload: payload)
        }
    }
}

/**
 navigationDelegate 프록시.

 WKNavigationDelegate 의 메서드는 대부분 optional 이라, 우리가 구현하지 않은 호출은
 원래 델리게이트(Capacitor 의 WebViewDelegationHandler)로 넘겨야 한다. ObjC 런타임의
 메시지 포워딩을 쓰면 메서드를 하나하나 옮겨 적지 않아도 된다.
 */
private final class NuplexNavigationProxy: NSObject, WKNavigationDelegate {

    private let target: WKNavigationDelegate
    private let onFail: (Error) -> Void

    init(target: WKNavigationDelegate, onFail: @escaping (Error) -> Void) {
        self.target = target
        self.onFail = onFail
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || target.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        target.responds(to: aSelector) ? target : super.forwardingTarget(for: aSelector)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        target.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
        onFail(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        target.webView?(webView, didFail: navigation, withError: error)
        onFail(error)
    }
}
