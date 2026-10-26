"""地形の回(kind: terrain)を、題材の設定(episodes/<名前>/ep.py の EP)から作る。

EP の主な項目:
  title, header(画面上の見出し), bbox=(西経度, 南緯度, 東経度, 北緯度), exag(高さの強調), stops(色の段。無ければ terrain.STOPS)
  points={名前: (経度, 緯度)}
  lines=[{id, text, say?, sub?, pause?, style?: question|end, labels?: [{point, text, color, at(0〜1), below?}]}]
  shots=[{line, a:{look, dist, height, yaw}, b:{...}}]   look は地点の名前か [x, y](km)。yaw は度(0 = 南から北を見る、90 = 東から西を見る)
  rise=行 id(この行で平らな地図から立ち上がる。無ければ最初から立体)
  pins=[{point, text}] を EP に置くと、問いと結び以外の間、地形の上に小さな地名を常に出す(本編向き)
  行に panel={kind: big|quote|image|bars|steps, ...} を付けると図の枠が出る(mapscene.draw_panel)。dem_z で標高タイルの細かさ(広い山は 12)
  行に compare={value, unit, n, note?, at} を付けると、数字を身近なものに換える図(箱を n 個並べる)が出る
  行に profile={a: 地点, b: 地点, at: 0〜1, names: [a の名, b の名]} を付けると、その行で a→b に地形を切った断面図が出る(地形の上に切り線も)
"""
from __future__ import annotations

import json
import math
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from . import chart, compose, dem as demmod, overlay as ov, sfx, terrain, tts
from .config import FPS, H, LAYOUT, W, blender

TR = 12          # カットの切り替えにかけるコマ数


def _paths(out: Path):
    return dict(timeline=out / "timeline.json", job=out / "job.json", tex=out / "tex.png", height=out / "height.npy", proj=out / "proj.json")


def kana(ep: dict) -> None:
    for s in tts.kana(ep["lines"]):
        print(s)


def voice(ep: dict, out: Path) -> dict:
    tl = tts.synth(ep["lines"], out)
    _paths(out)["timeline"].write_text(json.dumps(tl, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"語り {tl['total']:.1f} 秒")
    return tl


def prep(ep: dict, out: Path) -> dict:
    p = _paths(out)
    d = demmod.load(*ep["bbox"], z=ep.get("dem_z", 14))
    terrain.texture(d, ep.get("stops", terrain.STOPS), **ep.get("tex_opts", {})).save(p["tex"])
    np.save(p["height"], terrain.heights(d))
    pts = terrain.points(d, ep["points"], ep["exag"])
    Wkm, Hkm = d.size_km
    tl = json.loads(p["timeline"].read_text(encoding="utf-8"))
    nf = int(math.ceil(tl["total"] * FPS))
    L = {l["id"]: l for l in tl["lines"]}

    def pos(look):
        if isinstance(look, str):
            return pts[look]["pos"]
        return [look[0], look[1], look[2] if len(look) > 2 else 0.0]

    def cam_of(s):
        t = pos(s["look"])
        yaw = math.radians(s.get("yaw", 0))
        d_ = s["dist"]
        return [t[0] + math.sin(yaw) * d_, t[1] - math.cos(yaw) * d_, t[2] + s["height"]], [t[0], t[1], t[2] + s.get("tz", 0.0)]

    shots = ep["shots"]
    starts = [1] + [max(1, int(round(L[s["line"]]["start"] * FPS)) + 1) for s in shots[1:]]
    ends = starts[1:] + [nf]
    keys = []
    for i, s in enumerate(shots):
        a, b = starts[i], ends[i]
        a2 = a if i == 0 else min(b - 1, a + TR)
        for fr, side in ((a2, "a"), (b, "b")):
            c, t = cam_of(s[side])
            keys.append(dict(frame=fr, cam=c, tgt=t))
    rise = None
    if ep.get("rise"):
        l = L[ep["rise"]]
        rise = [int(l["start"] * FPS) + 1, max(int(l["start"] * FPS) + 2, int(l["end"] * FPS) - 10)]
    job = dict(height=str(p["height"]), tex=str(p["tex"]), Wkm=Wkm, Hkm=Hkm, exag=ep["exag"], fps=FPS, frames=nf, lens=ep.get("lens", 28), size=[W, H],
               keys=keys, rise=rise, points={k: v["pos"] for k, v in pts.items()}, heights={k: v["h"] for k, v in pts.items()}, out=str(out))
    text = json.dumps(job, ensure_ascii=False, indent=1)
    # 書き出しは途中から再開できる(できたコマは描き直さない)。設定が変わったら古いコマは捨てる
    if p["job"].exists() and p["job"].read_text(encoding="utf-8") != text and (out / "frames").exists():
        for f in (out / "frames").glob("f_*.png"):
            f.unlink()
    p["job"].write_text(text, encoding="utf-8")
    print(f"範囲 {Wkm:.1f}×{Hkm:.1f} km、コマ {nf}、地点の標高", {k: v["h"] for k, v in pts.items()})
    return job


def render(out: Path, frames: str = "all") -> None:
    (out / "frames").mkdir(exist_ok=True)
    for f in (out / "frames").glob("f_*.png"):
        if f.stat().st_size == 0:           # 途中で止まったコマの置き場所(空のファイル)は描き直す
            f.unlink()
    (out / "stills").mkdir(exist_ok=True)
    script = Path(__file__).with_name("blender_terrain.py")
    r = subprocess.run([blender(), "-b", "-P", str(script), "--", str(_paths(out)["job"]), frames], capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-3000:], r.stderr[-3000:])
        raise SystemExit("Blender が失敗した")


def frame_fn(ep: dict, out: Path, still: bool = False):
    p = _paths(out)
    tl = json.loads(p["timeline"].read_text(encoding="utf-8"))
    proj = json.loads(p["proj"].read_text())
    job = json.loads(p["job"].read_text(encoding="utf-8"))
    lines = tl["lines"]
    defs = {l["id"]: l for l in ep["lines"]}
    profiles = _profiles(ep)

    def frame(fi: int) -> Image.Image:
        t = (fi - 1) / FPS
        ov.BOXES.clear()
        src = out / ("stills" if still else "frames") / (f"s_{fi:04d}.png" if still else f"f_{fi:04d}.png")
        img = Image.open(src).convert("RGBA")
        dr = ImageDraw.Draw(img)
        cur = ov.current(lines, t)
        d = defs[cur["id"]] if cur else {}
        ov.corner(dr, "出典：国土地理院（標高タイル・空中写真）" if ep.get("tex_opts", {}).get("photo") else "出典：国土地理院（標高タイル）", f"高さは{ep['exag']:g}倍に強調")
        style = d.get("style")
        if style not in ("question", "end", "cta") and ep.get("header"):
            ov.rows(dr, ep["header"], *LAYOUT["header"], stroke=6)
        row = proj[str(fi)]
        if style not in ("question", "end", "cta"):
            for pn in ep.get("pins", []):
                x, y, z = row[pn["point"]]
                if z > 0 and 0.02 < x < 0.9 and 0.12 < y < 0.9:
                    ov.pin(img, x * W, y * H, pn["text"])
        # 比べの図・断面図が出ている間、その箱にかかる札は出さない(重なるので)
        panels = []
        for key, lay in (("compare", "compare"), ("profile", "profile")):
            if d.get(key) and cur and t >= cur["start"] + d[key].get("at", 0.0) * (cur["end"] - cur["start"]):
                panels.append(LAYOUT[lay])
        if d.get("panel") and cur and t >= cur["start"] + d["panel"].get("at", 0.0) * (cur["end"] - cur["start"]):
            from . import mapscene
            panels.append(mapscene._box(d["panel"]))
        def in_panel(px, py):
            return any(bx0 - 20 <= px <= bx1 + 20 and by0 - 130 <= py <= by1 + 90 for bx0, by0, bx1, by1 in panels)
        for lb in d.get("labels", []):
            t0 = cur["start"] + lb.get("at", 0.0) * (cur["end"] - cur["start"])
            a = min(1.0, max(0.0, (t - t0) * FPS / 8))
            x, y, z = row[lb["point"]]
            if in_panel(x * W, y * H):
                continue
            if z > 0 and 0.02 < x < 0.98 and 0.12 < y < 0.95:
                ov.label(img, x * W, y * H, lb["text"].format(h=job["heights"].get(lb["point"]) or 0), lb.get("color", ov.WHITE), a, lb.get("below", False))
        if d.get("panel") and cur and style not in ("question", "end", "cta"):
            from . import mapscene
            P = d["panel"]
            t0 = cur["start"] + P.get("at", 0.0) * (cur["end"] - cur["start"])
            if t >= t0:
                mapscene.draw_panel(img, P, min(1.0, (t - t0) / 0.4), min(1.0, (t - t0) / max(0.4, P.get("grow", 1.2))))
        if d.get("compare") and cur:
            cp = d["compare"]
            t0 = cur["start"] + cp.get("at", 0.0) * (cur["end"] - cur["start"])
            if t >= t0:
                ov.compare(img, min(1.0, (t - t0) / 1.6), cp, LAYOUT["compare"])
        if d.get("profile") and cur:
            pr = d["profile"]
            t0 = cur["start"] + pr.get("at", 0.0) * (cur["end"] - cur["start"])
            if t >= t0:
                _draw_profile(img, row, profiles[cur["id"]], pr, min(1.0, (t - t0) / 1.4))
        dr = ImageDraw.Draw(img)
        sub = d.get("sub") or ov.auto_sub(d.get("text", ""), LAYOUT["sub"][1], LAYOUT["maxw"])
        if style == "question":
            ov.rows(dr, sub, *LAYOUT["question"], stroke=10)
        elif style == "end":
            a = min(1.0, (t - cur["start"]) * FPS / 10)
            ov.band(img, *LAYOUT["end_band"], 0.75 * a)
            dr = ImageDraw.Draw(img)
            ov.rows(dr, sub, *LAYOUT["end_text"], stroke=10)
        elif style == "cta":
            ov.cta(img, t - cur["start"], LAYOUT["end_band"])
        elif cur:
            ov.rows(dr, ov.page_of(sub, t, cur["start"], cur["end"]), *LAYOUT["sub"])
        return img.convert("RGB")

    return frame, int(job["frames"])


def _profiles(ep: dict) -> dict:
    """profile を持つ行ごとに、a→b を 240 等分した標高(m)と長さ(km)。"""
    res = {}
    need = [d for d in ep["lines"] if d.get("profile")]
    if not need:
        return res
    d = demmod.load(*ep["bbox"], z=ep.get("dem_z", 14))
    h = terrain.clean(d)
    for ln in need:
        pr = ln["profile"]
        (lon0, lat0), (lon1, lat1) = ep["points"][pr["a"]], ep["points"][pr["b"]]
        n = 240
        hs = []
        for i in range(n + 1):
            px, py = d.pixel(lon0 + (lon1 - lon0) * i / n, lat0 + (lat1 - lat0) * i / n)
            x, y = min(h.shape[1] - 1, max(0, int(px))), min(h.shape[0] - 1, max(0, int(py)))
            hs.append(max(0.0, float(h[y, x])))
        (ax, ay), (bx, by) = d.pixel(lon0, lat0), d.pixel(lon1, lat1)
        res[ln["id"]] = dict(h=hs, km=math.hypot(bx - ax, by - ay) * d.mpp / 1000)
    return res


def _draw_profile(img: Image.Image, row: dict, data: dict, pr: dict, k: float) -> None:
    """地形の上に切り線、下に断面のグラフ。k は 0〜1 で線とグラフが伸びる。"""
    a, b = row[pr["a"]], row[pr["b"]]
    ovl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ovl)
    if a[2] > 0 and b[2] > 0:
        x0, y0, x1, y1 = a[0] * W, a[1] * H, b[0] * W, b[1] * H
        L = math.hypot(x1 - x0, y1 - y0)
        for s in range(0, int(L * k), 26):
            f0, f1 = s / L, min(L * k, s + 14) / L
            od.line([(x0 + (x1 - x0) * f0, y0 + (y1 - y0) * f0), (x0 + (x1 - x0) * f1, y0 + (y1 - y0) * f1)], fill=(255, 255, 255, 230), width=5)
    bx0, by0, bx1, by1 = LAYOUT["profile"]
    od.rounded_rectangle([bx0, by0, bx1, by1], 18, fill=ov.NAVY + (int(215 * min(1.0, k * 3)),), outline=(255, 255, 255, 120), width=2)
    img.alpha_composite(ovl)
    dr = ImageDraw.Draw(img)
    hs, km = data["h"], data["km"]
    top = max(50.0, math.ceil(max(hs) / 50.0) * 50.0)
    ax = chart.Axes(bx0 + 110, by0 + 56, bx1 - 40, by1 - 70, (0, km), (0, top))
    yt = [0, top / 2, top]
    xt = [0, round(km / 2, 1), round(km, 1)]
    ax.frame(dr, xt, yt, "", "標高 m（横は km）")
    pts = [(km * i / (len(hs) - 1), v) for i, v in enumerate(hs)]
    n = max(2, int(len(pts) * k))
    poly = [ax.px(x, y) for x, y in pts[:n]]
    fill = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(fill).polygon(poly + [ax.px(pts[n - 1][0], 0), ax.px(0, 0)], fill=ov.OCHRE + (90,))
    img.alpha_composite(fill)
    dr = ImageDraw.Draw(img)
    ax.curve(dr, pts, ov.OCHRE, width=6, upto=k)
    names = pr.get("names")
    if names:
        f = ov.font(34)
        dr.text((bx0 + 110, by1 - 40), names[0], font=f, fill=ov.WHITE)
        dr.text((bx1 - 40 - f.getlength(names[1]), by1 - 40), names[1], font=f, fill=ov.WHITE)
    ov.BOXES.append(("label", (bx0, by0, bx1, by1), "断面図", 1.0))


def stills(ep: dict, out: Path, frames: str) -> list:
    """確認用: 指定のコマだけ Blender で描いて、字幕と札を重ねた PNG を out/check に書く。"""
    render(out, frames)
    fr, _ = frame_fn(ep, out, still=True)
    (out / "check").mkdir(exist_ok=True)
    res = []
    for f in [int(x) for x in frames.split(",")]:
        q = out / "check" / f"c_{f:04d}.png"
        fr(f).save(q)
        res.append(q)
    return res


def sfx_events(ep: dict, out: Path) -> list:
    """カットの切り替え(2 つ目以降のカットの頭)に「シュッ」、札が出る瞬間に「ポン」。"""
    L = {l["id"]: l for l in json.loads(_paths(out)["timeline"].read_text(encoding="utf-8"))["lines"]}
    ev = [(L[s["line"]]["start"], "whoosh") for s in ep["shots"][1:]]
    for d in ep["lines"]:
        l = L[d["id"]]
        ev += [(l["start"] + lb.get("at", 0.0) * (l["end"] - l["start"]), "pop") for lb in d.get("labels", [])]
    return ev


def final(ep: dict, out: Path, name: str) -> Path:
    fr, n = frame_fn(ep, out)
    audio = sfx.mix(out / "narration.wav", sfx_events(ep, out), out / "narration_sfx.wav") if ep.get("sfx", True) else out / "narration.wav"
    return compose.write(fr, n, audio, out / f"{name}.mp4", bgm=ep.get("bgm"))
