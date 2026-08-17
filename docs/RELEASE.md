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

## TestFlight 까지

순서를 지켜야 한다. **앱이 App Store Connect 에 한 번 등록되기 전에는 API 키로 업로드해도
받아주지 않는다.**

1. App Store Connect 에 앱 생성 — Bundle ID `com.nugabox.nuplex`, 이름 `NUPLEX`
2. App Store Connect API 키 발급 → `APPSTORE_ISSUER_ID` · `APPSTORE_KEY_ID` ·
   `APPSTORE_PRIVATE_KEY`(.p8 내용)를 GitHub Secrets 에 등록
   - **`.p8` 은 재다운로드할 수 없다.** 받는 즉시 원본을 안전한 곳에 보관한다
3. 배포 인증서(.p12)·프로비저닝 프로파일 → `IOS_CERTIFICATE_P12` ·
   `IOS_CERTIFICATE_PASSWORD` · `IOS_PROVISIONING_PROFILE`
4. `GOOGLE_SERVICE_INFO_PLIST` 등록 (없으면 CI 는 자리표시자로 컴파일만 하고,
   릴리스 빌드는 실패한다)
5. 태그 `v1.0.0` 푸시 → `ios-release.yml` 이 아카이브·업로드
6. TestFlight 에서 빌드 처리(수 분~수십 분) 후 **수출 규정(Export Compliance)** 응답.
   HTTPS 만 쓰므로 면제 대상이다
7. 내부 테스터 초대 → 실기기 설치 → 아래 "실기기 확인" 을 다시 돈다

Play 쪽은 업로드 키스토어를 만들어 Secrets 에 넣고, 같은 태그로 `android-release.yml` 이
Play Internal Testing 에 올린다.

## 스토어 심사

리젝 사유로 예상되는 것이 둘이다. 미리 막는다.

- **App Store Guideline 4.2 (Minimum Functionality)** — 단순 웹 래퍼로 보이면 리젝된다.
  앱 설명에 "Plex 라이브러리 알림 및 브라우징 클라이언트" 임을 명시하고,
  푸시 알림 · 오프라인 화면 · Plex 앱 연동 등 네이티브 고유 기능을 설명한다.
- **심사자가 입장하지 못하면 그대로 리젝된다.** Review Notes 에 진입 방법을 적는다.

  > **열람용 공통 비밀번호는 없다.** 입장 화면(`/welcome`)에서 "입장하기" → 프로필을 고르고
  > **그 프로필의 가입 이메일**을 한 번 입력하는 방식이다. 심사자에게 넘길 프로필과
  > 이메일은 `docs/TESTING.md` 를 따른다(관리자 계정은 주지 않는다 — 그 프로필로는
  > 실제 사용자에게 푸시가 나간다).

  이메일 확인은 프로필·IP 조합당 10분에 10회로 제한된다. 심사자가 오타를 반복하면
  막힐 수 있으니 Review Notes 에 정확한 문자열을 그대로 적는다.

- Google Play 는 2026-08-31 부터 신규 앱이 **targetSdk 36** 이상이어야 한다. 이미 36 이다.
- 개인정보 처리방침 URL 이 필요하다. 푸시 토큰·기기 식별자를 수집하므로
  `PrivacyInfo.xcprivacy` 의 선언과 내용이 어긋나지 않아야 한다.
