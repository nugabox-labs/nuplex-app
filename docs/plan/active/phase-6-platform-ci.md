# Phase 6 — 플랫폼 마감 및 CI

- 상태: 진행 중 (2026-08-13, 2026-08-17 갱신). 코드는 끝났고 **검증과 사람 작업**이 남았다
- 스토어 등록·TestFlight·심사는 `phase-8-store-release.md` 로 옮겼다

## 끝난 것

### Android
- [x] 하드웨어·제스처 뒤로가기 — 웹뷰 히스토리 우선, 루트에서는 "한 번 더 누르면 종료"
- [x] 엣지 투 엣지 (`EdgeToEdge.enable`)
- [x] targetSdk 36
- [x] 릴리스 서명 설정 — 키는 저장소에 두지 않고 CI 환경변수로 받는다

### iOS
- [x] Privacy Manifest (`PrivacyInfo.xcprivacy`) — 기기 식별자 수집 · UserDefaults 사용 선언
- [x] 스와이프 뒤로가기 (`allowsBackForwardNavigationGestures`)
- [x] 로드 실패 → 오프라인 화면 (navigationDelegate 프록시)

### CI
- [x] `ci.yml` — 셸 타입 검사·빌드, Android assembleDebug, iOS 시뮬레이터 빌드
- [x] `android-release.yml` — 태그 → AAB. 빌드번호는 run number 로 채번
- [x] `ios-release.yml` — 태그 → 아카이브

## 검증 상태

| 항목 | 상태 |
| --- | --- |
| 양 플랫폼 빌드 | 통과 |
| Android 뒤로가기 | **미검증** — 에뮬레이터가 ANR(리소스 압박)로 입력을 못 받았다. 실기기 필요 |
| 엣지 투 엣지 표시 | **미검증** — 위와 같은 이유 |
| iOS 오프라인 폴백 | **미검증** — Claude Code 는 시뮬레이터를 탭할 수 없다(CLAUDE.md §2.1). Desktop 이 이어받는다 |
| iOS 브릿지 주입 | 통과 — Phase 7 에서 **주입 코드가 아예 없던 것**을 발견해 구현·확인 |
| Android 푸시 전 경로 | 통과 — 실제 FCM 발송으로 콜드 스타트 라우팅까지 (Phase 7) |
| Android Plex 딥링크 | 통과 — Plex 앱에서 해당 작품 재생까지 (Phase 7) |
| CI 워크플로 | 실행됨 (2026-08-16 첫 푸시). 셸·Android 통과, **iOS 잡 실패 → 수정함** |

### 아이콘 · 스플래시
- [x] 웹 워드마크(Inter Black, `NU` #f5f5f5 + `PLEX` #e5a00d, 배경 #0f0f0f)를 그대로
      쓴 아이콘 제작. 시안 3종 중 **A(한 줄)** 을 선택받아 확정
- [x] Android 적응형 아이콘 전경은 따로 만들었다 — 런처가 바깥을 원형으로 잘라내서
      아이콘 본체를 그대로 쓰면 양끝 글자가 날아간다. 원 안전영역에 맞춰 축소했고
      (글자 폭 597 / 허용 665) 마스크를 씌워 확인했다
- [x] `@capacitor/assets` 로 양 플랫폼 생성 (android 136 · ios 13개)

## CI 첫 실행에서 드러난 것

iOS 잡이 `GoogleService-Info.plist` 부재로 실패했다(exit 65,
"Build input file cannot be found"). 시크릿이라 커밋하지 않는데 Xcode 프로젝트는
참조하고 있어서다. 로컬에서 그대로 재현한 뒤, 시크릿이 없으면 자리표시자를 만들도록
`ci.yml` 을 고쳤다 — 이 잡이 보는 것은 컴파일 오류뿐이라 진짜 값이 필요 없다.
릴리스 빌드는 `ios-release.yml` 이 진짜 값을 넣는다.

## 남은 것

스토어 등록 · 인증서 · `exportOptions.plist` · `assetlinks.json` · 실기기 확인은
전부 **`phase-8-store-release.md`** 에 소유자를 붙여 옮겼다. 여기서는 관리하지 않는다.
