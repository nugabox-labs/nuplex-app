# nuplex-app

NUPLEX의 iOS/Android 네이티브 셸. Capacitor 기반이며 하는 일은 세 가지뿐이다.

1. **웹뷰 호스팅** — [nuplex](https://github.com/nugabox-labs/nuplex) 웹서비스를 원격 로드
2. **푸시 알림** — FCM 토큰 등록 및 알림 탭 → 딥링크 라우팅
3. **Plex 딥링크** — 작품 재생 시 Plex 앱으로 이동

콘텐츠 UI·API·동기화는 전부 `nuplex` 저장소에 있다. 이 저장소에는 셸 고유 화면
(스플래시·오프라인·강제 업데이트·알림 온보딩)만 둔다.

## 요구 환경

| 항목 | 버전 |
| --- | --- |
| Node.js | 22.x (`.nvmrc` = 22.23.2) |
| Capacitor | 8.5.0 |
| Xcode | 26.0+ (Deployment Target iOS 15.0) |
| Android Studio | Otter(2025.2.1)+ / JDK 17+ |
| Android SDK | compileSdk·targetSdk 36, minSdk 24 |

## 시작하기

```bash
nvm use              # .nvmrc → Node 22
npm install
npm run build        # 셸 로컬 자산 빌드 (shell/ → www/)
npm run sync         # build + npx cap sync

npm run open:ios     # Xcode 로 열기
npm run open:android # Android Studio 로 열기
```

Capacitor CLI 는 `npx cap` 대신 **`npm run cap -- <명령>`** 으로 실행한다.
이 래퍼(`scripts/cap.mjs`)가 로컬 환경 문제 두 가지를 우회한다 —
RVM 이 오염시킨 gem 환경변수 제거, Android Studio 번들 JDK 지정.
자세한 내용은 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## 디렉토리

```
shell/          셸 로컬 화면의 HTML/CSS 소스와 엔트리
src/            셸 TypeScript 로직 (config · native · bridge)
www/            빌드 산출물 = Capacitor webDir. 커밋하지 않음
ios/ android/   네이티브 프로젝트. 수동 설정이 들어가므로 커밋함
docs/           브릿지 계약 · 푸시 페이로드 · 릴리스 · 트러블슈팅
```

## 문서

- [CLAUDE.md](CLAUDE.md) — **작업 시작점.** 문서 지도와 두 에이전트(Claude Code · Desktop) 동기화 규약
- [docs/plan/active/](docs/plan/active/) — **지금 무엇이 남았는지.** 진행 상황의 단일 진실 원천
- [docs/BRIDGE_CONTRACT.md](docs/BRIDGE_CONTRACT.md) — 웹 ↔ 셸 계약. **`nuplex` 저장소에도 사본을 둔다**
- [docs/PUSH_PAYLOAD.md](docs/PUSH_PAYLOAD.md) — 푸시 페이로드 스키마
- [docs/TESTING.md](docs/TESTING.md) — **테스트 계정**과 확인 목록
- [docs/PLEX_DEEPLINK.md](docs/PLEX_DEEPLINK.md) — Plex 앱으로 보내는 사다리
- [docs/RELEASE.md](docs/RELEASE.md) — 버전 규칙 · TestFlight · 심사
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## 시크릿

`google-services.json`, `GoogleService-Info.plist`, 서명 키, `.p8` 은 **절대 커밋하지 않는다**
(`.gitignore` 참고). CI 에서는 GitHub Secrets 로 주입한다.
