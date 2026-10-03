"""つむぎの表情（目・口・眉・飾り）を、公式立ち絵の PSD から作る。

PSD 全体を表情ごとに合成すると1枚90秒かかるので、顔の部品を外した体を1回だけ合成し、
部品（目・口・眉・飾り）をその上に重ねる（部品1つは0.1秒もかからない）。
できた顔にヘルメットをかぶせて、assets/characters/tsumugi_faces/ に置く。

調子ごとの顔（口は閉じ／開きの2つ、まばたきは目を閉じた版）:
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

# 調子 → (目, 眉, 口・閉じ, 口・開き, 飾り)
EXPRESSIONS: dict[str, tuple[str, str, str, str, tuple[str, ...]]] = {
    "普通": ("*普通", "*普通", "*綴じ　にこ", "*あ", ()),
    "驚き": ("*見開く", "*困る", "*お", "*わあ！", ("！",)),
    "疑問": ("*普通", "*ん？", "*綴じ　－", "*え", ("？",)),
    "強調": ("*普通", "*真面目", "*綴じ　－", "*あ", ()),
    "しみじみ": ("*微笑む", "*困る", "*綴じ　にこ", "*う", ()),
    "明るい": ("*笑う", "*普通", "*ω", "*わ", ()),
    "笑い": ("*笑う", "*普通", "*ω", "*ω　わ", ("ほっぺ赤",)),
    "重い": ("*ハイライト無", "*悲しい", "*綴じ　－", "*お", ()),
    "ひそひそ": ("*ジト目", "*真面目", "*綴じ　むっ", "*い", ()),
    "納得": ("*綴じ", "*普通", "*綴じ　にこ", "*う", ()),
    "聞く": ("*微笑む", "*普通", "*綴じ　にこ", "*綴じ　にこ", ()),   # 聞いているときの顔
}
BLINK_EYES = "*綴じ"
ON_TOP = ("髪　前髪", "ヘアピン")       # 目や眉より手前にある層（前髪は目にかかる）
ALWAYS = ("ホクロ",)
OUTFIT = "私服"


def face_key(tone: str, mouth_open: bool, blink: bool) -> str:
    return f"{tone}_{'open' if mouth_open else 'shut'}{'_blink' if blink else ''}"


def _parts(psd) -> dict[str, dict]:
    """部品のグループ（!口 など）と、その中の層を名前で引けるようにする。"""
    groups = {}
    for g in psd:
        if g.name in ("!口", "!目", "!眉", "!アクセサリー"):
            groups[g.name] = {c.name: c for c in g}
    return groups


def build(psd_path: str | Path, out_dir: Path, put_helmet) -> list[Path]:
    """全部の表情を作る。put_helmet(src_png, out_png) でヘルメットをかぶせる。"""
    from psd_tools import PSDImage

    out_dir.mkdir(parents=True, exist_ok=True)
    psd = PSDImage.open(psd_path)
    groups = _parts(psd)
    top_layers = []
    for g in psd:
        if g.name == "!体部分":
            for c in g:
                if c.name in ("制服", "私服"):
                    c.visible = (c.name == OUTFIT)
                elif c.name in ON_TOP:
                    c.visible = False                       # 前髪は最後に重ねる
                    top_layers.append(c)
        elif g.name in groups:
            g.visible = False                               # 顔の部品は外して、体だけ合成する
    tops = []
    for c in top_layers:
        im = c.composite(force=True) if c.is_group() else c.topil()
        if im is not None:
            tops.append((im.convert("RGBA"), (c.left, c.top)))
    body_path = out_dir / "_body.png"
    if body_path.exists():
        body = Image.open(body_path).convert("RGBA")
    else:
        body = psd.composite(force=True).convert("RGBA")
        body.save(body_path)
    cache: dict[str, tuple[Image.Image, tuple[int, int]]] = {}

    def part(group: str, name: str):
        key = group + name
        if key not in cache:
            layer = groups[group][name]
            im = layer.topil()                              # グループが隠れていても、層の画素はそのまま取れる
            if im is None:
                raise ValueError(f"部品が空です: {group} {name}")
            cache[key] = (im.convert("RGBA"), (layer.left, layer.top))
        return cache[key]

    made = []
    for tone, (eyes, brows, shut, opened, acc) in EXPRESSIONS.items():
        for mouth_open in (False, True):
            for blink in (False, True):
                target = out_dir / f"{face_key(tone, mouth_open, blink)}.png"
                if target.exists():
                    made.append(target)
                    continue
                im = body.copy()
                for group, name in (("!眉", brows), ("!目", BLINK_EYES if blink else eyes),
                                    ("!口", opened if mouth_open else shut)):
                    p, xy = part(group, name)
                    im.alpha_composite(p, xy)
                for top, xy in tops:
                    im.alpha_composite(top, xy)
                for name in ALWAYS + acc:
                    p, xy = part("!アクセサリー", name)
                    im.alpha_composite(p, xy)
                tmp = out_dir / "_face.png"
                im.crop(im.getbbox()).save(tmp)
                put_helmet(str(tmp), str(target))
                made.append(target)
    for t in (out_dir / "_face.png",):
        if t.exists():
            t.unlink()
    return made
