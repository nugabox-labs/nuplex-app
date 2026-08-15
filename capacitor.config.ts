import type { CapacitorConfig } from '@capacitor/cli';

/**
 * ADR-001: 하이브리드 로드.
 * server.url 로 원격 도메인을 통째로 지정하지 않는다. 앱은 로컬 www/index.html 로
 * 부팅한 뒤, /api/app/config 로 받은 webBaseUrl 로 직접 이동한다.
 * 이렇게 해야 네트워크 장애 시 흰 화면 대신 offline.html 을 띄울 수 있고,
 * 도메인이 바뀌어도 앱 업데이트 없이 대응된다.
 */
const config: CapacitorConfig = {
  appId: 'com.nugabox.nuplex',
  appName: 'NUPLEX',
  webDir: 'www',
  server: {
    androidScheme: 'https',
    iosScheme: 'https',
    // 이 목록에 없는 도메인은 웹뷰 내 이동이 차단되고 시스템 브라우저로 나간다.
    // app.plex.tv 와 plex.nugabox.com 을 일부러 넣지 않는다 — Plex 링크는 웹뷰에
    // 가두지 않고 OS 로 넘겨야 한다(docs/PLEX_DEEPLINK.md).
    //
    // 뒤쪽 둘은 개발용이다(10.0.2.2 는 Android 에뮬레이터에서 본 맥의 주소).
    //
    // **와일드카드 IP(192.168.* 같은)를 넣지 말 것.** Android WebView 의 origin 규칙은
    // 그 형식을 거부하고, 브릿지 주입 단계에서 IllegalArgumentException 이 나서
    // 앱이 시작하자마자 죽는다. 실기기로 개발 서버를 볼 때는 맥의 주소를 정확히
    // 적는다 (예: '192.168.0.10'). docs/TROUBLESHOOTING.md 참고.
    allowNavigation: ['nuplex.nugabox.com', 'localhost', '10.0.2.2'],
  },
  ios: {
    // §5.2 — 웹이 서버사이드에서도 앱 여부를 판별할 수 있게 UA 접미사를 붙인다.
    // 주의: Capacitor 8 에서 공백 처리 동작이 바뀌었으므로 서버는 공백 개수에
    // 의존하지 말고 정규식으로 파싱할 것.
    appendUserAgent: 'NuplexApp (ios; bridge/1)',
    limitsNavigationsToAppBoundDomains: false,
  },
  android: {
    appendUserAgent: 'NuplexApp (android; bridge/1)',
  },
};

export default config;
