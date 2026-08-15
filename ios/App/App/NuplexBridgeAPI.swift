import Foundation
import UIKit
import FirebaseMessaging

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
        controller: NuplexViewController?,
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
            openInPlex(
                webUrl: args["webUrl"] as? String,
                machineIdentifier: args["machineIdentifier"] as? String,
                ratingKey: args["ratingKey"] as? String,
                type: args["type"] as? String,
                respond: respond)

        case "getPushPermission":
            NuplexPush.permissionState { respond($0) }

        case "requestPushPermission":
            NuplexPush.requestPermission { respond($0) }

        case "getPushToken":
            Messaging.messaging().token { token, error in
                if let error {
                    // 자격증명이 없거나 APNs 등록 전이다. 웹은 null 을 받고 폴백한다.
                    NSLog("[Nuplex] FCM 토큰을 받지 못했습니다: \(error.localizedDescription)")
                }
                respond(token)
            }

        case "clearPushRegistration":
            // 세션이 살아 있는 동안 불려야 한다. 로그아웃 뒤에 부르면 401 이다.
            NuplexTokenRegistrar.unregister(
                cookieStore: controller?.webView?.configuration.websiteDataStore.httpCookieStore)
            respond(nil)

        case "bridgeReady":
            // 주입 성공 로그. 이 줄이 안 보이면 브릿지가 안 붙은 것이다.
            NSLog("[Nuplex] 브릿지 주입됨: \(args["href"] as? String ?? "?")")
            respond(nil)

        case "notifyWebReady":
            // 앱이 꺼진 상태에서 알림을 탭했다면 라우트가 여기까지 대기하고 있다.
            NuplexPush.flush { route in controller?.navigate(toRoute: route) }
            // 웹이 준비됐다는 것은 로그인·프로필 선택을 마쳤다는 뜻이다. 토큰 등록에
            // 필요한 세션 쿠키가 이제야 생겼으므로 여기서 등록을 시도한다.
            Messaging.messaging().token { token, _ in
                guard let token else { return }
                NuplexTokenRegistrar.registerIfChanged(
                    token: token,
                    cookieStore: controller?.webView?.configuration.websiteDataStore.httpCookieStore)
            }
            respond(nil)

        default:
            // 신버전 웹이 구버전 셸에 없는 메서드를 부른 경우다. 무시한다.
            NSLog("[Nuplex] 알 수 없는 브릿지 메서드: \(method)")
            respond(nil)
        }
    }

    /// Plex 앱의 App Store 주소. src/config/constants.ts 의 PLEX 와 같이 고칠 것.
    private static let plexStoreURL = "https://apps.apple.com/app/plex/id383457673"

    /**
     Plex 로 이동한다 (ADR-003 개정, docs/PLEX_DEEPLINK.md).

     **웹이 준 `webUrl` 을 그대로 열지 않는다.** 웹은 이제 우리 Plex 서버가 직접
     서빙하는 웹앱 주소를 만든다(`plex.nugabox.com/web/index.html#!/...`). 브라우저에서는
     그게 맞지만 Plex 앱은 그 도메인을 자기 것으로 등록하지 않아 절대 가로채지 않는다.
     앱에서는 Plex 앱으로 보내는 것이 목적이므로 `machineIdentifier` · `ratingKey` 로
     주소를 다시 만든다.

     사다리는 넷이다.

     1. Plex 앱 미설치 → App Store. (`opened: "store"`)
     2. `plex://watch/video` — Plex 앱이 실제로 받는 형식. 영화 · 에피소드가 바로
        재생된다. 시리즈처럼 재생할 파일이 없는 종류는 건너뛴다(`type` 참고).
     3. `https://app.plex.tv/...` 를 `universalLinksOnly` 로 연다. 지금 Plex 는 이
        링크를 등록하지 않지만, 다시 등록할 경우를 위해 남겨둔다.
     4. 전부 실패하면 웹이 준 주소를 브라우저로 연다. **작품까지는 정확히 가므로
        여기까지 내려와도 시청은 된다.** 이 폴백을 지우지 말 것.
     */
    private static func openInPlex(
        webUrl: String?,
        machineIdentifier: String?,
        ratingKey: String?,
        type: String?,
        respond: @escaping (Any?) -> Void
    ) {
        DispatchQueue.main.async {
            let app = UIApplication.shared
            let fallback = webUrl.flatMap { URL(string: $0) }

            // 스킴 조회는 Info.plist 의 LSApplicationQueriesSchemes 에 plex 가
            // 선언돼 있어야 동작한다. 빠지면 항상 false 가 되어 전부 스토어로 간다.
            let installed = URL(string: "plex://").map { app.canOpenURL($0) } ?? false

            if !installed {
                if let store = URL(string: plexStoreURL) {
                    app.open(store, options: [:]) { ok in
                        if ok { respond(["opened": "store"]) }
                        else { openFallback(fallback, app: app, respond: respond) }
                    }
                    return
                }
                openFallback(fallback, app: app, respond: respond)
                return
            }

            let ladder = deepLinkLadder(
                machineIdentifier: machineIdentifier, ratingKey: ratingKey, type: type)
            attempt(ladder, index: 0, app: app) { openedInApp in
                if openedInApp {
                    respond(["opened": "app"])
                } else {
                    NSLog("[Nuplex] Plex 앱이 링크를 받지 않아 브라우저로 넘깁니다.")
                    openFallback(fallback, app: app, respond: respond)
                }
            }
        }
    }

    /**
     앱으로 보낼 후보 주소를 순서대로 만든다. 식별자가 없으면 만들 수 없다.

     1순위 `plex://watch/video?uri=…` 는 **Plex 앱 APK 에서 직접 확인한 형식**이다
     (Android 2026.15.0). 등록된 딥링크 문자열이 두 개뿐이고 그중 항목을 받는 것이
     이것이며, `uri` 값의 형식도 앱 안의 파서 정규식 그대로다. Android 에서는 그
     작품이 실제로 재생되는 것까지 확인했다 — docs/PLEX_DEEPLINK.md.

     **iOS 는 아직 실기기 확인 전이다.** 스킴은 두 플랫폼이 공유하는 것이 보통이라
     같은 순서로 둔다. 2순위 app.plex.tv 는 Android 에서 Plex 가 등록하지 않는 것을
     확인했고, iOS 에서도 기대하지 않는다. 남겨둔 것은 자리 표시에 가깝다.
     */
    private static func deepLinkLadder(
        machineIdentifier: String?, ratingKey: String?, type: String?
    ) -> [URL] {
        guard let mid = machineIdentifier, !mid.isEmpty,
              let key = ratingKey, !key.isEmpty else { return [] }

        // 재생할 파일이 없는 묶음이다. 재생 명령을 보내면 Plex 가 "Item not known" 으로
        // 실패한다 — 상세 화면을 띄우도록 웹 폴백으로 내려보낸다.
        if let type, ["show", "season", "collection", "artist", "album"].contains(type) {
            NSLog("[Nuplex] 재생 대상이 아닌 종류(\(type))라 웹으로 보냅니다.")
            return []
        }

        let metadataKey = "/library/metadata/\(key)"
        let encodedKey = metadataKey.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics) ?? metadataKey
        let sourceUri = "server://\(mid)/com.plexapp.plugins.library\(metadataKey)"
        let encodedUri = sourceUri.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics) ?? sourceUri

        var urls: [URL] = []
        if let scheme = URL(string: "plex://watch/video?uri=\(encodedUri)") {
            urls.append(scheme)
        }
        if let ul = URL(string: "https://app.plex.tv/desktop/#!/server/\(mid)/details?key=\(encodedKey)") {
            urls.append(ul)
        }
        return urls
    }

    /// 후보를 하나씩 시도한다. https 는 앱이 등록한 경우에만 열리게 막는다.
    private static func attempt(
        _ urls: [URL],
        index: Int,
        app: UIApplication,
        done: @escaping (Bool) -> Void
    ) {
        guard index < urls.count else { done(false); return }
        let url = urls[index]

        if url.scheme != "https" && !app.canOpenURL(url) {
            attempt(urls, index: index + 1, app: app, done: done)
            return
        }

        let options: [UIApplication.OpenExternalURLOptionsKey: Any] =
            url.scheme == "https" ? [.universalLinksOnly: true] : [:]

        app.open(url, options: options) { opened in
            if opened {
                NSLog("[Nuplex] Plex 앱으로 보냅니다: \(url.absoluteString)")
                done(true)
            }
            else { attempt(urls, index: index + 1, app: app, done: done) }
        }
    }

    /// 마지막 폴백 — 웹이 준 주소를 브라우저로 연다.
    private static func openFallback(
        _ url: URL?,
        app: UIApplication,
        respond: @escaping (Any?) -> Void
    ) {
        guard let url else {
            respond(["opened": "browser"])
            return
        }
        app.open(url, options: [:]) { _ in respond(["opened": "browser"]) }
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
