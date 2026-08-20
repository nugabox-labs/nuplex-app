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


/** TV 캐스트 후보 — 웹이 plex.tv 에서 받아 셸에 넘긴다 (계약 v2). */
export interface CastCandidate {
  /** 플레이어의 machineIdentifier. */
  id: string;
  /** 사용자에게 보여줄 이름 (예: "거실 Apple TV"). */
  name: string;
  /** 플레이어 주소. 사설 IP 다 — 예: `http://192.168.68.111:32500`. */
  uri: string;
}

/**
 * 지금 **실제로 닿는** 플레이어. 셸이 후보를 하나씩 찔러 보고 응답한 것만 담는다.
 * 목록에 있으면 반드시 눌린다 — 웹은 따로 도달 확인을 하지 않아도 된다.
 */
export interface CastTarget {
  /**
   * 플레이어가 스스로 보고한 machineIdentifier. **후보의 `id` 와 다를 수 있다** —
   * plex.tv 등록값과 어긋나는 경우가 있어 셸이 실물 값으로 덮어쓴다.
   * 재생 요청에는 반드시 이 값을 되돌려줄 것.
   */
  id: string;
  name: string;
  uri: string;
}

export interface CastPlayParams {
  /** listCastTargets 가 돌려준 target 의 `id` · `uri` 를 그대로 넘긴다. */
  targetId: string;
  uri: string;
  /** Plex 계정 토큰. 셸은 보관하지 않고 이 호출에만 쓴다. */
  token: string;
  /** 플레이어가 미디어를 받아올 우리 Plex 서버 주소. */
  serverAddress: string;
  serverPort: number;
  serverProtocol: 'http' | 'https';
  /** Plex 서버의 machineIdentifier. */
  machineIdentifier: string;
  ratingKey: string;
  /** 이어보기 위치(ms). 기본 0. */
  offset?: number;
}

export interface CastPlayResult {
  ok: boolean;
  /**
   * 실패 이유. 웹은 이 값으로 안내 문구를 고른다.
   *
   * - `unreachable` — 폰이 그 WiFi 를 떠났거나 TV 가 꺼졌다
   * - `rejected` — 플레이어가 명령을 거절했다. **대개 TV 에서 Plex 앱이 꺼져 있는
   *   경우다.** Companion 서버가 그 앱 안에 있어 앱이 떠 있어야만 받는다
   * - `missing-params` · `bad-url` — 웹이 인자를 빠뜨렸다
   * - `no-bridge` — 브라우저이거나 구버전 셸이다
   */
  error?: string;
  status?: number;
  detail?: string;
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

  /**
   * 후보 중 지금 닿는 플레이어만 골라 돌려준다 (계약 v2).
   *
   * **같은 WiFi 에 있을 때만 결과가 나온다.** Plex 플레이어는 사설 IP 하나만
   * 광고하고 relay 주소가 없어서, 밖에서는 원리적으로 닿지 않는다.
   * 빈 배열이면 "TV에서 시청" 을 감추면 된다.
   */
  listCastTargets(params: {
    candidates: CastCandidate[];
    token: string;
  }): Promise<{ targets: CastTarget[] }>;

  /** 플레이어에 재생을 시킨다 (계약 v2). */
  castToTarget(params: CastPlayParams): Promise<CastPlayResult>;

  /**
   * 시스템 화면 공유 피커를 연다 (계약 v2).
   *
   * **플랫폼마다 다른 물건이고, 둘 다 한계가 뚜렷하다.**
   * - iOS: AirPlay 피커. 앱이 네이티브로 재생 중인 것이 없으면 골라도 아무 일이
   *   일어나지 않는다. 화면 미러링은 제어 센터 전용이라 앱이 시작시킬 수 없다.
   * - Android: 시스템 캐스트 설정 패널. 목록은 Google Cast 계열이라
   *   **Apple TV 는 뜨지 않는다.** 기기에 따라 화면 자체가 없을 수 있다.
   */
  openRoutePicker(): Promise<{ shown: boolean }>;

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
