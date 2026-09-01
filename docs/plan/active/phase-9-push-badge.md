# Phase 9 — 알림 푸시 · 배지 검증

- 시작: 2026-09-01. 계정 전환(로그아웃 → 재로그인) 상황에서 푸시와 배지가 맞게
  가는지 확인하려고 시작했다
- 결론부터: **배지는 Android 에서 동작한다. 다만 계정을 바꿔도 푸시 대상이 바뀌지
  않는다** — 남의 공지를 받는다

## 1. 검증 환경

| | 내용 |
| --- | --- |
| Android | Galaxy S22 (SM-S901N), Android 16, One UI. 실기기 |
| 앱 | versionName 1.0.0 / versionCode 1 (2026-08-25 설치). `git log --since` 로 그 뒤 `android/` · `shell/` · `src/` 변경 없음을 확인하고 재설치 없이 진행 |
| 서버 | 운영 (`nuplex.nugabox.com`). 실제 FCM 발송 |
| 계정 | 관리자 NUGA(profileId 1) · 사용자 백송이(profileId 14) |
| 발송 | 관리자 세션을 `POST /api/profile/select` 로 받아 API 직접 호출. 공지는 `targetProfileIds` 를 항상 지정해 전체 브로드캐스트를 피했다 |
| iOS | **미검증** — 아래 §5 |

## 2. Android 검증 결과

기기는 NUGA 로 로그인된 상태에서 시작했다. 앱은 **백그라운드**(홈 화면)에 두었다 —
그래야 시스템이 알림을 그리는, 사용자가 실제로 겪는 경로를 본다.

| 단계 | 무엇을 했나 | 결과 |
| --- | --- | --- |
| S2 | 백송이 → NUGA 메시지 1통 | 푸시 표시(`chat` 채널) ✅ · **런처 배지 `1`** ✅ |
| S2-2 | 같은 대화로 1통 더 | **배지 `2`** ✅ (아래 §4 G) |
| S3a | 공지 대상 NUGA(1) | 푸시 표시(`general`) ✅ · **배지 `3`** ✅ |
| S3b | 공지 대상 백송이(14) | 이 기기에 **안 옴** ✅ · 배지 3 유지 ✅ (타깃팅 정상) |
| S4 | 앱에서 "나가기" | **`DELETE /api/app/push/token` 이 나가지 않음** ❌ |
| S5 | 백송이로 로그인 | **토큰 재등록이 일어나지 않음** ❌ |
| S6a | 공지 대상 NUGA(1) | 백송이로 로그인한 기기에 **도착** ❌ |
| S6b | 공지 대상 백송이(14) | 백송이 기기에 **안 옴** ❌ |
| S6c | NUGA → 백송이 메시지 | 백송이 기기에 **안 옴** ❌ |

배지 숫자는 런처 아이콘에서 눈으로 확인했고(스크린샷), 알림 도착 여부는
`dumpsys notification` 의 `android.title` 로 대조했다.

## 3. 확정된 결함

### D. 계정을 바꿔도 푸시 대상이 안 바뀐다 (심각)

원인이 두 군데다.

1. **로그아웃이 셸에 안 알려진다.** 계약에 `clearPushRegistration()` 이 있는데
   (`docs/BRIDGE_CONTRACT.md:70`) 웹의 "나가기"(`nuplex/components/navbar.tsx:77`)는
   `/api/auth/logout` 만 부르고 브릿지를 부르지 않는다. 웹 저장소 전체에 호출부가 없다.
   → `device.revoked_at` 이 NULL 로 남는다.
2. **재로그인해도 재등록을 건너뛴다.** `NuplexTokenRegistrar.registerIfChanged()` 는
   FCM 토큰이 이전과 같으면 POST 자체를 안 한다. 계정을 바꿔도 토큰은 그대로다.
   → `device.profile_id` 가 이전 프로필에 박제된다.

`registerDevice` 는 프로필을 쿠키에서 읽으므로(`nuplex/app/api/app/push/token/route.ts`)
**POST 만 한 번 더 가면 고쳐진다.** 지금은 그 POST 가 영영 안 간다.

결과: 계정을 바꾼 기기는 **이전 사용자 앞으로 온 공지를 계속 받고**(S6a — 공지 제목과
본문이 그대로 노출된다), **자기 앞으로 온 공지와 메시지는 못 받는다**(S6b · S6c).
가족이 한 기기를 나눠 쓰는 상황이 정확히 이 경우다.

### A. iOS 앱 아이콘 배지는 푸시로 절대 안 오른다

`nuplex/lib/push/fcm.ts` 의 `apns.payload.aps` 에 `sound` 만 있고 `badge` 가 없다.
iOS 배지는 APNs 페이로드의 `badge` 값으로만 오른다. 코드상 확정, 실행 검증은 §5.

### B. `setBadgeCount` 를 부르는 곳이 없다

브릿지 메서드는 양 플랫폼에 있는데(`ios/App/App/NuplexBridgeAPI.swift:250`)
웹 저장소에 호출부가 하나도 없다. 배지를 웹이 주도하는 경로가 통째로 비어 있다.

### F. Android 배지 플러그인이 깔려 있는데 안 쓴다

`@capawesome/capacitor-badge@8.0.2` 가 `package.json:32` 에 있고 양 플랫폼에 등록까지
돼 있다(`android/.../capacitor.plugins.json:35`). 그런데
`NuplexBridgeApi.java:103` 은 "표준 API 가 없어 여기서 할 수 있는 일이 없다" 는
주석과 함께 no-op 이다. **그 일을 하는 플러그인이 같은 APK 안에 있다.**

지금 배지가 오르는 것은 이 경로가 아니라 **채널의 `mShowBadge=true` 덕분에 런처가
활성 알림 개수를 세는 것**이다. 그래서 배지 숫자는 "안 읽은 알림 수" 이지
"앱이 아는 미읽음 수" 가 아니다 — 알림줄을 지우면 배지도 사라지고, 앱에서 다 읽어도
알림이 남아 있으면 배지는 그대로다.

## 4. 문서와 다른 동작

### G. 채팅 collapse 가 백그라운드에서는 안 먹는다

`nuplex/lib/devices.ts` 의 주석은 "안 읽은 사이에 여러 통이 와도 알림줄에는 마지막
하나만 남는다" 고 한다. 실제로는 S2-2 에서 두 통이 각각 남고 배지도 2가 됐다.

`collapse_key` 는 **전달되기 전** 대기 중인 메시지끼리만 합친다. 앱이 백그라운드면
`onMessageReceived` 가 안 불려 FCM SDK 가 직접 알림을 그리는데, 이때 알림 태그가
메시지마다 다르다(`FCM-Notification:<id>`). 우리 코드의
`collapseKey.hashCode()` 알림 id 는 포그라운드에서만 쓰인다.

## 5. iOS — 막힘

**막힘: 시뮬레이터에서 온보딩의 "알림 받기" 를 누를 수 없어 권한을 못 받았다.**
빌드·설치·부팅·브릿지 주입까지는 확인했다(`브릿지 주입됨: capacitor://localhost/onboarding.html`).
`osascript` 로 좌표 클릭을 시도했으나 명령이 걸린 채 응답이 없었고 화면도 그대로였다 —
CLAUDE.md §2.1 의 제약이 그대로 유효하다.

- 빌드: `xcodebuild -project ios/App/App.xcodeproj -scheme App`
  (워크스페이스가 아니라 **프로젝트** 다. SPM 구성이라 `App.xcworkspace` 는 없다)
- 설치본: iPhone 17 Pro (iOS 26.5) 시뮬레이터, 앱 실행됨

### [Desktop] 이어받을 것

1. 시뮬레이터에서 "알림 받기" → 권한 허용 → 프로필 로그인
2. `xcrun simctl push <udid> com.nugabox.nuplex payload.apns` 로 두 번 보내 비교
   - `aps` 에 `badge` 가 **없는** 페이로드 → 아이콘 배지가 안 오르는 것 확인 (결함 A 재현)
   - `aps` 에 `"badge": 3` 을 **넣은** 페이로드 → 배지가 3이 되는 것 확인 (고치면 되는 것 확인)
3. 로그아웃 → 다른 프로필 로그인 → `NSLog` 에 `푸시 토큰 등록 완료` 가 뜨는지
   (Android 와 같이 안 뜰 것으로 본다 — 같은 `registerIfChanged` 구조다)

## 6. 남은 것 — 고칠 순서

- [x] **[Code] D-1** 웹 "나가기" 가 `clearPushRegistration()` 을 먼저 부른다
      (`nuplex/components/navbar.tsx`). 세션이 살아 있을 때 불러야 401 이 아니다.
      브릿지가 없는 브라우저에서는 아무 일도 하지 않는다
- [x] **[Code] D-2** `notifyWebReady` 에서는 토큰이 같아도 매번 등록한다.
      프로필을 셸이 캐시해 비교하는 방법도 있었지만, 셸은 프로필 번호를 모르고
      서버가 쿠키로 이미 판단하고 있다 — 앱을 켤 때 POST 한 번이 늘 뿐이라
      **판단을 서버에 그대로 맡기는 쪽**을 골랐다. Android 는 안 쓰게 된
      `registerIfChanged` 와 마지막 토큰 캐시를 지웠고, iOS 는 토큰 갱신
      콜백(`AppDelegate`)이 아직 쓰므로 남겼다
- [ ] **[Code] A** `fcm.ts` 의 `aps` 에 `badge` 를 싣는다. 값은 서버가 아는 미읽음
      수여야 한다(공지 + 채팅)
- [ ] **[Code] B** 웹이 미읽음 수가 바뀔 때 `setBadgeCount()` 를 부른다
- [ ] **[Code] F** Android `setBadgeCount` 를 이미 깔린 플러그인에 연결하거나,
      연결하지 않기로 했다면 주석을 사실대로 고친다
- [ ] **[Code] G** `devices.ts` 의 collapse 주석을 실제 동작에 맞게 고친다
- [ ] **[Desktop]** §5 의 iOS 확인

## 7. 곁가지로 본 것

- `device` 행이 프로필당 여럿이다 — 공지 발송 응답의 `queued` 가 NUGA 2, 백송이 4였다.
  결함 D 때문에 쌓인 유령 기기가 섞여 있을 가능성이 크다. 서버에서 한 번 정리할 것
- 웹뷰 콘솔에 `Uncaught TypeError: Cannot read properties of undefined (reading 'triggerEvent')`
  가 매 기동마다 두 번 뜬다. Capacitor 쪽으로 보이고 이번 검증에는 영향이 없었다.
  별건으로 확인 필요
- **인앱 배지(종 · 채팅 아이콘)는 정상이다.** 프로필 기준으로 정확히 센다.
  백송이로 로그인했을 때 백송이 공지가 종에 1로 떴고, NUGA 로 되돌리니 채팅 1 · 공지 2가 됐다.
  **틀린 것은 푸시 대상이지 웹이 아니다**
