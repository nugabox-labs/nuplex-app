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

**스크린샷은 여기 없다.** 2~8장이 필요한데 로그인된 화면이어야 해서 실기기에서 찍는다
(에뮬레이터에는 세션이 없다). `docs/plan/active/phase-8-store-release.md` H절 참고.
