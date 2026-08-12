import UIKit
import Capacitor
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 알림 탭을 앱이 직접 받는다. 웹뷰의 JS 로는 처리할 수 없다 — 앱이 종료된
        // 상태에서 탭하면 웹뷰가 뜨기도 전에 이벤트가 오기 때문이다.
        UNUserNotificationCenter.current().delegate = self

        // TODO(phase-5b): Firebase 설정 파일이 들어오면 FirebaseApp.configure() 와
        //                 FCM 토큰 수신을 여기에 붙인다 (docs/FIREBASE_SETUP.md).
        return true
    }

    // MARK: - 원격 알림 등록

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // TODO(phase-5b): FCM 에 APNs 토큰을 넘긴다. 서버는 FCM 토큰 하나로 통일해
        //                 발송하므로(nuplex/lib/push/fcm.ts) 이 값을 직접 쓰지 않는다.
        NSLog("[Nuplex] APNs 등록 완료 (\(deviceToken.count) bytes)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // 시뮬레이터이거나 프로비저닝에 푸시 권한이 없는 경우가 대부분이다.
        // 앱이 죽을 이유는 아니다.
        NSLog("[Nuplex] APNs 등록 실패: \(error.localizedDescription)")
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// MARK: - 알림 수신 · 탭

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// 앱이 떠 있는 동안 도착한 알림. 기본 동작은 "표시하지 않음" 이라 명시해야 뜬다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    /// 알림 탭. 앱이 꺼져 있었다면 웹뷰가 준비되기 전에 여기로 온다 — 그래서 대기열이 있다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NuplexPush.offer(route: NuplexPush.route(from: userInfo)) { route in
            rootViewController()?.navigate(toRoute: route)
        }
        completionHandler()
    }

    private func rootViewController() -> NuplexViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .compactMap { $0 as? NuplexViewController }
            .first
    }
}
