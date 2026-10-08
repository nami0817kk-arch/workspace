"""背景（絵画）と前景（透明な画像の並び）を重ねて仕上げる。

背景と前景を分けるのは、前景（肖像・メモ・年表・字幕・2人）を変わったときだけ描けばよくするため。

背景を動かさないとき（config の video.bg_motion: false。10-06 から本編はこれ）は still_frames：
絵ごとに止まった1枚と、替わり目の溶け合い（XFADE 秒＝18コマ）だけの画像の並びにして、重ねるときに
ffmpeg が読む。背景の動画を別に作らない（10-08。前は30秒ずつの断片を作ってつなぎ、溶け合わせてから
重ねていて、本編1本の背景に約50分かかっていた）。溶け合いの式は ffmpeg の xfade（fade・smoothleft）と同じ。

背景を動かすとき（bg_motion: true）は background_track：絵ごとに「寄る」「引く」「右へ流れる」「左へ流れる」を
順に使い分け、拡大率を毎コマ計算して拡大してから 1920x1080 に切り抜く（zoompan より震えにくい）。
絵が替わるところは溶け合わせ、節が替わるところは横に流れて替わる。
"""
from __future__ import annotations

import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageEnhance

OVER = 1.2            # 動かす余裕（画面の 1.2 倍の大きさの絵を用意する）
PIECE = 30.0          # 1つの絵の動きを、この秒数ずつに分けて同時に作る（12個の CPU を使う）
ZOOM = 0.07           # 1つの絵のあいだに寄る（引く）量
XFADE = 0.6           # 絵が替わるときの溶け合いの秒数
MOTIONS = ("in", "right", "out", "left")


@dataclass
class Run:
    picture: object       # script.Picture（None なら暗い無地）
    start: float
    end: float
    section: int


def runs_of(cues: list, total: float) -> list[Run]:
    """行の並びから、同じ背景が続く区間を作る。"""
    out: list[Run] = []
    for i, cue in enumerate(cues):
        start = 0.0 if i == 0 else cue.start
        if i > 0 and cues[i - 1].line.section != cue.line.section:
            start = cues[i - 1].end                    # 節の頭の間（地層のワイプの下）で絵を替える
        pic = cue.line.background
        if out and out[-1].picture == pic:
            continue
        if out:
            out[-1].end = start
        out.append(Run(pic, start, total, cue.line.section))
    if out:
        out[-1].end = total
    return out


def still(painter, pic, path: Path, size: tuple[int, int]) -> None:
    """動かす元の絵（画面の 1.2 倍）。明るさと色を落とす（文字を読みやすく）。"""
    W, H = int(size[0] * OVER), int(size[1] * OVER)
    if pic is None:
        Image.new("RGB", (W, H), (24, 19, 14)).save(path)
        return
    src = painter.image(pic.image).convert("RGB")
    s = max(W / src.width, H / src.height)
    im = src.resize((int(src.width * s) + 1, int(src.height * s) + 1), Image.LANCZOS)
    x, y = (im.width - W) // 2, (im.height - H) // 2
    im = im.crop((x, y, x + W, y + H))
    im = ImageEnhance.Brightness(im).enhance(0.6)
    im = ImageEnhance.Color(im).enhance(0.85)
    im.save(path)


def motion_filter(kind: str, d: float, size: tuple[int, int], t0: float = 0.0) -> str:
    """拡大率を毎コマ変えてから切り抜く ffmpeg のフィルタ。d は絵1つぶんの長さ、t0 はその中の始まり
    （分けて作った断片がつながるように、動きは絵1つぶんの時間で計算する）。"""
    W, H = size
    bw, bh = int(W * OVER), int(H * OVER)
    u = f"((t+{t0:.3f})/{d:.3f})"
    if kind == "still":                                  # 動かさない（10-06 ユーザー「背景を微妙に動かさないで」）
        return f"scale={W}:{H}:flags=bicubic,setsar=1,format=yuv420p"
    if kind == "in":
        z, px, py = f"(1+{ZOOM}*{u})", "0.5", "0.5"
    elif kind == "out":
        z, px, py = f"(1+{ZOOM}-{ZOOM}*{u})", "0.5", "0.5"
    elif kind == "right":
        z, px, py = f"(1+{ZOOM / 2})", f"(0.2+0.6*{u})", "0.5"
    else:
        z, px, py = f"(1+{ZOOM / 2})", f"(0.8-0.6*{u})", "0.5"
    return (f"scale=w='trunc({bw}*{z}/2)*2':h='trunc({bh}*{z}/2)*2':eval=frame:flags=bilinear,"
            f"crop={W}:{H}:x='(in_w-{W})*{px}':y='(in_h-{H})*{py}',setsar=1,format=yuv420p")


class LengthError(RuntimeError):
    pass


def media_seconds(ffmpeg: str, path: Path) -> float | None:
    """ファイルの長さ（秒）。読めなければ None。"""
    import re
    r = subprocess.run([ffmpeg, "-i", str(path)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr)
    return None if not m else int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))


def _ok_length(ffmpeg: str, path: Path, want: float, tol: float) -> bool:
    got = media_seconds(ffmpeg, path)
    return got is not None and abs(got - want) <= tol


PIECE_TRIES = 4
PIECE_WAIT = 10.0       # 秒。落ちたら待つ（回ごとに長く）


def _piece(ffmpeg: str, still_path: Path, kind: str, d: float, t0: float, length: float, fps: int, size,
           out: Path) -> Path:
    # 10-05：メモリ不足の ffmpeg が途中までしか書かずに終わった断片が控えに残り、
    # 30分の本編が3分で仕上がった。控えも作ったものも、長さを測ってから使う
    n = max(1, round(length * fps))                       # コマ数で切る（つなぎ目がずれないように）
    want = n / fps
    if out.exists() and _ok_length(ffmpeg, out, want, 0.2):
        return out
    tmp = out.with_suffix(".tmp.mp4")
    for k in range(PIECE_TRIES):
        # 10-05 夜：空きメモリ2.4GBのとき、5本同時の ffmpeg が起動できずに落ちた（終了コード 0xDFABA7BB）。
        # 落ちたら少し待ってやり直す（ほかの断片が終わればメモリが空く）
        r = subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-loop", "1", "-framerate", str(fps), "-i", str(still_path),
                            "-frames:v", str(n), "-vf", motion_filter(kind, d, size, t0), "-r", str(fps),
                            "-c:v", "libx264", "-preset", "veryfast", "-crf", "16", str(tmp)])
        if r.returncode != 0:
            time.sleep(PIECE_WAIT * (k + 1))
            continue
        if _ok_length(ffmpeg, tmp, want, 0.2):
            tmp.replace(out)
            return out
    raise LengthError(f"背景の断片が予定の長さになりません: {out.name}（{want:.1f}秒）")


def _join(ffmpeg: str, pieces: list[Path], out: Path, want: float | None = None) -> Path:
    if out.exists() and (want is None or _ok_length(ffmpeg, out, want, 0.3)):
        return out
    lst = out.with_suffix(".txt")
    lst.write_text("".join(f"file '{p.as_posix()}'\n" for p in pieces), encoding="utf-8")
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy",
                    str(out)], check=True)
    lst.unlink()
    return out


def background_track(ffmpeg: str, painter, runs: list[Run], work: Path, fps: int, size, target: Path,
                     workers: int = 10, motion: bool = True) -> Path:
    """区間ごとに動く背景を作り、溶け合わせて1本にする。区間は同時に作る（速くするため）。"""
    import hashlib
    work.mkdir(parents=True, exist_ok=True)
    plans = []                                              # 絵ごとの断片の計画
    for i, r in enumerate(runs):
        last = i == len(runs) - 1
        d = (r.end - r.start) + (0 if last else XFADE)      # 次と重なるぶん長く作る
        kind = MOTIONS[i % len(MOTIONS)] if motion else "still"
        key = hashlib.sha1(repr((r.picture, kind, round(d, 3), fps, size, OVER, ZOOM)).encode()).hexdigest()[:12]
        sp = work / f"still_{hashlib.sha1(repr(r.picture).encode()).hexdigest()[:10]}.png"
        if not sp.exists():
            still(painter, r.picture, sp, size)
        pieces = []
        t0 = 0.0
        k = 0
        while t0 < d - 1e-6:
            length = min(PIECE, d - t0)
            pieces.append((sp, kind, d, t0, length, work / f"piece_{key}_{k:03}.mp4"))
            t0 += length
            k += 1
        plans.append((pieces, work / f"clip_{key}.mp4"))
    jobs = [p for pieces, _ in plans for p in pieces]
    with ThreadPoolExecutor(max_workers=workers) as ex:
        list(ex.map(lambda j: _piece(ffmpeg, j[0], j[1], j[2], j[3], j[4], fps, size, j[5]), jobs))
    clips = [_join(ffmpeg, [p[5] for p in pieces], out, sum(round(p[4] * fps) / fps for p in pieces))
             for pieces, out in plans]
    if len(clips) == 1:
        clips[0].replace(target) if not target.exists() else None
        return target
    # 溶け合わせ：節が替わるところは横に流れて、同じ節の中は溶ける
    inputs, chains = [], []
    for c in clips:
        inputs += ["-i", str(c)]
    prev = "[0:v]"
    offset = 0.0
    for i in range(1, len(clips)):
        offset += runs[i - 1].end - runs[i - 1].start
        trans = "smoothleft" if runs[i].section != runs[i - 1].section else "fade"
        label = f"[v{i}]"
        chains.append(f"{prev}[{i}:v]xfade=transition={trans}:duration={XFADE}:offset={offset:.3f}{label}")
        prev = label
    graph = ";".join(chains)
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", *inputs, "-filter_complex", graph, "-map", prev,
                    "-c:v", "libx264", "-preset", "ultrafast", "-crf", "14", "-r", str(fps), str(target)], check=True)
    return target


# --- 背景を動かさないとき（10-08）-----------------------------------------------------------

def _plate(ffmpeg: str, painter, pic, work: Path, size) -> Path:
    """絵1枚ぶんの止まった背景（画面の大きさ）。前と同じく 1.2 倍の絵を ffmpeg の bicubic で縮める
    （motion_filter("still") と同じ縮め方なので、出来上がりの画は前と同じ）。"""
    import hashlib
    key = hashlib.sha1(repr((pic, size, OVER, "plate1")).encode()).hexdigest()[:12]
    out = work / f"plate_{key}.png"
    if out.exists():
        return out
    big = work / f"plate_{key}.big.png"
    still(painter, pic, big, size)
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(big), "-vf",
                    f"scale={size[0]}:{size[1]}:flags=bicubic", "-pix_fmt", "rgb24", str(out)], check=True)
    big.unlink()
    return out


def _smooth(x: float) -> float:
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def blend(a: Image.Image, b: Image.Image, kind: str, progress: float) -> Image.Image:
    """ffmpeg の xfade と同じ式で、溶け合いの途中の1枚を作る。progress は 1（a だけ）→ 0（b だけ）。
    fade：a×p＋b×(1−p)。smoothleft：左から右へ smoothstep(1＋x/w−2p) の割合で b（右から新しい絵が入る）。"""
    if kind == "fade":
        return Image.blend(a, b, 1.0 - progress)
    w = a.width
    row = Image.new("L", (w, 1))
    row.putdata([round(255 * _smooth(1.0 + x / w - progress * 2.0)) for x in range(w)])
    return Image.composite(b, a, row.resize(a.size, Image.NEAREST))


def still_frames(ffmpeg: str, painter, runs: list[Run], work: Path, fps: int, size,
                 workers: int = 4) -> list[tuple[Path, float]]:
    """止まった背景の (画像, 秒数) の並び。絵が替わるところは XFADE 秒のあいだ1コマずつ溶け合わせる
    （同じ節の中は fade、節が替わるところは smoothleft。前の background_track と同じ）。"""
    import hashlib
    work.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=workers) as ex:
        plates = list(ex.map(lambda r: _plate(ffmpeg, painter, r.picture, work, size), runs))
    n = max(1, round(XFADE * fps))
    items: list[tuple[Path, float]] = []
    todo = []
    for i, r in enumerate(runs):
        length = r.end - r.start
        if i == 0 or plates[i] == plates[i - 1]:
            items.append((plates[i], length))
            continue
        kind = "smoothleft" if r.section != runs[i - 1].section else "fade"
        m = max(1, min(n, int(length * fps)))              # 短い区間は溶け合いも短く
        for k in range(m):                                   # k=0 は前の絵のまま（xfade の最初のコマ）
            if k == 0:
                items.append((plates[i - 1], 1 / fps))
                continue
            name = hashlib.sha1(repr((plates[i - 1].name, plates[i].name, kind, k, n)).encode()).hexdigest()[:14]
            path = work / f"mix_{name}.png"
            if not path.exists():
                todo.append((path, plates[i - 1], plates[i], kind, 1.0 - k / n))
            items.append((path, 1 / fps))
        items.append((plates[i], max(0.0, length - m / fps)))

    def run(job):
        path, a, b, kind, p = job
        with Image.open(a) as ia, Image.open(b) as ib:
            blend(ia.convert("RGB"), ib.convert("RGB"), kind, p).save(path, compress_level=1)
    with ThreadPoolExecutor(max_workers=workers) as ex:
        list(ex.map(run, todo))
    return [(p, d) for p, d in items if d > 0]


def compose(ffmpeg: str, background: Path, overlay_list: Path, audio: Path, target: Path, fps: int,
            preset: str = "medium") -> None:
    """背景（動画、または止まった背景の画像の並び .txt）＋前景（透明な画像の並び）＋声を重ねて仕上げる。"""
    if background.suffix == ".txt":                          # 止まった背景：画像は替わったときだけ読む
        bg_in = ["-f", "concat", "-safe", "0", "-i", str(background)]
        bg_chain = f"[0:v]setsar=1,format=yuv420p,fps={fps}[b];"
    else:
        bg_in = ["-i", str(background)]
        bg_chain = "[0:v]null[b];"
    subprocess.run([
        ffmpeg, "-y", "-loglevel", "error",
        *bg_in,
        "-f", "concat", "-safe", "0", "-i", str(overlay_list),
        "-i", str(audio),
        "-filter_complex", bg_chain + "[1:v]format=rgba,fps=" + str(fps) + "[o];[b][o]overlay=0:0:format=auto:shortest=1,format=yuv420p[v]",
        "-map", "[v]", "-map", "2:a",
        "-c:v", "libx264", "-preset", preset, "-crf", "20", "-g", str(fps * 2),
        "-af", loudnorm_filter(ffmpeg, audio), "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
        "-movflags", "+faststart", "-shortest", str(target)], check=True)


LOUD = "I=-14:TP=-1.5:LRA=11"     # YouTube の基準の大きさ


def loudnorm_filter(ffmpeg: str, audio) -> str:
    """音の大きさを2回に分けて揃える：先に測ってから、測った値を渡して掛ける。
    1回だけ掛けると -16 LUFS ほどにしかならなかった（10-07、信長の回を qc で測った）。"""
    import json, re
    try:
        r = subprocess.run([ffmpeg, "-hide_banner", "-nostats", "-i", str(audio),
                            "-af", f"loudnorm={LOUD}:print_format=json", "-f", "null", "-"],
                           capture_output=True, text=True, encoding="utf-8", errors="ignore")
    except OSError:
        return f"loudnorm={LOUD}"
    m = None
    for m in re.finditer(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr):
        pass
    try:
        d = json.loads(m.group(0))
        return (f"loudnorm={LOUD}:measured_I={d['input_i']}:measured_TP={d['input_tp']}"
                f":measured_LRA={d['input_lra']}:measured_thresh={d['input_thresh']}"
                f":offset={d['target_offset']}:linear=true")
    except Exception:
        return f"loudnorm={LOUD}"
