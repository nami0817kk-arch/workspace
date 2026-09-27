"""build/icon-1024.png（tool/render_icon_test.dart が書き出す）を、iOS の AppIcon と Web の favicon に置く。

App Store は**透過のあるアイコンを断る**ので、ここで RGB に落とす。
Xcode 14 以降は 1024px の1枚だけ置けば、各サイズは Xcode が作る。
"""
import json
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent.parent
src = Image.open(HERE / "build/icon-1024.png").convert("RGB")
assert src.size == (1024, 1024), src.size

icon_dir = HERE / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for old in icon_dir.glob("*.png"):
    old.unlink()
src.save(icon_dir / "Icon-1024.png", optimize=True)
(icon_dir / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "Icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1},
}, indent=2) + "\n", encoding="utf-8")

src.resize((64, 64), Image.LANCZOS).save(HERE / "web/favicon.png", optimize=True)
print("AppIcon と favicon を置いた", (icon_dir / "Icon-1024.png").stat().st_size // 1024, "KB")
