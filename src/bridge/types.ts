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
  /** https://app.plex.tv/... 형태. 웹이 이미 만들고 있다(lib/plex/client.ts). */
  webUrl: string;
  machineIdentifier?: string;
  ratingKey?: string;
}

export interface OpenInPlexResult {
  /**
   * 실제로 Plex 앱이 열렸는지 브라우저로 갔는지는 OS 가 정하고 알려주지 않는다.
   * https 링크로 넘긴 경우 'app' 은 "OS 에 넘겼다" 는 뜻이다.
   */
  opened: 'app' | 'browser';
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
