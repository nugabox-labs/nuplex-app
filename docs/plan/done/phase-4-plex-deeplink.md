# Phase 4 — Plex 딥링크

- 상태: 완료 (2026-08-12). 단 **실기기 검증 미완**
- 커밋: `024e7d9` feat: plex deep link handling
- 관련: `docs/PLEX_DEEPLINK.md`

## 한 일

- [x] https 우선 경로 (양 플랫폼 네이티브 구현)
- [x] 앱/브라우저 구분: iOS `universalLinksOnly`, Android `FLAG_ACTIVITY_REQUIRE_NON_BROWSER`
- [x] iOS `LSApplicationQueriesSchemes`, Android `<queries>` 선언
- [x] 웹뷰 외부 도메인 인터셉트 (allowNavigation 에 `app.plex.tv` 를 넣지 **않는** 것으로 해결)
- [x] `plex://` 실험 경로는 TODO(verify) 로 남김

## 미확정 해소

명세는 Plex 딥링크 형식을 미확정으로 뒀지만, **웹에 이미 구현돼 있었다**
(`nuplex/lib/plex/client.ts:374`):

```
https://app.plex.tv/desktop/#!/server/{serverId}/details?key={urlencoded /library/metadata/ratingKey}
```

셸은 이 형식을 모른다. 완성된 `webUrl` 을 통째로 받는다 — 웹이 형식을 바꿔도 앱을
다시 배포하지 않아도 되게.

## 남은 것 (실기기 필요)

- [ ] Plex 앱 설치 상태에서 앱으로 열리는지
- [ ] 미설치 상태에서 브라우저로 폴백하는지
- [ ] `{ opened: 'app' }` 이 실제로 돌아오는지
- [ ] `plex://` 형식 확인 후 실험 경로 구현 여부 결정

## 검증

- 시뮬레이터: `openInPlex={"opened":"browser"}` (Plex 미설치 상태의 정확한 응답)
- 양 플랫폼 빌드 통과
