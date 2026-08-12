import { App } from '@capacitor/app';

/**
 * 포그라운드 복귀 정책 (§9.3).
 *
 * 웹뷰는 브라우저보다 페이지를 오래 붙들고 있다. 며칠 만에 앱을 다시 열면 몇 일 전
 * 화면이 그대로 남아 있고, 그 사이 바뀐 라이브러리가 반영되지 않는다.
 * 마지막 로드로부터 일정 시간이 지났으면 조용히 새로고침한다.
 */
const STALE_AFTER_MS = 30 * 60 * 1000;

let lastActiveAt = Date.now();

export function markActive(): void {
  lastActiveAt = Date.now();
}

/**
 * 백그라운드에 오래 있다 돌아온 경우에만 새로고침한다.
 * 알림을 확인하려고 잠깐 나갔다 오는 흔한 동작에서 화면이 깜빡이면 안 된다.
 */
export async function watchForegroundRefresh(
  onStale: () => void,
  staleAfterMs: number = STALE_AFTER_MS,
): Promise<void> {
  await App.addListener('appStateChange', ({ isActive }) => {
    if (!isActive) {
      lastActiveAt = Date.now();
      return;
    }
    const awayFor = Date.now() - lastActiveAt;
    lastActiveAt = Date.now();
    if (awayFor >= staleAfterMs) onStale();
  });
}
