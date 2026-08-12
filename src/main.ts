import { DEFAULT_WEB_BASE_URL } from './config/constants';

/**
 * 셸 부트스트랩 엔트리.
 *
 * Phase 1 에서는 스캐폴딩이 빌드되는지만 확인하는 최소 구현이다.
 * Phase 2 에서 원격 설정 조회 → 버전 체크 → 웹뷰 이동 순서로 교체한다.
 */
export async function bootstrap(): Promise<void> {
  // TODO(phase-2): remote-config 조회 + 캐시 + 폴백, 오프라인 감지, 강제 업데이트 분기
  window.location.replace(DEFAULT_WEB_BASE_URL);
}
