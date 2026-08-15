# 테스트

셸은 웹 없이는 아무것도 못 한다. 그래서 확인은 대부분 **실제 웹에 붙여서** 한다.

## 테스트 계정

웹의 관문은 프로필 하나다. 프로필을 고르면 **가입 이메일**을 한 번 확인한다
(`nuplex/components/profile-picker.tsx`). 아래 둘로 전 경로를 볼 수 있다.

| 프로필 | 이메일 | 용도 |
| --- | --- | --- |
| **백송이** | `song2319@gmail.com` | 일반 사용자. **평소 확인은 이걸로 한다** |
| **NUGA** | `ngjang@kakao.com` | 관리자. 이메일 + 비밀번호 |

원본은 `nuplex/docs/SECURITY.md` 의 "테스트 계정" 절이다. 계정이 바뀌면 거기부터 고친다.

관리자 프로필은 이메일만으로 통과하지 않는다. 이 프로필로 들어오면 관리자 화면
진입점이 열리므로 비밀번호를 한 겹 더 묻는다. **비밀번호는 여기 적지 않는다** —
`nuplex` 저장소 `.env` 의 `ADMIN_PASSWORD` 에서 읽는다. 이 저장소는 셸 코드만 담고
시크릿을 담지 않는다(README "시크릿" 절).

> 일반 확인에 관리자 계정을 쓰지 말 것. 관리자 프로필은 실수로 공지를 발송하거나
> 스캔을 돌릴 수 있다. **푸시는 실제 사용자에게 나간다.**

이메일 확인은 프로필 · IP 조합당 10분에 10회로 막혀 있다. 자동화로 반복하다 걸리면
10분 기다린다(`nuplex/docs/SECURITY.md`).

## 셸을 임의의 주소에 붙이기

```bash
VITE_WEB_BASE_URL=http://10.0.2.2:2777 npm run sync   # Android 에뮬레이터
VITE_WEB_BASE_URL=http://localhost:2777 npm run sync  # iOS 시뮬레이터
```

주소는 `capacitor.config.ts` 의 `allowNavigation` 에도 있어야 한다. Android 는 이
목록이 브릿지 주입 허용 origin 을 겸한다. **주소를 바꾼 뒤 첫 실행에는 브릿지가
안 붙는다** — 한 번 껐다 켠다(docs/TROUBLESHOOTING.md).

릴리스 빌드에서는 이 변수를 넘기지 않는다.

## 브릿지 확인

웹 화면을 거치지 않고 브릿지만 눌러보고 싶을 때가 있다. Plex 딥링크처럼 관문 뒤에
있는 기능이 특히 그렇다. `window.NuplexNative` 를 그대로 호출하는 페이지를 하나 띄우고
위 방법으로 셸을 거기에 붙이면 된다. 확인할 것은 넷이다.

- `bridgeVersion` · `platform` · `appVersion` 이 채워져 있는가 (자리표시자가 남아 있으면 주입 실패)
- `navigator.userAgent` 에 `NuplexApp (ios|android; bridge/N)` 이 붙는가
- `openInPlex` 가 `{opened: 'app'|'browser'|'store'}` 를 돌려주는가
- `notifyWebReady()` 뒤에 대기 중이던 푸시 라우트가 흘러가는가

## 푸시

에뮬레이터·시뮬레이터에서도 확인할 수 있다.

**iOS** — `xcrun simctl push <device> com.nugabox.nuplex payload.apns`.
`aps` 옆에 `route` · `type` 을 최상위 키로 둔다(FCM 이 실제로 그렇게 내려준다).
**알림 권한을 허용한 뒤에만 표시된다.** 온보딩을 건너뛰면 아무것도 안 뜬다.

**Android** — 실제 FCM 으로 보내는 편이 정확하다. 토큰은 `getPushToken()` 으로 얻고,
발송은 `nuplex/lib/push/fcm.ts` 와 같은 모양으로 FCM v1 에 던진다. 자격증명은 웹
저장소 `.env` 의 `FCM_SERVICE_ACCOUNT`.

`adb shell pm grant com.nugabox.nuplex android.permission.POST_NOTIFICATIONS` 로
권한을 먼저 준다. **없으면 알림이 조용히 사라진다** — 발송은 성공으로 보인다.

앱을 백그라운드로 두고 보내야 "시스템이 그린 알림" 경로를 볼 수 있다. 그게 실제로
사용자가 겪는 경로이고, 라우팅이 깨지기 쉬운 쪽이다(docs/PUSH_PAYLOAD.md).

## 확인 목록

셸을 고쳤거나 웹을 배포하기 전에 훑는다. 실기기가 필요한 항목은 ★.

- [ ] 부팅 → 입장 → 프로필 선택 → 홈
- [ ] 작품 상세 → "시청하기" → ★ Plex 앱이 열리고 **그 작품**이 뜬다
- [ ] ★ Plex 미설치 상태에서 → 스토어의 Plex 페이지
- [ ] 알림 권한 허용 → 토큰 등록(`POST /api/app/push/token` 200)
- [ ] 앱 백그라운드에서 공지 푸시 → 표시 → 탭 → 해당 화면
- [ ] 앱 **종료** 상태에서 채팅 푸시 → 탭 → 콜드 스타트 후 그 대화로
- [ ] 로그아웃 → `DELETE /api/app/push/token`
- [ ] 비행기 모드 부팅 → 오프라인 화면(흰 화면 아님)
