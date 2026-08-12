import Foundation
import UIKit
import UserNotifications

/**
 알림 권한과 푸시 라우팅 (docs/PUSH_PAYLOAD.md).

 푸시 수신·라우팅은 네이티브에서 한다. 웹뷰의 JS 로는 처리할 수 없다 — 앱이 종료된
 상태에서 알림을 탭하면 웹뷰가 뜨기도 전에 이벤트가 도착하기 때문이다.
 */
enum NuplexPush {

    // MARK: - 권한

    /// 'granted' | 'denied' | 'prompt'
    static func permissionState(_ completion: @escaping (String) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let state: String
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                state = "granted"
            case .denied:
                state = "denied"
            case .notDetermined:
                state = "prompt"
            @unknown default:
                state = "prompt"
            }
            completion(state)
        }
    }

    /// 권한 다이얼로그는 온보딩에서 사용자가 동의를 누른 뒤에만 띄운다.
    static func requestPermission(_ completion: @escaping (String) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error {
                    NSLog("[Nuplex] 알림 권한 요청 실패: \(error.localizedDescription)")
                }
                if granted {
                    // APNs 등록은 권한을 받은 뒤에만 의미가 있다. 토큰은
                    // AppDelegate 의 didRegisterForRemoteNotifications 로 온다.
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                completion(granted ? "granted" : "denied")
            }
    }

    // MARK: - 라우팅

    /**
     푸시 라우트 대기열.

     앱이 완전히 종료된 상태에서 알림을 탭하면 라우트가 **웹뷰가 준비되기 전에**
     도착한다. 그대로 이동시키면 부팅 시퀀스가 그 위를 덮어써서 알림이 홈으로
     가버린다 — 이 기능에서 가장 자주 깨지는 지점이다.
     */
    private static var pendingRoute: String?
    private static var webReady = false
    private static let lock = NSLock()

    /// 알림 탭으로 라우트가 도착했다.
    static func offer(route: String?, navigate: (String) -> Void) {
        guard let route, !route.isEmpty else { return }

        lock.lock()
        let ready = webReady
        if !ready { pendingRoute = route }
        lock.unlock()

        if ready {
            navigate(route)
        } else {
            NSLog("[Nuplex] 웹 준비 전이라 라우트를 대기열에 넣습니다: \(route)")
        }
    }

    /// 웹이 라우팅 준비를 마쳤다(notifyWebReady).
    static func flush(navigate: (String) -> Void) {
        lock.lock()
        webReady = true
        let route = pendingRoute
        pendingRoute = nil
        lock.unlock()

        if let route { navigate(route) }
    }

    /// 웹뷰가 웹 도메인을 벗어났다(로그아웃 등). 다음 준비 신호를 기다린다.
    static func reset() {
        lock.lock()
        webReady = false
        lock.unlock()
    }

    /// 알림 payload 에서 라우트를 꺼낸다. 형식은 docs/PUSH_PAYLOAD.md.
    static func route(from userInfo: [AnyHashable: Any]) -> String? {
        // 라우팅 값은 전부 data 에 담기로 계약돼 있다. FCM 은 data 를 최상위로 펼쳐준다.
        if let route = userInfo["route"] as? String, !route.isEmpty {
            return route
        }
        NSLog("[Nuplex] 알림에 route 가 없습니다. 홈으로 보냅니다.")
        return "/"
    }
}
