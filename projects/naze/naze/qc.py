"""動画の点検。`python -m naze qc episodes/<題材>`(compose のあと)。

見るもの(✖ は通らない、△ は目で確かめる):
  台本  語りが速すぎる行(1 秒あたりの字数)・字幕が語りと食い違う行・字幕が長すぎて字が縮む行・
        ショートの長さ(3 分以内)・つかみ(最初の問いが 4 秒以内に終わる)
  画面  札と字幕・見出し・ほかの札の重なり・画面の外へのはみ出し・真っ黒なコマ・
        画面が止まったままの区間・1 分あたりの切り替えの回数
  音    音量(-17〜-12 LUFS)・ピーク・長い無音
結果は out/<題材>/qc.md と qc.json。行ごとに 1 コマずつ並べた qc_sheet.png も書く(目で確かめる用)。
qc.json の passed が true で、mp4 が点検のときから変わっていなければ、naze.upload が投稿を通す。
"""
from __future__ import annotations

import json
import re
import subprocess
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from . import overlay as ov
from .config import ASPECT, FPS, H, W, ffmpeg

CPS_WARN, CPS_FAIL = 8.5, 10.0          # 語りの速さ(字/秒、句読点を除く)
SENT_MAX = 25                           # 一文の字数(docs/writing.md)
NUMS_PER_MIN = 4.0                      # 数字の数(1 分あたり)
COMPARE = re.compile(r"倍|個分|杯分|歩いて|階建て|ぶん|分の|同じくらい|と同じ|ほどの")   # 身近な比べ
TWIST = re.compile(r"実は|ところが|しかし|でも、|ではなく|多くの人|と思いますか|思うかもしれません")   # 思い込みの切り返し
HANDOFF = re.compile(r"見てください|思い出してください|見たら|立ったら|通ったら|乗ったら|見上げたら")   # 暮らしへの渡し
SHRINK_WARN = 0.8                       # 字幕が長すぎて元の大きさの 8 割より小さくなる
STATIC_WARN, STATIC_FAIL = 4.0, 7.0     # 画面が止まったままの秒数
SAMPLE_FPS = 6                          # 画面の点検で見るコマの間隔


def _plain(s: str) -> str:
    return re.sub(r"[【】|\n、。，．,.「」『』・？！?!\s　（）()〜~…]", "", s)


def script(ep: dict, tl: dict) -> tuple[list, list]:
    fails, warns = [], []
    defs = {d["id"]: d for d in ep["lines"]}
    for l in tl["lines"]:
        d = defs[l["id"]]
        n = len(_plain(d["text"]))
        dur = max(0.1, l["end"] - l["start"])
        cps = n / dur
        if cps > CPS_FAIL:
            fails.append(f"語りが速すぎる [{l['id']}] {cps:.1f} 字/秒(上限 {CPS_FAIL})")
        elif cps > CPS_WARN:
            warns.append(f"語りがやや速い [{l['id']}] {cps:.1f} 字/秒")
        sub = d.get("sub")
        if sub and d.get("style") != "end" and _plain(sub) != _plain(d["text"]):
            warns.append(f"字幕が語りと違う [{l['id']}] 字幕「{_plain(sub)}」/ 語り「{_plain(d['text'])}」")
    body = [d for d in ep["lines"] if d.get("style") != "cta"]
    whole = "".join(d["text"] for d in body)
    for d in body:
        for s in re.split(r"[。？！?!]", d["text"]):
            if len(_plain(s)) > SENT_MAX + 8:
                warns.append(f"一文が長い [{d['id']}] {len(_plain(s))}字「{s[:18]}…」(目安 {SENT_MAX} 字)")
    dur_body = max(1.0, tl["lines"][len(body) - 1]["end"])
    nums = len(re.findall(r"\d+", whole))
    if nums / (dur_body / 60) < NUMS_PER_MIN:
        warns.append(f"数字が少ない {nums} 個({nums / (dur_body / 60):.1f}/分、目安 {NUMS_PER_MIN}/分)")
    first = body[0]["text"]
    if first.rstrip("。").endswith(("？", "?", "の")) and not re.search(r"\d", first):
        warns.append("冒頭が問いだけ(意外な事実を数字つきで言い切ってから問う。docs/writing.md)")
    if not COMPARE.search(whole):
        warns.append("身近な比べが無い(倍・個分・歩いて○分 など)")
    if not TWIST.search(whole):
        warns.append("思い込みの切り返しが無い(普通は〜のはず、ところが〜)")
    last = ep.get("cta", True)            # 本編の途中の章(cta=False)には結びの型を求めない
    if last and not HANDOFF.search(body[-1]["text"] + (body[-2]["text"] if len(body) > 1 else "")):
        warns.append("結びに暮らしへの渡しが無い(次に〜したら〜を見てください)")
    if last and ASPECT == "landscape" and not re.search(r"思い出して|冒頭|最初の", whole):
        warns.append("本編なのに伏線の回収が無い(〜を思い出してください)")
    if ASPECT == "portrait" and tl["total"] > 178:
        fails.append(f"ショートが長すぎる {tl['total']:.0f} 秒(3 分以内)")
    first = tl["lines"][0]
    if first["end"] > 4.0:
        warns.append(f"最初の問いが長い(終わりが {first['end']:.1f} 秒。4 秒以内に)")
    return fails, warns


def _overlap(a, b) -> float:
    x0, y0, x1, y1 = max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])
    return max(0.0, x1 - x0) * max(0.0, y1 - y0)


def layout(frame_fn, nf: int) -> tuple[list, list]:
    """全コマ(SAMPLE_FPS 間隔)を描いて、札の重なり・はみ出し・字の縮みを数える。"""
    hits: dict = {}
    step = max(1, FPS // SAMPLE_FPS)
    for fi in range(1, nf + 1, step):
        frame_fn(fi)
        t = (fi - 1) / FPS
        bs = list(ov.BOXES)
        for i, (k, b, s, sc) in enumerate(bs):
            if b[0] < -2 or b[1] < -2 or b[2] > W + 2 or b[3] > H + 2:
                hits.setdefault(("はみ出し", k, s), []).append(t)
            if k == "text" and sc < SHRINK_WARN:
                hits.setdefault(("字が縮む", k, s), []).append(t)
            for k2, b2, s2, _ in bs[i + 1:]:
                if "label" in (k, k2) and _overlap(b, b2) > 0:
                    hits.setdefault(("重なり", s, s2), []).append(t)
    fails, warns = [], []
    for key, ts in hits.items():
        dur = len(ts) / SAMPLE_FPS
        msg = f"{key[0]}「{key[1] if key[0] == '重なり' else key[2]}」" + (f"と「{key[2]}」" if key[0] == "重なり" else "") + f" {ts[0]:.1f}秒〜 計{dur:.1f}秒"
        (warns if key[0] == "字が縮む" or dur < 0.4 else fails).append(msg)
    return fails, warns


def _gray(video: Path) -> np.ndarray:
    w, h = (160, 284) if H > W else (284, 160)
    r = subprocess.run([ffmpeg(), "-loglevel", "error", "-i", str(video), "-vf", f"fps={SAMPLE_FPS},scale={w}:{h}", "-f", "rawvideo", "-pix_fmt", "gray", "-"],
                       capture_output=True, check=True)
    return np.frombuffer(r.stdout, np.uint8).reshape(-1, h, w).astype(np.float32)


def picture(video: Path) -> tuple[list, list, dict]:
    g = _gray(video)
    fails, warns = [], []
    dark = np.where(g.mean(axis=(1, 2)) < 6)[0]
    if len(dark):
        fails.append(f"真っ黒なコマ {len(dark) / SAMPLE_FPS:.1f}秒ぶん({dark[0] / SAMPLE_FPS:.1f}秒〜)")
    diff = np.abs(np.diff(g, axis=0))
    d = diff.mean(axis=(1, 2))
    # 止まっている = 目に見えて変わった画素がほとんど無い(小さな玉が動くだけでも「動いている」に数える)
    still = (diff > 8).mean(axis=(1, 2)) < 0.0004
    run, start = 0, 0
    for i, s in enumerate(list(still) + [False]):
        if s:
            if run == 0:
                start = i
            run += 1
        else:
            sec = run / SAMPLE_FPS
            if sec >= STATIC_FAIL:
                fails.append(f"画面が止まったまま {start / SAMPLE_FPS:.1f}秒〜 {sec:.1f}秒")
            elif sec >= STATIC_WARN:
                warns.append(f"画面がほぼ止まっている {start / SAMPLE_FPS:.1f}秒〜 {sec:.1f}秒")
            run = 0
    cuts = int((d > 12).sum())
    minutes = len(g) / SAMPLE_FPS / 60
    stats = dict(切り替え=cuts, 一分あたり=round(cuts / max(minutes, 1e-6), 1), 動いている割合=round(float((~still).mean()), 2))
    return fails, warns, stats


def sound(video: Path) -> tuple[list, list, dict]:
    r = subprocess.run([ffmpeg(), "-hide_banner", "-i", str(video), "-af", "ebur128=peak=true,silencedetect=noise=-45dB:d=1.5", "-f", "null", "-"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    err = r.stderr
    fails, warns = [], []
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", err)
    lufs = float(m[-1]) if m else None
    p = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", err)
    peak = float(p[-1]) if p else None
    total = None
    mm = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err)
    if mm:
        total = int(mm.group(1)) * 3600 + int(mm.group(2)) * 60 + float(mm.group(3))
    if lufs is None or not (-17 <= lufs <= -12):
        warns.append(f"音量 {lufs} LUFS(-17〜-12 に)")
    if peak is not None and peak > -0.5:
        warns.append(f"ピークが高い {peak} dBFS")
    for s, e in zip(re.findall(r"silence_start: ([\d.]+)", err), re.findall(r"silence_end: ([\d.]+)", err)):
        s, e = float(s), float(e)
        if total and e > total - 2.0:
            continue                                   # 終わりの余韻は数えない
        warns.append(f"無音 {s:.1f}〜{e:.1f}秒({e - s:.1f}秒)")
    return fails, warns, dict(LUFS=lufs, peak=peak)


def sheet(ep: dict, tl: dict, frame_fn, out: Path) -> Path:
    """行ごとに真ん中のコマを 1 枚ずつ並べ、行の id を添える。"""
    tw = 270 if H > W else 480
    th = int(tw * H / W)
    cols = 6 if H > W else 4
    ls = tl["lines"]
    rows = (len(ls) + cols - 1) // cols
    s = Image.new("RGB", (tw * cols, (th + 34) * rows), (20, 20, 24))
    d = ImageDraw.Draw(s)
    for i, l in enumerate(ls):
        fi = int((l["start"] + l["end"]) / 2 * FPS) + 1
        im = frame_fn(fi).resize((tw, th))
        x, y = (i % cols) * tw, (i // cols) * (th + 34)
        s.paste(im, (x, y + 34))
        d.text((x + 8, y + 4), f"{i + 1}. {l['id']}  {l['start']:.1f}s", font=ov.font(22), fill=(230, 230, 230))
    p = out / "qc_sheet.png"
    s.save(p)
    return p


def run(ep: dict, out: Path, kind_mod, name: str) -> bool:
    tl = json.loads((out / "timeline.json").read_text(encoding="utf-8"))
    video = out / f"{name}.mp4"
    if not video.exists():
        raise SystemExit(f"{video} が無い(compose を先に)")
    fr, nf = kind_mod.frame_fn(ep, out)
    F, Wn = [], []
    for f, w in (script(ep, tl), layout(fr, nf)):
        F += f
        Wn += w
    pf, pw, pst = picture(video)
    sf, sw, sst = sound(video)
    F += pf + sf
    Wn += pw + sw
    sh = sheet(ep, tl, fr, out)
    st = video.stat()
    res = dict(passed=not F, at=datetime.now().isoformat(timespec="seconds"), video=video.name, size=st.st_size, mtime=st.st_mtime,
               fails=F, warns=Wn, stats={**pst, **sst, "長さ": round(tl["total"], 1)})
    (out / "qc.json").write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
    md = [f"# 点検 {name}({res['at']})", "", f"結果: {'通過' if res['passed'] else '✖ 通らない'}", "",
          "## ✖ 直すもの", *(f"- {x}" for x in F or ["なし"]), "", "## △ 目で確かめるもの", *(f"- {x}" for x in Wn or ["なし"]), "",
          "## 数字", *(f"- {k}: {v}" for k, v in res["stats"].items()), "", f"行ごとのコマ: {sh.name}"]
    (out / "qc.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print("\n".join(md))
    return res["passed"]


def gate(video: Path) -> None:
    """投稿の前の関門: 点検に通っていて、そのあと動画が変わっていないこと。"""
    q = video.parent / "qc.json"
    if not q.exists():
        raise SystemExit(f"点検していない: python -m naze qc で点検してから投稿する({q})")
    r = json.loads(q.read_text(encoding="utf-8"))
    st = video.stat()
    if r.get("video") != video.name or r.get("size") != st.st_size or abs(r.get("mtime", 0) - st.st_mtime) > 1:
        raise SystemExit("点検のあとで動画が変わっている: 点検し直す")
    if not r.get("passed"):
        raise SystemExit("点検に通っていない:\n" + "\n".join(r.get("fails", [])))
