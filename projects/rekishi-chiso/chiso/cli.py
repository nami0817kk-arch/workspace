"""歴史の地層の制作コマンド。

    python -m chiso.cli prepare-characters --tsumugi <公式立ち絵png> --kenzaki <公式イラストpng>
    python -m chiso.cli voice   scripts/x.yaml          # 音声だけ作って1本にする（抑揚の確認用）
    python -m chiso.cli draft   scripts/x.yaml          # 確認用の動画（右上に「確認用」と出る）。承認は要らない
    python -m chiso.cli approve scripts/x.yaml          # 台本の承認を控える（ユーザーの OK が出たときだけ）
    python -m chiso.cli build   scripts/x.yaml          # 本番の動画。承認した台本の中身と一致しないと動かない
    python -m chiso.cli shorts  scripts/x.yaml [--draft]  # short: を付けた行からショートを全部作る
    python -m chiso.cli describe scripts/x.yaml         # 概要欄（章・クレジット・絵の出典）
    python -m chiso.cli kana    scripts/x.yaml          # 全行の読みをカタカナで書き出す（読み違いの点検）
    python -m chiso.cli thumb   scripts/x.yaml          # サムネイル（と、一覧で見える大きさの確認用）
    python -m chiso.cli screen  scripts/x.yaml          # 本番の動画を見てもらった控え（ユーザーの OK のあとだけ）
    python -m chiso.cli upload  scripts/x.yaml --at "2026-10-05 19:00"   # 予約投稿（承認と screen が要る）
    python -m chiso.cli whoami                          # 許可したチャンネルの名前を出す（取り違えの確認）
    python -m chiso.cli check   scripts/x.yaml          # 素材の有無・書きすぎ・抑揚の張りつきを点検

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

from . import check as check_mod, mix, render, script as script_mod, shorts as shorts_mod, tts, video
from . import people
from .voice import Voice, load_readings

ROOT = Path(__file__).resolve().parent.parent


def load_config() -> dict:
    with (ROOT / "config.yaml").open(encoding="utf-8") as f:
        return yaml.safe_load(f)


def assets_dir(config: dict) -> Path:
    env = os.environ.get("CHISO_ASSETS")
    return Path(env) if env else (ROOT / config["assets_dir"]).resolve()


def voices(config: dict) -> dict[str, Voice]:
    """立ち絵の2人と、人物の言葉の声（roles）。"""
    from .people import roles
    every = {**roles(config), **config["cast"]}
    return {k: Voice(style_id=c["style_id"], speed=c.get("speed", 1.0), pitch=c.get("pitch", 0.0),
                     intonation=c.get("intonation", 1.0), volume=c.get("volume", 1.0),
                     tone_strength=c.get("tone_strength", 1.0), max_intonation=c.get("max_intonation", 2.0),
                     max_speed=c.get("max_speed", 2.0))
            for k, c in every.items()}


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

def preflight(sc, config) -> bool:
    """作る前の点検。素材が無いときは False（音声を作る前に止める）。"""
    missing = check_mod.missing_assets(sc, assets_dir(config))
    for m in missing:
        print(f"  × 素材がありません: {m}")
    from .people import unknown_roles
    for who in unknown_roles(config, sc):
        print(f"  × 人物「{who}」の声が config.yaml の roles にありません")
        missing = missing + [who]
    if not str(sc.path.name).startswith("sample"):
        errors, warns = check_mod.episode(sc)
        for e in errors:
            print(f"  × {e}")
        for w in warns:
            print(f"  ! {w}")
        missing = missing + errors
    for w in check_mod.lint(sc, config.get("short", {}).get("max_seconds", 60)):
        print(f"  ! {w}")
    for who, (hit, n) in check_mod.saturation(sc, voices(config)).items():
        if hit:
            print(f"  ! {people.label(config, who)}：{n}行中{hit}行で抑揚が上限2.0を超えるか、1.2倍より早口です")
    return not missing


def synthesize(sc, config) -> tuple[list[mix.Cue], float]:
    engine = tts.Voicevox(config["voicevox_url"])
    vs = voices(config)
    readings = load_readings(ROOT / "readings.yaml")
    cache = work_dir(sc) / "voice"
    spoken = {}
    for i, line in enumerate(sc.lines, 1):
        s = tts.speak_line(engine, line, vs, readings, cache)
        if s.missing_emphasis:
            print(f"  ! {i}行目: 強調《》の語が読みの中に見つかりませんでした: {s.missing_emphasis}")
        spoken[line.index] = s
        print(f"\r音声 {i}/{len(sc.lines)}", end="", flush=True)
    print()
    return mix.plan(sc.lines, spoken)


def cmd_voice(args) -> int:
    config = load_config()
    sc = script_mod.load(args.script)
    if not preflight(sc, config):
        return 3
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
           "-g", str(fps * 2),                                   # 2秒ごとにキーフレーム（シークしやすい）
           "-pix_fmt", "yuv420p",
           "-af", "loudnorm=I=-14:TP=-1.5:LRA=11",               # YouTube の基準の大きさに揃える
           "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
           "-movflags", "+faststart",                            # 読み込みの途中から再生できる形
           "-shortest", str(target)]
    subprocess.run(cmd, check=True)
    lst.unlink()


def _stamp(painter_cls):
    """確認用の動画の右上に「確認用」と出す。"""
    class Stamped(painter_cls):
        def base(self, state, **kw):
            img = super().base(state, **kw)
            from PIL import ImageDraw
            dr = ImageDraw.Draw(img, "RGBA")
            dr.rounded_rectangle([self.W - 170, 48, self.W - 40, 88], radius=6, fill=(180, 40, 40, 170))
            dr.text((self.W - 105, 68), "確認用", font=self.font("gothic", 24), fill=(255, 255, 255), anchor="mm")
            return img
    return Stamped


def make_video(args, draft: bool) -> int:
    config = load_config()
    path = Path(args.script)
    sc = script_mod.load(path)
    limit = getattr(args, "lines", None)
    if limit:                                             # 冒頭だけの確認用（見た目の確認を速く）
        if not draft:
            print("--lines は確認用（draft）だけで使えます")
            return 2
        sc.lines = sc.lines[:limit]
    if not draft and not is_approved(path):
        print("この台本は承認されていません（または承認後に変わっています）。"
              "ユーザーの OK をもらってから approve してください。確認用は draft で作れます。")
        return 2
    if not preflight(sc, config):
        return 3
    cues, total = synthesize(sc, config)
    end_card = bool(sc.next)
    if end_card:
        total += render.END_SECONDS
    wd = work_dir(sc)
    audio = wd / "voice.wav"
    from . import sfx
    mix.write_audio(cues, total, audio, sfx.events(cues) if config.get("sfx", True) else None)
    v = config["video"]
    size = (v["width"], v["height"])
    cls = _stamp(render.Painter) if draft else render.Painter
    painter = cls(config, sc, assets_dir(config), size)
    painter.layered = True                                # 背景は動かす（video.py）、前景は透明に描く
    print("前景を描いています…")
    items = render.frames(painter, cues, total, wd / ("frames-draft" if draft else "frames"), v["fps"],
                          end_card=end_card)
    print("背景を動かしています…")
    bg = video.background_track(ffmpeg(), painter, video.runs_of(cues, total), wd / "bg", v["fps"], size,
                                wd / "background.mp4")
    suffix = ("_draft" if draft else "") + (f"_{limit}lines" if limit else "")
    target = out_dir() / f"{path.stem}{suffix}.mp4"
    lst = wd / "overlay.txt"
    lst.write_text(render.concat_list(items), encoding="utf-8")
    print("重ねています…")
    video.compose(ffmpeg(), bg, lst, audio, target, v["fps"], preset="veryfast" if draft else "medium")
    bg.unlink()
    names = {k: people.label(config, k) for k in list(config["cast"]) + sc.roles}
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
        spoken = {line.index: tts.speak_line(engine, line, vs, readings, cache)
                  for line in lines}
        # ショートの中では節の切れ目の長い間を入れない
        flat = [_same_section(line) for line in lines]
        cues, total = mix.plan(flat, spoken)
        total += shorts_mod.END_SECONDS                     # 最後に「続きは本編で」（声なし）
        if total > sz["max_seconds"]:
            print(f"  ! {sid}: {total:.1f}秒で、上限 {sz['max_seconds']}秒を超えています")
        wd = work_dir(sc) / f"short-{sid}"
        audio = wd / "voice.wav"
        mix.write_audio(cues, total, audio)
        cls = _stamp(shorts_mod.ShortPainter) if args.draft else shorts_mod.ShortPainter
        painter = cls(config, sc, assets_dir(config), meta.get("title", ""))
        items = render.frames(painter, cues, total, wd / "frames", config["video"]["fps"], with_text=True,
                              end_card=True, end_seconds=shorts_mod.END_SECONDS)
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
        chs = mix.chapters(cues, [s.title for s in sc.sections])
        starts = sorted({c.line.section: c.start for c in reversed(cues)}.values())
        short = [i + 1 for i, (a, b) in enumerate(zip(starts, starts[1:])) if b - a < 10]
        if len(chs) < 3 or short:
            print(f"  ! 章が YouTube の決まりに合いません（3つ以上・各10秒以上）: 数={len(chs)} 短い節={short}")
        out += ["■ 目次"] + chs + [""]
    out.append("■ 音声")
    out += [f"VOICEVOX:{n}" for n in people.credit_names(config, sc)]
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
    if sc.next:
        out += ["", f"■ 次回：{sc.next.get('title', '')}", sc.next.get("teaser", "")]
    sources = picture_sources(sc, config)
    if sources:
        out += ["", "■ 絵の出典（Wikimedia Commons）"] + sources
    if sc.series:
        out += ["", f"#歴史の地層 #{sc.series} #世界史 #日本史 #聞き流し"]
    out += ["", f"運営：{config.get('operator', '')}"]
    return "\n".join(out) + "\n"


def picture_sources(sc, config) -> list[str]:
    """使った絵の Commons のページ。素材の置き場の credits.json（取得時に控えたもの）から引く。"""
    cf = assets_dir(config) / "paintings" / "credits.json"
    if not cf.exists():
        return []
    credits = json.loads(cf.read_text(encoding="utf-8"))
    seen, out = set(), []
    for line in sc.lines:
        for pic in (line.background, line.portrait):
            if pic is None:
                continue
            key = Path(pic.image).stem
            if key in credits and key not in seen:
                seen.add(key)
                out.append(f"{credits[key]['source']}（{credits[key].get('license', '')}）")
    return out


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


def cmd_kana(args) -> int:
    """全行の読みをカタカナで書き出す。読み違いを音を出す前に見つけるため。"""
    from .voice import apply_readings, split_emphasis
    config = load_config()
    sc = script_mod.load(args.script)
    engine = tts.Voicevox(config["voicevox_url"])
    readings = load_readings(ROOT / "readings.yaml")
    vs = voices(config)
    for line in sc.lines:
        q = engine.query(apply_readings(split_emphasis(line.text)[0], readings), vs.get(line.speaker, vs["語り"]).style_id)
        phrases, _ = __import__("chiso.voice", fromlist=["join_n_phrases"]).join_n_phrases(q["accent_phrases"])
        kana = "／".join("".join(m["text"] for m in p["moras"]) for p in phrases)
        print(f"{line.index + 1:3} {people.label(config, line.speaker)[:2]} {kana}")
    return 0


def cmd_thumb(args) -> int:
    from . import thumb
    config = load_config()
    sc = script_mod.load(args.script)
    if not sc.thumbnail:
        print("台本に thumbnail の欄がありません")
        return 1
    img = thumb.make(sc, config, assets_dir(config))
    target = out_dir() / f"{sc.path.stem}_thumbnail.png"
    img.save(target)
    thumb.preview(img).save(out_dir() / f"{sc.path.stem}_thumbnail_preview.png")
    print(target)
    return 0


def cmd_check(args) -> int:
    config = load_config()
    sc = script_mod.load(args.script)
    ok = preflight(sc, config)
    print("点検は終わりました" + ("" if ok else "（素材が足りません）"))
    return 0 if ok else 3


# --- 投稿 ---------------------------------------------------------------

def screened_path(path: Path) -> Path:
    return ROOT / "approvals" / f"{path.stem}.screened.json"


def _sha(p: Path) -> str:
    import hashlib
    h = hashlib.sha256()
    with p.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def cmd_screen(args) -> int:
    """本番の動画をユーザーが見て OK と言ったときだけ打つ（投稿の前に動画を見せる決まり）。"""
    path = Path(args.script)
    video = out_dir() / f"{path.stem}.mp4"
    if not video.exists():
        print(f"本番の動画がありません: {video}（build を先に）")
        return 1
    a = screened_path(path)
    a.write_text(json.dumps({"video": video.name, "sha256": _sha(video)}, ensure_ascii=False) + chr(10),
                 encoding="utf-8")
    print(f"動画の確認を控えました: {a.name}（動画を作り直したら確認し直し）")
    return 0


TAGS = ["歴史", "世界史", "日本史", "聞き流し", "歴史解説", "歴史の地層"]


def cmd_upload(args) -> int:
    from . import upload as up
    config = load_config()
    path = Path(args.script)
    sc = script_mod.load(path)
    video = out_dir() / f"{path.stem}.mp4"
    if not is_approved(path):
        print("台本が承認されていません。ユーザーの OK のあと approve してください")
        return 2
    a = screened_path(path)
    if not a.exists() or not video.exists() or json.loads(a.read_text(encoding="utf-8"))["sha256"] != _sha(video):
        print("本番の動画をユーザーに見せて OK をもらってから screen してください（動画を作り直したら確認し直し）")
        return 2
    log = ROOT / "posted.json"
    key = f"{path.stem}:main"
    done = up.already_posted(log, key)
    if done:
        print(f"もう投稿してあります: https://youtu.be/{done['video_id']}（{done['publish_at']}）")
        return 1
    publish_at = up.publish_time(args.at)
    cues, _ = synthesize(sc, config)
    desc = description(sc, config, cues)
    thumb_p = out_dir() / f"{path.stem}_thumbnail.png"
    if not thumb_p.exists():
        from . import thumb
        thumb.make(sc, config, assets_dir(config)).save(thumb_p)
    srt = out_dir() / f"{path.stem}.srt"
    tags = TAGS + [x for x in (sc.series, sc.thumbnail.get("name", "")) if x]
    svc = up.service()
    name = up.channel_title(svc)
    if "歴史の地層" not in name:
        print(f"許可しているチャンネルが違います: {name}（secrets/token.json を消して、歴史の地層を選び直す）")
        return 2
    print(f"投稿します：{sc.title}"); print(f"  チャンネル {name}／公開 {args.at}（日本時間）")
    vid = up.upload(svc, video, sc.title, desc, tags, publish_at, thumb_p, srt)
    up.record(log, {"key": key, "video_id": vid, "title": sc.title, "publish_at": args.at})
    print(f"予約しました: https://youtu.be/{vid}")
    return 0


def cmd_whoami(args) -> int:
    from . import upload as up
    print(up.channel_title(up.service()))
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
    from . import jaw
    cx, rim_y, w, angle, keep = PLACEMENTS["kenzaki"]
    jaw.build(args.kenzaki, out / "kenzaki_faces", lambda s_, o_: put(s_, o_, cx, rim_y, w, angle, keep=keep))
    if args.tsumugi_psd:
        # サムネイル用：驚いた顔（目＝見開く・口＝わあ！・眉＝困る・「！」・私服）
        from psd_tools import PSDImage
        psd = PSDImage.open(args.tsumugi_psd)
        want = {"!口": "*わあ！", "!目": "*見開く", "!眉": "*困る"}
        for g in psd:
            if g.name == "!体部分":
                for c in g:
                    if c.name in ("制服", "私服"):
                        c.visible = (c.name == "私服")
            elif g.name in want:
                for c in g:
                    c.visible = (c.name == want[g.name])
            elif g.name == "!アクセサリー":
                for c in g:
                    c.visible = c.name in ("ホクロ", "！")
        face = psd.composite(force=True)
        tmp = out / "_tsumugi_surprised.png"
        face.crop(face.getbbox()).save(tmp)
        cx, rim_y, w, angle, keep = PLACEMENTS["tsumugi"]
        put(str(tmp), str(out / "tsumugi_surprised_helmet.png"), cx, rim_y, w, angle, keep=keep)
        tmp.unlink()
    print(f"立ち絵を作りました: {out}")
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="chiso")
    sub = p.add_subparsers(dest="cmd", required=True)
    for name, fn in [("voice", cmd_voice), ("draft", cmd_draft), ("approve", cmd_approve), ("build", cmd_build)]:
        s = sub.add_parser(name)
        s.add_argument("script")
        if name == "draft":
            s.add_argument("--lines", type=int, help="冒頭の何行だけで作る（見た目の確認用）")
        s.set_defaults(fn=fn)
    s = sub.add_parser("shorts")
    s.add_argument("script")
    s.add_argument("--draft", action="store_true")
    s.set_defaults(fn=cmd_shorts)
    s = sub.add_parser("describe")
    s.add_argument("script")
    s.add_argument("--no-voice", action="store_true", help="章の時刻を出さない（音声を作らない）")
    s.set_defaults(fn=cmd_describe)
    for name, fn in [("kana", cmd_kana), ("check", cmd_check), ("thumb", cmd_thumb), ("screen", cmd_screen)]:
        s = sub.add_parser(name)
        s.add_argument("script")
        s.set_defaults(fn=fn)
    s = sub.add_parser("upload")
    s.add_argument("script")
    s.add_argument("--at", required=True, help="公開時刻（日本時間）'YYYY-MM-DD HH:MM'。9時〜24時")
    s.set_defaults(fn=cmd_upload)
    s = sub.add_parser("whoami")
    s.set_defaults(fn=cmd_whoami)
    s = sub.add_parser("prepare-characters")
    s.add_argument("--tsumugi", required=True)
    s.add_argument("--kenzaki", required=True)
    s.add_argument("--tsumugi-psd", help="つむぎ公式立ち絵の PSD（サムネイル用の驚き顔を作る）")
    s.set_defaults(fn=cmd_prepare_characters)
    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
