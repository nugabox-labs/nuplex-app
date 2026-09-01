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

        installBridge()
        installNavigationProxy()
        installZoomGuard()
    }

    /**
     입력창을 누를 때 화면이 확대되는 것을 막는다.

     iOS 만의 동작이다. WKWebView 는 글자 크기가 16px 보다 작은 입력창에 포커스가
     가면 **읽을 수 있는 크기까지 화면을 확대한다.** 확대된 배율은 포커스가 풀려도
     돌아오지 않아서, 한 번 입력하면 그 뒤로 화면 전체가 커진 채로 남는다.
     Android WebView 에는 이 동작이 없다.

     이걸 통제하는 방법은 **뷰포트의 배율 상한 하나뿐이다.** 네이티브 쪽 확대/축소
     설정으로는 막히지 않는다 — 포커스 확대는 스크롤 뷰의 줌이 아니라 WebKit 이
     직접 하는 것이라서다. 그래서 뷰포트 메타를 문서 시작 시점에 덮어쓴다.

     **한 번 넣고 끝나지 않는다.** 원격 웹은 Next.js 라 자기 뷰포트 메타를 나중에
     붙이고, 화면을 옮길 때 다시 쓸 수도 있다. 그래서 감시자를 달아 값이 바뀌면
     되돌린다. 같은 값이면 다시 쓰지 않으므로 감시자가 자기 변경에 다시 불려
     무한히 도는 일은 없다.

     `viewport-fit=cover` 를 유지하는 것이 중요하다 — 이게 빠지면 안전영역이 죽어
     상태바에 헤더가 깔린다(phase-8 A-0-2 에서 한 번 겪은 문제다).

     **대가를 적어 둔다.** `user-scalable=no` 는 손가락으로 벌려 키우는 것까지 막는다.
     시력이 낮은 사용자에게는 손해다. 입력창 확대를 전부 막아 달라는 요청이라
     이렇게 했지만, 되돌린다면 이 줄에서 `user-scalable=no` 만 빼면 된다
     (그러면 포커스 확대는 `maximum-scale=1` 이 계속 막는다).
     */
    private func installZoomGuard() {
        guard let controller = webView?.configuration.userContentController else { return }
        controller.addUserScript(
            WKUserScript(
                source: Self.zoomGuardScript, injectionTime: .atDocumentStart,
                forMainFrameOnly: true))

        // 손가락으로 벌리는 확대. 위 뷰포트로도 막히지만, 웹이 뷰포트를 덮어쓴
        // 찰나에 열리지 않도록 스크롤 뷰 쪽도 함께 닫는다.
        webView?.scrollView.bouncesZoom = false
        webView?.scrollView.pinchGestureRecognizer?.isEnabled = false
    }

    /// 주입할 스크립트. 브릿지와 달리 iOS 전용이라 `shell/public/` 로 빼지 않았다 —
    /// 파일로 두면 `npm run sync` 를 거르는 순간 조용히 사라진다.
    ///
    /// ES5 문법만 쓴다. 브릿지 스크립트와 같은 이유는 아니고(여긴 iOS 뿐이다)
    /// 옆 파일과 결을 맞추기 위함이다.
    private static let zoomGuardScript = """
        (function () {
          'use strict';

          var CONTENT =
            'width=device-width, initial-scale=1, maximum-scale=1, ' +
            'user-scalable=no, viewport-fit=cover';

          var observer = null;
          var watchingHead = false;

          function apply() {
            var host = document.head || document.documentElement;
            if (!host) return;

            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
              meta = document.createElement('meta');
              meta.setAttribute('name', 'viewport');
              host.appendChild(meta);
            }
            // 같은 값이면 건드리지 않는다. 감시자가 자기 변경에 다시 불리지 않게 한다.
            if (meta.getAttribute('content') !== CONTENT) {
              meta.setAttribute('content', CONTENT);
            }

            // 글자만 부풀리는 iOS 의 자동 확대도 함께 끈다. 좁은 칸이나 가로 화면에서
            // 본문 글자 크기가 제멋대로 커지는 동작이다.
            if (document.documentElement) {
              document.documentElement.style.webkitTextSizeAdjust = '100%';
            }
          }

          function observe(target, options) {
            if (observer) observer.disconnect();
            observer = new MutationObserver(onMutation);
            observer.observe(target, options);
          }

          // head 가 생기면 감시 범위를 거기로 좁힌다. 문서 전체를 계속 보면
          // React 가 노드를 바꿀 때마다 불려 낭비가 크다.
          function narrowToHead() {
            if (watchingHead || !document.head) return;
            watchingHead = true;
            observe(document.head, {
              childList: true,
              subtree: true,
              attributes: true,
              attributeFilter: ['content'],
            });
          }

          function onMutation() {
            apply();
            narrowToHead();
          }

          apply();
          narrowToHead();

          // head 가 아직 없다면 그것이 생기는 것부터 지켜본다. DOMContentLoaded 를
          // 기다리면 그사이 웹이 붙인 뷰포트가 잠깐 살아 있게 된다.
          if (!watchingHead && document.documentElement) {
            observe(document.documentElement, { childList: true, subtree: true });
          }
        })();
        """

    /**
     window.NuplexNative 를 원격 페이지에 주입한다 (ADR-004).

     두 가지를 붙인다.

     - `WKUserScript` — 문서 시작 시점에 도는 스크립트. origin 과 무관하게 주입되므로
       웹뷰가 nuplex 웹으로 넘어간 뒤에도 살아 있다. **웹의 첫 스크립트보다 먼저 돈다.**
     - `nuplexShell` 메시지 핸들러 — 주입된 스크립트가 네이티브를 부르는 창구.

     주입 원본은 `shell/public/nuplex-bridge.js` 하나이고, 빌드 → `cap sync` 를 거쳐
     번들의 `public/` 로 들어온다. 자리표시자는 여기서 채운다 — Android 의
     `NuplexBridgeApi.buildBridgeScript()` 와 같은 일을 한다.
     */
    private func installBridge() {
        guard let controller = webView?.configuration.userContentController else {
            NSLog("[Nuplex] userContentController 가 없어 브릿지를 붙이지 못했습니다.")
            return
        }

        controller.removeScriptMessageHandler(forName: Self.messageHandlerName)
        controller.add(NuplexMessageHandler(controller: self), name: Self.messageHandlerName)

        guard let source = bridgeScript() else { return }
        controller.addUserScript(
            WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }

    private func bridgeScript() -> String? {
        guard let url = Bundle.main.url(
                forResource: "nuplex-bridge", withExtension: "js", subdirectory: "public"),
              let template = try? String(contentsOf: url, encoding: .utf8)
        else {
            NSLog("[Nuplex] nuplex-bridge.js 를 번들에서 읽지 못했습니다. npm run sync 를 실행하세요.")
            return nil
        }

        let appVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.0.0"

        return template
            .replacingOccurrences(of: "__NUPLEX_PLATFORM__", with: "ios")
            .replacingOccurrences(of: "__NUPLEX_APP_VERSION__", with: appVersion)
            .replacingOccurrences(
                of: "__NUPLEX_BRIDGE_VERSION__", with: String(NuplexBridgeAPI.bridgeVersion))
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
