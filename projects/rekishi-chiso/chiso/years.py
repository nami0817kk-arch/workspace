"""年の扱い（紀元前を含む）。10-09、始皇帝の回（紀元前259〜前210年）で足した。

台本では紀元前の年を負の数で書く（`year: -221`＝紀元前221年。timeline の start / end / events も同じ）。
紀元前には0年が無いので、年の差は「天文学の年」（紀元前1年＝0、紀元前2年＝-1）に直してから数える
（前259年生まれの人は前221年に38歳。紀元前4年生まれの人は紀元30年に33歳）。

画面の文字：紀元前は「紀元前221年」、狭い所（年表の目盛り）は「前221」。紀元後は今までどおり「1785年」「1785」。
札の見出し・行の文の「紀元前221年」「前221年」も負の年として読む。
"""
from __future__ import annotations

import re

# 札の見出しの頭の年月日（「1774年5月」「紀元前210年7月」「前221年」「紀元前257年ごろ」）。「1760年代」は1つの年ではない
_HEAD = re.compile(r"\s*(?:(紀元前|前)\s*([0-9]{1,4})|([0-9]{3,4}))年(?!代)\s*(?:([0-9]{1,2})月)?\s*(?:([0-9]{1,2})日)?")
# 文の中の紀元前の年（「紀元前230〜221年」の範囲は両方とも紀元前）
_BC_RANGE = re.compile(r"(?:紀元前|(?<![一-鿿ぁ-んァ-ヶ0-9])前)\s*([0-9]{1,4})\s*[〜～~ー－-]\s*(?:前\s*)?([0-9]{1,4})年")
_BC = re.compile(r"(?:紀元前|(?<![一-鿿ぁ-んァ-ヶ0-9])前)\s*([0-9]{1,4})年(?![代後前間分続ぶほもか])")
# 生没の日付（-259 / "-0259-01-01" / "-259-1" / 1755-11-02 / "1755"）
_DATE = re.compile(r"\s*(-)?0*([0-9]{1,4})(?:-([0-9]{1,2})(?:-([0-9]{1,2}))?)?\s*$")


def astro(y: float) -> float:
    """天文学の年（紀元前1年＝0、紀元前2年＝-1）。年の差・年表の位置はこれで数える。"""
    return y + 1 if y < 0 else y


def label(y, short: bool = False) -> str:
    """画面に出す年：「1785年」／「紀元前221年」（short なら「前221年」）。0年は無いので紀元前1年にする。"""
    y = round(y)
    if y >= 1:
        return f"{y}年"
    return f"{'前' if short else '紀元前'}{max(1, -y)}年"


def tick(y) -> str:
    """年表の目盛りの数字：「1785」／「前221」。"""
    y = round(y)
    return str(y) if y >= 1 else f"前{max(1, -y)}"


def head_date(text: str | None) -> tuple[int, int | None, int | None] | None:
    """見出しの頭の (年, 月, 日)。紀元前は負。年で始まらなければ None。"""
    m = _HEAD.match(text or "")
    if not m:
        return None
    year = -int(m.group(2)) if m.group(1) else int(m.group(3))
    if year == 0:
        return None
    return year, (int(m.group(4)) if m.group(4) else None), (int(m.group(5)) if m.group(5) else None)


def bc_in(text: str) -> tuple[set[int], str]:
    """文の中の紀元前の年（負の数）と、それを消した文（残りから紀元後の年を拾うため）。"""
    out: set[int] = set()

    def rng(m):
        a, b = int(m.group(1)), int(m.group(2))
        out.update({-a, -b})
        return "＿" * len(m.group(0))

    def one(m):
        out.add(-int(m.group(1)))
        return "＿" * len(m.group(0))

    rest = _BC.sub(one, _BC_RANGE.sub(rng, text))
    return {y for y in out if y < 0}, rest


def parse_date(value, end: bool = False) -> tuple[int, int, int]:
    """生没の (年, 月, 日)。年は紀元前が負。月日が無ければ、生まれは1月1日・亡くなったのは12月31日とみなす
    （end=True が没）。書けるのは -259 / "-0259-01-01" / "-259-01" / 1755-11-02 / "1755"。"""
    s = str(value)
    m = _DATE.match(s)
    if not m or int(m.group(2)) == 0:
        raise ValueError(f"生没の年月日が読めません: {value!r}（-259・\"-0259-01-01\"・1755-11-02 のように）")
    y = -int(m.group(2)) if m.group(1) else int(m.group(2))
    month = int(m.group(3)) if m.group(3) else (12 if end else 1)
    day = int(m.group(4)) if m.group(4) else (31 if end else 1)
    return y, month, day
