# Phase 2 — 셸 부팅 플로우

- 상태: 완료 (2026-08-12)
- 커밋: `f4d8d88` (셸) · `d1e5546` (nuplex 웹)

## 한 일

- [x] `src/config/remote-config.ts` — 조회 + Preferences 캐시 + 폴백
- [x] 셸 로컬 화면 4종 (스플래시 · 오프라인 · 강제 업데이트 · 온보딩)
- [x] 부팅 시퀀스: 스플래시 → config → 점검·버전 확인 → 웹뷰 이동
- [x] `allowNavigation`, UA 접미사
- [x] `@capacitor/network` 오프라인 감지
- [x] 웹(nuplex) 쪽: `GET /api/app/config`, `viewport-fit=cover`, HTML `no-store`

## 설계 판단

- 실패 순서는 **네트워크 → 캐시 → 하드코딩 기본값**. 설정 API 장애가 부팅 불가로
  이어지면 안 된다.
- 응답은 필드 단위로 좁혀 받는다. 웹이 필드를 빠뜨려도 구버전 셸이 죽지 않게.
- 기본값의 `pushEnabled` 는 **false**. 서버 응답 없이 알림 권한을 묻지 않는다.
- 오프라인 화면은 연결 복구를 감지해 **버튼 없이 자동 재시도**.
- 점검 중에는 스토어 버튼을 "다시 시도" 로 바꾼다. 점검은 업데이트로 안 풀린다.

## 웹 저장소 동시 작업 조율

푸시 백엔드를 다른 작업자가 동시에 수정 중이었다. `docs/APP-INTEGRATION.md` 에
담당 분담표를 만들고 제 파일만 골라 커밋했다. 환경변수 이름이 어긋난 것을 발견해
라우트가 양쪽 이름(`APP_MIN_SUPPORTED_VERSION` / `APP_MIN_VERSION`)을 모두 받도록 했다.

## 검증

- 실행 중인 웹 서버에 `GET /api/app/config` → 200, 인증 없이 통과, 스키마 일치
- 셸 빌드 · `cap sync` 통과
