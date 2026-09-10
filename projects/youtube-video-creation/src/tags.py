"""タグと概要欄の見出しを、話の中身から作る。

タグは4つ固定だった（サッカー / 海外サッカー / サッカーニュース / 解説）。
どの動画にも同じ4つが付くので、検索から見つけてもらう役に立っていない。

見出しに出ているクラブ・リーグ・話の種類は分かっているので、
そこから足す。作れないものは作らない（選手名は辞書が無いので推測しない）。
"""

from __future__ import annotations

from . import clubs as club_book

# どの動画にも付ける土台
BASE = ("サッカー", "海外サッカー", "サッカーニュース")
KIND_TAGS = {
    "transfer": ("移籍情報", "移籍市場"),
    # **「ハイライト」を外した**（2026-09-10）。試合映像は権利の関係で使えないので、
    # こちらの動画はハイライトではない。**中身と食い違うタグは付けない**
    "match": ("試合結果", "チャンピオンズリーグ"),
    "other": ("解説",),
}

# **表記ゆれは両方入れる**（2026-09-10 実測）。サッカー知恵袋は同じ動画に
# `#リバプール` と `#リヴァプール` の両方を貼っていた。検索する側の書き方は割れる
VARIANTS = {
    "リバプール": "リヴァプール",
    "リヴァプール": "リバプール",
    "ウーデゴール": "ウーデゴーア",
    "ハフィーニャ": "ラフィーニャ",
    "ラフィーニャ": "ハフィーニャ",
    "マクアリスター": "マック・アリスター",
    "鈴木彩艶": "鈴木ザイオン",
}
# YouTube の制限
MAX_TAGS_TEXT = 500      # タグ全体の合計文字数
MAX_TAG_LENGTH = 30      # タグ1つの長さ
MAX_DESCRIPTION = 5000
MAX_TITLE = 100


def japanese_players(clubs: list[str], path: str | None = None) -> list[str]:
    """そのクラブにいる日本人選手（`config/players.yaml`）。

    **参考4チャンネルは、話に出てこない日本人の名前を必ず入れていた**
    （2026-09-10 実測）。アラウホの回に `#遠藤航`、全動画に `#三笘薫`。
    日本語圏の検索は選手名で起きるので、クラブと結び付けておく。
    表に無いクラブでは何も足さない。**推測で埋めない**
    """
    import yaml

    from pathlib import Path as _P

    book = _P(path or "config/players.yaml")
    if not book.exists():
        return []
    try:
        data = yaml.safe_load(book.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError:
        return []
    table = data.get("players") or {}
    out: list[str] = []
    for club in clubs:
        for name in table.get(club) or []:
            name = str(name).strip()
            if name and name not in out:
                out.append(name)
    return out


def build(title: str, league_name: str = "", kind: str = "transfer",
          extra: list[str] | None = None, book=None,
          people: list[str] | None = None, players_path: str | None = None,
          topic: str = "") -> list[str]:
    """その動画のタグ。前から順に大事なものを並べる。

    **人の名前をいちばん前に置く**（2026-09-10 に順番を変えた）。
    参考4チャンネルのハッシュタグを実測したら、10〜34個あって中身はほぼ選手名で、
    こちらは7〜8個で**選手名が1つも入っていない回があった**
    （リヴァプール対アトレティコの回のタグが「リバプール／アトレティコマドリード」だけ）。
    人は選手名で検索する。
    """
    # **先頭の3つは、動画の上に丸いボタンとして出る**（2026-09-10 に Chrome で確認）。
    # 参考2チャンネルはどちらも「#サッカー ／ クラブかリーグ ／ **日本人選手**」だった。
    # こちらは「#サッカー ／ #海外サッカー ／ #サッカーニュース」で、
    # **いちばん目立つ3枠を分類語で埋めていた**。そこを名前に明け渡す
    clubs = club_book.canonical(title, book)
    # **2枠目はこの回の主役のクラブ。**見出しに出てくる順ではない
    # （2026-09-10 実測: アーセナルの回の見出しが「…敵地ナポリで決勝弾」で、
    #  2枠目が #ナポリ になっていた）。`topic` が分かっていればそれを先頭へ
    lead = club_book.canonical(topic, book) if topic else []
    if lead:
        clubs = lead[:1] + [c for c in clubs if c != lead[0]]
    # **相手クラブは `extra`（サムネの札）にしか出ないことがある。**
    # 日本人選手を引くときは、そちらも一緒に見る
    others = club_book.canonical(" ".join(str(x) for x in (extra or [])), book)
    japanese = japanese_players(clubs + [c for c in others if c not in clubs], players_path)

    found: list[str] = [BASE[0]]
    if clubs:
        found.append(clubs[0])
    found += japanese                                   # 日本人がいれば3枠目に来る

    # この回に出てくる人。台本の `people:` から来る
    for name in [str(x).strip() for x in (people or []) if str(x).strip()]:
        found.append(name)

    # 残りのクラブ。中黒を抜いた形でも探されるので、両方入れる
    for name in clubs:
        found.append(name)
        plain = name.replace("・", "")
        if plain != name:
            found.append(plain)

    found += [str(t).strip() for t in (extra or []) if str(t).strip()]

    # ④ 分類語。**いちばん後ろ**（あふれたら後ろから落ちるので、名前を守る）
    if league_name:
        found.append(league_name)
    found += list(KIND_TAGS.get(kind, KIND_TAGS["other"]))
    found += list(BASE[1:])

    # ⑤ 表記ゆれ
    for name in list(found):
        other = VARIANTS.get(name)
        if other and other not in found:
            found.append(other)
    return fit(found)


def fit(tags: list[str]) -> list[str]:
    """重複と長すぎるものを落とし、合計が制限に収まるところまでにする。

    前から順に大事な順なので、あふれたら後ろから落ちる。
    """
    kept: list[str] = []
    total = 0
    for tag in tags:
        tag = str(tag).strip()
        if not tag or tag in kept or len(tag) > MAX_TAG_LENGTH:
            continue
        # タグはカンマ区切りで送られる。区切りのぶんも数える
        cost = len(tag) + (1 if kept else 0)
        if total + cost > MAX_TAGS_TEXT:
            break
        kept.append(tag)
        total += cost
    return kept


def text_length(tags: list[str]) -> int:
    """YouTube が数えるときの長さ（カンマ区切り）。"""
    return len(",".join(tags))


def problems(title: str, description: str, tags: list[str]) -> list[str]:
    """公開前に引っかかるところ。"""
    found: list[str] = []
    if len(title) > MAX_TITLE:
        found.append(f"タイトルが{len(title)}字です（上限{MAX_TITLE}字）")
    if len(description) > MAX_DESCRIPTION:
        found.append(f"概要欄が{len(description)}字です（上限{MAX_DESCRIPTION}字）")
    if text_length(tags) > MAX_TAGS_TEXT:
        found.append(f"タグの合計が{text_length(tags)}字です（上限{MAX_TAGS_TEXT}字）")
    for tag in tags:
        if len(tag) > MAX_TAG_LENGTH:
            found.append(f"タグ『{tag}』が{len(tag)}字です（1つ{MAX_TAG_LENGTH}字まで）")
    if "<" in description or ">" in description:
        found.append("概要欄に < > が入っています。YouTube は受け付けません")
    return found
