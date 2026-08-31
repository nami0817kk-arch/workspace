"""候補ファイルの書き間違いを、深掘りに入る前に見つける。

候補ファイルは手で書く。`legue: england` と綴っても、`tier: 確報` と書いても、
今までは黙って通っていた。綴りを外した項目は既定値に落ちるだけなので、
「なぜかリーグの検索が出ない」「なぜか点が付かない」として後から効いてくる。

ここで見るのは書式と辻褄だけ。内容が正しいかは人が判断する。
"""

from __future__ import annotations

from dataclasses import dataclass

from . import clubs as club_book

KINDS = ("transfer", "match", "other")
# 確度の高い順。上限との比較に使う
TIER_ORDER = ("未確認", "背景", "報道", "確定")


@dataclass
class Issue:
    level: str      # × … 直すまで進めない / ! … 見たほうがよい / ・ … 埋められる
    where: str      # どの候補か
    message: str

    def line(self) -> str:
        return f"  {self.level} {self.where}　{self.message}"

    @property
    def blocking(self) -> bool:
        return self.level == "×"


def inspect(items, plan, book: list | None = None) -> list[Issue]:
    """候補ファイル全体を見る。"""
    book = club_book.load() if book is None else book
    issues: list[Issue] = []

    issues += _duplicates(items)
    for item in items:
        issues += _one(item, plan, book)
    return issues


def _duplicates(items) -> list[Issue]:
    found: list[Issue] = []
    seen_id: dict[str, int] = {}
    seen_url: dict[str, str] = {}
    for item in items:
        if item.id in seen_id:
            found.append(Issue("×", item.id, "id が重複しています。既出として弾かれます"))
        seen_id[item.id] = seen_id.get(item.id, 0) + 1

        if item.url and item.url in seen_url:
            found.append(
                Issue("!", item.id, f"『{seen_url[item.url]}』と同じURLです。まとめ漏れかもしれません")
            )
        elif item.url:
            seen_url[item.url] = item.id
    return found


def _one(item, plan, book) -> list[Issue]:
    found: list[Issue] = []

    # --- 綴り。外すと既定値に落ちて、黙って効かなくなる
    if item.league and item.league not in plan.leagues:
        found.append(
            Issue("×", item.id, f"league『{item.league}』は定義にありません"
                                f"（{' / '.join(plan.leagues)}）")
        )
    if item.kind not in KINDS:
        found.append(Issue("×", item.id, f"kind『{item.kind}』は定義にありません（{' / '.join(KINDS)}）"))
    if item.tier not in plan.tiers:
        found.append(Issue("×", item.id, f"tier『{item.tier}』は定義にありません（{' / '.join(plan.tiers)}）"))

    # --- 試合はリーグごとに分けて集める。リーグが無いと検索が出せない
    if item.kind == "match" and not item.league:
        found.append(Issue("×", item.id, "kind: match なのに league が空です。試合はリーグごとに引きます"))

    # --- 出典
    for url in _urls(item):
        if plan.is_blocked(url):
            found.append(Issue("×", item.id, f"取得できないサイトが出典に入っています: {_host(url)}"))
        elif not plan.group_of(url):
            found.append(Issue("!", item.id, f"網に無いサイトです: {_host(url)}。確度の上限が決められません"))

    found += _ceiling(item, plan)

    # --- 埋められるところ
    if not item.topic:
        hint = club_book.topic_of(item.title, book)
        found.append(
            Issue("・", item.id, f"topic が空です" + (f"（辞書からの当たり: {hint}）" if hint else ""))
        )
    if not item.league:
        hint = club_book.league_of(item.title, book)
        if hint:
            found.append(Issue("・", item.id, f"league が空です（辞書からの当たり: {hint}）"))
    if not item.en and item.league != "japan":
        found.append(Issue("・", item.id, "en が空です。英語サイトの深掘りが出せません"))

    # --- 辻褄
    # hours_ago を省くのは普通のこと（url から割り出す）。負は既定値なので触れない
    if item.tier == "確定" and len(item.sources) < 1 and not item.url:
        found.append(Issue("×", item.id, "確定なのに出典がありません"))

    return found


def _ceiling(item, plan) -> list[Issue]:
    """出典の群で置ける以上の確度を書いていないか。

    噂まとめだけを根拠に「確定」と書くのが、いちばん起きやすい間違い。
    """
    urls = _urls(item)
    if not urls or item.tier not in TIER_ORDER:
        return []

    ceilings = [plan.ceiling(url) for url in urls]
    known = [c for c in ceilings if c in TIER_ORDER]
    if not known:
        return []

    best = max(known, key=TIER_ORDER.index)
    if TIER_ORDER.index(item.tier) > TIER_ORDER.index(best):
        return [
            Issue(
                "×",
                item.id,
                f"出典で置けるのは『{best}』までです（tier: {item.tier}）。"
                "上の確度で出すなら、より確かな群まで辿ってください",
            )
        ]
    return []


def _urls(item) -> list[str]:
    found = list(item.sources)
    if item.url and item.url not in found:
        found.insert(0, item.url)
    return found


def _host(url: str) -> str:
    text = str(url).split("//", 1)[-1]
    return text.split("/", 1)[0]


def summarise(issues: list[Issue]) -> str:
    blocking = sum(1 for i in issues if i.level == "×")
    warn = sum(1 for i in issues if i.level == "!")
    fill = sum(1 for i in issues if i.level == "・")
    if not issues:
        return "書式の問題はありません"
    parts = []
    if blocking:
        parts.append(f"直すところ {blocking}件")
    if warn:
        parts.append(f"見たほうがよいところ {warn}件")
    if fill:
        parts.append(f"埋められるところ {fill}件")
    return " / ".join(parts)
