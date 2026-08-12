import { Browser } from '@capacitor/browser';
import { Preferences } from '@capacitor/preferences';
import { STORAGE_KEYS } from '../../src/config/constants';

/**
 * 강제 업데이트 · 점검 화면.
 * 어떤 문구를 띄울지는 부팅 시퀀스(src/main.ts)가 Preferences 에 넣어둔다.
 */
interface UpdateScreenState {
  message: string;
  storeUrl: string;
  kind: 'update' | 'maintenance';
}

const heading = document.querySelector<HTMLHeadingElement>('h1');
const messageEl = document.querySelector<HTMLParagraphElement>('#message');
const storeButton = document.querySelector<HTMLButtonElement>('#store');

async function render(): Promise<void> {
  let state: UpdateScreenState | null = null;
  try {
    const { value } = await Preferences.get({ key: STORAGE_KEYS.updateScreenState });
    if (value) state = JSON.parse(value) as UpdateScreenState;
  } catch {
    // 읽지 못하면 HTML 에 박아둔 기본 문구가 그대로 남는다.
  }

  if (!state) return;

  if (messageEl) messageEl.textContent = state.message;

  if (state.kind === 'maintenance') {
    if (heading) heading.textContent = '점검 중입니다';
    // 점검은 업데이트로 풀리지 않는다. 스토어 버튼을 다시 시도 버튼으로 바꾼다.
    if (storeButton) {
      storeButton.textContent = '다시 시도';
      storeButton.addEventListener('click', () => window.location.replace('/index.html'));
    }
    return;
  }

  // 심사 전이라 스토어 주소가 아직 없을 수 있다. 눌러도 아무 일 없는 버튼을
  // 보여주느니 감춘다.
  if (!state.storeUrl) {
    storeButton?.remove();
    return;
  }
  storeButton?.addEventListener('click', () => {
    void Browser.open({ url: state.storeUrl });
  });
}

void render();
