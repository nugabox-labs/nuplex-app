/**
 * 오프라인 화면. 재시도 시 부팅 화면으로 되돌린다.
 * Phase 2 에서 @capacitor/network 로 연결 복구를 감지해 자동 재시도를 붙인다.
 */
document.querySelector<HTMLButtonElement>('#retry')?.addEventListener('click', () => {
  window.location.replace('/index.html');
});
