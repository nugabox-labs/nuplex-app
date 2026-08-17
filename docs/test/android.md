# Android 확인 목록

쓰는 법은 [`README.md`](README.md). ★ 는 실기기가 필요한 항목.

## 회차 기록

| 날짜 | 기기 / OS | 빌드 | 한 줄 |
| --- | --- | --- | --- |
| 2026-08-16 | Pixel 에뮬레이터 (`emulator-5554`) | 1.0.0 (1) | Phase 7 — 푸시·딥링크 전 경로 검증 |
| 2026-08-17 | Pixel 에뮬레이터 (`emulator-5554`) | 1.0.0 (1), 웹 `nuplex.nugabox.com` | Plex 딥링크·오프라인 재확인, 전 항목 통과 |

에뮬레이터에 Plex 2026.15.0 설치 + 로그인 상태에서 확인했다.

---

## 1. 부팅 · 입장

- [x] 앱 실행 → 스플래시 → 홈 (프로필 세션 유지됨)
- [x] 상태바 침범 없음 — 헤더가 상태바 아래에 있다
      - iOS 에서 터졌던 안전영역 문제(웹 `ff4580e`·`81511bb`)가 Android 에는
        원래 증상이 없었다. 고친 뒤에도 레이아웃이 깨지지 않는 것을 확인
- [x] 홈 인디케이터(제스처 바) 침범 없음

## 2. 브릿지

- [x] 원격 페이지에 주입된다
      - 로그: `Nuplex: 브릿지 주입됨: https://nuplex.nugabox.com/`
- [x] 라우팅 후에도 다시 주입된다
      - 로그: `브릿지 주입됨: https://nuplex.nugabox.com/title/88793`
- [x] 로컬 화면에도 주입된다 — `브릿지 주입됨: https://localhost/offline.html`
- [ ] `bridgeVersion` · `platform` · `appVersion` 값 확인 — **미검증**
- [ ] UA 에 `NuplexApp (android; bridge/N)` — **미검증**

## 3. 푸시

- [x] 실제 FCM 발송 → 공지(백그라운드) 표시 → 탭 → `/?notice=1` 이동 — **Phase 7**
- [x] 채팅 푸시가 `chat` 채널로 표시 — **Phase 7**
      - 셸에 없는 채널이면 Android 8+ 는 조용히 버린다. 채널 추가로 해결
- [x] 앱 **종료**(`am kill`) → 탭 → 콜드 스타트 → 큐 대기 → `notifyWebReady` → 이동 — **Phase 7**
- [x] 시스템이 그린 알림의 `route` extra 폴백
      - 2026-08-17 재확인: `am start … --es route "/title/88793"` →
        `브릿지 주입됨: https://nuplex.nugabox.com/title/88793`
- [x] 프로필 선택 후 `푸시 토큰 등록 완료` (그 전에는 307 로 정상 유예) — **Phase 7**
- [ ] 로그아웃 → `DELETE /api/app/push/token` — **미검증**

> `POST_NOTIFICATIONS` 는 `granted=true` 상태에서 확인했다. 권한이 없으면
> **알림이 조용히 사라지고 발송은 성공으로 보인다.**

## 4. Plex 딥링크

에뮬레이터에 Plex 가 설치·로그인돼 있어 **여기서 끝까지 확인된다.**

- [x] 영화 상세 → "Plex에서 시청하기" → Plex 앱에서 **그 작품**이 열린다
      - `007 죽느냐 사느냐`(ratingKey 88793)
      - 셸 로그: `Plex 앱으로 보냅니다: plex://watch/video?uri=server%3A%2F%2F4962aaf0…%2Flibrary%2Fmetadata%2F88793`
      - 결과: 포그라운드가 `com.plexapp.android` 로 바뀌고,
        `dumpsys media_session` 에 `description=007 죽느냐 사느냐`,
        `state=PlaybackState {state=BUFFERING(6) …}` — **그 작품이 실제로 재생에 들어갔다**
- [x] 시리즈 → 웹 폴백(Plex Web 상세)
      - 히어로(`폴아웃`, 시리즈)에서 확인. 셸 로그
        `재생 대상이 아닌 종류(show)라 웹으로 보냅니다.` →
        `Plex 앱이 링크를 받지 않아 브라우저로 넘깁니다.` → Chrome 이
        `plex.nugabox.com/web/…` 을 연다
- [ ] Plex 미설치 → Play 스토어의 Plex 페이지 — **Phase 7 에서 확인**, 이번 회차는 안 함
      (지우면 위 두 항목을 다시 못 하므로 마지막에 할 것)

> **함정**: `am force-stop` 뒤에 딥링크를 던지면 `Failed to fetch play queue response`
> 가 난다. 평소 기기에서는 안 난다. **확인 전에 Plex 를 한 번 실행해 둘 것.**
> 이번 회차도 Plex 를 먼저 띄워 두고 진행했다.

## 5. 오프라인

**Android 는 비행기 모드를 명령으로 켤 수 있어 이 항목을 끝까지 볼 수 있다.**
iOS 시뮬레이터에는 그 수단이 없다.

- [x] 비행기 모드에서 실행 → 흰 화면이 아닌 오프라인 화면
      - `adb shell cmd connectivity airplane-mode enable` → 앱 실행
      - 로그: `브릿지 주입됨: https://localhost/offline.html`
      - 화면: `연결할 수 없습니다` + 안내문 + `다시 시도` 버튼
- [x] 네트워크 복구 후 `다시 시도` → 웹으로 돌아온다
      - `airplane-mode disable` → 버튼 탭 → `브릿지 주입됨: https://nuplex.nugabox.com/`

## 6. 이 플랫폼에서 겪은 함정

- **없는 알림 채널이면 Android 8+ 는 조용히 버린다.** 발송 로그에는 성공으로 남는다
- **`am force-stop` 상태에는 FCM 이 아예 전달되지 않는다.** 사용자가 최근 앱에서
  밀어 닫는 것과 다르다. 종료 상태 확인은 `am kill` 로 한다
- **에뮬레이터 화면이 잠들면 `screencap` 이 새까맣게 나온다.** 확인 전에
  `adb shell input keyevent KEYCODE_WAKEUP`
- `allowNavigation` 에 **와일드카드 IP 를 넣지 말 것** — Android WebView 가 거부해
  브릿지 주입 단계에서 앱이 죽는다(`docs/TROUBLESHOOTING.md`)

## 7. 관찰 (조치 안 함)

- 원격 페이지 로드 때 콘솔에 이 오류가 뜬다 —
  `Uncaught TypeError: Cannot read properties of undefined (reading 'triggerEvent')`
  (`https://nuplex.nugabox.com/`, Capacitor/Console)
  `triggerEvent` 는 Capacitor 내부 심볼이고 우리 저장소·웹 저장소 어디에도 없다.
  이번에 확인한 기능은 전부 정상 동작했다 — **영향 미확인.** iOS 에서도 나는지 안 봤다
