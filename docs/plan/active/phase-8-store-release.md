# Phase 8 — TestFlight · 스토어 심사

- 상태: 진행 중 (2026-08-17 시작)
- **이 문서가 두 에이전트의 단일 진실 원천이다.** 규약은 `CLAUDE.md` §2.

소유자 표기 — `[Code]` 터미널 · `[Desktop]` GUI(Xcode·Chrome·시뮬레이터) · `[사람]` 사람만 가능.

## 0. 지금 상태 한 줄

코드는 양 플랫폼 다 빌드되고 **Android 는 에뮬레이터에서 전 기능 검증됨**(Phase 7).
**iOS 는 상호작용 미검증**이고, 스토어 계정·인증서·앱 등록이 아직 없다.

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
- [ ] [Desktop] `xcrun simctl push` 로 공지 푸시 → 배너 표시 → **탭 → 해당 화면 이동**
      - 페이로드 예시는 `docs/TESTING.md` "푸시" 절
      - `aps` 옆에 `route`·`type` 을 최상위 키로 둔다
      - **여기까지 됨**: 앱 백그라운드 상태로 `simctl push` → 배너 정상 표시
        (제목 `새 공지가 등록되었습니다` / 본문 `8월 서비스 점검 안내`, 앱 아이콘 정상).
        알림 센터에도 남는다. 로그 `shouldPresentAlert: 1`, `pipelineState: completed`
      - 막힘: **배너·알림 센터 탭이 자동화로 안 눌린다**(위 상자). 탭 이후 라우팅 미검증
- [ ] [Desktop] 앱 완전 종료 상태에서 알림 탭 → 콜드 스타트 라우팅
      (Android 에서는 통과한 경로. iOS 는 `NuplexPush.offer` 큐가 같은 역할)
      - 막힘: 위와 같은 이유로 알림 탭을 못 한다
- [ ] [Desktop] 오프라인 화면 — 네트워크 끊고 실행 → 흰 화면이 아닌 오프라인 화면
      - 막힘: 맥의 네트워크를 끊지 않고는 `Network.getStatus().connected === false` 분기를
        탈 수 없다. 시뮬레이터에는 비행기 모드가 없다. **이 분기는 미검증**
      - 대신 "웹 주소에 닿지 못하는" 상황을 만들어 봤다(`VITE_WEB_BASE_URL=https://localhost:9`).
        결과가 좋지 않다 → 아래 A-2 요청 참고
- [ ] [Desktop] 노치·홈 인디케이터 침범 없음
      - **실패(상단).** 로그인 후 웹 헤더가 상태바·다이나믹 아일랜드를 침범한다.
        시계가 `NUPLEX` 로고 위에 겹치고, 프로필 아바타가 배터리 아이콘과 겹친다
      - **눈에 보이는 문제로 끝나지 않는다.** 헤더의 채팅·알림 아이콘을 탭하면 버튼이
        아니라 **iOS 상태바가 탭을 먹어 페이지가 맨 위로 스크롤**된다. 즉 그 버튼들은
        사실상 누를 수 없다
      - 원인은 웹 쪽이다 — `nuplex/components/navbar.tsx:83` 이 `fixed inset-x-0 top-0` 인데
        저장소 전체에 `env(safe-area-inset-*)` 사용이 없다. 셸 자체 화면
        (`shell/public/styles/shell.css:33`)은 안전영역을 제대로 쓰고 있어 멀쩡하다
      - 하단 홈 인디케이터는 스크롤 콘텐츠뿐이라 침범 없음. 고정 하단 바가 있는 화면
        (채팅 입력창)은 헤더 버튼을 못 눌러 진입하지 못했다 — **미검증**
      - → 아래 A-1 요청

### A-0. [Code] 에 넘기는 요청

Desktop 은 `src/`·`ios/`·웹 저장소를 고치지 않는다(CLAUDE.md §2.2-6). 확인한 것만 남긴다.

1. **[Code] 웹 헤더 안전영역** — `nuplex` 저장소 `components/navbar.tsx:83`.
   `fixed ... top-0` 에 `env(safe-area-inset-top)` 만큼 패딩을 준다. 안 하면 iOS 에서
   헤더 버튼이 상태바에 먹혀 눌리지 않는다(위 증상). **심사 전에 고쳐야 한다** —
   심사자가 채팅·알림에 못 들어간다.
2. **[Code] 웹 이동 실패가 오프라인 화면으로 안 간다(의심)** — 재현: `VITE_WEB_BASE_URL`
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

- [ ] [사람] Apple Developer Program 가입 상태 확인 (연 $99, 갱신 여부)
- [ ] [Desktop] App Store Connect 에 앱 생성 — Bundle ID `com.nugabox.nuplex`, 이름 `NUPLEX`
- [ ] [Desktop] App Store Connect API 키 발급 (Issuer ID · Key ID · `.p8`)
      - **`.p8` 은 재다운로드 불가.** 받는 즉시 안전한 곳에 원본 보관
- [ ] [Desktop] 배포 인증서(.p12) + 프로비저닝 프로파일 생성
- [ ] [사람] 위 값들을 GitHub Secrets 에 등록 — 이름은 `.github/workflows/ios-release.yml` 상단 주석
- [ ] [Desktop] Play Console 에 앱 등록 + 업로드 키스토어 생성
- [ ] [사람] Android Secrets 등록 — `.github/workflows/android-release.yml` 상단 주석

## C. 릴리스 파이프라인 [Code]

- [ ] [Code] `exportOptions.plist` 추가 후 `ios-release.yml` 의 IPA 내보내기·업로드 주석 해제
      (B 의 인증서가 있어야 실제로 돌려볼 수 있다)
- [ ] [Code] `assetlinks.json` — App Links 검증용. **업로드 키의 SHA-256 지문이 필요**하므로
      B 이후에 가능. `nuplex` 웹의 `/.well-known/` 에 배포한다
- [x] [Code] CI iOS 잡이 `GoogleService-Info.plist` 부재로 실패하던 것 수정
      (자리표시자 생성. 로컬에서 exit 65 재현 → 수정 후 BUILD SUCCEEDED 확인)

## D. TestFlight [Desktop]

- [ ] [Code] 태그 `v1.0.0` 푸시 → `ios-release.yml` 이 TestFlight 업로드
- [ ] [Desktop] App Store Connect → TestFlight 에서 빌드 처리 완료 확인
- [ ] [Desktop] 수출 규정(Export Compliance) 응답 — HTTPS 만 쓰므로 면제 대상
- [ ] [Desktop] 내부 테스터 초대 → 실기기 설치 → §A 확인 목록 재확인
- [ ] [Desktop] Play Console 내부 테스트 트랙에 AAB 올라갔는지 확인

## E. 심사 제출 [Desktop]

`docs/RELEASE.md` "스토어 심사" 절을 그대로 따른다. **리젝 사유 두 개가 예상된다.**

- [ ] [Desktop] Guideline 4.2 대비 — 설명에 네이티브 고유 기능(푸시 알림 · 오프라인 화면 ·
      Plex 앱 연동)을 명시. "웹사이트를 감싼 앱" 으로 보이면 리젝된다
- [ ] [Desktop] **Review Notes 에 심사자용 진입 방법**을 적는다. 이걸 빼면 입장 화면에서
      막혀 그대로 리젝된다. **공통 비밀번호는 없다** — 프로필을 고르고 그 프로필의
      가입 이메일을 넣는 방식이다. 계정은 `docs/TESTING.md`
- [ ] [Desktop] 스크린샷 · 개인정보 처리방침 URL · 연령 등급
- [ ] [Desktop] 심사 제출 → 결과 확인. **리젝되면 사유 원문을 이 문서에 붙일 것**

## F. 심사 통과 후 [Code]

- [ ] [Code] 웹 `.env` 의 `APP_STORE_URL_IOS` · `APP_STORE_URL_ANDROID` 채우기
      (지금 비어 있어 강제 업데이트 화면의 스토어 버튼이 안 뜬다)
- [ ] [Code] `APP_MIN_SUPPORTED_VERSION` 은 **스토어에 새 버전이 실제로 올라간 뒤에** 올린다

## 막힘 기록

- **iOS 시스템 UI 를 자동으로 못 누른다** (2026-08-17, Desktop). 시뮬레이터에 주입한 탭은
  앱 화면·홈 화면에는 가지만 SpringBoard 계층(권한 다이얼로그·배너·알림 센터)에는 안 간다.
  Return 키도 안 통한다. 이번엔 사람이 "허용" 을 눌러 권한은 넘겼고, **알림 탭이 필요한
  A-2·A-3 는 아직 막혀 있다.** 넘기는 방법 둘 —
  (a) 사람이 시뮬레이터에서 알림을 한 번 탭한다, (b) macOS 보조 접근으로 Simulator 앱을
  제어할 권한을 준다(이번 세션엔 거부됨). 실기기(D절)에서는 어차피 손으로 하게 된다.

- **오프라인 분기를 시뮬레이터에서 못 만든다** (2026-08-17, Desktop). 비행기 모드가 없고
  맥 네트워크를 끊는 건 범위 밖이라 판단했다. 위 A-0-2 참고.

곁가지로 확인된 것 — 시뮬레이터에서도 **FCM 토큰은 발급된다**
(`[Nuplex] FCM 토큰 수신`, `Preferences` 의 `nuplex.lastRegisteredToken` 에 저장됨).
`docs/TESTING.md` 가 암시하는 것과 달리 토큰 경로 확인에 실기기가 꼭 필요하지는 않다.
다만 서버 등록(`POST /api/app/push/token`) 성공 여부는 따로 안 봤다 — **미검증.**
