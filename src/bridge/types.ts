/**
 * 웹 ↔ 셸 브릿지 계약 타입 (docs/BRIDGE_CONTRACT.md).
 *
 * **이 파일은 nuplex 웹과 공유하는 계약이다.**
 * 메서드를 지우지 않는다. 새 기능은 BRIDGE_VERSION 을 올리고 메서드를 추가하는
 * 방식으로만 한다 — 웹은 앱 업데이트 없이 바뀌지만 구버전 셸을 쓰는 사용자는
 * 남아 있기 때문이다.
 */

export type PushPermissionState = 'granted' | 'denied' | 'prompt';

export interface OpenInPlexParams {
  /**
   * 웹이 만든 주소. 지금은 우리 Plex 서버가 직접 서빙하는 웹앱 주소다
   * (`https://plex.nugabox.com/web/index.html#!/server/<mid>/details?key=...`).
   * 셸은 이걸 **최후의 폴백으로만** 쓴다 — Plex 앱은 이 도메인을 가로채지 않는다.
   */
  webUrl: string;
  /** Plex 서버의 machineIdentifier. 셸이 앱용 주소를 다시 만들 때 쓴다. */
  machineIdentifier?: string;
  /** 작품의 ratingKey. 위와 같다. 둘 중 하나라도 없으면 앱 딥링크를 포기한다. */
  ratingKey?: string;
  /**
   * Plex 의 항목 종류(`movie` · `episode` · `show` · `season` · `collection` …).
   *
   * **넘겨주면 셸이 시리즈를 재생하려 들지 않는다.** Plex 앱의 항목 딥링크는 재생
   * 명령이라, 재생할 파일이 없는 묶음(show · season · collection)을 주면 "Item not
   * known" 으로 실패한다. 그런 종류는 셸이 곧바로 웹 폴백으로 보내 상세 화면을 띄운다.
   *
   * 없으면 재생 가능한 항목으로 보고 진행한다 — 구버전 웹과의 호환.
   */
  type?: string;
}

export interface OpenInPlexResult {
  /**
   * 어디로 보냈는지. 실제로 Plex 앱이 그 작품까지 갔는지는 OS 가 알려주지 않으므로
   * 'app' 은 "Plex 앱이 링크를 받았다" 는 뜻이다.
   *
   * 'store' 는 Plex 앱이 설치돼 있지 않아 스토어로 보냈다는 뜻이다. **구버전 웹은
   * 이 값을 모른다** — 계약상 웹은 이 값을 표시 문구에만 쓰므로 안전하다.
   */
  opened: 'app' | 'browser' | 'store';
}

export interface NuplexNative {
  bridgeVersion: number;
  appVersion: string;
  platform: 'ios' | 'android';

  openInPlex(params: OpenInPlexParams): Promise<OpenInPlexResult>;

  getPushPermission(): Promise<PushPermissionState>;
  requestPushPermission(): Promise<'granted' | 'denied'>;
  getPushToken(): Promise<string | null>;
  clearPushRegistration(): Promise<void>;

  openExternal(url: string): Promise<void>;
  setBadgeCount(n: number): Promise<void>;

  /**
   * 웹이 라우팅 준비를 마쳤음을 알린다.
   * 앱이 종료된 상태에서 알림을 탭하면 라우팅 이벤트가 웹뷰 로드보다 먼저 도착한다.
   * 셸은 그 경로를 큐에 넣고 이 호출을 기다렸다가 flush 한다.
   */
  notifyWebReady(): void;
}

declare global {
  interface Window {
    NuplexNative?: NuplexNative;
  }
}
