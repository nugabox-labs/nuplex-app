# iOS 확인 목록

쓰는 법은 [`README.md`](README.md). ★ 는 실기기가 필요한 항목.

## 회차 기록

| 날짜 | 기기 / OS | 빌드 | 한 줄 |
| --- | --- | --- | --- |
| 2026-08-17 | iPhone 17 시뮬레이터 / iOS 26.5 | Debug, 웹 `https://nuplex.nugabox.com` | 푸시 라우팅과 안전영역을 고치고 통과 |

---

## 1. 부팅 · 입장

- [x] 앱 실행 → 스플래시 → 온보딩(알림 안내) 화면
- [x] "알림 받기" → OS 권한 다이얼로그 → **허용**
      - 로그: `authorizationStatus: Authorized`, `didGrant: 1`,
        `alertSetting: Enabled`, `remoteNotifications: Enabled`
- [x] 프로필 선택 → 가입 이메일 확인 → 홈 진입
      - 테스트 계정 `백송이` / `song2319@gmail.com` (`docs/TESTING.md`)
- [x] 노치 · 다이나믹 아일랜드 침범 없음
      - **처음엔 실패했다.** 웹 헤더가 `viewport-fit=cover` 아래에서 안전영역 여백 없이
        `top-0` 이라 시계와 로고가 겹쳤다. 겹침으로 끝나지 않고 **iOS 상태바가 탭을 먼저
        먹어 헤더 버튼이 눌리지 않았다**
      - 웹 `ff4580e`(헤더) · `81511bb`(모달 셋) 로 고쳐 배포 후 재확인
- [x] 홈 인디케이터 침범 없음 — 모달 버튼도 충분히 위에 있다

## 2. 브릿지

- [x] 원격 페이지에 주입된다
      - 로그: `[Nuplex] 브릿지 주입됨: https://nuplex.nugabox.com/`
- [x] 라우팅 후에도 다시 주입된다
      - 로그: `브릿지 주입됨: https://nuplex.nugabox.com/title/88793`
- [ ] `bridgeVersion` · `platform` · `appVersion` 이 자리표시자가 아닌 값
- [ ] UA 에 `NuplexApp (ios; bridge/N)` 이 붙는다

## 3. 푸시

- [x] FCM 토큰 발급
      - 로그 `[Nuplex] FCM 토큰 수신`, `Preferences` 의 `nuplex.lastRegisteredToken` 에 저장
      - **시뮬레이터에서도 된다.** `docs/TESTING.md` 의 전제와 다르다
- [ ] 서버 등록 `POST /api/app/push/token` 200 — **미검증**
- [x] 앱이 떠 있을 때 푸시 → 배너가 뜬다
      - 시스템 로그 `shouldPresentAlert: YES`. 고치기 전에는 `NO` 였다
- [x] 앱 백그라운드 → 배너 표시 → **탭 → 해당 화면 이동**
      - `route: "/title/88793"` → 로그
        `[Nuplex] 푸시 라우트로 이동: https://nuplex.nugabox.com/title/88793`
      - **처음엔 실패했다.** Capacitor 의 `SceneDelegateProxy` 가
        `UNUserNotificationCenter` 델리게이트를 가로채 우리 핸들러가 한 번도 안 불렸다.
        셸 커밋 `0671b83` 로 프록시 호출 뒤에 델리게이트를 되찾아 온다
- [x] 앱 **완전 종료** 상태에서 탭 → 콜드 스타트 라우팅 (`NuplexPush.offer` 큐)
      - 큐 동작이 로그에 그대로 남는다 —
        `웹 준비 전이라 라우트를 대기열에 넣습니다: /title/88793` →
        `브릿지 주입됨: capacitor://localhost` →
        `브릿지 주입됨: https://nuplex.nugabox.com/`(웹 준비) →
        `푸시 라우트로 이동: https://nuplex.nugabox.com/title/88793` →
        `브릿지 주입됨: …/title/88793`
      - `docs/PUSH_PAYLOAD.md` 가 "가장 자주 깨지는 지점" 이라 한 경로다
- [ ] 로그아웃 → `DELETE /api/app/push/token`

## 4. Plex 딥링크 ★

시뮬레이터에는 Plex 를 설치할 수 없다. **전부 실기기 몫이다.**
`1.0.0 (1)` 이 TestFlight 내부 테스트(`Internal` 그룹)에 올라가 있으니 그걸로 확인한다.

- [ ] ★ 영화 상세 → "Plex에서 시청하기" → Plex 앱에서 **그 작품**이 열린다
- [ ] ★ 시리즈 → 웹 폴백(Plex Web 상세)
- [ ] ★ Plex 미설치 → App Store 의 Plex 페이지

> 스킴 형식(`plex://watch/video?uri=server://…`)은 **Android APK 에서 뽑은 근거**다.
> iOS 는 미검증 — 안 되면 iOS Plex 의 URL types 를 확인한다(`docs/PLEX_DEEPLINK.md`).

## 5. 오프라인

- [ ] 네트워크 끊고 실행 → 흰 화면이 아닌 오프라인 화면
      - **미검증.** 시뮬레이터에 비행기 모드가 없고 맥 네트워크를 끊는 것은 범위 밖이라
        `Network.getStatus().connected === false` 분기를 만들지 못했다
- [ ] 웹 주소에 닿지 못할 때 오프라인 화면
      - **의심.** `VITE_WEB_BASE_URL=https://localhost:9` 로 실행하면 `goTo()` 까지 도달하고도
        `NuplexNavigationProxy` 의 실패 콜백이 오지 않아 스플래시에 머문다.
        자세한 내용은 `docs/plan/active/phase-8-store-release.md` A-0-3

## 6. 이 플랫폼에서 겪은 함정

- **시스템 UI 는 자동으로 못 누른다.** 시뮬레이터에 주입한 탭은 앱 화면·홈 화면에는
  가지만 SpringBoard 가 그리는 계층(권한 다이얼로그 · 배너 · 알림 센터)에는 안 간다.
  Return 키도 안 통한다 — 사람이 눌러 줘야 한다
- **소프트 키보드가 뜬 뒤 웹 버튼 탭이 안 먹었다.** 이메일 입력 후 "확인" 이 그랬고
  Return 키로는 제출됐다. 주입 탭 한정인지 실제 사용자에게도 나는지 **미검증**
- **조용한 실패를 조심할 것.** 알림 라우팅이 옵셔널 체이닝 뒤에서 아무 로그 없이
  끝나고 있었다. 로그가 없다는 사실만으로 코드 경로를 추론하면 틀린다 — 계측이 빠르다
