import Foundation

/**
 셸 JS 가 남긴 값을 네이티브에서 읽는다.

 @capacitor/preferences 는 UserDefaults.standard 에 `CapacitorStorage.` 접두어를 붙여
 저장한다(Preferences.swift). Capacitor 의 내부 구현에 기대는 것이므로, 키 이름은
 src/config/constants.ts 의 STORAGE_KEYS 와 반드시 함께 고친다.
 */
enum NuplexPreferences {

    private static let prefix = "CapacitorStorage."
    private static let webBaseUrlKey = "nuplex.webBaseUrl.v1"

    /// 원격 설정을 아직 한 번도 못 받았을 때 쓰는 값. constants.ts 와 같아야 한다.
    private static let defaultWebBaseUrl = "https://nuplex.nugabox.com"

    static var webBaseUrl: String {
        let stored = UserDefaults.standard.string(forKey: prefix + webBaseUrlKey)
        guard let stored, !stored.isEmpty else { return defaultWebBaseUrl }
        // 끝의 슬래시가 남아 있으면 route 를 붙일 때 // 가 된다.
        var trimmed = stored
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed
    }
}
