"""参考チャンネルを測って、こちらと並べる（2026-10-15）。

ユーザー「過去に参考にしてといったものを見て仕組みづくりしたい」。
`config/references.yaml` の台帳を読み、各チャンネルの直近15本（公開RSS）から次を測る。
Data API の枠も Gemini も使わない（RSS と、動画ページ・サムネ画像の取得だけ）。

    python tools/refwatch.py                      # 全チャンネルを測って research/metrics/refwatch_<日付>.md に書く
    python tools/refwatch.py --only crack-football
    python tools/refwatch.py --no-thumbs          # サムネ画像を取らない（速い）

測るもの：再生数の中央値・公開の間隔・尺・題名の型（【】・数字・問い・感嘆）・
サムネの顔（有無と面積）・明るさ・彩度・細かさ。こちらの直近の本も同じ物差しで並べる。

**参考側の画像・文字起こしは、測るためだけに使い、保存しない**（メモリの中で数字にして捨てる）。
RSS は最新15本までしか返さない。クラックフットボールのように1本しか返らないチャンネルもあるので、
本数（n）を必ず一緒に見る。
"""
from __future__ import annotations

import argparse
import datetime
import io
import re
import statistics as st
import sys
import time
from pathlib import Path

import requests
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}
COOKIES = {"CONSENT": "YES+1", "SOCS": "CAI"}
PAUSE = 0.8           # 動画ページを続けて取るときの間隔（秒）
SHORT_MAX = 181       # これ以下はショートとして数える


def channel_id(handle: str) -> str | None:
    r = requests.get(f"https://www.youtube.com/@{handle}", headers=UA, cookies=COOKIES, timeout=30)
    m = re.search(r'"channelId":"(UC[\w-]{22})"', r.text) or re.search(r"channel_id=(UC[\w-]{22})", r.text)
    return m.group(1) if m else None


def feed(cid: str) -> list[dict]:
    r = requests.get(f"https://www.youtube.com/feeds/videos.xml?channel_id={cid}", headers=UA, timeout=30)
    out = []
    for e in re.findall(r"<entry>(.*?)</entry>", r.text, re.S):
        vid = re.search(r"<yt:videoId>([\w-]+)</yt:videoId>", e)
        title = re.search(r"<title>(.*?)</title>", e, re.S)
        pub = re.search(r"<published>(.*?)</published>", e)
        views = re.search(r'views="(\d+)"', e)
        if vid and title and pub:
            out.append({"id": vid.group(1), "title": _unesc(title.group(1)),
                        "published": pub.group(1), "views": int(views.group(1)) if views else None})
    return out


def _unesc(s: str) -> str:
    import html
    return html.unescape(s).strip()


def length_seconds(vid: str) -> int | None:
    try:
        r = requests.get(f"https://www.youtube.com/watch?v={vid}", headers=UA, cookies=COOKIES, timeout=30)
        m = re.search(r'"lengthSeconds":"(\d+)"', r.text)
        return int(m.group(1)) if m else None
    except requests.RequestException:
        return None


# ---- 題名の型 -------------------------------------------------------------

def title_features(title: str) -> dict:
    t = re.sub(r"\s*[#＃]\S+", "", title).strip()          # ハッシュタグは数えない
    return {
        "len": len(t),
        "bracket_head": t.startswith(("【", "[", "「")) and "】" in t[:14],
        "number": bool(re.search(r"\d|[一二三四五六七八九十]選|BEST|ベスト", t)),
        "question": bool(re.search(r"[？?]|なぜ|とは|どう|何|だろうか|のか", t)),
        "exclaim": bool(re.search(r"[！!]|ヤバ|衝撃|激震|騒然|悲報|朗報", t)),
        "ellipsis": "…" in t or "..." in t,
    }


# ---- サムネの特徴（メモリの中だけで測る） -----------------------------------

def thumb_features(img) -> dict:
    import numpy as np
    from src import faces
    rgb = img.convert("RGB")
    a = np.asarray(rgb).astype("float32") / 255.0
    mx, mn = a.max(axis=2), a.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    gray = a.mean(axis=2)
    gy, gx = np.gradient(gray)
    edge = float((np.hypot(gx, gy) > 0.12).mean())          # 細かさ（文字や輪郭の多さの目安）
    w, h = rgb.size
    fs = faces.find_faces(rgb) if faces.available() else []
    area = sum(b[2] * b[3] for b in fs[:3]) / (w * h) if fs else 0.0
    return {"bright": float(gray.mean()), "sat": float(sat.mean()), "edge": edge,
            "face": bool(fs), "face_area": area}


def fetch_thumb(vid: str):
    from PIL import Image
    for name in ("maxresdefault", "hqdefault"):
        r = requests.get(f"https://i.ytimg.com/vi/{vid}/{name}.jpg", headers=UA, timeout=30)
        if r.status_code == 200 and len(r.content) > 5000:
            return Image.open(io.BytesIO(r.content))
    return None


# ---- 集計 -----------------------------------------------------------------

def _med(xs):
    xs = [x for x in xs if x is not None]
    return st.median(xs) if xs else None


def _pct(xs):
    return 100 * sum(1 for x in xs if x) / len(xs) if xs else None


def summarize(videos: list[dict]) -> dict:
    pubs = sorted(datetime.datetime.fromisoformat(v["published"]) for v in videos if v.get("published"))
    gaps = [(b - a).total_seconds() / 3600 for a, b in zip(pubs, pubs[1:])]
    feats = [title_features(v["title"]) for v in videos]
    th = [v["thumb"] for v in videos if v.get("thumb")]
    return {
        "n": len(videos),
        "views": _med([v.get("views") for v in videos]),
        "gap_h": _med(gaps),
        "dur": _med([v.get("dur") for v in videos]),
        "short_pct": _pct([(v.get("dur") or 9999) <= SHORT_MAX for v in videos if v.get("dur")]),
        "t_len": _med([f["len"] for f in feats]),
        "bracket": _pct([f["bracket_head"] for f in feats]),
        "number": _pct([f["number"] for f in feats]),
        "question": _pct([f["question"] for f in feats]),
        "exclaim": _pct([f["exclaim"] for f in feats]),
        "face": _pct([t["face"] for t in th]),
        "face_area": _med([t["face_area"] for t in th if t["face"]]),
        "bright": _med([t["bright"] for t in th]),
        "sat": _med([t["sat"] for t in th]),
        "edge": _med([t["edge"] for t in th]),
        "n_thumb": len(th),
    }


def measure_channel(ch: dict, thumbs: bool) -> dict:
    cid = channel_id(ch["handle"])
    vids = feed(cid) if cid else []
    for v in vids:
        v["dur"] = length_seconds(v["id"])
        time.sleep(PAUSE)
        if thumbs:
            try:
                im = fetch_thumb(v["id"])
                v["thumb"] = thumb_features(im) if im else None
            except Exception:
                v["thumb"] = None
    return {"meta": ch, "cid": cid, "videos": vids, "sum": summarize(vids)}


def measure_ours(thumbs: bool) -> dict:
    """こちらの直近の本（scripts の題と、output の thumbnail.png）。"""
    import json
    posted = json.load(open(ROOT / "research" / "posted.json", encoding="utf-8"))
    since = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=14)).isoformat()
    recent = [e for e in posted if e.get("at", "") >= since]
    vids = []
    for e in recent:
        b = e["build"]
        base = b[:-6] if b.endswith("_short") else b
        md = ROOT / "scripts" / f"{base}.md"
        title = ""
        if md.exists():
            m = re.search(r"^title:\s*(.+)$", md.read_text(encoding="utf-8"), re.M)
            title = m.group(1).strip().strip("'\"") if m else ""
        v = {"id": e["video_id"], "title": title, "published": (e.get("publish_at") or e["at"]).replace("Z", "+00:00"),
             "views": None, "dur": None, "short": b.endswith("_short"), "thumb": None}
        p = ROOT / "output" / b / "thumbnail.png"
        if thumbs and p.exists():
            from PIL import Image
            try:
                v["thumb"] = thumb_features(Image.open(p))
            except Exception:
                pass
        if title:
            vids.append(v)
    out = {}
    for label, sel in (("本編", [v for v in vids if not v["short"]]), ("ショート", [v for v in vids if v["short"]])):
        out[label] = summarize(sel)
    return out


# ---- 出力 -----------------------------------------------------------------

def _f(x, nd=0, suf=""):
    return "—" if x is None else (f"{x:,.{nd}f}{suf}")


def render(results: list[dict], ours: dict, day: str) -> str:
    L = [f"# 参考チャンネルとの比較（{day}）", "",
         "RSS は最新15本まで。**n が小さいチャンネルは数字を信じすぎない**。"
         "再生数は公開からの経過がそろっていないので、チャンネル同士の大小は目安。", "",
         "## ① 数字の比較", "",
         "| チャンネル | 役 | n | 再生中央 | 間隔(h) | 尺(秒) | ショート% | 題の字数 | 【】頭% | 数字% | 問い% | 感嘆% |",
         "|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|"]
    for r in results:
        s = r["sum"]
        L.append(f"| {r['meta']['name']} | {r['meta']['role']} | {s['n']} | {_f(s['views'])} | {_f(s['gap_h'], 1)} | "
                 f"{_f(s['dur'])} | {_f(s['short_pct'])} | {_f(s['t_len'])} | {_f(s['bracket'])} | {_f(s['number'])} | "
                 f"{_f(s['question'])} | {_f(s['exclaim'])} |")
    for label, s in ours.items():
        L.append(f"| **こちら（{label}・直近14日）** | — | {s['n']} | — | {_f(s['gap_h'], 1)} | — | — | {_f(s['t_len'])} | "
                 f"{_f(s['bracket'])} | {_f(s['number'])} | {_f(s['question'])} | {_f(s['exclaim'])} |")
    L += ["", "## ② サムネの特徴", "",
          "顔は OpenCV の検出（見逃しあり）。面積は画面に対する割合（顔が写るサムネだけの中央値）。"
          "明るさ・彩度は 0〜1、細かさは輪郭の多さ（文字が多いほど高い）。", "",
          "| チャンネル | 画像n | 顔あり% | 顔の面積% | 明るさ | 彩度 | 細かさ |", "|---|--:|--:|--:|--:|--:|--:|"]
    for r in results:
        s = r["sum"]
        L.append(f"| {r['meta']['name']} | {s['n_thumb']} | {_f(s['face'])} | "
                 f"{_f(None if s['face_area'] is None else s['face_area'] * 100, 1)} | {_f(s['bright'], 2)} | "
                 f"{_f(s['sat'], 2)} | {_f(s['edge'], 3)} |")
    for label, s in ours.items():
        L.append(f"| **こちら（{label}）** | {s['n_thumb']} | {_f(s['face'])} | "
                 f"{_f(None if s['face_area'] is None else s['face_area'] * 100, 1)} | {_f(s['bright'], 2)} | "
                 f"{_f(s['sat'], 2)} | {_f(s['edge'], 3)} |")
    L += ["", "## ③ 各チャンネルの直近の題名（上位の再生順）", ""]
    for r in results:
        L.append(f"### {r['meta']['name']}（{r['meta']['note']}）")
        top = sorted([v for v in r["videos"] if v.get("views") is not None], key=lambda v: -v["views"])[:5]
        for v in top:
            d = f"{v['dur']}秒" if v.get("dur") else "?"
            L.append(f"- {v['views']:,}回 / {d} / {v['title'][:70]}")
        L.append("")
    L += ["## 読み方の注意", "",
          "- 比べて差が大きい項目は、**題名の型**（【】頭・数字・問い）と**サムネの顔の面積・細かさ**。",
          "  差があっても、それが再生の差の原因とは限らない（登録者数・配られる量が違う）",
          "- 決まり（人名頭・答えを言い切らない・札を頭に置かない 等）と衝突する型は採らない",
          ""]
    return "\n".join(L)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="ハンドルを1つだけ")
    ap.add_argument("--no-thumbs", action="store_true", help="サムネ画像を取らない")
    ap.add_argument("--out", help="出力先（既定: research/metrics/refwatch_<日付>.md）")
    a = ap.parse_args()
    cfg = yaml.safe_load(open(ROOT / "config" / "references.yaml", encoding="utf-8"))
    chans = [c for c in cfg["channels"] if not a.only or c["handle"] == a.only]
    results = []
    for c in chans:
        print(f"測る: {c['name']} (@{c['handle']})", flush=True)
        results.append(measure_channel(c, thumbs=not a.no_thumbs))
    ours = measure_ours(thumbs=not a.no_thumbs)
    day = datetime.date.today().isoformat()
    text = render(results, ours, day)
    out = Path(a.out) if a.out else ROOT / "research" / "metrics" / f"refwatch_{day.replace('-', '')}.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"書いた: {out}")


if __name__ == "__main__":
    main()
