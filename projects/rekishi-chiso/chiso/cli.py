"""歴史の地層の制作コマンド。

    python -m chiso.cli prepare-characters --tsumugi <公式立ち絵png> --kenzaki <公式イラストpng>
    python -m chiso.cli voice   scripts/x.yaml          # 音声だけ作って1本にする（抑揚の確認用）
    python -m chiso.cli draft   scripts/x.yaml          # 確認用の動画（右上に「確認用」と出る）。承認は要らない
    python -m chiso.cli reading-ok scripts/x.yaml       # 全行の kana を1行ずつ確かめたあとの控え（approve の前に要る）
    python -m chiso.cli approve scripts/x.yaml          # 台本の承認を控える（自分の確認を回しきったあとだけ。reading-ok が要る）
    python -m chiso.cli build   scripts/x.yaml          # 本番の動画。承認した台本の中身と一致しないと動かない
    python -m chiso.cli shorts  scripts/x.yaml [--draft]  # short: を付けた行からショートを全部作る
    python -m chiso.cli describe scripts/x.yaml [--keywords]   # 概要欄（章・クレジット・絵の出典。--keywords で扱う語）
    python -m chiso.cli assign  scripts/x.yaml --assets research/x_assets.md   # 絵の割り当ての下書き（out/x_assign.md）
    python -m chiso.cli keywords "織田信長" [--all]      # YouTube の検索候補でよく続く語・題名とタグの候補
    python -m chiso.cli kana    scripts/x.yaml          # 全行の読みをカタカナで書き出す（読み違いの点検）
    python -m chiso.cli thumb   scripts/x.yaml [--variants]   # サムネイル（--variants で3案 a・b・c と一覧の大きさの確認用）
    python -m chiso.cli screen  scripts/x.yaml          # 本番の動画を見てもらった控え（ユーザーの OK のあとだけ）
    python -m chiso.cli upload  scripts/x.yaml --at "2026-10-05 19:00"   # 予約投稿（承認と screen が要る）
    python -m chiso.cli whoami                          # 許可したチャンネルの名前を出す（取り違えの確認）
    python -m chiso.cli playlists [--sync]              # 投稿済みを台本の playlists:／series:／shorts_playlists: の再生リストへ
    python -m chiso.cli localize scripts/x.yaml [--dry-run]   # 投稿済みの本編に台本の en:（英語の題名と説明）を付ける
    python -m chiso.cli reauth                          # 許可の取り直し（ブラウザで同意する。ユーザーが打つ）
    python -m chiso.cli check   scripts/x.yaml          # 素材の有無・書きすぎ・抑揚の張りつきを点検
    python -m chiso.cli qc      scripts/x.yaml [--video out/x.mp4]   # 出来上がった動画の点検（一覧・画面の替わり方・音）

台本確認は必ず通す（チャンネル共通の決まり）。approve を打つのは、ユーザーが台本に
はっきり「OK」と言ったときだけ。「見せて」「出す」は承認ではない。

読みの確認も関門（10-10。10/12〜13 の4本で聞いて分かる誤読が約50か所あった）：check が「読み：」で
辞書との食い違い・読みが割れる語・readings.yaml の巻き込み（共有ライブラリ libs/yomi）を出す（chiso/reading.py）。kana を全行確かめたら
reading-ok を打つ。approve は、その控え（台本と readings.yaml のハッシュ）が無いか合わないと止まる。
readings.yaml を変えると全台本の控えが外れる。予約・公開済みの回（posted.json に main がある回）は対象外。
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import replace
from pathlib import Path
from urllib.parse import unquote

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
                     max_speed=c.get("max_speed", 2.0), emphasis=c.get("emphasis", 1.0))
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


def reading_ok_path(path: Path, root: Path | None = None) -> Path:
    return (root or ROOT) / "approvals" / f"{path.stem}.reading.json"


def _file_sha(p: Path) -> str:
    """ファイルの中身のハッシュ（改行は LF にそろえる。Windows の CRLF の取り出しと CI で同じ値に）。"""
    import hashlib
    return hashlib.sha256(p.read_bytes().replace(b"\r\n", b"\n")).hexdigest() if p.exists() else ""


def is_posted(path: Path, root: Path | None = None) -> bool:
    """予約・公開済みの本編か（posted.json に <名前>:main がある）。読みの関門の対象外。"""
    log = (root or ROOT) / "posted.json"
    if not log.exists():
        return False
    return any(str(e.get("key", "")) == f"{path.stem}:main" for e in json.loads(log.read_text(encoding="utf-8")))


def reading_ok_problem(path: Path, root: Path | None = None) -> str | None:
    """読みの確認の控えが使えないときの理由（使えるなら None）。予約・公開済みの回は見ない。"""
    root = root or ROOT
    if is_posted(path, root):
        return None
    a = reading_ok_path(path, root)
    if not a.exists():
        return "読みの確認の控えがありません。kana を全行確かめてから reading-ok を打ってください"
    got = json.loads(a.read_text(encoding="utf-8"))
    if got.get("sha256") != script_mod.digest(path):
        return "読みの確認のあとで台本が変わっています。変えた行の kana を確かめて reading-ok を打ち直してください"
    if got.get("readings_sha256") != _file_sha(root / "readings.yaml"):
        return "読みの確認のあとで readings.yaml が変わっています。kana を確かめて reading-ok を打ち直してください"
    return None


def cmd_reading_ok(args) -> int:
    """全行の kana を1行ずつ確かめたあとだけ打つ。台本と readings.yaml のハッシュを控える。"""
    path = Path(args.script)
    script_mod.load(path)
    a = reading_ok_path(path)
    a.parent.mkdir(exist_ok=True)
    a.write_text(json.dumps({"script": path.name, "sha256": script_mod.digest(path),
                             "readings_sha256": _file_sha(ROOT / "readings.yaml")}, ensure_ascii=False, indent=1)
                 + "\n", encoding="utf-8")
    print(f"読みの確認を控えました: {a.name}（台本か readings.yaml を変えたら確かめ直し）")
    return 0


def cmd_approve(args) -> int:
    path = Path(args.script)
    script_mod.load(path)  # 壊れた台本は承認しない
    why = reading_ok_problem(path)
    if why:
        print(why)
        return 2
    a = approval_path(path)
    a.parent.mkdir(exist_ok=True)
    a.write_text(json.dumps({"script": path.name, "sha256": script_mod.digest(path)}, ensure_ascii=False, indent=1)
                 + "\n", encoding="utf-8")
    print(f"承認を控えました: {a.name}（台本を変えたら承認し直し）")
    return 0


# --- 音声 ---------------------------------------------------------------

def preflight(sc, config) -> bool:
    """作る前の点検。止めるもの（×）があれば False（音声を作る前に止める）。
    並びは check.report：止めるもの → 直すと効くもの → 参考。同じ種類は1件にまとめる（10-08）。"""
    errors = [f"素材がありません: {m}" for m in check_mod.missing_assets(sc, assets_dir(config))]
    from .people import unknown_roles
    errors += [f"人物「{who}」の声が config.yaml の roles にありません" for who in unknown_roles(config, sc)]
    warns: list[str] = []
    if not str(sc.path.name).startswith("sample"):
        e, w = check_mod.episode(sc)
        errors += e
        warns += w
        if sc.thumbnail:                                 # 同じ構図が3回続いたら知らせる（10-07）
            from .thumb import layout_of
            warns += check_mod.layout_streak(ROOT / "posted.json", ROOT / "scripts", sc.path.stem,
                                             layout_of(sc.thumbnail))
            if not errors:                               # 引きの要素と構図の組み合わせで文字が狭くならないか（10-08）
                from .thumb import text_room
                warns += text_room(sc.thumbnail, config, assets_dir(config))
    if not errors:                                       # 節の題が右上の札・肖像の額に隠れないか（10-09）
        from .render import Painter
        painter = Painter(config, sc, assets_dir(config), (1920, 1080))
        errors += check_mod.section_title_fit(painter)
        warns += check_mod.timeline_crowding(painter)
    warns += check_mod.lint(sc, config.get("short", {}).get("max_seconds", 60))
    from . import reading                                # 読み違い（10-10）：辞書との食い違い・割れる字・辞書の巻き込み
    e, w = reading.notes(sc, load_readings(ROOT / "readings.yaml"), kana_source(config))
    errors += e
    warns += w
    for who, (hit, n) in check_mod.saturation(sc, voices(config)).items():
        if hit:
            warns.append(f"{people.label(config, who)}：{n}行中{hit}行で抑揚が上限2.0を超えるか、1.2倍より早口です")
    rows = check_mod.report(errors, warns)
    for row in rows:
        print(f"  {row}")
    if rows:
        n = {k: sum(r.startswith(k) for r in rows) for k in ("×", "!", "・")}
        print(f"  （止める {n['×']}件・直すと効く {n['!']}件・参考 {n['・']}件）")
    return not errors


def kana_source(config):
    """読みの点検に使う VOICEVOX のカナ（control は work/kana_cache.json）。"""
    from .reading import kana_source as source
    return source(config["voicevox_url"], config["cast"]["語り"]["style_id"])


def readings_for(sc) -> dict:
    """readings.yaml を読み、この台本で辞書のキーが長い語を巻き込んでいれば知らせる（10-10。「露: つゆ」が「披露」に）。"""
    readings = load_readings(ROOT / "readings.yaml")
    from . import reading
    for row in reading.collision_lines(readings, reading.items(sc)):
        print(f"  ! 読み：{row}")
    return readings


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
    voicevox_guard(config)
    from .render import recap_sections
    return mix.plan(sc.lines, spoken, recap_sections(config, sc))


VOICEVOX_MAX_GB = 6.0


def voicevox_guard(config) -> None:
    """VOICEVOX のエンジンは動かし続けるとメモリを抱え込む（10-06、9/24 から動いて約15GB。
    ffmpeg が malloc に失敗して書き出しが止まった）。音声を作り終えたあと、抱えすぎなら立ち上げ直す。"""
    if os.name != "nt":
        return
    port = str(config["voicevox_url"]).rstrip("/").rsplit(":", 1)[-1]
    ps = ("$p = Get-CimInstance Win32_Process -Filter \"Name='run.exe'\" | "
          f"Where-Object {{ $_.CommandLine -like '*vv-engine*' -and $_.CommandLine -like '*{port}*' }} | Select-Object -First 1; "
          "if ($p) { '{0}|{1}|{2}' -f $p.ProcessId, $p.PrivatePageCount, $p.ExecutablePath }")
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True,
                             timeout=60).stdout.strip()
    except Exception:
        return
    if not out:
        return
    pid, used, exe = out.split("|", 2)
    gb = int(used) / 1024 ** 3
    if gb < VOICEVOX_MAX_GB:
        return
    print(f"VOICEVOX のエンジンが {gb:.1f}GB 抱えているので立ち上げ直します")
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    f"Stop-Process -Id {pid} -Force; Start-Process -FilePath '{exe}' "
                    f"-ArgumentList '--host','127.0.0.1','--port','{port}' -WindowStyle Hidden"], timeout=60)
    import time, urllib.request
    for _ in range(60):
        time.sleep(2)
        try:
            urllib.request.urlopen(f"{config['voicevox_url'].rstrip('/')}/version", timeout=2)
            return
        except Exception:
            pass
    print("  ! VOICEVOX のエンジンが立ち上がりません")


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
           "-af", video.loudnorm_filter(ffmpeg(), audio),        # YouTube の基準の大きさに揃える（2回に分けて）
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
    clock = Clock()
    cues, total = synthesize(sc, config)
    clock.lap("音声")
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
    clock.lap("前景")
    runs = video.runs_of(cues, total)
    if v.get("bg_motion", True):
        print("背景を動かしています…")
        bg = video.background_track(ffmpeg(), painter, runs, wd / "bg", v["fps"], size, wd / "background.mp4",
                                    workers=v.get("bg_workers", 5))
    else:                                                 # 止まった背景は動画にせず、画像の並びのまま重ねる（10-08）
        print("背景を並べています…")
        bg = wd / "background.txt"
        bg.write_text(render.concat_list(video.still_frames(ffmpeg(), painter, runs, wd / "bg", v["fps"], size,
                                                            workers=v.get("bg_workers", 5))), encoding="utf-8")
    clock.lap("背景")
    suffix = ("_draft" if draft else "") + (f"_{limit}lines" if limit else "")
    target = out_dir() / f"{path.stem}{suffix}.mp4"
    lst = wd / "overlay.txt"
    lst.write_text(render.concat_list(items), encoding="utf-8")
    print("重ねています…")
    video.compose(ffmpeg(), bg, lst, audio, target, v["fps"], preset="veryfast" if draft else "medium")
    clock.lap("重ね")
    got = video.media_seconds(ffmpeg(), target)
    if got is None or abs(got - total) > 2.0:               # 10-05：3分しかない本編が「30.7分」と出て通っていた
        raise video.LengthError(f"仕上がりの長さが合いません: {got}秒（予定 {total:.1f}秒）。work/<台本>/bg を消して作り直す")
    if bg.suffix == ".mp4":                               # 動かした背景の動画は大きいので消す（並びの .txt は残す）
        bg.unlink()
    names = {k: people.label(config, k) for k in list(config["cast"]) + sc.roles}
    (out_dir() / f"{path.stem}.srt").write_text(mix.srt(cues, names), encoding="utf-8")
    print(f"{target}（{total / 60:.1f}分）")
    print(f"かかった時間：{clock}")
    remind_mismatch(sc)
    return 0


def remind_mismatch(sc) -> None:
    """話と画面の食い違いの知らせ（10-08）を、作り終えたあとにもう一度並べる。点検の知らせは作る前に流れて読まれないので、
    コマを見る前に目に入るように。"""
    from . import match
    rows = match.notes(sc)
    if rows:
        print(f"話と画面の食い違いが{len(rows)}件あります（コマで確かめる）：")
        for r in rows:
            print(f"  ! {r}")


class Clock:
    """段ごとにかかった時間（10-08。build の遅い所を見るため）。"""
    def __init__(self):
        import time
        self._t = time.perf_counter()
        self.laps: list[tuple[str, float]] = []

    def lap(self, name: str) -> None:
        import time
        now = time.perf_counter()
        self.laps.append((name, now - self._t))
        self._t = now

    def __str__(self) -> str:
        total = sum(s for _, s in self.laps)
        return "・".join(f"{n} {s / 60:.1f}分" for n, s in self.laps) + f"（計 {total / 60:.1f}分）"


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
    readings = readings_for(sc)
    cache = work_dir(sc) / "voice"
    sz = config["short"]
    hook_on, loop_on = shorts_mod.options(config)          # 頭の大きな問い・ループしやすい終わり（10-08）
    say_hook = shorts_mod.hook_say(config)                 # 頭の問いを つむぎの声でも読む（10-08）
    fps = config["video"]["fps"]
    for sid, meta in sc.shorts.items():
        if getattr(args, "only", None) and sid not in args.only.split(","):
            continue
        body = sc.short_lines(sid)
        hook_line, tease_line = shorts_mod.extra_lines(body, meta, say_hook and hook_on)
        lines = ([hook_line] if hook_line else []) + body + ([tease_line] if tease_line else [])
        spoken = {line.index: tts.speak_line(engine, line, vs, readings, cache)
                  for line in lines}
        # ショートの中では節の切れ目の長い間を入れない
        flat = [_same_section(line) for line in lines]
        cues, total = mix.plan(flat, spoken)
        wd = work_dir(sc) / f"short-{sid}"
        cls = _stamp(shorts_mod.ShortPainter) if args.draft else shorts_mod.ShortPainter
        painter = cls(config, sc, assets_dir(config), meta.get("title", ""))
        # 頭の問いの行は、下のせりふの箱を出さない（問いは上に特大で出ている）
        shown = [replace(c, line=replace(c.line, text="")) if c.line.index == -1 else c for c in cues]
        hold = (cues[0].end + shorts_mod.HOOK_AFTER) if hook_line else shorts_mod.HOOK_HOLD
        if tease_line:                                      # 最後のもう一つの疑問（10-08）。「続きは本編で」とループの画の代わり
            tc = shown.pop()
            total = tc.end + shorts_mod.TEASE_AFTER
            items = render.frames(painter, shown, tc.start, wd / "frames", fps, with_text=True)
            items = shorts_mod.finish(items, painter, shorts_mod.hook_text(meta) if hook_on else "", wd / "hook",
                                      fps, False, hold=hold)
            items += shorts_mod.tease_items(painter, tc.line.background, shorts_mod.tease_text(meta),
                                            total - tc.start, wd / "tease")
            tail = 0.0
        else:
            end_s = shorts_mod.LOOP_END_SECONDS if loop_on else shorts_mod.END_SECONDS
            tail = shorts_mod.LOOP_TAIL if loop_on else 0.0
            total += end_s                                  # 最後に「続きは本編で」（声なし）
            items = render.frames(painter, shown, total, wd / "frames", fps, with_text=True,
                                  end_card=True, end_seconds=end_s)
            items = shorts_mod.finish(items, painter, shorts_mod.hook_text(meta) if hook_on else "", wd / "hook",
                                      fps, loop_on, hold=hold)
        total += tail
        if total > sz["max_seconds"]:
            print(f"  ! {sid}: {total:.1f}秒で、上限 {sz['max_seconds']}秒を超えています")
        audio = wd / "voice.wav"
        mix.write_audio(cues, total, audio)                 # 最後の画面の残り・ループ用の画のあいだは無音
        target = out_dir() / f"{path.stem}_short_{sid}{'_draft' if args.draft else ''}.mp4"
        encode(items, audio, target, fps)
        print(f"{target}（{total:.1f}秒）")
    return 0


def _same_section(line):
    return replace(line, section=0)


# --- 概要欄 -------------------------------------------------------------

def description(sc, config, cues, reserve: int = 0) -> str:
    """reserve：あとに足す行（この動画で扱うこと）の字数。そのぶん絵の出典の欄を詰める。"""
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
    tail = []
    if sc.series:
        tail += ["", f"#歴史の地層 #{sc.series} #世界史 #日本史 #聞き流し"]
    tail += ["", f"運営：{config.get('operator', '')}"]
    room = DESC_ROOM - reserve - len("\n".join(out)) - len("\n".join(tail)) - 2
    return "\n".join(out + source_lines(picture_sources(sc, config), room) + tail) + "\n"


DESC_ROOM = 4900   # YouTube の概要欄は5000字まで。超えると後ろ（運営・扱う語）が切れる（10-09、絵の多い回で1万字を超えた）


def source_lines(sources: list[tuple[str, str]], room: int) -> list[str]:
    """絵の出典の欄。同じ許諾をまとめて見出しの行に書く（URL のすぐ後ろに字を付けるとリンクが壊れる）。
    room 字に入らない分は件数だけ書く。"""
    if not sources:
        return []
    groups: dict[str, list[str]] = {}
    for url, lic in sources:
        groups.setdefault(lic, []).append(url)
    lines, shown = ["", "■ 絵の出典（Wikimedia Commons）"], 0
    rest = f"ほか{len(sources)}点（いずれも Wikimedia Commons。上の「画面の絵」の作品名で探せます）"
    for lic, urls in groups.items():
        head = [f"［{lic}］"] if lic else []
        for url in urls:
            if len("\n".join(lines + head + [url, rest])) > room:
                break
            lines += head + [url]
            head = []
            shown += 1
        else:
            continue
        break
    if shown < len(sources):
        lines.append(rest.replace(str(len(sources)), str(len(sources) - shown), 1))
    return lines


def picture_sources(sc, config) -> list[tuple[str, str]]:
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
                out.append((unquote(credits[key]["source"]), credits[key].get("license", "")))
    return out


def keyword_line(sc) -> str:
    """検索候補から拾った語のうち、台本で扱っているもの（「この動画で扱うこと：」の1行）。"""
    from . import keywords as kw
    name = sc.thumbnail.get("name") or next(iter(sc.people), "") or sc.question
    cache = kw.cache_path(out_dir(), name)
    if cache.exists():
        data = json.loads(cache.read_text(encoding="utf-8"))
    else:
        _, data = kw.report(name, kw.collect(name))
        cache.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    line = kw.description_line(kw.covered_words([w for w, _ in data["words"]], sc))
    if not line:
        print(f"  ! 「{name}」の検索候補の語で、台本に出てくるものがありませんでした")
    return line


def full_description(sc, config, cues, keywords: bool = True) -> str:
    """概要欄。describe と upload で同じものを作る（前は upload に扱う語の行が入らなかった）。5000字に収める。"""
    line = keyword_line(sc) if keywords else ""
    text = description(sc, config, cues, reserve=len(line) + 2 if line else 0)
    return text + ("\n" + line + "\n" if line else "")


def cmd_describe(args) -> int:
    config = load_config()
    sc = script_mod.load(args.script)
    cues = []
    if not args.no_voice:
        cues, _ = synthesize(sc, config)
    text = full_description(sc, config, cues, keywords=args.keywords)
    target = out_dir() / f"{sc.path.stem}_description.txt"
    target.write_text(text, encoding="utf-8")
    print(text)
    return 0


def cmd_keywords(args) -> int:
    """YouTube の検索候補から、名前のあとによく続く語を数える。題名・タグ・概要欄の語の下書きも出す。"""
    from . import keywords as kw
    raw = kw.collect(args.name, full=args.all)
    if not any(raw.values()):
        print("検索候補が1件も取れませんでした（通信を確かめる）")
        return 1
    text, data = kw.report(args.name, raw)
    cache = kw.cache_path(out_dir(), args.name)
    cache.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    cache.with_suffix(".md").write_text(text, encoding="utf-8")
    print(text)
    print(f"控え：{cache.with_suffix('.md').as_posix()}")
    return 0


def cmd_assign(args) -> int:
    """絵の一覧（research の *_assets.md）と台本の各行を照らし、どの行でどの絵に替えるかの下書きを out/x_assign.md に。"""
    from . import assign
    sc = script_mod.load(args.script)
    assets = assign.parse_assets(Path(args.assets).read_text(encoding="utf-8"))
    if not assets:
        print(f"絵の一覧の表が読めません（「ファイル名」の列がある表）: {args.assets}")
        return 1
    picks = assign.draft(sc, assets)
    text = assign.report(sc, assets, picks)
    target = out_dir() / f"{sc.path.stem}_assign.md"
    target.write_text(text, encoding="utf-8")
    print(text)
    print(f"控え：{target.as_posix()}")
    return 0


def cmd_kana(args) -> int:
    """全行の読みをカタカナで書き出す。読み違いを音を出す前に見つけるため。"""
    from .voice import apply_readings, split_emphasis
    config = load_config()
    sc = script_mod.load(args.script)
    engine = tts.Voicevox(config["voicevox_url"])
    readings = readings_for(sc)
    vs = voices(config)
    for line in sc.lines:
        q = engine.query(apply_readings(split_emphasis(line.text)[0], readings), vs.get(line.speaker, vs["語り"]).style_id)
        phrases, _ = __import__("chiso.voice", fromlist=["join_n_phrases"]).join_n_phrases(q["accent_phrases"])
        kana = "／".join("".join(m["text"] for m in p["moras"]) for p in phrases)
        print(f"{line.index + 1:3} {people.label(config, line.speaker)[:2]} {kana}")
    from .reading import items
    for label, text in items(sc)[len(sc.lines):]:          # ショートの頭の問い・最後の問い（つむぎが読む。10-10）
        q = engine.query(apply_readings(split_emphasis(text)[0], readings), vs[shorts_mod.TEASER].style_id)
        phrases, _ = __import__("chiso.voice", fromlist=["join_n_phrases"]).join_n_phrases(q["accent_phrases"])
        print(f"{label} {'／'.join(''.join(m['text'] for m in p['moras']) for p in phrases)}")
    return 0


def cmd_thumb(args) -> int:
    from . import thumb
    config = load_config()
    sc = script_mod.load(args.script)
    if not sc.thumbnail:
        print("台本に thumbnail の欄がありません")
        return 1
    out = Path(args.out) if args.out else out_dir()
    out.mkdir(parents=True, exist_ok=True)
    stem = sc.path.stem
    if args.variants:                     # 3案（YouTube Studio の「テストと比較」用）
        imgs = thumb.make_variants(sc, config, assets_dir(config), work_dir(sc))
        for k, img in imgs.items():
            img.save(out / f"{stem}_thumbnail_{k}.png")
            print(out / f"{stem}_thumbnail_{k}.png")
        thumb.variants_preview(imgs, config["fonts"]["gothic"]).save(out / f"{stem}_thumbnail_variants_preview.png")
        print(out / f"{stem}_thumbnail_variants_preview.png")
        return 0
    img = thumb.make(sc, config, assets_dir(config), work_dir(sc))
    target = out / f"{stem}_thumbnail.png"
    img.save(target)
    thumb.preview(img).save(out / f"{stem}_thumbnail_preview.png")
    print(target)
    return 0


def cmd_check(args) -> int:
    config = load_config()
    sc = script_mod.load(args.script)
    ok = preflight(sc, config)
    print("点検は終わりました" + ("" if ok else "（× を直すまで draft・build は止まります）"))
    return 0 if ok else 3


def cmd_qc(args) -> int:
    """出来上がった動画を見る：20秒ごとの一覧（節ごとの段）・画面が大きく変わらない区間・字幕と長さの差・音の大きさ・無音。"""
    from . import qc
    config = load_config()
    sc = script_mod.load(args.script)
    video_path = Path(args.video) if args.video else out_dir() / f"{sc.path.stem}.mp4"
    if not video_path.exists():
        print(f"動画がありません: {video_path.as_posix()}")
        return 1
    stem = sc.path.stem
    png, md = out_dir() / f"{stem}_qc.png", out_dir() / f"{stem}_qc.md"
    print(f"{video_path.as_posix()} を読んでいます（1回通して見ます）…")
    lines = qc.run(ffmpeg(), sc, video_path, png, md, config.get("fonts", {}).get("gothic"),
                   end_seconds=render.END_SECONDS if sc.next else 0.0)
    print("\n".join(lines))
    print(f"\n控え：{md.as_posix()}")
    return 0


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


def shorts_screened_path(path: Path) -> Path:
    return ROOT / "approvals" / f"{path.stem}.shorts.screened.json"


def short_video(path: Path, sid: str) -> Path:
    return out_dir() / f"{path.stem}_short_{sid}.mp4"


def cmd_screen_shorts(args) -> int:
    """本番のショートをユーザーが見て OK と言ったときだけ打つ。全ショートの動画のハッシュを控える。"""
    path = Path(args.script)
    sc = script_mod.load(path)
    got = {}
    for sid in sc.shorts:
        v = short_video(path, sid)
        if not v.exists():
            print(f"本番のショートがありません: {v.name}（shorts を先に）")
            return 1
        got[sid] = _sha(v)
    shorts_screened_path(path).write_text(json.dumps(got, ensure_ascii=False, indent=1) + chr(10), encoding="utf-8")
    print(f"ショート{len(got)}本の確認を控えました")
    return 0


def cmd_upload_shorts(args) -> int:
    """ショートを順に予約投稿する。--start から --every 分ごと。投稿済みのものは飛ばす。"""
    from . import shortpost, upload as up
    config = load_config()
    path = Path(args.script)
    sc = script_mod.load(path)
    if not is_approved(path):
        print("台本が承認されていません")
        return 2
    sp = shorts_screened_path(path)
    seen = json.loads(sp.read_text(encoding="utf-8")) if sp.exists() else {}
    log = ROOT / "posted.json"
    main = up.already_posted(log, f"{path.stem}:main")
    sids = [s for s in sc.shorts if not args.only or s in args.only.split(",")]
    times = shortpost.schedule(args.start, args.every, len(sids))
    for sid in sids:
        v = short_video(path, sid)
        if not v.exists() or seen.get(sid) != _sha(v):
            print(f"{sid}: 本番のショートを見せて OK をもらってから screen-shorts（作り直したら確認し直し）")
            return 2
    svc = _service(need_manage=bool(sc.shorts_playlists))
    if svc is None:
        return 2
    for sid, at in zip(sids, times):
        key = f"{path.stem}:short:{sid}"
        done = up.already_posted(log, key)
        if done:
            print(f"{sid}: もう投稿してあります https://youtu.be/{done['video_id']}")
            continue
        publish_at = up.publish_time(at)
        t = shortpost.title(sc, sid)
        desc = shortpost.description(sc, config, sid, main and main["video_id"])
        print(f"{sid}: {t}（{at}）")
        vid = up.upload(svc, short_video(path, sid), t, desc, shortpost.tags(sc, sid), publish_at)
        up.record(log, {"key": key, "video_id": vid, "title": t, "publish_at": at})
        print(f"  予約しました: https://youtu.be/{vid}")
        _into_playlists(svc, sc.shorts_playlists, key, vid)
    return 0


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
    desc = full_description(sc, config, cues)
    thumb_p = out_dir() / f"{path.stem}_thumbnail.png"
    if not thumb_p.exists():
        from . import thumb
        thumb.make(sc, config, assets_dir(config), work_dir(sc)).save(thumb_p)
    srt = out_dir() / f"{path.stem}.srt"
    tags = list(dict.fromkeys(TAGS + list(sc.tags) + [x for x in (sc.series, sc.thumbnail.get("name", "")) if x]))
    from . import channel
    loc = channel.localizations(sc.en, desc) if sc.en else None     # 章の数の食い違いは投稿の前に止める
    svc = _service(need_manage=bool(sc.en or sc.playlists))
    if svc is None:
        return 2
    print(f"投稿します：{sc.title}"); print(f"  公開 {args.at}（日本時間）")
    vid = up.upload(svc, video, sc.title, desc, tags, publish_at, thumb_p, srt, localizations=loc)
    up.record(log, {"key": key, "video_id": vid, "title": sc.title, "publish_at": args.at})
    print(f"予約しました: https://youtu.be/{vid}")
    _into_playlists(svc, sc.playlists, key, vid)
    return 0


def _service(need_manage: bool = False):
    """許可を読み、チャンネルが「歴史の地層」かを確かめる。足りなければ取り直しの手順を出して None。"""
    from . import upload as up
    try:
        svc = up.service(need_manage=need_manage)
    except up.NeedConsent as err:
        print(str(err))
        return None
    name = up.channel_title(svc)
    if "歴史の地層" not in name:
        print(f"許可しているチャンネルが違います: {name}\n" + up.REAUTH)
        return None
    print(f"  チャンネル：{name}")
    return svc


def _into_playlists(svc, names, key: str, vid: str) -> None:
    """投稿した1本を再生リストへ。落ちても投稿は済んでいるので警告だけ（あとで playlists --sync）。"""
    if not names:
        return
    from . import channel
    p = channel.Plan()
    for n in names:
        p.add(n, key, vid)
    try:
        channel.sync(svc, p, channel.load_descriptions(ROOT / "playlists.yaml"), channel.Budget(1000))
    except Exception as err:  # noqa: BLE001
        print(f"! 再生リストに入りませんでした（{str(err)[:80]}）。あとで playlists --sync を打ってください")


def posted_scripts(root: Path = ROOT) -> dict:
    """posted.json に出てくる台本（stem → Script）。"""
    log = root / "posted.json"
    entries = json.loads(log.read_text(encoding="utf-8")) if log.exists() else []
    out = {}
    for stem in dict.fromkeys(str(e.get("key", "")).split(":")[0] for e in entries):
        f = root / "scripts" / f"{stem}.yaml"
        if f.exists():
            out[stem] = script_mod.load(f)
    return out


def cmd_playlists(args) -> int:
    """投稿済みの動画を再生リストへ。--sync が無ければ計画を出すだけ（API を使わない）。"""
    from . import channel
    log = ROOT / "posted.json"
    posted = json.loads(log.read_text(encoding="utf-8")) if log.exists() else []
    p = channel.plan(posted_scripts(), posted, args.only)
    if not p.lists:
        print("入れる再生リストがありません（台本に playlists:・series:・shorts_playlists: を書く）")
        return 0
    for name, items in p.lists.items():
        print(f"■ {name}（{len(items)}本）")
        for key, vid in items:
            print(f"  {key}  https://youtu.be/{vid}")
    print(f"書き込みは最大 {p.max_units()} 単位（作る1つ・足す1本ごとに50。入っているものは飛ばす）／1日の枠は 10,000")
    if not args.sync:
        print("（計画だけ。入れるのは --sync）")
        return 0
    svc = _service(need_manage=True)
    if svc is None:
        return 2
    budget = channel.Budget(args.budget)
    r = channel.sync(svc, p, channel.load_descriptions(ROOT / "playlists.yaml"), budget)
    print(f"作ったリスト {len(r['created'])}・足した動画 {len(r['added'])}・入っていた {r['skipped']}（使った単位 約{budget.used}）")
    return 1 if r["stopped"] else 0


def cmd_localize(args) -> int:
    """投稿済みの本編に英語の題名と説明を付ける。video_id は posted.json から。"""
    from . import channel, upload as up
    path = Path(args.script)
    sc = script_mod.load(path)
    if not sc.en:
        print("台本に en: {title, description, chapters} がありません")
        return 2
    done = up.already_posted(ROOT / "posted.json", f"{path.stem}:main")
    if not done:
        print(f"posted.json に {path.stem}:main がありません（まだ投稿していない回は upload のときに付きます）")
        return 2
    svc = _service(need_manage=True)
    if svc is None:
        return 2
    body = channel.localize(svc, done["video_id"], sc.en, dry_run=args.dry_run)
    en = body["localizations"]["en"]
    print(f"https://youtu.be/{done['video_id']}")
    print(f"題名（英語）：{en['title']}")
    print(en["description"])
    if not args.dry_run:
        print("英語の題名と説明を付けました（videos.update 50 単位）")
    return 0


def cmd_reauth(args) -> int:
    """許可の取り直し。ブラウザが開くので、ユーザーが「歴史の地層」を選んで同意する。"""
    from . import upload as up
    backup = up.reauth()
    if backup:
        print(f"古い許可は残してあります: {backup}")
    svc = _service(need_manage=True)
    if svc is None:
        if backup:
            print(f"前の許可に戻すときは {backup.name} を token.json に名前を戻す")
        return 2
    print("投稿・再生リスト・英語の題名を書き込めます")
    return 0


def cmd_whoami(args) -> int:
    from . import upload as up
    try:
        cred = up.credentials()
    except up.NeedConsent as err:
        print(str(err))
        return 2
    *_, build, _ = up._deps()
    print(up.channel_title(build("youtube", "v3", credentials=cred)))
    ok = up.can_manage(up.granted_scopes(cred))
    print("許可：投稿" + ("・再生リスト・英語の題名（videos.update）" if ok else "だけ（再生リストと英語の題名には reauth が要る）"))
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
    s.add_argument("--only", help="作るショートだけ（例 s1,s3）")
    s.set_defaults(fn=cmd_shorts)
    s = sub.add_parser("describe")
    s.add_argument("script")
    s.add_argument("--no-voice", action="store_true", help="章の時刻を出さない（音声を作らない）")
    s.add_argument("--keywords", action="store_true", help="最後に「この動画で扱うこと：」（検索候補の語のうち台本に出てくるもの）")
    s.set_defaults(fn=cmd_describe)
    s = sub.add_parser("assign")
    s.add_argument("script")
    s.add_argument("--assets", required=True, help="絵の一覧（research/x_assets.md）")
    s.set_defaults(fn=cmd_assign)
    s = sub.add_parser("keywords")
    s.add_argument("name", help="人物・出来事の名前（例：織田信長）")
    s.add_argument("--all", action="store_true", help="頭文字をあ〜ん全部（46回）。既定は各行の頭の10回")
    s.set_defaults(fn=cmd_keywords)
    s = sub.add_parser("thumb")
    s.add_argument("script")
    s.add_argument("--variants", action="store_true", help="3案（a・b・c）と一覧の大きさの確認用を作る")
    s.add_argument("--out", help="書き出す場所（省けば out/）")
    s.set_defaults(fn=cmd_thumb)
    for name, fn in [("kana", cmd_kana), ("check", cmd_check), ("screen", cmd_screen), ("reading-ok", cmd_reading_ok)]:
        s = sub.add_parser(name)
        s.add_argument("script")
        s.set_defaults(fn=fn)
    s = sub.add_parser("qc")
    s.add_argument("script")
    s.add_argument("--video", help="点検する動画（省けば out/<台本>.mp4）")
    s.set_defaults(fn=cmd_qc)
    s = sub.add_parser("upload")
    s.add_argument("script")
    s.add_argument("--at", required=True, help="公開時刻（日本時間）'YYYY-MM-DD HH:MM'。9時〜24時")
    s.set_defaults(fn=cmd_upload)
    s = sub.add_parser("screen-shorts")
    s.add_argument("script")
    s.set_defaults(fn=cmd_screen_shorts)
    s = sub.add_parser("upload-shorts")
    s.add_argument("script")
    s.add_argument("--start", required=True, help="最初の公開時刻（日本時間）'YYYY-MM-DD HH:MM'")
    s.add_argument("--every", type=int, default=60, help="何分ごとに出すか")
    s.add_argument("--only", default="", help="s1,s3 のように一部だけ")
    s.set_defaults(fn=cmd_upload_shorts)
    s = sub.add_parser("whoami")
    s.set_defaults(fn=cmd_whoami)
    s = sub.add_parser("playlists")
    s.add_argument("--sync", action="store_true", help="作って入れる（書き込み）。無ければ計画を出すだけ（API を使わない）")
    s.add_argument("--only", default="", help="1つの台本だけ（例 kira）")
    s.add_argument("--budget", type=int, default=3000, help="今回の書き込みで使ってよい単位（既定 3000＝約60本）")
    s.set_defaults(fn=cmd_playlists)
    s = sub.add_parser("localize")
    s.add_argument("script")
    s.add_argument("--dry-run", action="store_true", help="今の概要欄から英語の説明を作って見せるだけ（videos.list 1 単位）")
    s.set_defaults(fn=cmd_localize)
    s = sub.add_parser("reauth")
    s.set_defaults(fn=cmd_reauth)
    s = sub.add_parser("prepare-characters")
    s.add_argument("--tsumugi", required=True)
    s.add_argument("--kenzaki", required=True)
    s.add_argument("--tsumugi-psd", help="つむぎ公式立ち絵の PSD（サムネイル用の驚き顔を作る）")
    s.set_defaults(fn=cmd_prepare_characters)
    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
