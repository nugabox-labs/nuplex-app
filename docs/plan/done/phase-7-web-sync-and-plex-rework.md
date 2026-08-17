# Phase 7 — 웹 변경 따라잡기 · Plex 딥링크 재작업 · iOS 브릿지 주입

- 상태: 완료 (2026-08-16)
- 커밋: `19c99c7`(app) · `00ee33d`(web, 배포까지 완료)

웹이 8/14~8/15 에 바꾼 것들을 앱에 반영하다가, **셸의 두 전제가 이미 깨져 있었다는 것**을
발견해 같이 고쳤다.

## 1. Plex 딥링크 — 전제가 깨져 있었다

웹이 Plex 링크를 `app.plex.tv` 에서 **우리 서버가 서빙하는 웹앱**으로 바꿨다
(`plex.nugabox.com/web/index.html#!/...`, 웹 커밋 `4c4fb66`).

셸은 "웹이 준 주소를 그대로 열면 Plex 앱이 가로챈다" 를 전제로 만들어져 있었다.
우리 도메인은 Plex 가 가로채지 않으므로 **앱에서도 브라우저로만 나갔다.**

### 형식을 추측하지 않고 APK 에서 찾았다

설치된 Plex(Android 2026.15.0)를 뜯었다.

```bash
adb shell dumpsys package com.plexapp.android          # 인텐트 필터
adb pull .../base.apk; strings classes*.dex | grep 'plex://'
```

- 등록된 https 호스트: `watch.plex.tv` · `plex.smart.link` · `l.plex.tv` ·
  `links.plex.tv` · `click.plex.tv` — **`app.plex.tv` 없음.** 기존 사다리는 원리상 실패였다
- dex 안 `plex://` 문자열은 둘: `plex://downloads/in-progress`, `plex://watch/video?uri=`
- `uri` 파서 정규식도 그대로: `server://([^/]+)/com\.plexapp\.plugins\.library(/…)`

결론 —

```
plex://watch/video?uri=server://<machineIdentifier>/com.plexapp.plugins.library/library/metadata/<ratingKey>
```

### 이건 재생 명령이라 시리즈에서 깨진다

`watch/video` 는 재생 대기열을 만든다. `show` 를 주면 `Item not known when attempting to
build decision` 이 뜬다(홈 히어로가 시리즈일 때가 많아 실제로 걸렸다).

→ 브릿지에 `type` 을 추가하고, `show`·`season`·`collection`·`artist`·`album` 이면
스킴을 건너뛰어 웹 폴백으로 보낸다. `type` 이 없으면 재생 가능으로 본다(구버전 웹 호환).

→ 웹도 `type` 을 넘기도록 고쳤다(`components/plex-link.tsx` + 호출부 3곳).

### 검증 (Android 에뮬레이터, Plex 로그인 상태)

| 입력 | 결과 |
| --- | --- |
| `type: movie` (88793) | Plex 앱 재생. 미디어 세션 `description=007 죽느냐 사느냐` ✅ |
| `type: show` (113597) | `재생 대상이 아닌 종류(show)라 웹으로 보냅니다.` → Chrome → Plex Web ✅ |
| `type` 없음 | 재생 시도 → Plex 오류. 의도된 호환 동작 ✅ |
| Plex 미설치 | Play 스토어 (`com.android.vending` 최상위) ✅ |

운영 반영 확인: `/title/113597 → "type":"show"`, `/title/88793 → "type":"movie"`.

**함정**: `am force-stop` 뒤에 딥링크를 던지면 `Failed to fetch play queue response` 가 뜬다.
Plex 가 정지 상태에서 깨어나 서버 연결을 못 잡은 것이고 평소 기기에서는 안 난다.
`am kill` 로는 정상. **확인 전에 Plex 를 한 번 실행해 둘 것.**

## 2. iOS 브릿지가 주입되지 않고 있었다

`NuplexViewController` 에 메시지 핸들러 클래스와 자리표시자만 있고 **`WKUserScript` 를
붙이는 코드가 없었다.** iOS 에서는 `window.NuplexNative` 자체가 없었다는 뜻이고, 따라서

- `openInPlex` · `notifyWebReady` 미호출
- 푸시 토큰 등록 안 됨 (등록 시점이 `notifyWebReady`)
- 앱 종료 상태 알림 라우팅이 영원히 큐에 대기

가 전부 무동작이었다. 주입을 구현했고 시뮬레이터에서 확인했다 —
`브릿지 주입됨: https://nuplex.nugabox.com/welcome`, `bridgeVersion=1`,
UA `NuplexApp (ios; bridge/1)`.

## 3. 푸시 — 채팅 알림이 사라지던 것

- 웹이 `android.notification.channel_id: "chat"` 을 보내는데 셸에 그 채널이 없었다.
  **Android 8+ 는 없는 채널이면 알림을 조용히 버린다**(발송은 성공으로 남는다). 채널 추가.
- 앱이 백그라운드면 `onMessageReceived` 가 안 불려 시스템이 알림을 그리는데, 그때는 우리가
  심은 `nuplex_route` extra 가 없다. FCM 이 `data` 를 런처 인텐트 extra 로 실어주므로
  `MainActivity` 가 `route` extra 를 폴백으로 읽게 했다.

### 검증 (실제 FCM 발송)

- 공지 푸시(백그라운드) → 표시 → 탭 → `https://nuplex.nugabox.com/?notice=1` 이동 ✅
- 채팅 푸시 → `chat` 채널로 표시 ✅
- **앱 프로세스 종료(`am kill`) → 탭 → 콜드 스타트 → 큐 대기 → `notifyWebReady` → 이동** ✅
  (문서가 "가장 자주 깨지는 지점" 이라 한 경로)
- 프로필 선택 후 `푸시 토큰 등록 완료` (그 전에는 307 로 정상 유예) ✅

**함정**: `am force-stop` 상태에는 FCM 이 아예 전달되지 않는다(Android 가 앱을 정지
상태로 둔다). 사용자가 최근 앱에서 밀어 닫는 것과는 다르다.
**함정**: `POST_NOTIFICATIONS` 권한이 없으면 알림이 조용히 사라진다. 발송은 성공으로 보인다.

## 4. 문서 정합

- 계약 문서가 옛 웹 동작을 기술하고 있었다(`/login`, `nuplex_session`) → `/welcome` ·
  프로필 쿠키로 갱신하고 양 저장소 사본 동기화
- `docs/TESTING.md` 신설 — 테스트 계정, 셸을 임의 주소에 붙이는 법, 푸시 확인법
- `features.plexCustomScheme` 배선 제거. 스킴이 유일하게 동작하는 경로가 된 이상 기본값 0
  짜리 플래그 뒤에 두면 운영에서 꺼진 채로 나간다. 웹 `.env` 의
  `APP_PLEX_CUSTOM_SCHEME` 은 이제 아무 데서도 읽지 않는다 — 지워도 된다

## 5. 이번에 확인 못 한 것

| 항목 | 왜 |
| --- | --- |
| **iOS 전 상호작용** | Claude Code 에서 시뮬레이터 탭 자동화 불가(보조 접근 권한 없음). 부팅·주입·로그까지만 확인 |
| iOS Plex 딥링크 | 스킴 형식이 **Android APK 근거**다. iOS 미검증 |
| 실기기 전반 | 시뮬레이터/에뮬레이터만 사용 |

→ `docs/plan/active/phase-8-store-release.md` 로 넘긴다.

## 6. 부수적으로 발견한 것 (미조치)

- 웹 `lib/utils.ts:31` 의 `isNuplexApp` 정규식이 `NuplexApp \(` 로 **공백 하나에 의존**한다.
  계약 §2 가 "공백 개수에 의존하지 말 것" 을 명시적으로 경고하는 지점이다. 지금 UA 는
  공백 하나라 동작하지만 Capacitor 업그레이드 때 조용히 깨진다. `\s+` 로 바꾸면 안전하다
- 앱 첫 실행 직후 웹 주소를 바꾸면 그 실행에서만 브릿지가 안 붙는다(원인·대응은
  `docs/TROUBLESHOOTING.md`)
