# Phase 8 — TestFlight · 스토어 심사

- 상태: 진행 중 (2026-08-17 시작)
- **이 문서가 두 에이전트의 단일 진실 원천이다.** 규약은 `CLAUDE.md` §2.

소유자 표기 — `[Code]` 터미널 · `[Desktop]` GUI(Xcode·Chrome·시뮬레이터) · `[사람]` 사람만 가능.

## 0. 지금 상태 한 줄

**iOS `1.0.0 (1)` 이 TestFlight 에서 테스트 준비 완료**(2026-08-17). 시뮬레이터 검증은
푸시 라우팅·안전영역까지 전부 통과했고, **남은 것은 실기기에서의 Plex 딥링크**다.
Android 는 에뮬레이터에서 Plex 재생까지 확인됐다. 플랫폼별 결과는 `docs/test/`.

## A. iOS 검증 — 막혀 있던 것 [Desktop]

Claude Code 는 시뮬레이터를 탭할 수 없어 여기서 멈췄다(`CLAUDE.md` §2.1).
Desktop 은 GUI 를 쓸 수 있으니 이어받는다.

> **Desktop 도 시스템 UI 는 자동으로 못 누른다.** 시뮬레이터에 주입한 탭(HID)은 앱 화면과
> 홈 화면에는 전달되지만 **SpringBoard 가 그리는 계층 — 권한 다이얼로그 · 배너 · 알림 센터 —
> 에는 전달되지 않는다.** Return 키도 안 통한다. 이 항목들은 사람이 시뮬레이터 창을 한 번
> 클릭해 줘야 넘어간다. macOS 보조 접근으로 Simulator 앱을 직접 클릭하는 우회로가 있으나
> 이번 세션에서는 그 권한이 승인되지 않았다.

- [x] [Desktop] 시뮬레이터에서 온보딩 → **알림 권한 허용** → 홈까지 진입
      - iPhone 17 / iOS 26.5, Debug 빌드(프로덕션 주소 `https://nuplex.nugabox.com`)
      - 온보딩 "알림 받기" → 권한 다이얼로그 → **허용**(사람이 클릭) → 프로필 `백송이` →
        가입 이메일 확인 → 홈 히어로까지 진입 확인
      - 권한 상태를 로그로 확인 — `authorizationStatus: Authorized`, `didGrant: 1`,
        `alertSetting: Enabled`, `remoteNotifications: Enabled`
      - **함정**: 이메일 입력 후 소프트 키보드가 뜬 상태에서는 "확인" 버튼 탭이 먹지 않았다.
        Return 키로는 제출됐다. 주입 탭 한정 현상인지 실제 사용자에게도 나는지는 **미검증** —
        실기기(D절)에서 손으로 확인할 것
- [x] [Desktop] `xcrun simctl push` 로 공지 푸시 → 배너 표시 → **탭 → 해당 화면 이동**
      - 페이로드 예시는 `docs/TESTING.md` "푸시" 절
      - `aps` 옆에 `route`·`type` 을 최상위 키로 둔다
      - 배너 표시는 정상 (제목 `새 공지가 등록되었습니다` / 본문 `8월 서비스 점검 안내`,
        앱 아이콘 정상). 알림 센터에도 남는다. 로그 `shouldPresentAlert: 1`,
        `pipelineState: completed`
      - 처음엔 탭해도 홈에 머물렀다. 원인은 A-0-1(Capacitor 가 알림 델리게이트를
        가로챔). 고친 뒤 **통과** —
        `route: "/title/88793"` 으로 보내고 탭 → 로그
        `[Nuplex] 푸시 라우트로 이동: https://nuplex.nugabox.com/title/88793`,
        이어서 그 주소로 `브릿지 주입됨`. 화면도 그 작품(007 죽느냐 사느냐)이 떴다
- [ ] [Desktop] 앱 완전 종료 상태에서 알림 탭 → 콜드 스타트 라우팅
      (Android 에서는 통과한 경로. iOS 는 `NuplexPush.offer` 큐가 같은 역할)
      - A-0-1 을 고쳤으니 이제 볼 수 있다. 백그라운드 탭이 통과하면 이어서 확인한다
- [ ] [Desktop] 오프라인 화면 — 네트워크 끊고 실행 → 흰 화면이 아닌 오프라인 화면
      - 막힘: 맥의 네트워크를 끊지 않고는 `Network.getStatus().connected === false` 분기를
        탈 수 없다. 시뮬레이터에는 비행기 모드가 없다. **이 분기는 미검증**
      - 대신 "웹 주소에 닿지 못하는" 상황을 만들어 봤다(`VITE_WEB_BASE_URL=https://localhost:9`).
        결과가 좋지 않다 → 아래 A-0-3 참고
- [x] [Desktop] 노치·홈 인디케이터 침범 없음 — **고쳐서 통과**
      - 처음엔 **실패(상단)였다.** 로그인 후 웹 헤더가 상태바·다이나믹 아일랜드를 침범한다.
        시계가 `NUPLEX` 로고 위에 겹치고, 프로필 아바타가 배터리 아이콘과 겹친다
      - **눈에 보이는 문제로 끝나지 않는다.** 헤더의 채팅·알림 아이콘을 탭하면 버튼이
        아니라 **iOS 상태바가 탭을 먹어 페이지가 맨 위로 스크롤**된다. 즉 그 버튼들은
        사실상 누를 수 없다
      - 원인은 웹 쪽이다 — `nuplex/components/navbar.tsx:83` 이 `fixed inset-x-0 top-0` 인데
        저장소 전체에 `env(safe-area-inset-*)` 사용이 없다. 셸 자체 화면
        (`shell/public/styles/shell.css:33`)은 안전영역을 제대로 쓰고 있어 멀쩡하다
      - **채팅·알림·홈정렬 모달도 같은 문제였다.** 셋 다 `fixed inset-0 ... p-4` 라
        제목과 닫기(X) 버튼이 상태바에 깔렸다
      - 조치: 헤더와 모달 셋에 안전영역 여백을 넣고 **운영에 배포했다**
        (웹 커밋 `ff4580e`, `81511bb`)
      - 배포 후 재확인 — 헤더가 상태바 아래로 내려왔고, 가려져 있던 검색 아이콘이
        드러났으며, **채팅 아이콘 탭이 정상 동작**한다(모달이 열린다). 모달 제목·X 도
        상태바를 침범하지 않는다
      - 하단 홈 인디케이터 침범은 없다 — 모달 버튼도 충분히 위에 있다
      - → 아래 A-0-2

### A-0. 이번에 나온 세 건

원래는 `CLAUDE.md` §2.2-6 대로 [Code] 에 넘길 항목이었으나, **사람이 직접 진행하라고 해서
Desktop 이 1·2 를 고쳤다.** [Code] 는 같은 파일을 다시 건드리기 전에 이 절을 먼저 읽을 것.

1. ~~**[Code] iOS 알림 탭 라우팅이 동작하지 않는다**~~ → **Desktop 이 고쳤다** (커밋 `0671b83`)
   - **원인: Capacitor 가 알림 델리게이트를 가로챈다.**
     `SceneDelegate.scene(_:willConnectTo:)` 안에서 부르는
     `SceneDelegateProxy.shared.scene(_:willConnectTo:options:)` 가
     `UNUserNotificationCenter.current().delegate` 를 Capacitor 의 `NotificationRouter`
     로 바꿔치운다. `AppDelegate.didFinishLaunching` 에서 걸어 둔 것이 그 직후 덮인다
   - 그래서 우리 핸들러가 **한 번도** 불리지 않았다. 증상 둘 —
     · 알림을 눌러도 `didReceive` 가 안 불려 `route` 로 이동하지 않는다
     · 앱이 떠 있으면 `NotificationRouter` 가 표시 옵션 0 으로 답해 배너 자체가 안 뜬다
   - 조치: 프록시 호출 **뒤에** 델리게이트를 도로 가져온다. 셸은 Capacitor 푸시
     플러그인을 쓰지 않고 알림을 네이티브에서 직접 처리하므로 잃는 것이 없다
   - 검증 둘 다 통과 —
     · 포그라운드 푸시에서 시스템 로그의 `shouldPresentAlert` 가 **NO → YES**
       (`Received response 0` 도 사라짐)
     · 백그라운드 알림 탭 → `[Nuplex] 푸시 라우트로 이동: …/title/88793` 로그와
       실제 화면 이동 확인
   - **찾는 데 오래 걸린 이유를 남긴다.** 처음엔 `rootViewController()` 가 nil 이라
     조용히 끝나는 것으로 진단했는데 **틀렸다.** 진단용 로그를 넣어 보니 핸들러
     자체가 안 불렸다. Firebase 스위즐링도 의심해 `FirebaseAppDelegateProxyEnabled`
     를 꺼 봤지만 무관했다(되돌림). 결국 생명주기 시점마다 델리게이트 클래스명을
     찍어서야 `AppDelegate → NotificationRouter` 로 바뀌는 순간이 잡혔다.
     **로그가 없다는 사실만으로 코드 경로를 추론하면 틀릴 수 있다** — 계측이 빨랐다
   - 곁가지로 `rootViewController()` 를 `NuplexViewController.current` 로 통일하고
     못 찾을 때 로그를 남기게 했다(커밋 `1510984`). 조용한 실패를 없애기 위함이다

2. **웹 안전영역** — `nuplex` 저장소. **Desktop 이 고치고 배포까지 했다**
   (웹 커밋 `ff4580e` 헤더, `81511bb` 모달).
   - 근거(추측 아님): 배포된 HTML 은 `viewport-fit=cover` 를 켜 두었는데
     **배포된 CSS 번들 55,951바이트 안에 `safe-area-inset` 이 0회**였다.
     `app/layout.tsx:52` 주석이 "이걸 켰으면 `env(safe-area-inset-*)` 로 여백을 줘야
     한다" 고 스스로 적어 두고 지키지 않은 상태였다
   - 변경 둘 —
     · `components/navbar.tsx` `<header>` 에 `pt-[env(safe-area-inset-top)]`.
       안쪽 `h-16`(64px) 행은 그대로라 총 높이가 `inset + 64px` 가 된다.
       배경 그라디언트가 `h-[130%]` 라 늘어난 높이를 그대로 덮는다
     · `chat-panel` · `notice-bell` · `home-order-modal` 세 모달의
       `fixed inset-0 … p-4` 에 위아래 안전영역 여백. 셋이 같은 클래스 문자열을 쓴다
   - **고정값을 박지 않았다.** iPhone 17(다이나믹 아일랜드) 59pt · 노치 세대 47pt ·
     홈버튼 세대 20pt 로 기기마다 다르다. 브라우저에서는 inset 이 0 이라 변화 없다
   - 배포 후 시뮬레이터에서 눈으로 확인했다(위 체크 항목)

3. **[Code] 웹 이동 실패가 오프라인 화면으로 안 간다(의심)** — 재현: `VITE_WEB_BASE_URL`
   을 닿지 않는 주소로 주고 실행(`https://localhost:9`, `allowNavigation` 에 있는 호스트).
   - 캐시된 설정이 있어 부팅은 통과하고 `Preferences` 에 `webBaseUrl=https://localhost:9`
     까지 기록된다 = `main.ts:107` 의 `goTo(target)` 에 도달했다
   - 그런데 **`NuplexNavigationProxy` 의 실패 콜백이 오지 않는다.** 로그에
     `[Nuplex] 웹 로드 실패 → 오프라인 화면으로` 가 없고, 그 주소로 나가는 요청 로그도 없다.
     화면은 스플래시에 무한정 머문다
   - 평문 `http://` 주소(`http://127.0.0.1:9`, `http://localhost:9`)도 같다. `127.0.0.1` 은
     `allowNavigation` 에 없어서 그런 것이지만 `localhost` 는 목록에 있다
   - **ADR-001 과 설계 명세 §9.4 가 막으려던 바로 그 상태**(흰 화면/멈춤)로 보인다.
     다만 재현이 합성 시나리오라 실제 네트워크 단절에도 같은지는 미확정 —
     실제 단절은 `main.ts:56` 에서 먼저 걸러지므로 이 경로를 안 탈 수도 있다.
     **원인 확인이 필요하다**(Capacitor 가 이동을 외부로 넘겨 델리게이트가 안 불리는지 등)
   - 곁가지: `docs/TESTING.md` 는 iOS 개발 시 `VITE_WEB_BASE_URL=http://localhost:2777` 을
     쓰라고 하는데, 위가 사실이면 **그 방법 자체가 iOS 에서 동작하지 않는다.** Phase 7 이
     iOS 를 거의 못 돌려본 탓에 안 드러났을 수 있다

### A-1. iOS Plex 딥링크 [Desktop] + [사람]

**스킴 형식은 Android APK 에서 뽑은 근거다. iOS 는 미검증.**
시뮬레이터에는 Plex 를 설치할 수 없으므로 **실기기가 필요하다.**

- [ ] [사람] iPhone 에 Plex 설치 + 로그인
- [ ] [Desktop] 영화 상세 → "Plex에서 시청하기" → Plex 앱에서 **그 작품**이 열리는가
- [ ] [Desktop] 시리즈 → 웹 폴백(Plex Web 상세)으로 가는가
- [ ] [Desktop] Plex 삭제 상태 → App Store 의 Plex 페이지

**안 되면** iOS Plex 앱의 URL types 를 확인해 형식을 찾는다. Android 에서 쓴 방법이
그대로 통한다 — 자세한 절차와 근거는 `docs/PLEX_DEEPLINK.md`.
찾은 형식은 `NuplexBridgeAPI.swift` 의 `deepLinkLadder` 에 넣는다 → **[Code] 에 요청으로 남길 것.**

## B. 계정 · 인증서 [사람] + [Desktop]

서비스 계정 업로드는 **앱이 한 번 등록된 뒤에만** 동작한다. 여기가 먼저다.

- [x] [사람] Apple Developer Program 가입 상태 확인 (연 $99, 갱신 여부)
      - 가입돼 있고 유효하다고 확인받음 (2026-08-17)
> **사람이 직접 해야 하는 것** — 비밀번호·키 취급이라 대신하지 않는다:
> Apple ID 로그인(2단계 인증), `.p8` · `.p12` 다운로드와 보관, GitHub Secrets 등록,
> 유료 계약 동의.
>
> **Claude in Chrome 확장이 끊기면 Desktop 은 브라우저를 조작할 수 없다.**
> 화면을 읽는 것까지는 되지만 클릭·입력이 안 된다. 끊겼으면 사람이 Chrome 의
> Claude 사이드 패널에서 다시 로그인해야 한다.

- [x] [사람] Chrome 에서 App Store Connect 로그인
- [x] [사람] App Store Connect 에 앱 생성 — Bundle ID `com.nugabox.nuplex`, 이름 `NUPLEX`
      - 2026-08-17 확인. **App ID `6802186306`**, `iOS 앱 버전 1.0`,
        상태 `1.0 제출 준비 중`
      - 남은 것: **미리보기·스크린샷 0/10** (iPhone 6.5" 디스플레이 필요),
        개인정보 처리방침 URL, 연령 등급 — E절에서 다룬다
- [ ] [사람] App Store Connect API 키 발급 (Issuer ID · Key ID · `.p8`)
      - **`.p8` 은 재다운로드 불가.** 받는 즉시 안전한 곳에 원본 보관
      - 키 파일 취급이라 [Desktop] → **[사람]** 으로 소유자를 옮긴다
- [x] 배포 인증서 + 프로비저닝 프로파일 — **따로 만들 필요 없었다**
      - `xcodebuild -allowProvisioningUpdates` 가 자동으로 만들었다(로컬 업로드 때 확인).
        CI 도 API 키를 넘겨 같은 방식으로 처리한다
- [ ] [사람] GitHub Secrets 4개 등록 — `.github/workflows/ios-release.yml` 상단 주석
      - `APPSTORE_ISSUER_ID` · `APPSTORE_KEY_ID` · `APPSTORE_PRIVATE_KEY`(.p8 내용)
      - **API 키 권한은 `Admin` 이어야 한다.** `App Manager` 로 만들면 내보내기에서
        `Cloud signing permission error` · `No signing certificate "iOS Distribution" found`
        로 끝난다. 클라우드 관리 배포 인증서 접근이 Admin 에만 열려 있다 (2026-08-21 확인)
      - `GOOGLE_SERVICE_INFO_PLIST`
      - **인증서(.p12)·프로비저닝 프로파일은 이제 필요 없다.** API 키를 xcodebuild 에
        넘기면 자동 서명이 CI 에서도 동작한다(커밋 `4ef7a6c`)
      - 이게 없으면 **매달 도는 TestFlight 갱신이 실패한다** — 90일 만료 방지용이다
- [ ] [Desktop] Play Console 에 앱 등록 + 업로드 키스토어 생성
- [ ] [사람] Android Secrets 등록 — `.github/workflows/android-release.yml` 상단 주석

## C. 릴리스 파이프라인 [Code]

- [x] [Desktop] `exportOptions.plist` 추가 — `ios/App/exportOptions.plist`
      - `method: app-store-connect`, `teamID: U5796QB9C8`, 자동 서명
      - **아카이브는 개발 인증서로 서명돼 나온다.** 배포 서명은 내보내기 단계에서 붙으므로
        `xcodebuild -exportArchive` 에 `-allowProvisioningUpdates` 를 반드시 함께 넘긴다
- [ ] [Code] `ios-release.yml` 의 IPA 내보내기·업로드 주석 해제
      (CI 는 GitHub Secrets 의 인증서·API 키가 있어야 돌아간다)
- [ ] [Code] `assetlinks.json` — App Links 검증용. **업로드 키의 SHA-256 지문이 필요**하므로
      B 이후에 가능. `nuplex` 웹의 `/.well-known/` 에 배포한다
- [x] [Code] CI iOS 잡이 `GoogleService-Info.plist` 부재로 실패하던 것 수정
      (자리표시자 생성. 로컬에서 exit 65 재현 → 수정 후 BUILD SUCCEEDED 확인)

## D. TestFlight [Desktop]

- [x] [Desktop] 로컬에서 배포 서명 IPA 생성 (2026-08-17)
      - 배포용 인증서가 없었는데 `-allowProvisioningUpdates` 로 Xcode 가 만들었다
      - 결과: `Authority=Apple Distribution: Nuga Jang (U5796QB9C8)`,
        `1.0.0` / 빌드 `1`, 번들에 개발 주소 없음(프로덕션 `nuplex.nugabox.com`)
      - 아카이브를 `~/Library/Developer/Xcode/Archives/<오늘>/NUPLEX 1.0.0 (1).xcarchive`
        에 넣어 뒀다 — **Xcode > Window > Organizer 에서 바로 Distribute App 이 된다**
      - `ITSAppUsesNonExemptEncryption = false` 를 Info.plist 에 선언했다.
        없으면 올릴 때마다 수출 규정 답변을 기다리며 빌드가 멈춘다
- [x] [Desktop] TestFlight 업로드 완료 (2026-08-17 21:12)
      - **자격증명 없이 올리는 길이 있다.** `exportOptions.plist` 에
        `destination: upload` 을 넣고 `xcodebuild -exportArchive` 를 돌리면
        **Xcode 에 로그인된 세션**으로 업로드한다. Organizer 의 Distribute App 과 같은 경로다.
        `altool` 은 API 키나 앱 암호를 따로 요구하지만 이쪽은 필요 없다
      - 이 맥에는 API 키(`~/.appstoreconnect/private_keys/`)도 Transporter 도 없다
- [ ] [Code] 태그 `v1.0.0` 푸시 → `ios-release.yml` 이 TestFlight 업로드 (CI 경로)
- [x] [Desktop] App Store Connect → TestFlight 에서 빌드 처리 완료 확인
      - `1.0.0 (1)` — 처리 중 → **테스트 준비 완료**, 90일 후 만료
- [x] [Desktop] 수출 규정(Export Compliance) — Info.plist 에 면제 선언을 박아 해결
      - 업로드 뒤 대기 없이 바로 `테스트 준비 완료` 로 넘어간 것으로 확인
- [x] [Desktop] 내부 테스터 초대
      - 내부 그룹 `Internal` 생성(자동 배포 켬 — 이후 빌드도 자동으로 간다)
      - `root@nugabox.com`(JangNuga, 계정 소유자) 추가 → 상태 `초대됨`
      - **내부 테스트는 Beta App Review 를 거치지 않는다.** 초대 메일의 링크로 바로 설치된다
- [ ] [사람] 실기기 설치 → `docs/test/ios.md` 의 ★ 항목 확인
      - 특히 **Plex 딥링크**. 스킴은 Android APK 근거라 iOS 는 형식이 다를 수 있다
- [ ] [Desktop] Play Console 내부 테스트 트랙에 AAB 올라갔는지 확인

## E. 심사 제출 [Desktop]

`docs/RELEASE.md` "스토어 심사" 절을 그대로 따른다. **리젝 사유 두 개가 예상된다.**

- [x] [Desktop] Guideline 4.2 대비 — 설명에 네이티브 고유 기능(푸시 알림 · 오프라인 화면 ·
      Plex 앱 연동)을 명시. "웹사이트를 감싼 앱" 으로 보이면 리젝된다
      - 2026-08-17 초안 작성·저장. `■ 앱에서만 되는 것` 절에 셋을 앞세웠다
- [x] [Desktop] **Review Notes 에 심사자용 진입 방법**을 적는다. 이걸 빼면 입장 화면에서
      막혀 그대로 리젝된다. **공통 비밀번호는 없다** — 프로필을 고르고 그 프로필의
      가입 이메일을 넣는 방식이다. 계정은 `docs/TESTING.md`
      - 진입 4단계 · 알림/Plex/오프라인 확인법 · 앱 성격을 적었다
      - **계정 두 줄은 비워 뒀다** — 아래 [사람] 항목 참고
- [x] [Desktop] 메타데이터 초안 — 프로모션 텍스트 · 설명 · 키워드 · 지원 URL ·
      마케팅 URL · 저작권. 저장 후 새로고침으로 반영 확인
- [ ] [사람] Review Notes 의 **심사용 프로필 이름과 이메일**을 채운다
      - Desktop 이 채우지 않은 이유: 실존 인물의 개인 Gmail 을 Apple 에 넘기게 된다.
        **심사 전용 프로필을 하나 만들어 그 계정을 적는 편이 안전하다**
- [ ] [사람] `앱 심사 정보 > 로그인 정보` 의 사용자 이름·암호
      - 비밀번호 입력은 에이전트가 하지 않는다. 이 앱은 원래 비밀번호가 없으므로
        사용자 이름에 프로필명, 암호에 가입 이메일을 넣는 방식이 된다.
        메모에 진입 절차를 적어 뒀으니 그대로 따라가면 된다
- [ ] [Desktop] 스크린샷 — 6.5" 규격 `1242 × 2688`
      - 규격에 맞는 시뮬레이터(`NUPLEX-6.5`, iPhone 11 Pro Max / iOS 17.2)를 만들고
        앱까지 설치해 뒀다. **기기 접근 승인이 나면 바로 찍는다**
      - iPhone 17 은 `1206 × 2622` 라 App Store 가 받지 않는다
- [ ] [사람] **개인정보 처리방침 URL — 없다.** 필수 항목인데 웹에 해당 페이지가 없다
      (`/privacy` 는 307). 페이지를 만들어야 제출이 된다
- [ ] [Desktop] 연령 등급
- [ ] [Desktop] 심사 제출 → 결과 확인. **리젝되면 사유 원문을 이 문서에 붙일 것**

### E-1. 미리 짚어 둘 위험

**Guideline 4.2 보다 5.2(지식재산권)가 더 걸릴 수 있다.** 이 앱은 개인 Plex 서버에 있는
상용 영화·애니메이션 목록을 보여준다. 심사자가 배포 권한을 물을 수 있다.
4.2 대비 문구만으로는 이 지점이 방어되지 않는다 — 제출 전에 어떻게 답할지 정해 둘 것.

또 하나, **초대제라 심사자가 스스로 가입할 수 없다.** Review Notes 의 계정이
살아 있지 않으면 그대로 리젝이다. 제출 직전에 그 계정으로 실제로 들어가 볼 것.

## F. 심사 통과 후 [Code]

- [ ] [Code] 웹 `.env` 의 `APP_STORE_URL_IOS` · `APP_STORE_URL_ANDROID` 채우기
      (지금 비어 있어 강제 업데이트 화면의 스토어 버튼이 안 뜬다)
- [ ] [Code] `APP_MIN_SUPPORTED_VERSION` 은 **스토어에 새 버전이 실제로 올라간 뒤에** 올린다

## 막힘 기록

- **iOS 시스템 UI 를 자동으로 못 누른다** (2026-08-17, Desktop). 시뮬레이터에 주입한 탭은
  앱 화면·홈 화면에는 가지만 SpringBoard 계층(권한 다이얼로그·배너·알림 센터)에는 안 간다.
  Return 키도 안 통한다. 사람이 "허용" 과 알림 탭을 대신 눌러 A-2 까지는 진행했다.
  넘기는 방법 둘 — (a) 사람이 시뮬레이터에서 한 번 눌러 준다, (b) macOS 보조 접근으로
  Simulator 앱을 제어할 권한을 준다. 실기기(D절)에서는 어차피 손으로 하게 된다.

- **오프라인 분기를 시뮬레이터에서 못 만든다** (2026-08-17, Desktop). 비행기 모드가 없고
  맥 네트워크를 끊는 건 범위 밖이라 판단했다. 위 A-0-2 참고.

곁가지로 확인된 것 — 시뮬레이터에서도 **FCM 토큰은 발급된다**
(`[Nuplex] FCM 토큰 수신`, `Preferences` 의 `nuplex.lastRegisteredToken` 에 저장됨).
`docs/TESTING.md` 가 암시하는 것과 달리 토큰 경로 확인에 실기기가 꼭 필요하지는 않다.
다만 서버 등록(`POST /api/app/push/token`) 성공 여부는 따로 안 봤다 — **미검증.**

## G. TV 캐스트 1단계 (2026-08-20) [Code]

`docs/PLEX_CAST.md` 에 근거가 있다. **코드는 양 저장소에 들어갔고 빌드까지 통과했다.**

- [x] [Code] 명령 형식을 실기기로 확정 — iPhone 브라우저 → Apple TV 재생 성공
- [x] [Code] 브릿지 v2 — `listCastTargets` · `castToTarget` · `openRoutePicker`
      (`ios/App/App/NuplexCast.swift` · `android/.../NuplexCast.java`)
- [x] [Code] 플랫폼 설정 — iOS `NSAllowsLocalNetworking` + 로컬 네트워크 권한 문구,
      Android 사설 대역만 여는 `network_security_config.xml`
- [x] [Code] 웹 — 시청하기 모달(`components/watch-menu.tsx`) + 후보 API
      (`app/api/app/cast/targets/route.ts`). **커밋만 했고 푸시하지 않았다** —
      웹 main 푸시는 곧 운영 배포다
- [ ] [사람] 실기기 확인 — TestFlight 새 빌드 설치 → 같은 WiFi 에서 모달의 TV 항목
      → 재생. **TV 에서 Plex 앱을 먼저 켜 둘 것**(안 켜면 명령을 못 받는다)
- [ ] [Code] 웹 배포 (사람 확인 후)

### Desktop 이 알아야 할 것

**`ios/App/App.xcodeproj/project.pbxproj` 를 건드렸다.** `NuplexCast.swift` 를 빌드에
넣기 위한 파일 참조 4줄 추가뿐이고 서명·Capabilities 는 손대지 않았다.
Xcode 에서 프로젝트를 열어 두었다면 되읽어야 충돌하지 않는다.

### 미검증 · 남은 위험

- **셸에서의 캐스트는 아직 안 돌려봤다.** 브라우저로 형식만 검증했다. 실기기 확인 전이다
- **가족 각자의 TV 는 아직 안 보인다.** 후보 목록이 서버 소유자 Plex 계정 기준이라,
  다른 계정으로 로그인한 TV 는 목록에 없다. 프로필 ↔ Plex 계정 연결이 2단계다
- **후보 API 응답에 Plex 토큰이 들어간다.** 프로필 관문 뒤지만 계정 전체 권한을 가진
  값이라 좋은 상태가 아니다. 위 연결 작업이 붙으면 각자의 토큰으로 바뀌며 해소된다
- **iOS 의 AirPlay 피커는 반쪽이다.** 앱에 네이티브 재생 세션이 없어 골라도 아무 일이
  일어나지 않는다. "여기서 시청하기"(2단계)가 붙어야 온전해진다
- 곁가지 — 웹 빌드 결과에 **`/privacy` 가 정적 페이지로 잡힌다.** E절에서 "없다" 고
  적어 둔 개인정보 처리방침이 생긴 것으로 보인다. **제출 전에 실제 내용을 확인할 것**
