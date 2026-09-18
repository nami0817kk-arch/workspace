"""その題材、最近すでに読み上げていないか（2026-09-18）。

ユーザー指摘「**かこにかいたやつばっかー**」。9/18 の朝に出した題材8件が
全部×になった。突き合わせたら、**5件は前日の代表発表の回で名前を
読み上げたばかり**だった（菅原由勢・佐藤龍之介・守田英正・鎌田大地・冨安健洋）。

**既存の仕組みでは捕まらない。**`coverage.duplicates` は取材メモの `id` が
一致したときだけ弾くので、同じ人でも見出しが違えば素通りする。しかも
代表発表の回の `id` は `daihyo_new` で、**そこで名前を読み上げた6人ぶんの
控えはどこにも残っていない**。

**人の目でも捕まらない。**こちらは見出しの重なりしか見ておらず、
「この人を最近出したか」を見ていなかった。**台本の本文まで見ないと分からない。**

    python -m src.cli recent "久保建英「国籍は関係ない」" "板倉滉にも影響"

**落とすのではなく知らせる。**続報は正しく続報だし、同じ人を2日あけて
出すのが悪いわけでもない。**気づかずに出す**ことだけを防ぐ。
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path

from .config import _resolve

# **名前らしい形**だけを見る。助詞や記号で切れるので、走りで拾える
KATAKANA = re.compile(r"[ァ-ヴー]{3,}")
KANJI = re.compile(r"[一-鿿]{2,5}")

# 何日ぶんの台本を見るか。**代表ウィークは同じ顔ぶれが続く**ので、
# 3日では足りず、7日だと続報まで鳴る
DEFAULT_DAYS = 5

# **どの回にも出てくる語は名前ではない。**この割合を超えて出てくる語は、
# 「代表」「試合」「理由」のような共通語とみなして黙る。
# 一覧を持つと足し忘れるので、**実際の並びから決める**。
# 0.5 では緩すぎた（82本のうち41本に出ないと共通語にならない）
COMMON_RATIO = 0.15


@dataclass
class Past:
    """最近の台本1本。"""

    path: Path
    day: date
    text: str

    @property
    def headline(self) -> str:
        """その回の題名だけ。**人に読ませるのはこちら。**"""
        for line in self.text.splitlines():
            if line.startswith("title:"):
                return line[len("title:"):].strip().strip("'\"")
            if line.startswith("##"):
                break
        return self.path.stem

    @property
    def title(self) -> str:
        """その回が**何の話か**を表すところ。

        台本の頭は YAML で、`title:` と `topic:` に題名と話のまとまりが入る。
        **`# ` の見出しではない**（台本に無い。最初これで探して空振りした）。
        ファイル名も足す（`20260916_itakura.md` の `itakura`）。
        """
        parts = [self.path.stem]
        for line in self.text.splitlines():
            if line.strip() in ("---", ""):
                continue
            for head in ("title:", "topic:", "short_title:", "intro_title:"):
                if line.startswith(head):
                    parts.append(line[len(head):].strip())
            if line.startswith("##"):     # 本文に入ったら終わり
                break
        return "　".join(parts)


@dataclass
class Hit:
    """最近すでに出ていた語。"""

    word: str
    day: date
    path: Path
    subject: bool          # その回の**題材**だったか（題名に出ている）
    times: int             # 本文に出た回数
    headline: str = ""     # その回の題名。**これが無いと判断を誤る**

    def line(self) -> str:
        """**題名まで出す**（2026-09-18）。

        「久保建英（09/17 題材にした）」だけを見て、こちらは
        「試合結果は別の中身だから重ならない」と判断して押し通した。
        **過去の台本を読んでいなかった。**実際には 9/14 に
        「久保建英が2戦続けてベンチ。出番が来たのは何分からか」があり、
        本文には「地元紙が採点をつけなかった」まで入っていた。
        **題名が見えていれば、同じ形だとその場で分かる。**
        """
        what = "題材にした" if self.subject else f"名前を{self.times}回読んだ"
        head = f"「{self.headline}」" if self.headline else ""
        return f"{self.word}（{self.day:%m/%d} {what}）{head}"


def words(text: str) -> list[str]:
    """見出しから、名前らしい語を取り出す。**順番は出てきた順、重複は落とす。**"""
    out: list[str] = []
    for found in (KATAKANA.findall(text), KANJI.findall(text)):
        for word in found:
            if word not in out:
                out.append(word)
    return out


def past(days: int = DEFAULT_DAYS, root: str | Path = "scripts",
         today: date | None = None) -> list[Past]:
    """直近の台本を、新しい順に読む。

    **日付はファイル名から取る**（`20260917b_endo.md`）。更新時刻だと、
    あとから直した台本が「今日の台本」に化ける。
    """
    today = today or datetime.now().date()
    edge = today - timedelta(days=max(0, days))
    folder = _resolve(root)
    if not folder.exists():
        return []
    out: list[Past] = []
    for path in folder.glob("*.md"):
        head = re.match(r"(\d{8})", path.name)
        if not head:
            continue
        try:
            day = datetime.strptime(head.group(1), "%Y%m%d").date()
        except ValueError:
            continue
        if day < edge:
            continue
        try:
            out.append(Past(path, day, path.read_text(encoding="utf-8")))
        except OSError:
            continue
    return sorted(out, key=lambda p: p.day, reverse=True)


def common(scripts: list[Past], ratio: float = COMMON_RATIO) -> set[str]:
    """**どの回にも出てくる語**。名前として数えない。"""
    if not scripts:
        return set()
    count: dict[str, int] = {}
    for item in scripts:
        for word in set(words(item.text)):
            count[word] = count.get(word, 0) + 1
    edge = max(2, int(len(scripts) * ratio))
    return {word for word, times in count.items() if times >= edge}


def hits(title: str, scripts: list[Past], ratio: float = COMMON_RATIO) -> list[Hit]:
    """その見出しの名前が、最近の台本で読み上げられていないか。

    **題材にした回を優先して返す。**名前を1回読んだだけの回より、
    その人を主役にした回のほうが重い。無ければ、いちばん新しい回を返す。
    """
    skip = common(scripts, ratio)
    found: list[Hit] = []
    for word in words(title):
        if word in skip:
            continue
        best: Hit | None = None
        for item in scripts:      # 新しい順
            times = item.text.count(word)
            if not times:
                continue
            hit = Hit(word, item.day, item.path, word in item.title, times,
                      item.headline)
            if best is None:
                best = hit
            if hit.subject:       # 題材にした回が見つかったらそこで決める
                best = hit
                break
        if best is not None:
            found.append(best)
    # 題材にした回を先に並べる。**読む順で重さが分かる**ように
    return sorted(found, key=lambda h: (not h.subject, -h.times))


def advise(titles: list[str], days: int = DEFAULT_DAYS,
           root: str | Path = "scripts", today: date | None = None,
           subjects_only: bool = False) -> list[str]:
    """題材の一覧を渡すと、最近読み上げたものだけ1行ずつ返す。

    `subjects_only` を立てると、**題材にした回があるものだけ**にする。
    「名前を読んだだけ」まで出すと、どの見出しも何かしら当たって読めない。
    """
    scripts = past(days, root, today)
    if not scripts:
        return []
    out: list[str] = []
    for title in titles:
        found = hits(title, scripts)
        if subjects_only:
            found = [h for h in found if h.subject]
        if found:
            out.append(f"{title}\n    → " + "\n    → ".join(h.line() for h in found))
    return out
