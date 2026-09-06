"""人物の顔写真を Wikimedia Commons から取ってくる。

**サムネイルには顔が要る**（review が必須項目として止める）。1本ごとに
手で探して credits.json を書いていたが、1日10本になると手作業では回らない。

**被写体を確かめてからしか落とさない。**ファイル名に名前が入っているだけの
集合写真や、同姓の別人が混ざる。人物の Wikidata 項目（P18）か、
Commons の depicts（P180）で本人だと言い切れるものだけを使う。
"""

from __future__ import annotations

import json
from pathlib import Path

from .subjects import COMMONS_API, _get, fetch, portrait_of, verify


class PortraitError(Exception):
    pass


def info(title: str, session=None) -> dict:
    """Commons から画像のURL・ライセンス・撮影者を引く。"""
    pages = _get(COMMONS_API, {
        "action": "query", "format": "json", "titles": title,
        "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": 1920,
    }, session).get("query", {}).get("pages", {})
    for page in pages.values():
        for item in page.get("imageinfo") or []:
            meta = item.get("extmetadata") or {}
            return {
                "image_url": item.get("thumburl") or item.get("url") or "",
                "page_url": item.get("descriptionurl") or "",
                "license": _plain(meta.get("LicenseShortName")),
                "author": _plain(meta.get("Artist")),
            }
    raise PortraitError(f"Commons に見つかりません: {title}")


def _plain(field) -> str:
    """extmetadata の値から中身だけ取り出す。HTML が混ざることがある。"""
    raw = (field or {}).get("value", "") if isinstance(field, dict) else str(field or "")
    out, depth = [], 0
    for ch in raw:
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(ch)
    # &amp; などがそのまま残ると、概要欄の撮影者名に化けて出る
    import html

    return " ".join(html.unescape("".join(out)).split())


# 使ってよいライセンス。
# **BY-SA を許可した（2026-09-06 ユーザーの判断）。**日本人選手は CC BY で
# 見つかるものがほぼ全部スタジアムの引き写真で、顔が使えなかった。
# 「サムネの顔は必須」と両立しないので、継承条件を受け入れる側を選んだ。
#   → 継承（SA）の条件は「同じ条件で公開する」こと。**表示義務も強くなる**ので、
#     概要欄にライセンス名を必ず出す（tts.image_credits）
# NC は商用不可、ND は改変不可（切り抜きができない）で、こちらは引き続き断る。
ALLOWED = ("cc0", "public domain", "pd-", "cc by 1.0", "cc by 2.0",
           "cc by 2.5", "cc by 3.0", "cc by 4.0", "attribution",
           "cc by-sa 1.0", "cc by-sa 2.0", "cc by-sa 2.5",
           "cc by-sa 3.0", "cc by-sa 4.0")
# 非営利（NC）は収益化と両立しないので、どこでも使わない
REFUSED = ("nc", "noncommercial", "non commercial")
# 改変不可（ND）は**切らずにそのまま出すなら使える**（2026-09-06 ユーザーの案）。
# CC 4.0 は「媒体や形式を変えるための技術的な変更は改変物を生まない」と
# 明記しており、**縮小はこれに当たる**。本文に差し込む写真は min で縮めるだけで、
# 切り取りもズームもしていないので条件を満たす。
# サムネイル（16:9に切り、文字を重ねる）と背景（ズームをかける）では使えない。
NO_DERIVS = ("nd", "noderivatives", "no derivatives", "noderivs")


def license_ok(name: str, modify: bool = True) -> tuple[bool, str]:
    """そのライセンスで使ってよいか。

    ``modify`` は、切り取り・ズーム・重ね書きをするかどうか。
    サムネイルと背景は True、本文にそのまま差し込むだけなら False。
    """
    low = (name or "").strip().lower()
    if not low:
        return False, "ライセンスが読めません"
    words = low.replace("-", " ").replace("/", " ").split()
    if any(w in REFUSED for w in words):
        return False, f"{name} は非営利で、収益化と両立しません"
    banned = any(w in NO_DERIVS for w in words)
    if banned and modify:
        return False, (f"{name} は改変不可です。"
                       "切り取らずそのまま出す用途（本文の image:）でだけ使えます")
    if banned:
        return True, name
    if any(a in low for a in ALLOWED):
        return True, name
    return False, f"{name} は許可した一覧にありません"


def candidates(names: list[str], session=None, limit: int = 8) -> list[str]:
    """本人が写っていると確かめられたファイルを、確からしい順に返す。

    まず Wikidata の P18（人が本人の画像として紐づけた1枚）。
    それが使えないライセンスのときのために、Commons の検索結果も足す。
    **検索結果はファイル名で信じない。**1件ずつ被写体を確かめる。
    """
    found: list[str] = []
    title, _ = portrait_of(*names, session=session)
    if title:
        found.append(title)
    for name in [n for n in names if n and n.strip()]:
        hits = _get(COMMONS_API, {
            "action": "query", "format": "json", "list": "search",
            "srsearch": name.strip(), "srnamespace": 6, "srlimit": limit,
        }, session).get("query", {}).get("search", [])
        for hit in hits:
            if hit["title"] not in found:
                found.append(hit["title"])
    return found


# 引きの試合写真をつかまないための手がかり。
# **顔が要るのに、被写体もライセンスも通った写真で顔が写っていなかった**
# （2026-09-06 に2回。マルティネッリは販促カード、モドリッチは背番号側からの引き）。
# 見てから捨てるのでは1日10本に追いつかないので、選ぶ順を変える。
PORTRAIT_WORDS = ("cropped", "portrait", "headshot", "interview", "presser",
                  "press conference", "profile")
SCENE_WORDS = (" vs ", " v ", " x ", "match", "training", "warm", "cup final",
               "stadium", "celebrat", "trophy", "team")
# 写っているものがこれより多い写真は、人物ではなく場面を写したもの
SCENE_SUBJECTS = 4


def rank(title: str) -> int:
    """小さいほど顔写真らしい。ファイル名だけで決まるぶんの並べ替え。"""
    low = title.lower()
    score = 0
    if any(w in low for w in PORTRAIT_WORDS):
        score -= 4
    if any(w in low for w in SCENE_WORDS):
        score += 3
    # 「Foo 2024-144.jpg」のような連番は、まとめて撮った試合写真に多い
    if any(ch.isdigit() for ch in low.rsplit(".", 1)[0][-4:]):
        score += 1
    return score


def crop_to(path: Path, box: str) -> tuple[int, int]:
    """写真を切り出す。box は "x,y,w,h" を画像に対する割合で。

    **顔だけを切り出す用。**自由ライセンスの写真は全身の動作写真が多く、
    サムネイルの脇に置くと顔が豆粒になる（2026-09-06 実測）。
    顔がどこにあるかは機械で分からないので、人が数字で渡す。
    CC BY は改変を認めているので切ってよい（BY-SA・ND は最初から使わない）。
    """
    from PIL import Image

    parts = [float(v) for v in box.split(",")]
    if len(parts) != 4:
        raise PortraitError("--crop は x,y,w,h の4つを割合で（例: 0.55,0.05,0.4,0.3）")
    with Image.open(path) as im:
        w, h = im.size
        x0, y0 = int(w * parts[0]), int(h * parts[1])
        x1, y1 = x0 + int(w * parts[2]), y0 + int(h * parts[3])
        cut = im.crop((max(0, x0), max(0, y0), min(w, x1), min(h, y1)))
        cut.save(path, quality=92)
        return cut.size


def save(names: list[str], folder: Path, session=None, only: str = "",
         modify: bool = True) -> dict:
    """本人と確認でき、ライセンスも通った1枚を落として控える。

    `only` に File: 名を渡すと、その1枚だけを見る。**機械が選べない差**
    （現役時代の写真か、監督としての写真か）は人が決めるしかない。
    それでも被写体とライセンスの確認は同じように通す。
    """
    reasons: list[str] = []
    pool = [only] if only else sorted(candidates(names, session=session), key=rank)
    for title in pool:
        ok, reason = verify(title, *names, session=session)
        if not ok:
            reasons.append(f"{title}: {reason}")
            continue
        # **写っているものが多い写真は、人物ではなく場面。**顔が小さいか、
        # 写っていないことがある。指定が無い写真（P18 で通ったもの）は素通し
        if not only:
            found = fetch(title, session)
            if len(found.names) > SCENE_SUBJECTS:
                reasons.append(
                    f"{title}: {len(found.names)}つが写った場面の写真です（顔が小さい）")
                continue
        meta = info(title, session)
        fine, note = license_ok(meta["license"], modify=modify)
        if not fine:
            reasons.append(f"{title}: {note}")
            continue
        break
    else:
        nl = chr(10) + "  "
        raise PortraitError("使える写真がありません:" + nl + nl.join(reasons[:6]))

    if not meta["image_url"]:
        raise PortraitError(f"画像のURLが取れません: {title}")

    import requests

    folder.mkdir(parents=True, exist_ok=True)
    body = (session or requests).get(
        meta["image_url"], timeout=30,
        headers={"User-Agent": "youtube-video-creation/1.0 (subject-checked)"},
    )
    body.raise_for_status()
    name = "01.jpg"
    (folder / name).write_bytes(body.content)

    banned = any(w in NO_DERIVS for w in
                 meta["license"].lower().replace("-", " ").split())
    entry = {"file": name, "source": "wikimedia", "title": title,
             # **改変不可の印。**サムネイルや背景に回すと条件を破るので、
             # review がこの印を見て止める
             "no_derivatives": banned,
             "page_url": meta["page_url"], "image_url": meta["image_url"],
             "license": meta["license"], "author": meta["author"],
             "subject_check": reason}
    path = folder / "credits.json"
    existing = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    existing = [e for e in existing if e.get("file") != name] + [entry]
    path.write_text(json.dumps(existing, ensure_ascii=False, indent=2), encoding="utf-8")
    return entry
