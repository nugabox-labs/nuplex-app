import Foundation
import UIKit

/**
 브릿지 메서드의 실제 구현 (iOS).

 계약: docs/BRIDGE_CONTRACT.md §1. **메서드를 지우지 않는다** — 구버전 셸을 쓰는
 사용자가 남아 있듯이, 신버전 셸에도 구버전 웹이 로드될 수 있다.

 여기서 던지는 예외는 웹의 클릭 핸들러를 깨뜨린다. 그래서 모든 경로가 값을
 돌려주며 실패해도 조용히 물러난다.
 */
enum NuplexBridgeAPI {

    static let bridgeVersion = 1

    static func handle(
        method: String,
        args: [String: Any],
        respond: @escaping (Any?) -> Void
    ) {
        switch method {
        case "openExternal":
            openExternal(args["url"] as? String)
            respond(nil)

        case "setBadgeCount":
            setBadge(count: args["count"] as? Int ?? 0)
            respond(nil)

        case "openInPlex":
            // TODO(phase-4): Plex 딥링크. 지금은 넘겨받은 https 주소를 그대로 연다.
            openExternal(args["webUrl"] as? String)
            respond(["opened": "browser"])

        // TODO(phase-5): 아래 넷은 푸시 구현과 함께 채운다. 계약을 먼저 세워두는 이유는
        // 웹이 bridgeVersion 만 보고 호출하기 때문이다 — 없으면 TypeError 로 화면이 죽는다.
        case "getPushPermission":
            respond("prompt")
        case "requestPushPermission":
            respond("denied")
        case "getPushToken":
            respond(nil)
        case "clearPushRegistration":
            respond(nil)

        case "bridgeReady":
            // 주입 성공 로그. 이 줄이 안 보이면 브릿지가 안 붙은 것이다.
            NSLog("[Nuplex] 브릿지 주입됨: \(args["href"] as? String ?? "?")")
            respond(nil)

        case "notifyWebReady":
            // TODO(phase-5): 대기 중인 푸시 라우트를 흘려보낸다.
            respond(nil)

        default:
            // 신버전 웹이 구버전 셸에 없는 메서드를 부른 경우다. 무시한다.
            NSLog("[Nuplex] 알 수 없는 브릿지 메서드: \(method)")
            respond(nil)
        }
    }

    private static func openExternal(_ urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private static func setBadge(count: Int) {
        DispatchQueue.main.async {
            // 배지는 알림 권한에 딸려 있다. 권한이 없으면 조용히 무시된다.
            UIApplication.shared.applicationIconBadgeNumber = max(0, count)
        }
    }

    /// 주입된 스크립트에 넘길 JS 리터럴. 문자열은 JSON 으로 감싸 이스케이프한다.
    static func jsonLiteral(_ value: Any?) -> String {
        guard let value else { return "null" }
        if let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
           let text = String(data: data, encoding: .utf8),
           text.count >= 2 {
            // 최상위가 배열이어야 직렬화되므로 감쌌다가 대괄호를 벗긴다.
            return String(text.dropFirst().dropLast())
        }
        return "null"
    }
}
