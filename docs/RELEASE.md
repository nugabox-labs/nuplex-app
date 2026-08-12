# 릴리스

## 버전 규칙

```
semver: MAJOR.MINOR.PATCH   (package.json 이 원본)
  MAJOR — 브릿지 계약 breaking change
  MINOR — 셸 신규 기능
  PATCH — 버그 수정
```

빌드번호(iOS `CFBundleVersion`, Android `versionCode`)는 **단조 증가 정수**이며
CI 가 GitHub run number 로 채번한다. **손으로 올리지 않는다** — 사람이 관리하면
반드시 언젠가 같은 번호를 두 번 올려 스토어가 거부한다.

릴리스 흐름: `main` → 태그 `v1.2.0` → CI 가 TestFlight / Play Internal 에 업로드.

## 배포 전 확인

### 셸

- [ ] `npm run build && npm run cap -- sync` 가 통과한다
- [ ] **`capacitor.config.ts` 의 `allowNavigation` 에 개발용 항목이 남아 있어도 되는지 확인**
      (`localhost`, `192.168.*`, `10.*` — 사설 대역이라 위험은 낮지만 의도한 상태여야 한다)
- [ ] `VITE_WEB_BASE_URL` 을 넘기지 않고 빌드했다 (넘기면 개발 주소가 박힌다)
- [ ] 시크릿 파일이 커밋되지 않았다: `git log -p | grep -iE 'google-services|GoogleService-Info|BEGIN PRIVATE KEY'`

### 웹과의 계약

- [ ] `minSupportedAppVersion` 을 올려야 한다면 **스토어에 새 버전이 실제로 올라간 뒤** 올린다.
      먼저 올리면 사용자가 업데이트할 수도 없는 화면에 갇힌다
- [ ] 브릿지 메서드를 지우지 않았다 (docs/BRIDGE_CONTRACT.md §5)
- [ ] 웹의 라우트 경로를 바꿨다면 과거에 발송된 푸시의 `route` 가 여전히 유효하다

### 실기기 확인 (시뮬레이터로는 못 하는 것)

- [ ] 앱 완전 종료 상태에서 알림 탭 → 해당 작품 페이지로 이동 (가장 자주 깨지는 케이스)
- [ ] 알림 권한 거부 → 크래시 없이 안내
- [ ] 비행기 모드로 실행 → 오프라인 화면, 해제하면 자동 복귀
- [ ] Android 백버튼: 히스토리가 있으면 뒤로, 루트면 종료 확인
- [ ] iOS 노치 · 홈 인디케이터 영역 침범 없음

## 스토어 심사 메모

- **App Store Guideline 4.2 (Minimum Functionality)** — 단순 웹 래퍼로 보이면 리젝된다.
  앱 설명에 "Plex 라이브러리 알림 및 브라우징 클라이언트" 임을 명시하고,
  푸시 알림 · 오프라인 화면 등 네이티브 고유 기능을 설명한다.
- 심사자용 **테스트 계정(공통 비밀번호)과 프로필 선택 방법**을 Review Notes 에 적는다.
  넣지 않으면 로그인 화면에서 막혀 그대로 리젝된다.
- Google Play 는 2026-08-31 부터 신규 앱이 **targetSdk 36** 이상이어야 한다. 이미 36 이다.
