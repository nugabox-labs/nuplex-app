# Play 스토어 그래픽

`resources/icon.png`(1024×1024)에서 만들었다. 아이콘을 다시 만들면 여기도 다시 만든다.

| 파일 | 규격 | 쓰이는 곳 |
| --- | --- | --- |
| `icon-512.png` | 512×512 | 스토어 등록정보 › 앱 아이콘 |
| `feature-1024x500.png` | 1024×500 | 스토어 등록정보 › 그래픽 이미지 |

만드는 법 (저장소 루트에서):

```bash
python3 - <<'PY'
from PIL import Image
im = Image.open('resources/icon.png').convert('RGB')
im.resize((512, 512), Image.LANCZOS).save('resources/store/play/icon-512.png')

bg = im.getpixel((8, 8))                       # 아이콘 배경색을 그대로 쓴다
f = Image.new('RGB', (1024, 500), bg)
f.paste(im.resize((360, 360), Image.LANCZOS), ((1024 - 360) // 2, (500 - 360) // 2))
f.save('resources/store/play/feature-1024x500.png')
PY
```

## 스크린샷 (`screenshots/`)

| 파일 | 무엇 |
| --- | --- |
| `01-welcome.png` | 웹 입장 화면 (`/welcome`) |
| `02-onboarding.png` | 셸의 알림 권한 화면 (`shell/onboarding.html`) |
| `03-offline.png` | 셸의 오프라인 화면 (`shell/offline.html`) |
| `04-privacy.png` | 개인정보 처리방침 (`/privacy`) |

넷 다 1080×1920(9:16)이다. Play 는 2~8장을 받고, 각 변이 1,080px 이상인 것이 4장
이상이어야 프로모션 대상이 된다.

**로그인이 필요한 화면은 쓰지 않았다.** `/profile` 은 실제 이용자들의 이름과 프로필
사진이 그대로 나온다 — 내부용이라도 스토어에 올릴 것이 아니다. `/guide` 는 화면
한가운데에 "VPN 설치 → 지역을 미국으로" 절차가 있어 뺐다.

만드는 법 — 헤드리스 Chrome 으로 찍는다. `--force-device-scale-factor=2` 라
540×960 뷰포트가 1080×1920 으로 나온다.

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --window-size=540,960 --force-device-scale-factor=2 --virtual-time-budget=8000 \
  --screenshot=resources/store/play/screenshots/01-welcome.png \
  https://nuplex.nugabox.com/welcome
```

셸 자체 화면(`02`·`03`)은 `shell/*.html` 과 `shell/public/styles/` 를 한 폴더에 모아
정적 서버로 띄운 뒤 같은 방법으로 찍는다.

## 올리는 법

**손으로 올리지 않는다.** 콘솔의 애셋 업로드는 OS 파일 선택창을 띄워서 자동화가
닿지 않는다. `.github/workflows/play-listing.yml` 을 `workflow_dispatch` 로 돌린다 —
`inspect` 로 현재 값을 먼저 보고, `apply` 로 반영한다.
