# ADR-004: 브릿지는 셸 JS 가 아니라 네이티브가 주입한다

- 상태: 채택 (2026-08-12)
- 관련: ADR-001(하이브리드 로드), docs/BRIDGE_CONTRACT.md

## 배경

설계 명세 Phase 3 은 `src/bridge/expose.ts` 가 `window.NuplexNative` 를 주입하도록
적고 있다. 그런데 ADR-001 에 따라 셸은 로컬 `www/index.html` 로 부팅한 뒤 웹뷰를
원격 도메인으로 보낸다. **이동하는 순간 로컬 페이지의 JS 컨텍스트는 통째로
사라진다.** 웹 JS 로 주입한 객체는 원격 페이지에 남지 않는다.

"그러면 Capacitor 브릿지 위에 얹으면 되지 않나" 가 다음 질문인데, 두 플랫폼의
동작이 갈린다. Capacitor 8.5.0 소스 기준으로 확인한 사실이다.

| | 원격 origin 페이지에 Capacitor 브릿지가 주입되는가 |
| --- | --- |
| iOS | **된다.** `WKUserScript(injectionTime: .atDocumentStart, forMainFrameOnly: true)` 는 origin 을 가리지 않는다 (`JSExport.swift`) |
| Android | **안 된다.** `WebViewCompat.addDocumentStartJavaScript` 의 허용 origin 이 앱 주소 하나로 고정되고, 그 분기에서 HTML 삽입용 injector 가 null 로 꺼진다 (`Bridge.java`) |

즉 Android 원격 페이지에는 `window.Capacitor` 자체가 없다. `server.url` 을 지정하면
해결되지만 그건 ADR-001 을 뒤집는 선택이고, 웹 주소를 원격 설정으로 바꿀 수 있는
여지도 사라진다.

## 결정

브릿지 스크립트를 **네이티브가 문서 시작 시점에 직접 주입한다.** Capacitor 의 주입
경로에 의존하지 않는다.

- 스크립트 원본은 `shell/public/nuplex-bridge.js` **하나**다. 빌드 → `cap sync` 를
  타고 `ios/App/App/public/`, `android/.../assets/public/` 으로 들어간다.
  플랫폼별 사본을 따로 두면 반드시 어긋난다.
- iOS: `NuplexViewController`(CAPBridgeViewController 서브클래스)가 `WKUserScript` 로
  주입하고 `WKScriptMessageHandler("nuplexShell")` 로 받는다.
- Android: `MainActivity` 가 `addDocumentStartJavaScript` 로 주입하고
  `@JavascriptInterface("NuplexShellNative")` 로 받는다. 허용 origin 은 Capacitor 가
  allowNavigation 을 포함해 만들어 둔 `getAllowedOriginRules()` 를 그대로 쓴다.
- 응답은 네이티브가 `window.__nuplexBridgeResolve(id, payload)` 를 평가해 돌려준다.

## 결과

- 두 플랫폼에서 동일한 계약이 보장된다. 실제로 시뮬레이터에서 원격 페이지
  (`http://localhost:2620/login`)에 주입되는 것을 로그로 확인했다.
- Capacitor 내부 구현이 바뀌어도 브릿지는 영향을 받지 않는다.
- 대신 브릿지 메서드는 **네이티브에 두 번 구현해야 한다**(Swift/Java). 계약이
  작게 유지되어야 하는 실질적인 이유가 여기 있다.
- `addJavascriptInterface` 는 origin 을 가리지 않는다. `allowNavigation` 목록이
  사실상의 방어선이므로 **거기에 신뢰할 수 없는 도메인을 넣지 않는다.**

## 곁가지: 로컬 페이지에서의 CORS

셸의 로컬 페이지 origin 은 `capacitor://localhost` 다. 여기서 웹 도메인으로 보내는
`fetch` 는 전부 교차 출처가 되어 CORS 에 막힌다. 그래서 원격 설정 조회는 브라우저
`fetch` 가 아니라 **`CapacitorHttp`**(네이티브에서 나가는 요청)로 한다.
웹뷰가 웹 도메인으로 이동한 뒤에는 동일 출처라 이 문제가 없다.
