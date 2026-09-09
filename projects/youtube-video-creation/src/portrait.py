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
# 使ってよいライセンス（2026-09-06 ユーザーの判断で確定）。
# **BY / BY-SA も使う。**自由ライセンスのスポーツ写真はほぼ全部これで、
# 外すと在庫が29枚中5枚まで落ちる（実測。アルテタは候補6枚すべて CC BY）。
# 表示義務は果たすが、**概要欄の上には出さず末尾に畳む**（tts.image_credits）。
#   NC … 収益化と両立しない
#   ND … 切り取り・ズームをする用途では使えない（そのまま出すだけなら可）
ALLOWED = ("cc0", "public domain", "pd-", "pd ", "attribution",
           "cc by 1.0", "cc by 2.0", "cc by 2.5", "cc by 3.0", "cc by 4.0",
           "cc by-sa 1.0", "cc by-sa 2.0", "cc by-sa 2.5",
           "cc by-sa 3.0", "cc by-sa 4.0")
REFUSED = ("nc", "noncommercial", "non commercial")
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
    if banned or any(a in low for a in ALLOWED):
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


# 画像でない添付。**Commons には音声も動画もある。**
# 実測（2026-09-07）で、久保建英の候補に .ogg（音声）が混ざって選ばれた
NOT_IMAGES = (".ogg", ".oga", ".ogv", ".mp3", ".wav", ".flac", ".webm",
              ".mid", ".pdf", ".djvu", ".svg", ".gif", ".tif", ".tiff", ".stl")


def is_image(title: str) -> bool:
    """写真として使える拡張子か。**音声や動画を掴まない。**"""
    low = title.lower().rsplit(".", 1)
    if len(low) != 2:
        return False
    return ("." + low[1]) not in NOT_IMAGES


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
        # **Commons の PNG は透過を持っていることがある。**落とした中身は
        # 拡張子に関係なく 01.jpg に書くので、RGBA のままだと JPEG で保存できず
        # 「cannot write mode RGBA as JPEG」で落ちる（2026-09-09 実測）
        if cut.mode not in ("RGB", "L"):
            cut = cut.convert("RGB")
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
    pool = ([only] if only
            else sorted([c for c in candidates(names, session=session) if is_image(c)],
                        key=rank))
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


# 試合の写真を探すときの手がかり（2026-09-07）。顔写真とは逆に、
# **場面が写っているほうを上に**する。
MATCH_WORDS = (" vs ", " v ", " x ", "match", "cup", "league", "final",
               "kick", "goal", "celebrat", "derby", "friendly", "fc ")
# 試合の場面ではないもの。**建物・物・記章はいくら CC でも使えない。**
# 実測（2026-09-07）で、"Arsenal Chelsea" の1件目がロッカールームの写真だった
SCENE_REJECT = ("dressing room", "logo", "badge", "shirt", "kit ", "museum",
                "sign", "map", "exterior", "aerial", "seat", "ticket", "statue",
                "poster", "scarf", "flag", "programme", "trophy cabinet",
                "construction", "entrance", "concourse", "pitch invasion")


def scene_rank(title: str) -> int:
    """小さいほど試合の場面らしい。顔写真の `rank` と反対に並べる。"""
    low = title.lower()
    score = 0
    if any(w in low for w in MATCH_WORDS):
        score -= 4
    if any(w in low for w in PORTRAIT_WORDS):
        score += 3
    if any(w in low for w in SCENE_REJECT):
        score += 20        # 建物・物の写真。並べ替えの下に落とす
    return score


def scene_ok(title: str) -> bool:
    """試合の場面として使える名前か。**物と建物は落とす。**"""
    low = title.lower()
    return not any(w in low for w in SCENE_REJECT)


def save_scene(words: list[str], folder: Path, session=None, only: str = "",
               modify: bool = True) -> dict:
    """試合の場面を写した1枚を落として控える。

    **顔写真ではない。**参考チャンネルの最高再生は下地が試合のワンシーンで、
    顔は写っていない（2026-09-07 に実物を確認）。放送映像は使えないので、
    Commons にある**実際の試合の写真**（CC BY / CC BY-SA）で置き換える。

    被写体の確認の仕方が顔写真とは違う。人物を特定する必要はなく、
    **指定した言葉がその写真の説明に出てくるか**だけを見る。
    誰が写っているかを言い切らないので、台本でも「その試合の写真」とは書かない。
    """
    keys = [w.strip().lower() for w in words if str(w).strip()]
    if not keys:
        raise PortraitError("探す言葉がありません（クラブ名・大会名・スタジアム名）")

    reasons: list[str] = []
    if only:
        pool = [only]
    else:
        # **言葉をまとめて1つの検索にする。**別々に引くと、クラブの記章や
        # 建物の写真が上に来る（2026-09-07 実測）。football を足して場面に寄せる
        found = _get(COMMONS_API, {
            "action": "query", "format": "json", "list": "search",
            "srsearch": " ".join(keys) + " football match",
            "srnamespace": 6, "srlimit": 20,
        }, session).get("query", {}).get("search", [])
        pool = sorted(
            [h["title"] for h in found if scene_ok(h["title"])], key=scene_rank
        )
    meta = None
    chosen = ""
    for title in pool:
        try:
            found = info(title, session)
        except PortraitError as error:
            reasons.append(str(error))
            continue
        haystack = f"{title} {found.get('author', '')}".lower()
        if not only and not any(key in haystack for key in keys):
            reasons.append(f"{title}: 指定した言葉が出てきません")
            continue
        fine, note = license_ok(found["license"], modify=modify)
        if not fine:
            reasons.append(f"{title}: {note}")
            continue
        meta, chosen = found, title
        break
    if meta is None:
        nl = chr(10) + "  "
        raise PortraitError("使える試合写真がありません:" + nl + nl.join(reasons[:6]))

    import requests

    folder.mkdir(parents=True, exist_ok=True)
    body = (session or requests).get(
        meta["image_url"], timeout=30,
        headers={"User-Agent": "youtube-video-creation/1.0 (scene)"},
    )
    body.raise_for_status()
    name = "scene.jpg"
    (folder / name).write_bytes(body.content)

    banned = any(w in NO_DERIVS for w in
                 meta["license"].lower().replace("-", " ").split())
    entry = {"file": name, "source": "wikimedia", "title": chosen,
             "no_derivatives": banned,
             "page_url": meta["page_url"], "image_url": meta["image_url"],
             "license": meta["license"], "author": meta["author"],
             # 誰が写っているかは確かめていない。**場面として使う写真**
             "subject_check": "場面（人物は特定していない）"}
    path = folder / "credits.json"
    existing = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    existing = [e for e in existing if e.get("file") != name] + [entry]
    path.write_text(json.dumps(existing, ensure_ascii=False, indent=2), encoding="utf-8")
    return entry
