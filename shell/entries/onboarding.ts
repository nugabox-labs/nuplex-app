/**
 * 알림 권한 사전 설명 화면 (§6.4).
 * OS 권한 다이얼로그를 즉시 띄우지 않고, 사용자가 '알림 받기'를 누른 뒤에만 요청한다.
 * Phase 5 에서 src/native/push 와 연결한다.
 */
document.querySelector<HTMLButtonElement>('#allow')?.addEventListener('click', () => {
  // TODO(phase-5): requestPushPermission() → getToken() → 서버 등록
});

document.querySelector<HTMLButtonElement>('#skip')?.addEventListener('click', () => {
  window.location.replace('/index.html');
});
