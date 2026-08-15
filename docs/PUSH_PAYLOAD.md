# 푸시 페이로드

> 이 문서는 `nuplex`(발송)와 `nuplex-app`(수신)이 함께 지키는 계약이다.
> 발송 구현은 `nuplex/lib/push/fcm.ts` 에 있다.

## 스키마

```jsonc
{
  "notification": {
    "title": "새 작품이 추가되었습니다",
    "body": "듄: 파트 3"
  },
  "data": {
    "v": "1",                     // 페이로드 스키마 버전
    "type": "notice",             // notice | chat | new_item | available | custom
    "route": "/title/12345",      // 셸이 웹뷰에서 열 경로 (필수)
    "collapseKey": "notice"       // 같은 종류 알림 묶기 (선택)
  }
}
```

## 설계 원칙 셋

**1. 라우팅에 필요한 값은 전부 `data` 에 담는다.**
`notification` 은 표시용일 뿐이다. iOS 백그라운드에서는 `notification` 만 오면
앱의 코드가 아예 호출되지 않는다.

**2. `route` 는 경로 문자열이지 완전한 URL 이 아니다.**
셸이 `webBaseUrl + route` 로 조립한다. 도메인이 바뀌어도 **이미 발송된 알림이
깨지지 않게** 하기 위함이다. 완전한 URL 을 넣으면 도메인 이전 시 과거 알림이
전부 죽은 링크가 된다.

**3. `v` 로 스키마 버전을 표시한다.**
구버전 셸이 모르는 `type` 을 만나면 홈으로 폴백한다. 앱은 강제로 업데이트시킬 수
없으므로, 새 `type` 을 추가할 때 구버전이 무엇을 하게 될지 항상 확인한다.

## 플랫폼별 수신 동작

| 상황 | Android | iOS |
| --- | --- | --- |
| 포그라운드 | 앱이 직접 받아 처리 | 앱이 직접 받아 처리 |
| 백그라운드 | `data` 메시지는 앱이 받고, `notification` 이 함께 오면 시스템 트레이가 그린다 | 시스템이 그린다. `content-available` 사일런트 푸시만 앱이 깨어난다 |
| 알림 탭 | 앱이 라우트를 받아 웹뷰를 이동시킨다 | 동일 |
| **앱 종료 상태에서 탭** | 콜드 스타트. **라우팅 정보가 웹뷰 로드보다 먼저 도착한다** | 동일 |

마지막 줄이 이 기능에서 가장 자주 깨지는 지점이다. 셸은 도착한 라우트를 큐에
넣어두고, 웹이 `notifyWebReady()` 를 부른 뒤에 이동시킨다.

## Android 알림 채널

Android 8+ 는 채널이 필수다. 종류별로 나눠야 사용자가 "새 작품 알림만 끄기" 를
할 수 있다. 한 채널에 다 몰아넣으면 하나라도 거슬리는 순간 전부 꺼진다.

| 채널 id | 이름 | 용도 |
| --- | --- | --- |
| `new_item` | 새 작품 | 라이브러리에 작품이 추가됨 |
| `available` | 시청 가능 | 관심 작품을 이제 볼 수 있음 |
| `chat` | 메시지 | 채팅 (`nuplex/docs/CHAT.md`) |
| `general` | 일반 | 공지 등 그 외 |

**이 표는 발송 쪽 `nuplex/lib/push/fcm.ts` 의 `ANDROID_CHANNELS` 와 같아야 한다.**
웹이 `android.notification.channel_id` 로 채널 id 를 실어 보내는데, 앱이 백그라운드일
때는 시스템이 그 채널로 알림을 그린다. **셸에 없는 채널이면 Android 8+ 는 알림을
조용히 버린다.** 발송 로그에는 성공으로 남고 사용자에게는 아무것도 안 뜬다.
웹이 채널을 추가하면 셸도 함께 추가할 것.

### 시스템이 그린 알림을 탭했을 때

셸은 알림을 직접 그리지만, 앱이 백그라운드면 `onMessageReceived` 가 아예 불리지
않아 시스템이 대신 그린다. 그때 탭하면 우리가 심은 `nuplex_route` extra 가 없다.
FCM 이 `data` 의 키를 그대로 런처 인텐트 extra 로 실어주므로, `MainActivity` 는
`route` extra 를 폴백으로 읽는다. 이게 없으면 그 경로로 들어온 사람은 홈으로만 간다.

## Android 알림 아이콘

Android 는 상태바 아이콘을 **투명 배경 위 흰색 픽셀**로 요구한다. 지정하지 않으면
앱 아이콘이 폴백으로 쓰이는데, 그 조건을 만족하지 않아 회색 사각형으로 뭉개진다.
`res/drawable/ic_stat_nuplex.xml` 을 만들고 매니페스트에 지정한다.

## 토큰 생명주기

```
앱 최초 실행
  → 온보딩 화면에서 알림이 왜 필요한지 설명 (권한 다이얼로그를 곧바로 띄우지 않는다)
  → 사용자가 동의 → OS 권한 요청
  → 토큰 획득 → POST /api/app/push/token
     { deviceId, token, platform, appVersion, locale, timezone }

토큰 갱신 → 로컬 캐시와 다르면 재등록
로그아웃  → DELETE /api/app/push/token { deviceId }

앱 삭제 / 장기 미사용
  → 셸은 알 수 없다. 서버가 FCM 의 UNREGISTERED / NOT_FOUND 응답을 보고 지워야 한다
    (nuplex 백엔드 책임. lib/push/fcm.ts 의 SendResult.unregistered)
```

Android 13+ 는 `POST_NOTIFICATIONS` 런타임 권한이 필요하다. Android 12 이하에서는
권한 상태가 항상 "허용" 으로 나온다는 점을 UI 로직에서 감안한다.
