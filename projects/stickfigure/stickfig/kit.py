"""投稿の道具一式: サムネイル(1280x720)と、題名の候補・概要欄・タグ・章(場面の時刻)を作る。**投稿そのものはしない**(公開はユーザーが見てから)。

    python -m stickfig kit out/ep_revenge --title "雪辱戦" --hero ミドリ

エピソードの out ディレクトリ(seg01…/ と plan.json を持つ)から、見せ場のコマを選び、題名の文字を重ねる。
概要欄には、モーションデータの出典(CMU Graphics Lab Motion Capture Database)を必ず入れる。
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import List, Optional

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

from . import anime, camera

W, H = camera.W, camera.H
CREDIT = "モーションデータ: CMU Graphics Lab Motion Capture Database(mocap.cs.cmu.edu / NSF EIA-0196217)を、棒人間に写して使用。映像・効果音・BGM はすべてプログラムで作成。"


def _segments(ep_dir: Path) -> List[Path]:
    return sorted(p for p in ep_dir.glob("seg*") if p.is_dir())


def pick_frame(ep_dir: Path):
    """見せ場のコマ: 最後の場面の、最後の大きな命中(heel/slash/kick)の少しあと(放射線が出ている)。無ければ中央のコマ。"""
    for seg in reversed(_segments(ep_dir)):
        pj = seg / "plan.json"
        if not pj.exists():
            continue
        plan = json.loads(pj.read_text(encoding="utf-8"))
        hits = [e for e in plan["events"] if e["kind"] in ("heel", "slash", "kick", "wall")]
        frames = sorted((seg / "frames").glob("*.png"))
        if not frames:
            continue
        if hits:
            e = max(hits, key=lambda e: {"heel": 3, "slash": 2, "kick": 2, "wall": 1}[e["kind"]] * 1000 + e["frame"])
            i = min(len(frames) - 1, e["frame"] + 4)
        else:
            i = len(frames) // 2
        return seg, i
    return None


def make_thumbnail(ep_dir, title: str, sub: str = "", out=None, frame: Optional[Path] = None) -> Path:
    ep_dir = Path(ep_dir)
    pick = pick_frame(ep_dir) if frame is None else None
    if frame is None and pick is None:
        raise SystemExit("見せ場のコマが見つからない(エピソードを先に作る)")
    if frame is not None:
        im = Image.open(frame).convert("RGB")
    else:                                                  # 字幕の無いコマを、人物と舞台から作り直す(題名の文字とぶつからない)
        from . import compose
        seg, i = pick
        plan = json.loads((seg / "plan.json").read_text(encoding="utf-8"))
        sc = plan.get("scene", {})
        plan["scene"] = dict(sc, captions=[], anime=dict(sc.get("anime") or {}, sfx=False))
        plan.pop("_vertical", None)
        figs = {i: Image.open(seg / "figs" / f"f_{i + 1:04d}.png").convert("RGBA")}
        stages = {i: Image.open(seg / "stage" / f"f_{i + 1:04d}.png").convert("RGB")} if (seg / "stage").exists() else None
        im = compose.compose_frame(plan, i, figs, stages).convert("RGB")
    if im.size != (W, H):
        im = im.resize((W, H), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(1.25)
    im = ImageEnhance.Contrast(im).enhance(1.12)
    shade = Image.new("L", (W, H), 0)                      # 左から暗くして、文字を読みやすく
    d = ImageDraw.Draw(shade)
    for x in range(W):
        d.line([(x, 0), (x, H)], fill=int(170 * max(0.0, 1 - x / (W * 0.75))))
    im = Image.composite(Image.new("RGB", (W, H), (6, 6, 12)), im, shade)
    d = ImageDraw.Draw(im)
    size = 190 if len(title) <= 4 else (150 if len(title) <= 6 else 110)
    f = anime._font(size)
    y = H * 0.18
    for i, line in enumerate(_split(title, 5 if len(title) > 6 else 99)):
        d.text((54, y + i * (size + 10)), line, font=f, fill=(255, 226, 60), stroke_width=max(8, size // 12), stroke_fill=(15, 12, 20))
    if sub:
        f2 = anime._font(64)
        d.text((60, H - 150), sub, font=f2, fill=(255, 255, 255), stroke_width=6, stroke_fill=(15, 12, 20))
    out = Path(out) if out else ep_dir / "thumb.png"
    im.save(out)
    return out


def _split(text: str, n: int) -> List[str]:
    return [text[i:i + n] for i in range(0, len(text), n)] or [text]


def chapters(ep_dir: Path, fps: int = 30) -> List[tuple]:
    """各区間の開始時刻(秒)と、カードの文字(場面の章立て)。"""
    out, t = [], 0.0
    for seg in _segments(ep_dir):
        card = list(seg.glob("card.mp4"))
        pj = seg / "plan.json"
        if card:
            n = len(list(seg.glob("*.png")))
            out.append((t, "カード"))
            t += n / fps
        elif pj.exists():
            plan = json.loads(pj.read_text(encoding="utf-8"))
            out.append((t, plan.get("scene", {}).get("_name", seg.name)))
            t += plan["n"] / plan["fps"]
    return out


def description(title: str, hero: str, rival: str = "", arc: str = "", extra: str = "") -> str:
    lines = [f"棒人間のアクションで描く、{title}。" + (f"{hero}と{rival}の物語。" if rival else ""), "",
             "▼ このチャンネルについて", "棒人間のアクション・ストーリーを、毎回プログラムで作っています。", "",
             extra.strip(), "", "▼ 制作メモ", CREDIT, "", "#棒人間 #アクション #アニメーション"]
    return "\n".join(l for i, l in enumerate(lines) if l != "" or (i and lines[i - 1] != ""))


def titles(arc: str, hero: str, rival: str) -> List[str]:
    base = {
        "revenge": [f"【棒人間アクション】負けた剣士が1か月で変わった｜{hero}の雪辱戦", f"{hero} vs {rival}｜完敗からの再戦【棒人間】", "最強に負けた男、1か月後の逆襲【棒人間アニメ】"],
        "tournament": [f"【棒人間アクション】無敗の王者を倒せ｜{hero}の勝ち上がり", "素手→剣→王者｜勝ち上がり3連戦【棒人間】", f"{hero}、大会を駆け上がる【棒人間アニメ】"],
        "duel": [f"【棒人間アクション】因縁の一騎打ち｜{hero} vs {rival}", f"必殺・燕返し｜{hero} vs {rival}【棒人間】", "一撃で決める、因縁の決着【棒人間アニメ】"],
        "protect": [f"【棒人間アクション】守るために立ち上がる｜{hero}の戦い", "背中に守るものがある｜棒人間の戦い", "追い詰められた剣士の、最後の一撃【棒人間】"],
        "mentor": [f"【棒人間アクション】師の教えで強敵を倒す｜{hero}", "力任せでは勝てない｜師匠の稽古と旅の決戦【棒人間】", f"{hero}と師匠、そして決戦【棒人間アニメ】"],
    }
    return base.get(arc, [f"【棒人間アクション】{hero} vs {rival}"])


def make_kit(ep_dir, title: str, hero: str, rival: str = "", arc: str = "") -> Path:
    ep_dir = Path(ep_dir)
    kit = ep_dir / "kit"
    kit.mkdir(exist_ok=True)
    thumb = make_thumbnail(ep_dir, title, f"{hero} vs {rival}" if rival else hero, kit / "thumb.png")
    md = ["# 投稿の下書き(公開はユーザーが見てから)", "", "## 題名の候補", *[f"- {t}" for t in titles(arc, hero, rival)], "",
          "## 概要欄", "```", description(title, hero, rival, arc), "```", "",
          "## タグ", "棒人間, アクション, アニメーション, 剣, 戦い, 物語, プログラム, 棒人間アニメ", "",
          f"## サムネイル\n`{thumb.name}`(1280x720)"]
    (kit / "投稿の下書き.md").write_text("\n".join(md), encoding="utf-8")
    return kit
