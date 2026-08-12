/**
 * 셸 하드코딩 기본값.
 *
 * §9.1 폴백 정책: /api/app/config 가 실패하고 캐시도 없을 때 이 값으로 부팅한다.
 * 설정 API 장애가 앱 부팅 불가로 이어져서는 안 된다.
 */

/** 운영 웹 도메인. capacitor.config.ts 의 server.allowNavigation 과 반드시 일치시킬 것. */
export const DEFAULT_WEB_BASE_URL = 'https://nuplex.nugabox.com';

/** 로컬 개발 서버 (nuplex 웹의 `npm run dev` 는 0.0.0.0:2620 을 연다). */
export const DEV_WEB_BASE_URL = 'http://localhost:2620';

/** 원격 설정 엔드포인트 경로 (§9.1). */
export const REMOTE_CONFIG_PATH = '/api/app/config';

/** 푸시 토큰 등록/해제 엔드포인트 경로 (§6.4). */
export const PUSH_TOKEN_PATH = '/api/app/push/token';

/** 원격 설정 조회 타임아웃(ms). 초과 시 캐시 또는 기본값으로 진행한다. */
export const REMOTE_CONFIG_TIMEOUT_MS = 5_000;

/** 브릿지 계약 버전 (§5.1). 새 메서드를 추가할 때만 올린다. */
export const BRIDGE_VERSION = 1;

/** Preferences 저장 키. */
export const STORAGE_KEYS = {
  remoteConfigCache: 'nuplex.remoteConfig.v1',
  pushToken: 'nuplex.pushToken.v1',
  onboardingSeen: 'nuplex.onboardingSeen.v1',
} as const;
