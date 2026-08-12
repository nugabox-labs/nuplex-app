import { App } from '@capacitor/app';
import { Network } from '@capacitor/network';
import { Preferences } from '@capacitor/preferences';
import { DEFAULT_WEB_BASE_URL, STORAGE_KEYS } from './config/constants';
import { loadRemoteConfig, type RemoteConfig } from './config/remote-config';
import { isBelow } from './config/version';

/**
 * 셸 부트스트랩 (설계 명세 Phase 2).
 *
 *   스플래시 → 원격 설정 조회 → 점검/버전 확인 → 웹뷰를 webBaseUrl 로 이동
 *
 * 원칙 하나: **어떤 실패 경로에서도 흰 화면을 남기지 않는다.** 설정 조회가 실패하면
 * 캐시로, 캐시도 없으면 기본값으로 부팅하고, 네트워크 자체가 죽었으면 오프라인
 * 화면을 띄운다.
 */

/** 강제 업데이트 화면에 넘길 정보. 화면 쪽에서 Preferences 로 읽는다. */
interface UpdateScreenState {
  message: string;
  storeUrl: string;
  kind: 'update' | 'maintenance';
}

async function getAppVersion(): Promise<string> {
  try {
    const info = await App.getInfo();
    return info.version;
  } catch {
    // 브라우저에서 dev 로 열었을 때. 버전 체크를 건너뛰게 큰 값을 준다.
    return '999.0.0';
  }
}

async function isOnline(): Promise<boolean> {
  try {
    return (await Network.getStatus()).connected;
  } catch {
    return true; // 판단이 안 되면 일단 시도해 본다.
  }
}

function goTo(path: string): void {
  window.location.replace(path);
}

async function showUpdateScreen(state: UpdateScreenState): Promise<void> {
  await Preferences.set({
    key: STORAGE_KEYS.updateScreenState,
    value: JSON.stringify(state),
  });
  goTo('/update-required.html');
}

export async function bootstrap(): Promise<void> {
  if (!(await isOnline())) {
    // 연결이 없으면 설정 조회에 5초를 버릴 이유가 없다. 바로 오프라인 화면으로 간다.
    goTo('/offline.html');
    return;
  }

  const { config, source } = await loadRemoteConfig(DEFAULT_WEB_BASE_URL);

  // 설정을 한 번도 받아본 적 없는데 네트워크도 못 뚫었다면 웹뷰를 띄워봐야 어차피
  // 실패한다. 흰 화면 대신 재시도할 수 있는 화면을 보여준다.
  if (source === 'default') {
    goTo('/offline.html');
    return;
  }

  if (config.maintenance.enabled) {
    await showUpdateScreen({
      kind: 'maintenance',
      message: config.maintenance.message || '점검 중입니다. 잠시 후 다시 시도해 주세요.',
      storeUrl: '',
    });
    return;
  }

  const appVersion = await getAppVersion();
  if (isBelow(appVersion, config.minSupportedAppVersion)) {
    await showUpdateScreen({
      kind: 'update',
      message: '계속 사용하려면 최신 버전으로 업데이트해 주세요.',
      storeUrl: await storeUrlFor(config),
    });
    return;
  }

  // 알림을 쓸 수 있는 상태이고 아직 설명한 적이 없으면 온보딩을 한 번 보여준다.
  // 서버에 FCM 자격증명이 없으면(pushEnabled=false) 묻지 않는다 — 받을 수도 없는
  // 알림을 허용해 달라고 하는 것만큼 나쁜 첫인상이 없다.
  if (config.features.pushEnabled && !(await hasSeenOnboarding())) {
    goTo('/onboarding.html');
    return;
  }

  // 네이티브가 푸시 라우트를 조립할 때 쓴다. 알림 탭은 앱이 꺼진 상태에서도 오므로
  // 원격 설정을 기다릴 수 없다 — 마지막으로 확정된 주소를 남겨둔다.
  await Preferences.set({ key: STORAGE_KEYS.webBaseUrl, value: config.webBaseUrl });

  goTo(config.webBaseUrl);
}

async function hasSeenOnboarding(): Promise<boolean> {
  try {
    const { value } = await Preferences.get({ key: STORAGE_KEYS.onboardingSeen });
    return value === '1';
  } catch {
    // 읽지 못했다면 다시 보여주기보다 넘어간다. 온보딩 때문에 앱을 못 쓰면 안 된다.
    return true;
  }
}

async function storeUrlFor(config: RemoteConfig): Promise<string> {
  const { Capacitor } = await import('@capacitor/core');
  return Capacitor.getPlatform() === 'ios' ? config.storeUrls.ios : config.storeUrls.android;
}
