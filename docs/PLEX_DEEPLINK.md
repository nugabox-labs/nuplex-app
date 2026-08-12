# Plex 딥링크

## 무엇을 여는가

웹(`nuplex`)이 이미 링크를 만들고 있다. 셸은 그 주소를 받아 열기만 한다.

```ts
// nuplex: lib/plex/client.ts · lib/library.ts
const key = encodeURIComponent(`/library/metadata/${ratingKey}`)
return `https://app.plex.tv/desktop/#!/server/${serverId}/details?key=${key}`
```

`serverId` 는 웹의 환경변수 `PLEX_SERVER_ID`(Plex 서버의 machineIdentifier)다.
**셸은 이 형식을 알 필요가 없다.** 웹이 형식을 바꿔도 셸을 다시 배포하지 않아도
되도록, 브릿지는 완성된 `webUrl` 을 통째로 받는다.

## 왜 https 링크인가 (ADR-003)

`plex://` 커스텀 스킴은 **Plex 가 공식 문서화한 적이 없다.** 커뮤니티에서 알려진
형식은 있으나 OS 나 Plex 앱 업데이트에 조용히 깨질 수 있다.

반면 `https://app.plex.tv/...` 는 Plex 앱이 Universal Links(iOS) / App Links(Android)로
가로채고, **앱이 없으면 브라우저로 자동 폴백**된다. 표준 메커니즘이라 안정적이다.

## 앱으로 갔는지 브라우저로 갔는지 어떻게 아는가

그냥 열면 알 수 없다. 그래서 양 플랫폼 모두 "앱이 아니면 열지 마라" 를 먼저 시도한다.

| 플랫폼 | 방법 |
| --- | --- |
| iOS | `UIApplication.open(url, options: [.universalLinksOnly: true])` — 실패하면 일반 open 으로 재시도 |
| Android | `Intent.FLAG_ACTIVITY_REQUIRE_NON_BROWSER` (API 30+) — `ActivityNotFoundException` 이면 일반 VIEW 로 재시도 |

이 결과가 브릿지의 `{ opened: 'app' | 'browser' }` 다. 웹은 이 값으로 안내 문구를
정확히 띄울 수 있다.

## 웹뷰 안에서 Plex 링크를 눌렀을 때

`capacitor.config.ts` 의 `allowNavigation` 에 `app.plex.tv` 를 **일부러 넣지 않았다.**
목록에 없는 도메인은 Capacitor 가 웹뷰 안에서 열지 않고 OS 로 넘긴다. 그래서
웹이 브릿지를 부르지 않고 평범한 `<a href>` 를 써도 Plex 앱으로 넘어간다.

목록에 넣으면 반대로 **웹뷰 안에 Plex 웹이 갇힌다.** 넣지 말 것.

## TODO(verify) — plex:// 실험 경로

원격 설정의 `features.plexCustomScheme` 이 이 실험을 켜는 스위치가 될 자리다.
지금은 켜도 아무 일도 하지 않는다. 다음을 실기기에서 확인하기 전에는 구현하지 않는다.

1. Plex 앱에서 아무 작품 → 공유 → **실제로 생성되는 URL 을 캡처**한다.
2. 그 URL 을 메모 앱 등에 붙여 눌렀을 때 Plex 앱으로 넘어가는지 확인한다.
3. `plex://` 로 서버·아이템을 지정하는 파라미터 형식이 무엇인지 확인한다.
4. iOS 는 `LSApplicationQueriesSchemes` 에 `plex` 가 이미 선언돼 있다(Info.plist).
   Android 는 `<queries>` 에 선언돼 있다(AndroidManifest.xml).

붙일 위치는 두 곳이다.

- `ios/App/App/NuplexBridgeAPI.swift` 의 `openInPlex(webUrl:respond:)`
- `android/.../NuplexBridgeApi.java` 의 `openInPlex(int, String)`

**어느 경우에도 https 폴백을 지운다는 뜻은 아니다.** 커스텀 스킴은 실패할 수 있고,
실패하면 조용히 https 경로로 내려와야 한다.

## 확인 목록 (실기기)

- [ ] Plex 앱 설치 상태에서 "시청하기" → Plex 앱이 열리고 해당 작품이 뜬다
- [ ] Plex 앱 삭제 상태에서 → 브라우저로 열리고 로그인 후 재생 가능하다
- [ ] 웹뷰 안에서 Plex 링크를 눌러도 웹뷰에 갇히지 않는다
- [ ] 앱으로 열린 경우 브릿지가 `{ opened: 'app' }` 을 돌려준다
