# Phase 3 — 브릿지 주입

- 상태: 완료 (2026-08-12)
- 커밋: `7e8b343` feat: expose NuplexNative bridge to webview
- 관련: `docs/ADR-004-bridge-injection.md`

## 명세를 뒤집은 지점

명세는 셸 JS(`src/bridge/expose.ts`)가 `window.NuplexNative` 를 주입하라고 했다.
**동작하지 않는다.** 웹뷰가 원격 도메인으로 이동하는 순간 로컬 페이지의 JS
컨텍스트가 통째로 사라진다.

Capacitor 브릿지에 얹는 것도 답이 아니었다 (8.5.0 소스 확인):

| | 원격 origin 에 Capacitor 브릿지 주입 |
| --- | --- |
| iOS | 된다 (`WKUserScript` 는 origin 무관) |
| Android | **안 된다** (허용 origin 이 앱 주소 하나로 고정) |

→ 브릿지를 **네이티브가 직접 주입**한다.

## 한 일

- [x] `src/bridge/types.ts` — 계약 타입 (웹과 공유)
- [x] `shell/public/nuplex-bridge.js` — 주입 스크립트 **원본 하나**
- [x] iOS `NuplexViewController` + `NuplexBridgeAPI`
- [x] Android `MainActivity` + `NuplexBridgeApi`
- [x] `openExternal`, `setBadgeCount`
- [x] `docs/BRIDGE_CONTRACT.md` (nuplex 저장소에도 사본)

## 도중에 잡은 버그

`fetch` 로는 원격 설정을 못 받는다. 셸 로컬 페이지 origin 이 `capacitor://localhost`
라서 웹 도메인 요청이 전부 **CORS 에 막힌다**. `CapacitorHttp` 로 교체했다.
시뮬레이터에서 돌려보지 않았으면 실기기 테스트 때까지 몰랐을 문제다.

## 검증 (iOS 시뮬레이터)

- 스플래시 → 설정 조회 → `http://localhost:2620/login` 렌더링
- **원격 페이지에 브릿지 주입 확인** — 로그 `브릿지 주입됨: http://localhost:2620/login`
- 브릿지 RPC 왕복 확인 — `openInPlex={"opened":"browser"}`, `perm=prompt`
- 네트워크 실패 시 오프라인 화면 (흰 화면 없음)
- Android: 빌드만 확인. **에뮬레이터 실행 검증은 아직 안 했다.**
