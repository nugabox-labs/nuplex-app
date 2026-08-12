import { Preferences } from '@capacitor/preferences';
import { STORAGE_KEYS } from '../../src/config/constants';

/**
 * 알림 권한 사전 설명 화면 (docs/PUSH_PAYLOAD.md).
 *
 * OS 권한 다이얼로그를 곧바로 띄우지 않는다. iOS 는 한 번 거절당하면 앱에서 다시
 * 물어볼 방법이 없다 — 사용자가 설정 앱까지 들어가야 한다. 그래서 왜 필요한지
 * 먼저 설명하고, 동의를 누른 사람에게만 OS 다이얼로그를 띄운다.
 *
 * 브릿지는 네이티브가 주입하므로 이 로컬 페이지에도 존재한다(ADR-004).
 */
const allow = document.querySelector<HTMLButtonElement>('#allow');
const skip = document.querySelector<HTMLButtonElement>('#skip');

async function markSeenAndContinue(): Promise<void> {
  // 다시 묻지 않는다. 알림은 설정 화면에서 언제든 켤 수 있다.
  await Preferences.set({ key: STORAGE_KEYS.onboardingSeen, value: '1' });
  window.location.replace('/index.html');
}

allow?.addEventListener('click', () => {
  void (async () => {
    allow.disabled = true;
    try {
      // 거절해도 그냥 넘어간다. 권한 없이도 앱은 온전히 동작한다.
      await window.NuplexNative?.requestPushPermission();
    } catch {
      // 브릿지가 없거나 실패한 경우. 온보딩에서 막을 이유가 없다.
    }
    await markSeenAndContinue();
  })();
});

skip?.addEventListener('click', () => {
  void markSeenAndContinue();
});
