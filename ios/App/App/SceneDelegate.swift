import UIKit
import Capacitor
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        // 기본 CAPBridgeViewController 대신 브릿지 주입을 얹은 서브클래스를 쓴다.
        // 원격 페이지에는 셸이 직접 window.NuplexNative 를 넣어야 한다(ADR-001).
        window?.rootViewController = NuplexViewController()
        window?.makeKeyAndVisible()

        SceneDelegateProxy.shared.scene(scene, willConnectTo: session, options: connectionOptions)

        // **이 줄을 지우면 알림이 다시 죽는다.**
        //
        // 바로 위 SceneDelegateProxy 가 UNUserNotificationCenter 의 델리게이트를
        // Capacitor 의 NotificationRouter 로 바꿔치운다. AppDelegate 가
        // didFinishLaunching 에서 자기를 델리게이트로 걸어 두지만 이 시점에 덮인다.
        //
        // 그 결과가 조용해서 오래 못 찾았다 —
        //   · 알림을 눌러도 didReceive 가 안 불려 route 로 이동하지 않는다
        //   · 앱이 떠 있을 때는 NotificationRouter 가 표시 옵션 0 으로 답해
        //     배너 자체가 안 뜬다 (시스템 로그의 `Received response 0`)
        //
        // 셸은 Capacitor 푸시 플러그인을 쓰지 않고 알림을 네이티브에서 직접
        // 처리하므로(docs/PUSH_PAYLOAD.md) 델리게이트를 도로 가져온다.
        UNUserNotificationCenter.current().delegate =
            UIApplication.shared.delegate as? UNUserNotificationCenterDelegate
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        SceneDelegateProxy.shared.scene(scene, openURLContexts: URLContexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        SceneDelegateProxy.shared.scene(scene, continue: userActivity)
    }
}
