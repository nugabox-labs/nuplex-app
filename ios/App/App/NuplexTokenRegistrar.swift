import Foundation
import WebKit

/**
 푸시 토큰을 서버에 등록·해제한다 (docs/PUSH_PAYLOAD.md 토큰 생명주기).

 까다로운 점이 둘 있다.

 1. `/api/app/push/token` 은 **인증 게이트 뒤에** 있다. 그런데 URLSession 은 웹뷰의
    쿠키 저장소를 공유하지 않는다. `WKHTTPCookieStore` 에서 꺼내 직접 실어야 한다.
 2. 그래서 **로그인 전에 부르면 401 이다.** 실패를 정상 흐름으로 취급하고, 웹이
    준비를 알릴 때(notifyWebReady) 다시 시도한다.
 */
enum NuplexTokenRegistrar {

    /**
     리다이렉트를 따라가지 않는 세션.

     기본 URLSession 은 리다이렉트를 따라가서 로그인 화면 HTML 을 200 으로 돌려준다.
     그러면 등록에 성공한 줄 알고 토큰을 캐시해버려, 진짜 등록이 영영 일어나지 않는다.
     미인증은 미인증으로 보여야 다음 기회에 다시 시도한다.
     */
    private static let session: URLSession = {
        URLSession(configuration: .default, delegate: RedirectBlocker(), delegateQueue: nil)
    }()

    private static let deviceIdKey = "nuplex.deviceId"
    private static let lastTokenKey = "nuplex.lastRegisteredToken"

    /// 기기 식별자. 앱을 지웠다 깔면 새 값이 된다 — 서버도 그렇게 전제한다.
    static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: deviceIdKey)
        return created
    }

    /// 이미 등록한 토큰과 같으면 건너뛴다. 부팅할 때마다 같은 요청을 보낼 이유가 없다.
    static func registerIfChanged(token: String, cookieStore: WKHTTPCookieStore?) {
        guard UserDefaults.standard.string(forKey: lastTokenKey) != token else { return }
        register(token: token, cookieStore: cookieStore)
    }

    static func register(token: String, cookieStore: WKHTTPCookieStore?) {
        var body: [String: Any] = [
            "deviceId": deviceId,
            "token": token,
            "platform": "ios",
            "locale": Locale.preferredLanguages.first ?? Locale.current.identifier,
            "timezone": TimeZone.current.identifier
        ]
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            body["appVersion"] = version
        }

        send(method: "POST", body: body, cookieStore: cookieStore) { status in
            switch status {
            case 200..<300:
                UserDefaults.standard.set(token, forKey: lastTokenKey)
                NSLog("[Nuplex] 푸시 토큰 등록 완료")
            case 300..<400, 401, 403:
                // 아직 로그인 전이다. 인증 게이트가 401 대신 /login 으로 리다이렉트하기도
                // 한다. 다음 기회에 다시 시도한다.
                NSLog("[Nuplex] 아직 로그인 전이라 토큰 등록을 미룹니다 (\(status))")
            default:
                NSLog("[Nuplex] 푸시 토큰 등록 실패 (\(status))")
            }
        }
    }

    /// 로그아웃. 세션이 지워지기 전에 불려야 한다(docs/BRIDGE_CONTRACT.md).
    static func unregister(cookieStore: WKHTTPCookieStore?) {
        send(method: "DELETE", body: ["deviceId": deviceId], cookieStore: cookieStore) { status in
            NSLog("[Nuplex] 푸시 토큰 해제 (\(status))")
            UserDefaults.standard.removeObject(forKey: lastTokenKey)
        }
    }

    private static func send(
        method: String,
        body: [String: Any],
        cookieStore: WKHTTPCookieStore?,
        completion: @escaping (Int) -> Void
    ) {
        guard let url = URL(string: NuplexPreferences.webBaseUrl + "/api/app/push/token") else {
            completion(-1)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        // 웹뷰가 쥐고 있는 세션 쿠키를 실어야 인증을 통과한다.
        attachCookies(to: request, from: cookieStore, host: url.host) { prepared in
            session.dataTask(with: prepared) { _, response, error in
                if let error {
                    NSLog("[Nuplex] 토큰 요청 실패: \(error.localizedDescription)")
                    completion(-1)
                    return
                }
                completion((response as? HTTPURLResponse)?.statusCode ?? -1)
            }.resume()
        }
    }

    private static func attachCookies(
        to request: URLRequest,
        from cookieStore: WKHTTPCookieStore?,
        host: String?,
        completion: @escaping (URLRequest) -> Void
    ) {
        guard let cookieStore, let host else {
            completion(request)
            return
        }

        // WKHTTPCookieStore 접근은 메인 스레드에서 해야 한다.
        DispatchQueue.main.async {
            cookieStore.getAllCookies { cookies in
                let matching = cookies.filter { host.hasSuffix($0.domain.hasPrefix(".") ? String($0.domain.dropFirst()) : $0.domain) }
                var prepared = request
                if !matching.isEmpty {
                    let header = matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    prepared.setValue(header, forHTTPHeaderField: "Cookie")
                }
                completion(prepared)
            }
        }
    }
}

/// 리다이렉트를 막는다. 이유는 NuplexTokenRegistrar.session 주석 참고.
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
