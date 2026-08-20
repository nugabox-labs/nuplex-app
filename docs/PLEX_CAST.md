# TV로 쏘기 (Plex Companion)

딥링크는 "이 폰에서 재생" 이다. TV로 쏘는 것은 다른 메커니즘 — **Plex Companion** 이다.
TV 의 Plex 앱이 *플레이어* 로 등록되고, 다른 기기가 그 플레이어에게 재생 명령을 HTTP 로 던진다.

**아직 구현하지 않았다.** 2026-08-20 조사에서 나온 사실만 적는다.

## 1. TV 쪽 준비 — "플레이어로 광고" 를 켜야 한다

켜기 전 Apple TV 는 `provides=[client]` 뿐이었다. 켠 뒤:

```
'Apple TV' / Plex for Apple TV
provides = [client, player, pubsub-player, provider-playback]
id       = 64971850-8C86-49C8-B6A9-0EF085BEA254
```

`player` 가 없으면 원격 재생 명령을 받지 못한다. **기기마다 사람이 한 번 켜 줘야 한다.**

## 2. 목록은 Plex **계정** 단위다 — 프로필 단위가 아니다

`https://plex.tv/api/resources` · `https://plex.tv/devices.xml` 은 **토큰이 속한 Plex
계정의 기기만** 돌려준다. 지금 `.env` 의 `PLEX_TOKEN` 주인은 `NUPLEX_`(NUGA) 다.

**NUPLEX 의 "프로필" 과 Plex 의 "계정" 은 별개다.** NUPLEX 는 프로필을 고르고 가입 이메일로
확인하는 자체 방식이고 Plex 계정과 연결돼 있지 않다. 그래서 지금 구조 그대로면:

- 가족이 **자기 Plex 계정으로 로그인한 TV** 는 이 토큰으로 보이지 않는다
- 즉 "TV 로 쏘기" 는 **NUGA 계정 기기에만** 동작한다

거실 TV 한 대만 대상이면 문제되지 않는다. 프로필마다 다른 TV 를 원하면 프로필 ↔ Plex 계정을
묶는 설계가 따로 필요하다. **아직 정하지 않았다.**

## 3. 막힌 지점 — 명령을 보낼 주체가 같은 망에 있어야 한다

Apple TV 가 광고하는 연결 주소는 **로컬 하나뿐**이다.

```
http://192.168.68.111:32500   local=1   relay=None
publicAddressMatches=0
```

relay 주소가 없다. 그리고 조사 시점의 망 구성이 셋으로 갈라져 있었다.

| | 주소 |
| --- | --- |
| Apple TV | `192.168.68.111` |
| 개발 맥 | `192.168.1.172` |
| Plex 서버 | `192.168.101.x` |

**서로 못 닿는다.** 실제로 확인한 것 —

- 맥 → TV `192.168.68.111:32500` 연결 실패 (curl exit 7)
- 맥 → 서버 `plex.nugabox.com:13394` · 로컬 `plex.direct` 주소 전부 연결 실패
- **공식 Plex Web(app.plex.tv)에서도 캐스트 목록이 비어 있었다.** NUGA 계정으로
  로그인한 상태에서 "플레이어 선택" 을 눌렀더니 `캐스트...` 헤더만 뜨고 기기가 하나도 없다.
  우리 구현 문제가 아니라 **망이 갈라져서 Plex 자신도 못 찾는 것**이다

### `pubsub-player` 가 있는데 왜 안 되나

`pubsub-player` 는 plex.tv 를 거쳐 명령을 받겠다는 선언이다. 그런데 **그 명령을 어디로
보내는지 공개된 엔드포인트를 찾지 못했다.** 읽기로 확인한 것 —

```
GET https://plex.tv/api/v2/user          200
GET https://plex.tv/api/v2/devices       200
GET https://plex.tv/api/v2/ping          200
GET https://plex.tv/api/v2/players       404
GET https://plex.tv/api/v2/pubsub        404
GET https://plex.tv/api/v2/clients       404
GET https://plex.tv/devices/<id>         404
```

Plex Web 이 캐스트할 때 보내는 요청을 그대로 베끼려 했으나, **캐스트 자체가 불가능해서
캡처에 실패했다.** 이 형식은 **미확인**이다.

## 4. 그래서 설계가 바뀐다

원래 "웹 서버가 명령을 보낸다" 로 갈 생각이었으나 **서버도 TV 와 같은 망에 없다.**
명령은 **TV 와 같은 WiFi 에 있는 기기** 에서 나가야 한다 = **폰의 앱 셸**이다.

즉 이건 웹 기능이 아니라 **셸의 브릿지 메서드**로 붙여야 한다. 다만 형식(§3)이 미확인이라
아직 시작하지 않았다.

## 5. 다음에 할 일

1. **개발 맥을 TV 와 같은 WiFi(`192.168.68.x`)에 붙인다.** 그 상태로 `app.plex.tv` 에서
   Apple TV 로 캐스트하면 목록에 뜰 것이고, 그때 요청을 캡처하면 형식이 확정된다
2. 형식이 나오면 셸 브릿지에 `castToPlayer` 류 메서드를 더한다
   (**지우지 말고 추가만** — `BRIDGE_CONTRACT.md` §5)
3. 프로필 ↔ Plex 계정 문제(§2)를 어떻게 할지 정한다

## 확인 방법

```bash
cd ../nuplex && export $(grep -E '^(PLEX_TOKEN|PLEX_CLIENT_ID)=' .env | xargs)
curl -s -H "X-Plex-Token: $PLEX_TOKEN" -H "X-Plex-Client-Identifier: $PLEX_CLIENT_ID" \
  "https://plex.tv/api/resources?includeHttps=1&includeRelay=1"
```

`provides` 에 `player` 가 있는 `Device` 를 찾고, 그 `Connection` 에 **닿을 수 있는 주소가
있는지** 본다. 로컬 주소뿐이면 같은 망에서만 쏠 수 있다.
