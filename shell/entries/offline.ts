import { Network } from '@capacitor/network';

/**
 * 오프라인 화면.
 *
 * 재시도 버튼을 누르지 않아도, 연결이 돌아오면 스스로 부팅을 다시 시도한다.
 * 사용자가 지하철에서 나왔을 때 버튼을 찾아 누르게 만들 이유가 없다.
 */
function retry(): void {
  window.location.replace('/index.html');
}

document.querySelector<HTMLButtonElement>('#retry')?.addEventListener('click', retry);

void Network.addListener('networkStatusChange', (status) => {
  if (status.connected) retry();
});
