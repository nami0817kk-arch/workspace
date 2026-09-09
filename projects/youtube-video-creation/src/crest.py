"""クラブのエンブレムを小さく添えるための置き場。

**権利は晴れていない**（2026-09-08 ユーザー判断で、危険を引き受けて使う）。
Openclipart などに上がっているエンブレムは、なぞって上げた人が CC0 を
付けているだけで、**その人にクラブの商標を解放する権利は無い。**
Google 画像検索の「クリエイティブ・コモンズ」絞り込みも、サイトの主張を
見ているだけで元の権利までは見ていない。

だから使い方を絞る。**クラブ名の札の横に小さく添えるだけ**で、
サムネの主役にしない。クラブが認めているようにも見せない。
"""

from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path

CREST_DIR = Path("assets/crests")
# 札の高さに合わせる。**これ以上大きくしない**（主役にしないため）
# **大きくした**（2026-09-09 ユーザー指示「クラブロゴは大きく」）。
# 44px は一覧に並べたとき何のクラブか判別できなかった。
# 2026-09-09 にさらに「もっと大きく、左に」と指示があり 210px へ。
# 「小さく添えるだけ」の決まりは同じ日に取り消してある
CREST_PX = 300


def slug(club: str) -> str:
    """クラブ名からファイル名を作る。表記ゆれを吸収する。"""
    s = unicodedata.normalize("NFKC", club or "").strip()
    s = re.sub(r"[\s・･/\:*?\"<>|]", "", s)
    return s


def path_for(club: str, root: Path | None = None) -> Path:
    base = (root or Path(".")) / CREST_DIR
    return base / f"{slug(club)}.png"


def find(club: str, root: Path | None = None) -> Path | None:
    """そのクラブのエンブレムがあれば返す。無ければ None。"""
    p = path_for(club, root)
    return p if p.exists() else None


def save(club: str, image_bytes: bytes, source_url: str,
         root: Path | None = None) -> Path:
    """エンブレムを置く。**どこから取ったかを必ず控える。**

    権利が晴れていない以上、あとから「どれを消すか」を選べる必要がある。
    """
    from io import BytesIO

    from PIL import Image

    out = path_for(club, root)
    out.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(BytesIO(image_bytes)).convert("RGBA")
    ratio = CREST_PX * 3 / max(im.width, im.height)   # 3倍で持っておく
    im = im.resize((max(1, int(im.width * ratio)), max(1, int(im.height * ratio))),
                   Image.LANCZOS)
    im.save(out)

    ledger = out.parent / "credits.json"
    rows = []
    if ledger.exists():
        try:
            rows = json.loads(ledger.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            rows = []
    rows = [r for r in rows if r.get("club") != club]
    rows.append({"club": club, "file": out.name, "source": source_url,
                 "note": "権利は晴れていない。小さく添えるだけ"})
    ledger.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
    return out


# ---------------------------------------------------------------- 取ってくる

UA = "kaigai-soccer-video/1.0"
# エンブレムらしいファイル名。**Commons-logo などの飾りを外す**
CREST_WORDS = ("crest", "badge", "escut", "escudo", "logo")
NOT_CREST = ("commons-logo", "wikidata", "wiki", "folder", "sound", "edit",
             "symbol_", "flag_of", "question",
             # 順位の推移グラフを掴んだ（2026-09-08 実測）
             "performance", "league table", "kit ")


def _session():
    import requests

    s = requests.Session()
    s.headers["User-Agent"] = UA
    return s


def _api(session, params: dict, tries: int = 4) -> dict:
    """MediaWiki の API を叩く。**たまに JSON でないものが返る**（実測）。

    立て続けに叩くと、HTML のエラーページが返ってくることがある。
    そのまま .json() すると落ちるので、少し待って試し直す。
    """
    import time

    for attempt in range(tries):
        try:
            r = session.get("https://en.wikipedia.org/w/api.php",
                            params={**params, "format": "json"}, timeout=25)
            return r.json()
        except Exception:
            if attempt == tries - 1:
                return {}
            time.sleep(1.5 * (attempt + 1))
    return {}


def look_up(page: str, session=None) -> list[str]:
    """英語版の記事から、**いまのエンブレム**らしいファイル名を探す。

    現行のエンブレムは Commons に無く、各言語版に非フリーとして置かれている。
    `pageimages` は自由な画像しか返さないので、記事の画像一覧から選ぶ。

    **年号の入ったものは昔のエンブレム。**実際、素朴に拾ったら
    「レアル・マドリード 1908年版」「アーセナルのアールデコ版」を掴んだ
    （2026-09-08）。**クラブ名そのものに近いファイル名**が現行のもの。
    """
    import re

    s = session or _session()
    # **80 では足りない**（2026-09-10 実測）。記事の画像一覧はアルファベット順で、
    # 代表選手の国旗（File:Flag of …）が数十枚並ぶ。PSG は 93 枚あって、
    # 現行エンブレム `File:Paris Saint-Germain F.C..svg` が 80 番目より後ろにあり、
    # **切り落とされて「見つけられません」になっていた。**
    # 上限は API の最大（500）まで引く。国旗の多いクラブほど当たらなくなる
    r = _api(s, {"action": "query", "titles": page, "prop": "images",
                 "imlimit": "500", "redirects": "1"})
    names = [i["title"] for pg in r.get("query", {}).get("pages", {}).values()
             for i in pg.get("images", [])]

    def key(page_title: str) -> str:
        return re.sub(r"[^a-z0-9]", "", page_title.lower())

    want = key(page.replace("F.C.", "FC").replace("C.F.", "CF"))

    scored = []
    for name in names:
        low = name.lower()
        if any(bad in low for bad in NOT_CREST):
            continue
        if not low.endswith((".svg", ".png")):
            continue
        stem = re.sub(r"^file:", "", name, flags=re.I)
        stem = re.sub(r"\.(svg|png)$", "", stem, flags=re.I)
        flat = key(stem)
        score = 0
        if any(ch.isdigit() for ch in stem):
            score -= 40                      # 年号入りは昔のもの
        if flat == want:
            score += 60                      # クラブ名そのもの
        elif want.startswith(flat) or flat.startswith(want):
            score += 40
        if any(word in low for word in CREST_WORDS):
            score += 20
        score -= len(flat) // 8              # 長い名前ほど説明的で怪しい
        if score > 0:
            scored.append((score, name))
    scored.sort(reverse=True)
    return [n for _, n in scored]


def guess_names(page: str) -> list[str]:
    """ありそうなファイル名を並べる。

    記事の画像一覧から選ぶやり方は、**クラブによって当たらない**
    （2026-09-08 実測で18クラブ中10クラブが空振り）。
    ファイル名は「クラブ名＋FC/logo/crest」の形が多いので、
    直接あるかどうか聞きにいく。
    """
    base = page.replace("F.C.", "").replace("A.F.C.", "").replace("C.F.", "")
    base = base.replace("FC ", "").strip().rstrip(".").strip()
    short = base.replace(" & ", " and ")
    out = []
    for stem in {base, short}:
        for suffix in ("FC.svg", "FC crest.svg", "crest.svg", "logo.svg",
                       "FC logo.svg", "badge.svg", ".svg",
                       "FC.png", "crest.png", "logo.png"):
            sep = "" if suffix.startswith(".") else " "
            out.append(f"File:{stem}{sep}{suffix}")
    return out


def exists(title: str, session=None) -> bool:
    r = _api(session or _session(), {"action": "query", "titles": title})
    pages = r.get("query", {}).get("pages", {})
    return any("missing" not in pg for pg in pages.values())


def image_url(title: str, session=None, width: int = 256) -> tuple[str, str]:
    """ファイル名から、画像のURLと権利表示を取る。"""
    s = session or _session()
    r = _api(s, {"action": "query", "titles": title, "prop": "imageinfo",
                 "iiprop": "url|extmetadata", "iiurlwidth": str(width)})
    for pg in r.get("query", {}).get("pages", {}).values():
        info = (pg.get("imageinfo") or [{}])[0]
        url = info.get("thumburl") or info.get("url") or ""
        meta = info.get("extmetadata", {})
        return url, meta.get("LicenseShortName", {}).get("value", "記載なし")
    return "", "記載なし"


def fetch(club: str, page: str, root: Path | None = None,
          session=None) -> tuple[Path | None, str]:
    """クラブのエンブレムを取って置く。戻りは (置いた場所, 説明)。"""
    s = session or _session()
    hits = look_up(page, s)
    if not hits:
        # 記事の一覧で当たらないクラブは、ファイル名を直接当てにいく
        hits = [n for n in guess_names(page) if exists(n, s)]
    if not hits:
        return None, f"{page} のエンブレムを見つけられません"
    url, license_name = image_url(hits[0], s)
    if not url:
        return None, f"{hits[0]} の画像URLを取れません"
    body = s.get(url, timeout=40).content
    out = save(club, body, url, root)
    return out, f"{hits[0]}（{license_name}）"
