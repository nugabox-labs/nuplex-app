# Plex 딥링크

## 웹과 앱이 다른 곳으로 간다

전에는 웹이 만든 주소를 셸이 그대로 열기만 했다. 그 전제가 깨졌다.

웹(`nuplex`)은 2026-08-14 부터 **우리 Plex 서버가 직접 서빙하는 웹앱** 주소를 만든다.

```ts
// nuplex: lib/library.ts · lib/plex/client.ts
const key = encodeURIComponent(`/library/metadata/${ratingKey}`)
return `${PLEX_PUBLIC_URL}/web/index.html#!/server/${serverId}/details?key=${key}`
```

브라우저에서는 그게 맞다. 그런데 **Plex 앱은 이 주소를 절대 가로채지 않는다.**
`plex.nugabox.com` 은 Plex 의 도메인이 아니기 때문이다.

그래서 **앱에서는 셸이 주소를 다시 만든다.** 브릿지가 `machineIdentifier` ·
`ratingKey` · `type` 을 함께 받는 이유가 이것이다.

## Plex 앱이 실제로 받는 링크 (실측)

추측하지 않고 **설치된 APK 를 직접 확인했다** (Android 2026.15.0).

```bash
adb shell dumpsys package com.plexapp.android   # 인텐트 필터
adb pull .../base.apk && strings classes*.dex | grep 'plex://'
```

### https 로는 안 된다

Plex 가 등록한 https 호스트는 이것뿐이다.

```
watch.plex.tv · plex.smart.link · l.plex.tv · links.plex.tv · click.plex.tv
```

**`app.plex.tv` 는 없다.** 우리가 만들 수 있는 주소도 아니다(뒤 넷은 Plex 의 링크
단축 도메인이다). https 경로는 이 앱 버전에서 존재하지 않는 길이다.

### `plex://` 는 된다 — 단 형식이 하나다

dex 안에 있는 `plex://` 문자열은 딱 둘이다.

```
plex://downloads/in-progress
plex://watch/video?uri=
```

`uri` 값의 형식도 앱 안의 파서 정규식 그대로 확인했다.

```
server://([^/]+)/com\.plexapp\.plugins\.library(/…)
```

즉 우리가 만들 주소는 이것이다.

```
plex://watch/video?uri=server://<machineIdentifier>/com.plexapp.plugins.library/library/metadata/<ratingKey>
```

`uri` 는 인코딩해도, 안 해도 똑같이 동작한다. 셸은 인코딩해서 보낸다.

**에뮬레이터에서 실제로 그 작품이 재생되는 것까지 확인했다** — 앱에서 "시청하기" →
Plex 앱 전환 → 미디어 세션 메타데이터가 그 작품 제목.

### 이건 "재생" 명령이지 "상세 열기" 가 아니다

`watch/video` 는 이름 그대로 재생 대기열을 만든다. 그래서 **재생할 파일이 없는
묶음을 주면 실패한다.**

| `type` | 결과 |
| --- | --- |
| `movie` · `episode` | 바로 재생된다 |
| `show` | 되는 것도 있고(에피소드를 스스로 고름) `Item not known when attempting to build decision` 로 죽는 것도 있다 |
| `season` · `collection` | 기대하지 않는다 |

그래서 브릿지는 `type` 을 받아 **묶음이면 스킴을 건너뛰고 웹 폴백으로 내려보낸다.**
사용자는 Plex 웹앱 상세 화면에서 볼 회차를 고른다 — 재생 오류 팝업보다 낫다.

`type` 이 없으면(구버전 웹) 재생 가능한 항목으로 보고 진행한다. 계약을 깨지 않기
위해서다. **웹이 `type` 을 넘겨야 시리즈가 제대로 처리된다.**

## 사다리

`openInPlex` 는 넷을 순서대로 시도한다. 구현은 `NuplexBridgeAPI.swift` ·
`NuplexBridgeApi.java` 에 같은 순서로 들어가 있다.

| # | 시도 | 결과값 |
| --- | --- | --- |
| 1 | **Plex 앱 미설치** → App Store · Play 스토어 | `store` |
| 2 | `plex://watch/video?uri=…` (묶음 종류면 건너뜀) | `app` |
| 3 | `https://app.plex.tv/…` 를 **앱에게만** 던진다 | `app` |
| 4 | 웹이 준 `webUrl` 을 브라우저로 | `browser` |

3번은 지금 항상 실패한다(위 실측). 남겨둔 것은 Plex 가 다시 등록할 경우를 위한
자리이고, 비용은 예외 하나다.

### 설치 여부를 어떻게 아는가

| 플랫폼 | 방법 | 전제 |
| --- | --- | --- |
| iOS | `canOpenURL("plex://")` | `Info.plist` 의 `LSApplicationQueriesSchemes` 에 `plex` |
| Android | `getPackageInfo("com.plexapp.android")` | 매니페스트 `<queries>` 에 같은 패키지 |

전제가 빠지면 **항상 "미설치" 로 판정되어 시청하기가 전부 스토어로 샌다.** 둘 다
지금 선언돼 있다. 지우지 말 것.

### 앱으로 갔는지 브라우저로 갔는지 어떻게 아는가

| 플랫폼 | 방법 |
| --- | --- |
| iOS | 커스텀 스킴은 `canOpenURL`, https 는 `open(options: [.universalLinksOnly: true])` |
| Android | `Intent.setPackage("com.plexapp.android")` — 받아줄 곳이 없으면 `ActivityNotFoundException` |

Android 는 `FLAG_ACTIVITY_REQUIRE_NON_BROWSER` 대신 명시적 패키지를 쓴다. 플래그는
"브라우저만 아니면 된다" 라서 다른 앱이 가로챌 수 있고 API 30 미만에는 아예 없다.

### 4번 폴백을 지우지 말 것

2 · 3 이 실패해도 4 는 그 작품 상세로 간다. "Plex 앱이 안 열렸다" 는 이유로
사용자를 빈손으로 돌려보낼 이유가 없다.

같은 이유로 `capacitor.config.ts` 의 `allowNavigation` 에 `plex.nugabox.com` 을
**넣지 않는다.** 목록에 없는 도메인은 웹뷰 안에서 열리지 않고 OS 로 나간다.

## 확인할 때 걸리는 것들

**`am force-stop` 뒤에 딥링크를 던지면 실패한다.** Plex 가 정지 상태에서 깨어나며
서버 연결을 아직 못 잡아 `Failed to fetch play queue response` 가 뜬다. 평소에 앱을
한 번이라도 쓴 기기에서는 나지 않는다. `am kill` (프로세스만 종료) 로는 정상이다.
**확인 전에 Plex 를 한 번 실행해 둘 것.**

`Conversion failed. The transcoder process crashed.` 는 서버 쪽 트랜스코딩 문제다.
딥링크와 무관하다.

## 확인 목록 (실기기)

- [x] Android — Plex 설치 · 영화 "시청하기" → Plex 앱에서 **그 작품**이 재생된다
- [x] Android — Plex 미설치 → Play 스토어의 Plex 페이지
- [ ] iOS — 위 둘. **스킴 형식은 Android APK 에서 확인한 것이라 iOS 는 미검증이다**
- [ ] 시리즈에서 "시청하기" → 웹 폴백으로 상세가 열린다 (웹이 `type` 을 넘긴 뒤)
- [ ] 어느 경로에서도 웹뷰 안에 Plex 가 갇히지 않는다

## 시리즈는 첫 화로 보낸다 (2026-08-17)

Plex 앱에는 **상세 페이지를 여는 딥링크가 없다.** APK 에 등록된 `plex://` 문자열은
`watch/video?uri=` 와 `downloads/in-progress` 둘뿐이고, 이번에 다시 뜯어 확인했다.
`plex:` 스킴 필터에는 호스트·경로 제한이 없어 앱이 내부에서 경로를 해석한다.

`watch/video` 는 재생 명령이라 시리즈를 넘기면 재생 대기열을 못 만들어 실패한다.
그래서 셸은 `show`·`season`·`collection`·`artist`·`album` 을 웹으로 돌린다 —
**영화만 앱에서 열리고 시리즈는 브라우저로 새는 이유였다.**

해결은 셸이 아니라 웹에서 했다. 항목 조회에 **첫 화의 ratingKey** 를 얹어
(`nuplex: lib/library.ts` 의 `first_episode_rating_key`), 시리즈 버튼이 그 화를
가리키게 했다. 화는 재생 가능한 항목이라 스킴이 그대로 통한다.
셸의 `deepLinkLadder` 는 손대지 않았다 — 넘어오는 `type` 이 `episode` 로 바뀔 뿐이다.

스페셜(시즌 0)은 뒤로 미룬다. 처음 보는 사람에게 보여줄 화가 아니다.

**iOS 스킴은 유효하다.** 기기 Safari 에 앱이 만드는 주소를 넣으면 Plex 가 열린다.
열린 뒤 `Failed to fetch play queue response` 가 뜨면 Plex 가 정지 상태에서 깨어난
경우다 — 한 번 띄워 두면 안 난다. Android 에서도 같다.
