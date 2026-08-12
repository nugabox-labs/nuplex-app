# Phase 5a — 푸시 권한 · 채널 · 라우팅

- 상태: 완료 (2026-08-12). 실제 알림 수신은 Phase 5b 이후 검증
- 커밋: `2494f96` · `a3cab1a`(GoogleService-Info.plist 등록)
- 관련: `docs/PUSH_PAYLOAD.md`, `docs/FIREBASE_SETUP.md`

## 명세를 뒤집은 지점

명세 ADR-002 는 `@capacitor-firebase/messaging` 으로 JS 에서 푸시를 다루라고 했다.
**이 구조에서는 동작하지 않는다.** 앱이 종료된 상태에서 알림을 탭하면 웹뷰가 뜨기도
전에 이벤트가 도착하고, 그 시점에 JS 컨텍스트는 존재하지 않는다.

→ 푸시 수신·라우팅을 **네이티브에** 뒀다. 서버는 이미 FCM HTTP v1 로 발송하므로
(nuplex/lib/push/fcm.ts) FCM 을 쓴다는 선택 자체는 그대로다.

## 한 일

- [x] 라우트 대기열 (양 플랫폼) — `notifyWebReady()` 이후 flush
- [x] Android 알림 채널 3종 (new_item / available / general)
- [x] Android 상태바 아이콘 `ic_stat_nuplex` (흰색 실루엣)
- [x] `POST_NOTIFICATIONS` 권한 + Android 12 이하 분기
- [x] iOS `UNUserNotificationCenter` 델리게이트 (포그라운드 표시 · 탭 라우팅)
- [x] 온보딩 화면 → 동의한 사람에게만 OS 다이얼로그
- [x] 네이티브가 읽을 `webBaseUrl` 을 Preferences 에 남김

## 왜 대기열이 필요한가

"앱 완전 종료 상태에서 알림 탭 → 해당 작품으로" 가 이 기능에서 가장 자주 깨진다.
라우트가 웹뷰보다 먼저 도착하는데 그대로 이동시키면 부팅 시퀀스가 덮어써서 홈으로
가버린다. 그래서 들고 있다가 웹이 준비를 알린 뒤에 이동시킨다.

## 검증

- 양 플랫폼 빌드 통과
- `GoogleService-Info.plist` 번들 포함 확인
- **실제 알림 수신·탭은 미검증** (Firebase SDK 연동과 실기기 필요)
