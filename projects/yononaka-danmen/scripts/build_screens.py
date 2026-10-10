# -*- coding: utf-8 -*-
"""台本から画面（1920×1080）を作る。

**図を1枚作って4分出しっぱなしにすると、どれだけ作り込んでも間が持たない**
（CLAUDE.md）。だから節ごとに、

    中扉 → 図の項目が1つずつ増える列 → （足りなければ `more:` の図も同じく）

の順で作る。`make_screens.py` は試作30秒ぶんを手で組んだものだったので、
台本から組めるようにこちらを足した（2026-10-09）。

    python scripts/build_screens.py scripts/cartel.yaml
    python scripts/build_screens.py scripts/cartel.yaml --only 02

**1枚あたり22秒を超えたら画面が足りない。** 節ごとに秒数と枚数を出すので、
足りない節は台本の `more:` に図を足す。
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from PIL import Image

from danmen import figures, fullscreen, screens, sequence, texture

OUT = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/screens")
PHOTOS = Path(r"C:/Users/なみ/dev/output/yononaka-danmen/assets/photos")

W, H = 1920, 1080
# 字幕と、左右の立ち絵（420px）と、言いたいことの帯のために空ける。
# **立ち絵を 420 にしたのに 320 のときの値のままで、大きな表の下が2人の頭にかかっていた**（2026-10-10）
SAFE_BOTTOM = 484

# 節の番号と、sequence.SECTIONS の名前。長さの目安はそこから引く
KINDS = {"00": "surface", "01": "question", "02": "cut1", "03": "cut2", "04": "cut3",
         "05": "world", "06": "myth", "07": "reading", "08": "close"}


def place(panel: Image.Image, bg: Image.Image, width: int = 1740, point: str = "") -> Image.Image:
    """板を背景の上に、字幕と立ち絵の場所を避けて置く。

    `point` は**その板で言いたいこと**を1行で（2026-10-10 ユーザー「表でも何を伝えたいか分かるように」）。
    板のすぐ下、2人のあいだに金の帯で出す。
    """
    out = bg.copy()
    room_h = H - SAFE_BOTTOM - 30
    s = min(width / panel.width, room_h / panel.height, 1.0)
    p = panel.resize((int(panel.width * s), int(panel.height * s)), Image.LANCZOS)
    top = 34 + (room_h - p.height) // 2
    out.alpha_composite(p.convert("RGBA"), ((W - p.width) // 2, top))
    if point:
        from PIL import ImageDraw
        from danmen.figures import F as FF
        d = ImageDraw.Draw(out)
        size = 46
        while size > 32 and d.textlength(point, font=FF(size)) > 980:
            size -= 2
        tw = d.textlength(point, font=FF(size))
        bx0, by0 = int((W - tw) / 2) - 34, top + p.height + 14
        d.rounded_rectangle([bx0, by0, bx0 + tw + 68, by0 + size + 30], radius=14, fill=(255, 206, 72))
        d.text((bx0 + 34, by0 + 10), point, font=FF(size), fill=(16, 22, 36))
    return out


def finish_panel(panel: Image.Image) -> Image.Image:
    """板に紙の質感を掛ける。**透ける部分を保つ。**

    `texture.finish(panel.convert("RGB"), "panel")` と書くと、板の落ち影の
    半透明が黒くつぶれ、**板の周りに黒い枠が出る**（2026-10-09 に見つけた）。
    質感は RGB にしないと掛けられないので、掛けたあとアルファを戻す。
    """
    rgba = panel.convert("RGBA")
    out = texture.finish(rgba.convert("RGB"), "panel").convert("RGBA")
    out.putalpha(rgba.getchannel("A"))
    return out


def find_photo(key: str | None) -> Path | None:
    """写真を部分一致で探す。**名前の文字列をそのまま backdrop に渡さない**
    （渡すと濃紺のままになる。2026-10-09 に踏んだ）。"""
    if not key:
        return None
    for p in sorted(PHOTOS.glob("*.jpeg")) + sorted(PHOTOS.glob("*.jpg")):
        if str(key).lower() in p.name.lower():
            return p
    return None


def panels_of(sec: dict, with_point: bool = False) -> list:
    """その節で出す板を、出す順に返す。(役割, 画像)。with_point なら (役割, 画像, 言いたいこと)。"""
    out: list = []
    for n, fig in enumerate([sec.get("figure")] + list(sec.get("more") or [])):
        if not fig:
            continue
        kind = fig.get("kind")
        if kind not in figures.KINDS:
            raise SystemExit("節{} の図「{}」は知りません".format(sec.get("id"), kind))
        fn = figures.KINDS[kind]
        # 項目を1つずつ増やす。項目を持たない図（hero など）は1枚だけ
        point = str(fig.get("point", "") or "")
        photo = fig.get("photo")                # 図ごとの背景（無ければ節の背景）
        if isinstance(fig.get("items"), list) and len(fig["items"]) > 1 and fig.get("step") is not False:
            ims = sequence.grow(fn, fig)
            # 言いたいことの帯は、最後の1枚（全部の行が出たところ）だけに出す
            out += [(kind, im, point if k == len(ims) - 1 else "", photo) if with_point else (kind, im)
                    for k, im in enumerate(ims)]
        else:
            out.append((kind, fn(fig), point, photo) if with_point else (kind, fn(fig)))
    return out


def build(path: Path, only: str | None) -> int:
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    # **前に作った画面を消してから作る。** 消さないと、台本で減った画面や別の回の画面が残って
    # 割り当てに混ざった（2026-10-10、カルテルの回にガソリンの画面 s02 が残っていた）
    if not only:
        for p in OUT.glob("s*.png"):
            p.unlink()
    photo = find_photo((doc.get("thumbnail") or {}).get("photo"))
    bg = screens.backdrop(photo, dark=0.44, blur=9).convert("RGBA")

    total, rows = 0, []
    for sec in doc["sections"]:
        sid = str(sec["id"])
        if only and sid != only:
            continue
        kind = KINDS.get(sid, "")
        secs = sequence.SECTIONS.get(kind, 0)
        frames: list[Image.Image] = []
        # **節ごとに背景の写真を変えられる**（`photo:`）。1本を同じ写真で通すと30分変化が無い
        # （2026-10-10 ユーザー「直して」）。`photo: なし` は写真を敷かない（濃紺）。
        # 書かなければ台本全体の写真（サムネと同じ）
        sec_photo = photo
        if "photo" in sec:
            key = sec.get("photo")
            sec_photo = None if key in (None, "なし", "none") else find_photo(key)
            if key not in (None, "なし", "none") and sec_photo is None:
                raise SystemExit("節{} の写真「{}」が見つかりません".format(sid, key))
        sec_bg = screens.backdrop(sec_photo, dark=0.44, blur=9).convert("RGBA")

        # ⓪ 冒頭の10秒。**ここで離脱が決まる**（CLAUDE.md）。
        #    いちばん強い数字を理由を言わずに出し、その数字から問いを立てる
        if sid == "00" and doc.get("hook"):
            h = dict(doc["hook"])
            h["photo"] = photo
            frames.append(fullscreen.number(h).convert("RGB"))
            frames.append(screens.title({"photo": photo, "lines": h.get("question", [])}))

        # ① 節の中扉。何節目で何を見るのか
        frames.append(screens.chapter({
            "no": sid, "name": sec.get("name", ""),
            "lead": sec.get("lead", ""), "photo": sec_photo}))

        # ② 図。項目が1つずつ増える
        bgs = {}
        for _, panel, point, fphoto in panels_of(sec, with_point=True):
            bg_ = sec_bg
            if fphoto:
                if fphoto not in bgs:
                    fp = find_photo(fphoto)
                    if fp is None:
                        raise SystemExit("図の写真「{}」が見つかりません".format(fphoto))
                    bgs[fphoto] = screens.backdrop(fp, dark=0.44, blur=9).convert("RGBA")
                bg_ = bgs[fphoto]
            frames.append(place(finish_panel(panel), bg_, point=point))

        for i, im in enumerate(frames, 1):
            name = "s{}{:02d}".format(sid, i)
            texture.finish(im.convert("RGB"), "screen").save(OUT / (name + ".png"))

        total += len(frames)
        hold = secs / len(frames) if frames else 0
        warn = "  ← 足りない（{}枚は要る）".format(int(secs / 14) + 1) if hold > 22 else ""
        rows.append("  {} {:8s} {:>4}秒 / {:>2}枚 = {:>5.1f}秒{}".format(
            sid, sec.get("name", ""), secs, len(frames), hold, warn))

    print("■ 画面を作りました: {}".format(OUT))
    print(chr(10).join(rows))
    print("  合計 {} 枚".format(total))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="台本から画面を作る")
    ap.add_argument("script", help="台本の yaml")
    ap.add_argument("--only", help="この節だけ作る（例: 02）")
    a = ap.parse_args()
    return build(Path(a.script), a.only)


if __name__ == "__main__":
    raise SystemExit(main())
