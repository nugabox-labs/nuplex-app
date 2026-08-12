import { Preferences } from '@capacitor/preferences';
import {
  DEFAULT_WEB_BASE_URL,
  REMOTE_CONFIG_PATH,
  REMOTE_CONFIG_TIMEOUT_MS,
  STORAGE_KEYS,
} from './constants';

/**
 * 원격 설정 (계약: docs/BRIDGE_CONTRACT.md §3).
 *
 * 앱 업데이트 없이 셸 동작을 바꿀 수 있는 유일한 수단이다. 그만큼 부팅 경로의
 * 급소이기도 해서, 실패해도 앱은 반드시 뜬다 — 네트워크 → 캐시 → 하드코딩 기본값
 * 순으로 물러난다.
 */
export interface RemoteConfig {
  webBaseUrl: string;
  minSupportedAppVersion: string;
  recommendedAppVersion: string;
  maintenance: { enabled: boolean; message: string };
  features: { pushEnabled: boolean; plexCustomScheme: boolean };
  storeUrls: { ios: string; android: string };
}

export type ConfigSource = 'network' | 'cache' | 'default';

export const FALLBACK_CONFIG: RemoteConfig = {
  webBaseUrl: DEFAULT_WEB_BASE_URL,
  minSupportedAppVersion: '0.0.0',
  recommendedAppVersion: '0.0.0',
  maintenance: { enabled: false, message: '' },
  // 서버 응답을 못 받은 상태에서 알림 권한을 묻지 않는다. 받을 수 있는지도 모르는
  // 알림을 허용해 달라고 하는 것만큼 나쁜 첫인상이 없다.
  features: { pushEnabled: false, plexCustomScheme: false },
  storeUrls: { ios: '', android: '' },
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function str(value: unknown, fallback: string): string {
  return typeof value === 'string' ? value : fallback;
}

function bool(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

/**
 * 서버 응답을 신뢰하지 않고 필드 단위로 좁힌다.
 * 웹이 필드를 하나 빠뜨렸다고 구버전 셸이 부팅 중에 죽으면 안 된다.
 */
export function normalize(raw: unknown): RemoteConfig {
  if (!isRecord(raw)) return FALLBACK_CONFIG;

  const maintenance = isRecord(raw.maintenance) ? raw.maintenance : {};
  const features = isRecord(raw.features) ? raw.features : {};
  const storeUrls = isRecord(raw.storeUrls) ? raw.storeUrls : {};

  return {
    webBaseUrl: str(raw.webBaseUrl, FALLBACK_CONFIG.webBaseUrl).replace(/\/+$/, ''),
    minSupportedAppVersion: str(raw.minSupportedAppVersion, FALLBACK_CONFIG.minSupportedAppVersion),
    recommendedAppVersion: str(raw.recommendedAppVersion, FALLBACK_CONFIG.recommendedAppVersion),
    maintenance: {
      enabled: bool(maintenance.enabled, false),
      message: str(maintenance.message, ''),
    },
    features: {
      pushEnabled: bool(features.pushEnabled, false),
      plexCustomScheme: bool(features.plexCustomScheme, false),
    },
    storeUrls: {
      ios: str(storeUrls.ios, ''),
      android: str(storeUrls.android, ''),
    },
  };
}

async function readCache(): Promise<RemoteConfig | null> {
  try {
    const { value } = await Preferences.get({ key: STORAGE_KEYS.remoteConfigCache });
    if (!value) return null;
    return normalize(JSON.parse(value));
  } catch {
    return null;
  }
}

async function writeCache(config: RemoteConfig): Promise<void> {
  try {
    await Preferences.set({
      key: STORAGE_KEYS.remoteConfigCache,
      value: JSON.stringify(config),
    });
  } catch {
    // 캐시 저장 실패는 부팅을 막을 이유가 아니다.
  }
}

/**
 * 설정을 가져온다. 어디서 왔는지(source)도 함께 돌려준다 — 호출부가 "네트워크가
 * 정말 죽었는지" 를 판단해 오프라인 화면을 띄울지 결정해야 하기 때문이다.
 */
export async function loadRemoteConfig(
  baseUrl: string = DEFAULT_WEB_BASE_URL,
): Promise<{ config: RemoteConfig; source: ConfigSource }> {
  try {
    const response = await fetch(`${baseUrl}${REMOTE_CONFIG_PATH}`, {
      headers: { Accept: 'application/json' },
      cache: 'no-store',
      signal: AbortSignal.timeout(REMOTE_CONFIG_TIMEOUT_MS),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const config = normalize(await response.json());
    await writeCache(config);
    return { config, source: 'network' };
  } catch {
    const cached = await readCache();
    if (cached) return { config: cached, source: 'cache' };
    return { config: FALLBACK_CONFIG, source: 'default' };
  }
}
