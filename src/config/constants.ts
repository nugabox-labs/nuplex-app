/**
 * 셸 하드코딩 기본값.
 *
 * §9.1 폴백 정책: /api/app/config 가 실패하고 캐시도 없을 때 이 값으로 부팅한다.
 * 설정 API 장애가 앱 부팅 불가로 이어져서는 안 된다.
 */

/**
 * 웹 도메인. capacitor.config.ts 의 server.allowNavigation 과 반드시 일치시킬 것.
 *
 * 개발 중 맥에서 띄운 dev 서버(:2620)를 실기기로 보려면 빌드할 때 넘긴다.
 * 시뮬레이터/에뮬레이터가 아니라 실기기라면 localhost 가 아니라 맥의 사설망
 * 주소여야 한다.
 *
 *   VITE_WEB_BASE_URL=http://192.168.0.10:2620 npm run sync
 */
export const DEFAULT_WEB_BASE_URL =
  import.meta.env.VITE_WEB_BASE_URL || 'https://nuplex.nugabox.com';

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
  /** 강제 업데이트·점검 화면에 넘기는 문구와 스토어 주소. */
  updateScreenState: 'nuplex.updateScreen.v1',
  /**
   * 마지막으로 확정된 웹 주소.
   *
   * 네이티브가 푸시 라우트를 조립할 때 읽는다. 알림 탭은 앱이 종료된 상태에서도
   * 오므로, 네이티브가 원격 설정을 기다리지 않고 바로 쓸 값이 필요하다.
   * 네이티브 쪽 참조: NuplexPreferences.java / NuplexPreferences.swift
   */
  webBaseUrl: 'nuplex.webBaseUrl.v1',
} as const;
