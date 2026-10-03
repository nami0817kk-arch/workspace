"""歴史の地層の制作コマンド。

    python -m chiso.cli prepare-characters --tsumugi <公式立ち絵png> --kenzaki <公式イラストpng>
    python -m chiso.cli voice   scripts/x.yaml          # 音声だけ作って1本にする（抑揚の確認用）
    python -m chiso.cli draft   scripts/x.yaml          # 確認用の動画（右上に「確認用」と出る）。承認は要らない
    python -m chiso.cli approve scripts/x.yaml          # 台本の承認を控える（ユーザーの OK が出たときだけ）
    python -m chiso.cli build   scripts/x.yaml          # 本番の動画。承認した台本の中身と一致しないと動かない
    python -m chiso.cli shorts  scripts/x.yaml [--draft]  # short: を付けた行からショートを全部作る
    python -m chiso.cli describe scripts/x.yaml         # 概要欄（章・クレジット）

台本確認は必ず通す（チャンネル共通の決まり）。approve を打つのは、ユーザーが台本に
はっきり「OK」と言ったときだけ。「見せて」「出す」は承認ではない。
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

import yaml

from . import mix, render, script as script_mod, shorts as shorts_mod, tts
from .voice import Voice, load_readings

ROOT = Path(__file__).resolve().parent.parent


def load_config() -> dict:
    with (ROOT / "config.yaml").open(encoding="utf-8") as f:
        return yaml.safe_load(f)


def assets_dir(config: dict) -> Path:
    env = os.environ.get("CHISO_ASSETS")
    return Path(env) if env else (ROOT / config["assets_dir"]).resolve()


def voices(config: dict) -> dict[str, Voice]:
    return {k: Voice(style_id=c["style_id"], speed=c.get("speed", 1.0), pitch=c.get("pitch", 0.0),
                     intonation=c.get("intonation", 1.0), volume=c.get("volume", 1.0))
            for k, c in config["cast"].items()}


def ffmpeg() -> str:
    import shutil
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def work_dir(sc) -> Path:
    return ROOT / "work" / sc.path.stem


def out_dir() -> Path:
    d = ROOT / "out"
    d.mkdir(exist_ok=True)
    return d


# --- 承認 ---------------------------------------------------------------

def approval_path(path: Path) -> Path:
    return ROOT / "approvals" / f"{path.stem}.json"


def is_approved(path: Path) -> bool:
    a = approval_path(path)
    if not a.exists():
        return False
    return json.loads(a.read_text(encoding="utf-8")).get("sha256") == script_mod.digest(path)


def cmd_approve(args) -> int:
    path = Path(args.script)
    script_mod.load(path)  # 壊れた台本は承認しない
    a = approval_path(path)
    a.parent.mkdir(exist_ok=True)
    a.write_text(json.dumps({"script": path.name, "sha256": script_mod.digest(path)}, ensure_ascii=False, indent=1)
                 + "\n", encoding="utf-8")
    print(f"承認を控えました: {a.name}（台本を変えたら承認し直し）")
    return 0


# --- 音声 ---------------------------------------------------------------

def synthesize(sc, config) -> tuple[list[mix.Cue], float]:
    engine = tts.Voicevox(config["voicevox_url"])
    vs = voices(config)
    readings = load_readings(ROOT / "readings.yaml")
    cache = work_dir(sc) / "voice"
    spoken = {}
    for i, line in enumerate(sc.lines, 1):
        s = tts.speak(engine, line.text, vs[line.speaker], line.tone, readings, cache)
        if s.missing_emphasis:
            print(f"  ! {i}行目: 強調《》の語が読みの中に見つかりませんでした: {s.missing_emphasis}")
        spoken[line.index] = s
        print(f"\r音声 {i}/{len(sc.lines)}", end="", flush=True)
    print()
    return mix.plan(sc.lines, spoken)


def cmd_voice(args) -> int:
    config = load_config()
    sc = script_mod.load(args.script)
    cues, total = synthesize(sc, config)
    target = out_dir() / f"{sc.path.stem}_voice.wav"
    mix.write_audio(cues, total, target)
    print(f"{target}（{total:.1f}秒）")
    return 0


# --- 動画 ---------------------------------------------------------------

def encode(items, audio: Path, target: Path, fps: int) -> None:
    lst = target.with_suffix(".frames.txt")
    lst.write_text(render.concat_list(items), encoding="utf-8")
    cmd = [ffmpeg(), "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-i", str(audio),
           "-r", str(fps), "-c:v", "libx264", "-tune", "stillimage", "-preset", "medium", "-crf", "20",
           "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-shortest", str(target)]
    subprocess.run(cmd, check=True)
    lst.unlink()


def _stamp(painter_cls):
    """確認用の動画の右上に「確認用」と出す。"""
    class Stamped(painter_cls):
        def base(self, state):
            img = super().base(state)
            from PIL import ImageDraw
            dr = ImageDraw.Draw(img, "RGBA")
            dr.rounded_rectangle([self.W - 230, 60, self.W - 40, 120], radius=8, fill=(180, 40, 40, 220))
            dr.text((self.W - 135, 90), "確認用", font=self.font("gothic", 34), fill=(255, 255, 255), anchor="mm")
            return img
    return Stamped


def make_video(args, draft: bool) -> int:
    config = load_config()
    path = Path(args.script)
    sc = script_mod.load(path)
    if not draft and not is_approved(path):
        print("この台本は承認されていません（または承認後に変わっています）。"
              "ユーザーの OK をもらってから approve してください。確認用は draft で作れます。")
        return 2
    cues, total = synthesize(sc, config)
    wd = work_dir(sc)
    audio = wd / "voice.wav"
    mix.write_audio(cues, total, audio)
    v = config["video"]
    cls = _stamp(render.Painter) if draft else render.Painter
    painter = cls(config, sc, assets_dir(config), (v["width"], v["height"]))
    items = render.frames(painter, cues, total, wd / ("frames-draft" if draft else "frames"), v["fps"])
    target = out_dir() / f"{path.stem}{'_draft' if draft else ''}.mp4"
    encode(items, audio, target, v["fps"])
    names = {k: c["name"] for k, c in config["cast"].items()}
    (out_dir() / f"{path.stem}.srt").write_text(mix.srt(cues, names), encoding="utf-8")
    print(f"{target}（{total / 60:.1f}分）")
    return 0


def cmd_draft(args) -> int:
    return make_video(args, draft=True)


def cmd_build(args) -> int:
    return make_video(args, draft=False)


def cmd_shorts(args) -> int:
    config = load_config()
    path = Path(args.script)
    sc = script_mod.load(path)
    if not args.draft and not is_approved(path):
        print("この台本は承認されていません。確認用は --draft で作れます。")
        return 2
    if not sc.shorts:
        print("台本に shorts がありません")
        return 1
    engine = tts.Voicevox(config["voicevox_url"])
    vs = voices(config)
    readings = load_readings(ROOT / "readings.yaml")
    cache = work_dir(sc) / "voice"
    sz = config["short"]
    for sid, meta in sc.shorts.items():
        lines = sc.short_lines(sid)
        spoken = {line.index: tts.speak(engine, line.text, vs[line.speaker], line.tone, readings, cache)
                  for line in lines}
        # ショートの中では節の切れ目の長い間を入れない
        flat = [_same_section(line) for line in lines]
        cues, total = mix.plan(flat, spoken)
        if total > sz["max_seconds"]:
            print(f"  ! {sid}: {total:.1f}秒で、上限 {sz['max_seconds']}秒を超えています")
        wd = work_dir(sc) / f"short-{sid}"
        audio = wd / "voice.wav"
        mix.write_audio(cues, total, audio)
        cls = _stamp(shorts_mod.ShortPainter) if args.draft else shorts_mod.ShortPainter
        painter = cls(config, sc, assets_dir(config), meta.get("title", ""))
        items = render.frames(painter, cues, total, wd / "frames", config["video"]["fps"], with_text=True)
        target = out_dir() / f"{path.stem}_short_{sid}{'_draft' if args.draft else ''}.mp4"
        encode(items, audio, target, config["video"]["fps"])
        print(f"{target}（{total:.1f}秒）")
    return 0


def _same_section(line):
    from dataclasses import replace
    return replace(line, section=0)


# --- 概要欄 -------------------------------------------------------------

def description(sc, config, cues) -> str:
    out = []
    if cues:
        out += ["■ 目次"] + mix.chapters(cues, [s.title for s in sc.sections]) + [""]
    out.append("■ 音声")
    out += [f"VOICEVOX:{c['name']}" for c in config["cast"].values()]
    out += config.get("character_credits", [])
    seen, pics = set(), []
    for line in sc.lines:
        for pic in (line.background, line.portrait):
            label = pic and (pic.credit or pic.caption)
            if label and label not in seen:
                seen.add(label)
                pics.append(label)
    if pics:
        out += ["", "■ 画面の絵（いずれも著作権の切れた作品）"] + pics
    out += ["", f"運営：{config.get('operator', '')}"]
    return "\n".join(out) + "\n"


def cmd_describe(args) -> int:
    config = load_config()
    sc = script_mod.load(args.script)
    cues = []
    if not args.no_voice:
        cues, _ = synthesize(sc, config)
    text = description(sc, config, cues)
    target = out_dir() / f"{sc.path.stem}_description.txt"
    target.write_text(text, encoding="utf-8")
    print(text)
    return 0


# --- 立ち絵 -------------------------------------------------------------

def cmd_prepare_characters(args) -> int:
    from .helmet import PLACEMENTS, put
    config = load_config()
    out = assets_dir(config) / "characters"
    out.mkdir(parents=True, exist_ok=True)
    for key, src in (("tsumugi", args.tsumugi), ("kenzaki", args.kenzaki)):
        cx, rim_y, w, angle, keep = PLACEMENTS[key]
        put(src, str(out / f"{key}_helmet.png"), cx, rim_y, w, angle, keep=keep)
    print(f"立ち絵を作りました: {out}")
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="chiso")
    sub = p.add_subparsers(dest="cmd", required=True)
    for name, fn in [("voice", cmd_voice), ("draft", cmd_draft), ("approve", cmd_approve), ("build", cmd_build)]:
        s = sub.add_parser(name)
        s.add_argument("script")
        s.set_defaults(fn=fn)
    s = sub.add_parser("shorts")
    s.add_argument("script")
    s.add_argument("--draft", action="store_true")
    s.set_defaults(fn=cmd_shorts)
    s = sub.add_parser("describe")
    s.add_argument("script")
    s.add_argument("--no-voice", action="store_true", help="章の時刻を出さない（音声を作らない）")
    s.set_defaults(fn=cmd_describe)
    s = sub.add_parser("prepare-characters")
    s.add_argument("--tsumugi", required=True)
    s.add_argument("--kenzaki", required=True)
    s.set_defaults(fn=cmd_prepare_characters)
    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
