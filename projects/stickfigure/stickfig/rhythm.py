# -*- coding: utf-8 -*-
"""動画のリズムを数字にする(カットの長さ・同じ絵を続ける割合・画面の揺れ・閃光)。参考のアニメ戦闘6本と比べる物差し。

  python -m stickfig rhythm <動画>            # 参考の範囲と比べて、外れた指標を出す
元動画は他人の著作物。測った数字(`REFERENCE`)だけを残す(動画・切り出した画像はリポジトリに入れない)。
"""
import json
import subprocess
import sys

import numpy as np
import imageio_ffmpeg

W, H = 320, 180
FF = imageio_ffmpeg.get_ffmpeg_exe()


def frames(path):
    p = subprocess.Popen([FF, "-v", "error", "-i", path, "-vf", f"scale={W}:{H}", "-pix_fmt", "rgb24", "-f", "rawvideo", "-"], stdout=subprocess.PIPE)
    n = W * H * 3
    while True:
        b = p.stdout.read(n)
        if len(b) < n:
            break
        yield np.frombuffer(b, dtype=np.uint8).reshape(H, W, 3)


def fps_of(path):
    import re
    p = subprocess.run([FF, "-i", path], capture_output=True, text=True)
    m = re.search(r"(\d+(?:\.\d+)?) fps", p.stderr)
    return float(m.group(1)) if m else 30.0


def main(path):
    fps = fps_of(path)
    prev = None
    rows = []          # (diff, brightness, sat, shift_x, shift_y)
    for i, f in enumerate(frames(path)):
        g = f.astype(np.float32).mean(axis=2)
        mx, mn = f.max(axis=2).astype(np.float32), f.min(axis=2).astype(np.float32)
        sat = float(((mx - mn) / (mx + 1e-3)).mean())
        br = float(g.mean())
        if prev is None:
            rows.append((0.0, br, sat, 0.0, 0.0))
        else:
            diff = float(np.abs(g - prev).mean())
            sx = sy = 0.0
            if diff < 20:           # 同じカットの中だけ、画面全体の平行移動(カメラの揺れ・パン)を測る
                A = np.fft.fft2(prev[::2, ::2] - prev.mean())
                B = np.fft.fft2(g[::2, ::2] - g.mean())
                R = A * np.conj(B)
                R /= np.abs(R) + 1e-9
                c = np.fft.ifft2(R).real
                iy, ix = np.unravel_index(np.argmax(c), c.shape)
                sy = (iy if iy < c.shape[0] // 2 else iy - c.shape[0]) * 2
                sx = (ix if ix < c.shape[1] // 2 else ix - c.shape[1]) * 2
            rows.append((diff, br, sat, float(sx), float(sy)))
        prev = g
    a = np.array(rows)
    n = len(a)
    diff, br, sat, sx, sy = a.T
    # カット(大きな変化)
    cuts = []
    last = -10
    for i in range(1, n):
        if diff[i] > 22 and i - last > 2 and abs(br[i] - br[i - 1]) < 60:
            cuts.append(i)
            last = i
    lens = np.diff([0] + cuts + [n]) / fps
    # 閃光(明るさが大きく跳ねる/落ちる)
    flash = [i for i in range(1, n) if abs(br[i] - br[i - 1]) > 35]
    flash_groups = []
    for i in flash:
        if not flash_groups or i - flash_groups[-1][-1] > 3:
            flash_groups.append([i])
        else:
            flash_groups[-1].append(i)
    # 同じ絵を続ける割合(カット以外で、変化がほぼ無いコマ)
    mask = np.ones(n, bool)
    for c in cuts:
        mask[max(0, c - 1): c + 2] = False
    dup = (diff < 0.6) & mask
    # 2コマ撮り/3コマ撮りの判定: 動いている区間で、同じ絵が何コマ続くか
    run_lengths = []
    cur = 0
    for i in range(1, n):
        if dup[i] and diff[max(0, i - 6): i + 6].mean() > 1.5:       # 周りは動いているのに、このコマだけ同じ
            cur += 1
        else:
            if cur:
                run_lengths.append(cur + 1)
            cur = 0
    # 画面の揺れ
    mag = np.hypot(sx, sy)
    shake_frames = int((mag > 3).sum())
    return dict(
        fps=fps, frames=n, seconds=round(n / fps, 1),
        cuts=len(cuts), cuts_per_min=round(len(cuts) / (n / fps / 60), 1),
        shot_len_median=round(float(np.median(lens)), 2), shot_len_p25=round(float(np.percentile(lens, 25)), 2),
        shot_len_p10=round(float(np.percentile(lens, 10)), 2), short_shots_under_0_5s=round(float((lens < 0.5).mean()), 2),
        dup_frame_ratio=round(float(dup.sum() / max(1, mask.sum())), 3),
        hold_run_median=float(np.median(run_lengths)) if run_lengths else 0, hold_run_count=len(run_lengths),
        flash_groups_per_min=round(len(flash_groups) / (n / fps / 60), 1),
        flash_len_median=float(np.median([len(g) for g in flash_groups])) if flash_groups else 0,
        shake_frame_ratio=round(shake_frames / n, 3), shake_amp_p90=round(float(np.percentile(mag[mag > 3], 90)), 1) if shake_frames else 0,
        motion_mean=round(float(diff.mean()), 2), sat_mean=round(float(sat.mean()), 3), contrast=round(float(np.std(br)), 1))


# 参考6本(2026-10-19 実測)の範囲。reference/anime_rhythm.md と同じ数字
REFERENCE = {
    "cuts_per_min": (116, 258, "カット数/分(山場は短いカットの連打)"),
    "shot_len_median": (0.10, 0.20, "カット長の中央値(秒)"),
    "dup_frame_ratio": (0.17, 0.33, "同じ絵を続けるコマの割合(2コマ撮り)"),
    "flash_groups_per_min": (17, 41, "閃光(明るさの跳ね)/分"),
    "shake_frame_ratio": (0.03, 0.17, "画面が揺れているコマの割合"),
}


def compare(path: str) -> dict:
    """動画を測り、参考の範囲に対して 低い/範囲内/高い を返す。"""
    m = main(path)
    rows = []
    for k, (lo, hi, label) in REFERENCE.items():
        v = m[k]
        st = "範囲内" if lo <= v <= hi else ("低い" if v < lo else "高い")
        rows.append(dict(key=k, label=label, value=v, lo=lo, hi=hi, status=st))
    return dict(metrics=m, rows=rows, ok=all(r["status"] == "範囲内" for r in rows))


def report(path: str) -> str:
    r = compare(path)
    out = [f"# リズムの比較: {path}", "", "| 指標 | 値 | 参考の範囲 | 判定 |", "|---|---|---|---|"]
    for x in r["rows"]:
        out.append(f"| {x['label']} | {x['value']} | {x['lo']}〜{x['hi']} | {x['status']} |")
    return chr(10).join(out)


if __name__ == "__main__":
    print(report(sys.argv[1]))


# ---- plan(計算結果)から、書き出す前に見積もる(数秒。動画を作らずに、リズムの外れを知る) ----
def plan_metrics(plan: dict) -> dict:
    fr = plan["frames"]
    n, fps = len(fr), plan["fps"]
    minutes = n / fps / 60
    cuts, prev = 0, None
    for f in fr:
        c = f["cam"]
        key = (c.get("yaw", 0.0), c.get("scale", 1.0), c.get("x", 0.0), f.get("look"))
        if prev is not None:
            dyaw = abs(key[0] - prev[0])
            ratio = max(key[1], prev[1]) / max(1e-6, min(key[1], prev[1]))
            dx = abs(key[2] - prev[2]) / max(1e-6, prev[1])
            if dyaw > 8 or ratio > 1.3 or dx > 0.35 or key[3] != prev[3]:
                cuts += 1
        prev = key
    dup = 0
    for i in range(1, n):
        if fr[i]["cam"] is fr[i - 1]["cam"] or fr[i]["cam"] == fr[i - 1]["cam"]:
            if any(fr[i]["actors"][w].get("stepped") for w in fr[i]["actors"]):
                dup += 1
    flashes = len(plan.get("scene", {}).get("fx", {}).get("flashes", []))
    inv = set(plan.get("scene", {}).get("fx", {}).get("invert", ["kick", "heel"]))
    flashes += sum(1 for e in plan["events"] if e["kind"] in inv or e["kind"] == "wall")
    shake_kinds = {"kick", "slash", "wall", "heel", "hit"}
    shaken = set()
    for e in plan["events"]:
        if e["kind"] in shake_kinds:
            shaken.update(range(e["frame"], min(n, e["frame"] + 6)))
    return {"cuts_per_min": round(cuts / minutes, 1), "dup_frame_ratio": round(dup / max(1, n), 3),
            "flash_groups_per_min": round(flashes / minutes, 1), "shake_frame_ratio": round(len(shaken) / max(1, n), 3)}


def plan_report(plan: dict) -> str:
    m = plan_metrics(plan)
    out = ["## 演出のリズム(見積もり。動画を作る前の目安。参考6本の範囲と比べる)", ""]
    for k, v in m.items():
        lo, hi, label = REFERENCE[k]
        st = "範囲内" if lo <= v <= hi else ("低い→足す" if v < lo else "高い→減らす")
        out.append(f"- {label}: {v}(参考 {lo}〜{hi}) {st}")
    return chr(10).join(out)
