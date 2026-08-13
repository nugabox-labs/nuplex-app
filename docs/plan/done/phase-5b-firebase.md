# Phase 5b — Firebase 연동 (토큰 발급 · 등록 · 수신)

- 상태: 완료 (2026-08-13). 실기기 검증만 남음
- 선행: Phase 5a
- 관련: `docs/FIREBASE_SETUP.md`, `docs/PUSH_PAYLOAD.md`

## 한 일

- [x] iOS: `App.entitlements`(aps-environment) + `UIBackgroundModes: remote-notification`
      — Xcode UI 로 추가하는 것을 파일로 대신했다
- [x] Android: firebase-bom 34.5.0 + firebase-messaging
- [x] Android: `NuplexMessagingService` — 토큰 갱신, 메시지 수신, 알림 생성
- [x] Android: 알림 탭 PendingIntent 에 route 적재
- [x] iOS: firebase-ios-sdk(SPM) 추가, `FirebaseApp.configure()`, APNs↔FCM 연결
- [x] 공통: `deviceId` 생성·보관
- [x] 공통: `POST/DELETE /api/app/push/token` — 웹뷰 쿠키를 직접 실어 보냄
- [x] 브릿지 `getPushToken` / `clearPushRegistration` 구현
- [x] 웹(nuplex): `NativeBridgeReady` 컴포넌트 — `notifyWebReady()` 호출

## 알림을 직접 그리는 이유

서버가 `notification` 필드를 함께 보내면 백그라운드에서는 시스템이 알림을 그려주는데,
**그렇게 만들어진 알림은 탭해도 route 를 실어주지 않는다.** 그냥 런처 인텐트로 앱을
열 뿐이다. 그래서 `NuplexMessagingService` 가 직접 만든다.

## 실행해 보고 나서야 잡은 것들

빌드만으로는 전부 통과였고, 에뮬레이터에 올리고 나서 드러났다.

| 증상 | 원인 | 조치 |
| --- | --- | --- |
| **앱이 시작하자마자 죽음** | `allowNavigation` 의 `192.168.*` 를 WebView 가 origin 규칙으로 거부(IllegalArgumentException) | 와일드카드 IP 제거 + try/catch 로 방어 |
| 설정 조회 실패 | Android 가 평문 HTTP 차단 | 디버그 빌드 전용 network security config |
| **WebView 기본 에러 페이지 노출** | 로드 실패를 아무도 처리하지 않음 | `NuplexWebViewClient` → offline.html (명세 §9.4) |
| 알림 라우트가 대기열에서 안 나감 | Capacitor 의 origin 목록에 **포트가 없어** :2620 페이지에 브릿지 미주입 | webBaseUrl 의 origin(포트 포함)을 규칙에 추가 |
| 에뮬레이터가 웹에 못 닿음 | 서버가 돌려주는 webBaseUrl 은 서버 기준 주소 | 개발 빌드는 `VITE_WEB_BASE_URL` 이 우선 |
| 미인증인데 등록 성공으로 볼 뻔함 | 인증 게이트가 401 이 아니라 /login 으로 **리다이렉트**(307). iOS 는 기본 URLSession 이 그걸 따라가 로그인 HTML 을 200 으로 받는다 | 리다이렉트 추적 차단 + 3xx 를 미인증으로 판정 |

## 검증 (Android 에뮬레이터, API 36)

- [x] 부팅 → 설정 조회 → 온보딩 → nuplex 로그인 화면 렌더링
- [x] 원격 페이지(`http://10.0.2.2:2620/login`)에 브릿지 주입
- [x] **FCM 토큰 발급** (`onNewToken` 수신)
- [x] **앱 완전 종료 상태에서 알림 탭 → 대기열 → 웹 준비 후 `/title/12345` 로 이동**
      (로그: `푸시 라우트로 이동: http://10.0.2.2:2620/title/12345`)
- [x] 토큰 등록 요청이 실제로 나감. 로그인 전이면 307 을 받고 "미룹니다" 로 처리 —
      설계대로 실패를 정상 흐름으로 다룬다
- [x] 웹이 실제로 `notifyWebReady()` 를 부르는 경로로 재검증 (임시 코드 없이).
      로컬 웹 컨테이너를 재빌드(`./compose.sh restart`)한 뒤 확인했다
- [x] 인증 게이트가 목적지를 보존하는 것까지 확인:
      `/title/12345` → `/login?next=%2Ftitle%2F12345`

## 남은 것 (실기기 필요)

- [ ] 실제 푸시 수신 (포그라운드 / 백그라운드 / 종료 상태)
- [ ] 로그인 후 토큰 등록 성공 → 서버 `device` 테이블에 행 생성
- [ ] 로그아웃 시 토큰 해제
- [ ] iOS 푸시 전반 (Apple Developer 포털 App ID 의 Push Notifications 는 활성화 확인됨.
      Team ID U5796QB9C8)
- [ ] 권한 거부 상태에서의 동작
