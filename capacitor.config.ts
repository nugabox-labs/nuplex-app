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
    // app.plex.tv 를 일부러 넣지 않는다 — Plex 링크는 OS 가 앱으로 인터셉트해야 한다.
    //
    // 뒤쪽 세 줄은 개발용이다. 실기기에서 맥의 dev 서버(:2620)를 보려면 사설망
    // 주소로 이동할 수 있어야 한다. 사설 대역이라 스토어 빌드에 남아도 외부에서
    // 악용할 수 있는 경로는 아니지만, 릴리스 점검 목록에 확인 항목을 둔다
    // (docs/RELEASE.md).
    allowNavigation: ['nuplex.nugabox.com', 'localhost', '192.168.*', '10.*'],
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
