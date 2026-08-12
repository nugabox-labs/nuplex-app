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

    override func webView(with frame: CGRect, configuration: WKWebViewConfiguration) -> WKWebView {
        let controller = configuration.userContentController

        // WKUserScript 는 origin 을 가리지 않고 모든 메인프레임 문서에 들어간다.
        // 원격 페이지에도 브릿지가 생기는 이유가 이것이다.
        if let source = Self.bridgeScript() {
            controller.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
        }

        controller.add(NuplexMessageHandler(controller: self), name: Self.messageHandlerName)

        return super.webView(with: frame, configuration: configuration)
    }

    /// 번들의 스크립트를 읽어 자리표시자를 채운다. 실패하면 브릿지 없이 뜬다 —
    /// 웹은 브릿지를 optional 로 다루므로 앱이 못 쓰게 되지는 않는다.
    private static func bridgeScript() -> String? {
        // public/ 은 웹 자산 폴더다. cap sync 가 www/ 를 통째로 여기에 복사한다.
        guard let url = Bundle.main.url(
                forResource: "nuplex-bridge", withExtension: "js", subdirectory: "public"),
              let template = try? String(contentsOf: url, encoding: .utf8)
        else {
            NSLog("[Nuplex] public/nuplex-bridge.js 를 번들에서 찾지 못했습니다. npm run sync 를 실행하세요.")
            return nil
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return template
            .replacingOccurrences(of: "__NUPLEX_PLATFORM__", with: "ios")
            .replacingOccurrences(of: "__NUPLEX_APP_VERSION__", with: version)
            .replacingOccurrences(of: "__NUPLEX_BRIDGE_VERSION__", with: String(NuplexBridgeAPI.bridgeVersion))
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

        NuplexBridgeAPI.handle(method: method, args: args) { [weak controller] payload in
            controller?.resolve(callId: callId, payload: payload)
        }
    }
}
