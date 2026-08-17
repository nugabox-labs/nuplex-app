# CLAUDE.md — nuplex-app

NUPLEX 의 iOS/Android 네이티브 셸. 하는 일은 셋뿐이다 — 웹뷰 호스팅 · 푸시 · Plex 딥링크.
콘텐츠 UI·API 는 전부 `nuplex`(웹) 저장소에 있다.

**이 저장소는 지금 Claude 두 대가 나눠서 작업한다.** 아래 §2 의 동기화 규약을 먼저 읽는다.

## 1. 읽는 순서

작업 전에 이 파일과 `docs/plan/active/` 만 읽는다. 나머지는 필요할 때 하나씩 연다.

| 무엇을 하려는가 | 읽을 것 |
| --- | --- |
| 지금 뭐가 남았는지 | `docs/plan/active/` ← **항상 여기부터** |
| 웹과의 약속 | `docs/BRIDGE_CONTRACT.md` (`nuplex` 저장소에 사본이 있다) |
| Plex 앱으로 보내기 | `docs/PLEX_DEEPLINK.md` |
| 푸시 페이로드·채널 | `docs/PUSH_PAYLOAD.md` |
| 실행·계정·확인 목록 | `docs/TESTING.md` |
| 스토어 업로드·심사 | `docs/RELEASE.md` |
| 빌드가 안 될 때 | `docs/TROUBLESHOOTING.md` |
| 왜 이렇게 만들었나 | `docs/ADR-*.md` |

## 2. 두 에이전트 동기화 규약

### 2.1 역할

경계는 **"GUI 가 필요한가"** 하나로 가른다.

| | Claude Code (터미널) | Claude Desktop (GUI) |
| --- | --- | --- |
| 저장소 수정 · 커밋 · 푸시 | ✅ 주담당 | 필요할 때만 |
| 빌드 (`gradlew` · `xcodebuild`) | ✅ | ✅ |
| Android 에뮬레이터 (`adb`) | ✅ 입력 자동화까지 됨 | ✅ |
| **iOS 시뮬레이터 화면 조작** | ❌ **불가** (아래) | ✅ 주담당 |
| Xcode GUI (서명 · 프로파일 · Organizer) | ❌ | ✅ 주담당 |
| App Store Connect · Play Console (Chrome) | ❌ | ✅ 주담당 |
| 실기기 확인 | ❌ | ✅ |

> **iOS 시뮬레이터를 Claude Code 로 조작할 수 없다.** `xcrun simctl` 로 설치·실행·
> 스크린샷·`simctl push` 까지는 되지만 **탭이 안 된다** — 화면 좌표 클릭에 필요한
> macOS 보조 접근(Accessibility) 권한이 터미널에 없고, `idb` 도 없다. 실제로 막혀서
> iOS 는 "부팅·브릿지 주입·로그" 까지만 확인하고 온보딩 이후를 못 넘겼다.
> **알림 권한 허용 · 시청하기 탭 같은 iOS 상호작용 검증은 Desktop 몫이다.**

### 2.2 규칙

1. **시작 전에 `git pull`.** 두 에이전트가 같은 브랜치(`main`)를 쓴다.
2. **단일 진실 원천은 `docs/plan/active/*.md`** 다. 대화 맥락이나 기억에 의존하지 않는다.
   항목마다 소유자를 붙인다 — `[Code]` · `[Desktop]` · `[사람]`.
3. **한 항목이 끝나면 그때 바로** 체크박스를 갱신하고 커밋·푸시한다. 몰아서 쓰지 않는다.
   상대는 푸시된 것만 볼 수 있다.
4. **"빌드 통과" 는 검증이 아니다.** 무엇을 어떻게 확인했는지 적는다. 확인 못 한 것은
   `미검증` 으로 남긴다(`docs/plan/README.md` 규칙 4).
5. **막히면 지우지 말고 남긴다.** 해당 항목 아래에 `막힘: <무엇이 왜>` 한 줄.
   상대가 이어받을 수 있는 형태여야 한다.
6. **파일 충돌을 피한다.** 같은 파일을 동시에 고치지 않는다.

   | 영역 | 주인 |
   | --- | --- |
   | `src/` · `shell/` · `android/**/*.java` · `ios/**/*.swift` · `docs/` | Code |
   | Xcode 프로젝트 설정(서명·Capabilities) · 스토어 메타데이터 · 스크린샷 | Desktop |
   | `docs/plan/active/*.md` | 둘 다 — **자기 소유 항목 줄만** 고친다 |

7. 상대 영역을 건드려야 하면 `active/` 문서에 요청으로 남기고 넘긴다. 직접 고치지 않는다.

## 3. 절대 규칙

- **시크릿을 커밋하지 않는다.** `google-services.json` · `GoogleService-Info.plist` ·
  서명 키 · `.p8` 은 `.gitignore` 에 있다. CI 는 GitHub Secrets 로 주입한다.
  (그 탓에 iOS CI 가 한 번 깨졌다 — `ci.yml` 의 "Firebase 설정 파일 준비" 주석 참고)
- **브릿지 메서드를 지우지 않는다.** 웹은 앱 업데이트 없이 바뀌지만 구버전 셸 사용자는
  남는다. 추가만 한다 — `docs/BRIDGE_CONTRACT.md` §5.
- **계약 문서는 양 저장소에 같은 내용을 둔다.** 한쪽만 고치면 계약이 깨진다.
  원본 `nuplex-app/docs/BRIDGE_CONTRACT.md` → 사본 `nuplex/docs/BRIDGE_CONTRACT.md`.
- **`minSupportedAppVersion` 은 스토어에 새 버전이 실제로 올라간 뒤에 올린다.** 먼저 올리면
  사용자가 업데이트할 수도 없는 화면에 갇힌다.
- **빌드번호를 손으로 올리지 않는다.** CI 가 run number 로 채번한다.
- **`VITE_WEB_BASE_URL` 을 넘긴 채로 릴리스 빌드를 만들지 않는다.** 개발 주소가 박힌다.

## 4. 웹(`nuplex`)과의 관계

- 웹 저장소는 `../nuplex`. 지침은 그쪽 `AGENTS.md`.
- **웹 `main` 푸시는 곧 운영 배포다.** self-hosted runner 가 마이그레이션 + `compose.sh restart`
  를 돌린다. `nuplex.nugabox.com` 이 그 컨테이너다.
- 웹을 배포하면 앱 화면도 같이 바뀐다. 배포 전 앱 셸에서 주요 흐름을 한 번 본다.
- 앱 여부는 UA 로 판별한다 — `NuplexApp (ios|android; bridge/N)`.

## 5. 자주 쓰는 명령

```bash
nvm use && npm install
npm run build          # shell/ → www/
npm run sync           # build + cap sync
npm run cap -- <cmd>   # npx cap 대신 이 래퍼를 쓴다(docs/TROUBLESHOOTING.md)

# 개발 서버에 붙이기 (릴리스 빌드에는 넘기지 않는다)
VITE_WEB_BASE_URL=http://10.0.2.2:2630 npm run sync
```
