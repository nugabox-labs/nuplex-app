# Phase 6 — 플랫폼 마감 및 CI

- 상태: 시작 전
- 선행: Phase 5b

## 할 일

### Android
- [ ] 하드웨어 백버튼 — 히스토리 있으면 뒤로, 루트면 종료 확인 다이얼로그
- [ ] 엣지 투 엣지 (Android 15+ 강제) — SystemBars 로 상태바·내비바 색 제어
- [x] targetSdk 36 (Capacitor 기본값이 이미 36)
- [ ] App Links 검증용 `assetlinks.json` — nuplex 웹의 `/.well-known/` 에 배포
- [ ] 서명 키: Play App Signing, 업로드 키는 GitHub Secrets 에 base64

### iOS
- [ ] Privacy Manifest (`PrivacyInfo.xcprivacy`) — App Store 제출 필수
- [ ] Safe area 실기기 확인 (웹 쪽 `viewport-fit=cover` 는 이미 적용)
- [ ] 스와이프 뒤로가기(`allowsBackForwardNavigationGestures`) 켤지 결정
- [ ] Push Notifications capability — Apple Developer 포털 App ID 설정 필요

### 공통
- [ ] 앱 아이콘 · 스플래시 (`@capacitor/assets`, `resources/` 원본 필요)
- [ ] GitHub Actions: CI(lint · typecheck · build)
- [ ] GitHub Actions: android-release(AAB → Play Internal), ios-release(IPA → TestFlight)
- [x] `docs/RELEASE.md`
- [x] `docs/TROUBLESHOOTING.md`

## 사람이 해야 하는 것

- 앱 아이콘 원본 (1024×1024). 없으면 `@capacitor/assets` 를 돌릴 수 없다
- App Store Connect / Play Console 앱 등록
- 서명 인증서 · 업로드 키 생성
