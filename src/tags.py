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
    "match": ("試合結果", "ハイライト"),
    "other": ("解説",),
}
# YouTube の制限
MAX_TAGS_TEXT = 500      # タグ全体の合計文字数
MAX_TAG_LENGTH = 30      # タグ1つの長さ
MAX_DESCRIPTION = 5000
MAX_TITLE = 100


def build(title: str, league_name: str = "", kind: str = "transfer",
          extra: list[str] | None = None, book=None) -> list[str]:
    """その動画のタグ。前から順に大事なものを並べる。"""
    found: list[str] = list(BASE)

    if league_name:
        found.append(league_name)
    found += list(KIND_TAGS.get(kind, KIND_TAGS["other"]))

    # 見出しに出ているクラブ。検索されるのはたいていクラブ名
    for name in club_book.canonical(title, book):
        found.append(name)
        # 中黒を抜いた形でも探されるので、両方入れる
        plain = name.replace("・", "")
        if plain != name:
            found.append(plain)

    found += [str(t).strip() for t in (extra or []) if str(t).strip()]
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
