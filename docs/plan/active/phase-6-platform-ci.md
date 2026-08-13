# Phase 6 — 플랫폼 마감 및 CI

- 상태: 진행 중 (2026-08-13). 코드는 대부분 끝났고 **검증과 사람 작업**이 남았다

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
| iOS 오프라인 폴백 | **미검증** — 시뮬레이터에 탭 자동화 수단이 없어 온보딩을 넘기지 못했다. Android 쪽 같은 로직은 검증됨 |
| CI 워크플로 | **미실행** — 저장소를 GitHub 에 올려야 돌아간다 |

### 아이콘 · 스플래시
- [x] 웹 워드마크(Inter Black, `NU` #f5f5f5 + `PLEX` #e5a00d, 배경 #0f0f0f)를 그대로
      쓴 아이콘 제작. 시안 3종 중 **A(한 줄)** 을 선택받아 확정
- [x] Android 적응형 아이콘 전경은 따로 만들었다 — 런처가 바깥을 원형으로 잘라내서
      아이콘 본체를 그대로 쓰면 양끝 글자가 날아간다. 원 안전영역에 맞춰 축소했고
      (글자 폭 597 / 허용 665) 마스크를 씌워 확인했다
- [x] `@capacitor/assets` 로 양 플랫폼 생성 (android 136 · ios 13개)

## 남은 것 — 사람이 해야 하는 작업
- [ ] App Store Connect / Play Console 에 앱 등록 (서비스 계정 업로드는 앱이 한 번
      등록된 뒤에만 동작한다)
- [ ] 업로드 키스토어 · 배포 인증서 생성 → GitHub Secrets 등록
      (필요한 이름은 각 워크플로 상단 주석 참고)
- [ ] `exportOptions.plist` 추가 후 ios-release 의 IPA 내보내기·업로드 주석 해제

## 남은 것 — 코드

- [ ] App Links 검증용 `assetlinks.json` — 업로드 키의 SHA-256 지문이 필요해서
      키 생성 전에는 만들 수 없다. nuplex 웹의 `/.well-known/` 에 배포한다
- [ ] 실기기 확인 목록 전체 (docs/RELEASE.md)
