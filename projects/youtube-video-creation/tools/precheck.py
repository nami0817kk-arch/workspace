# -*- coding: utf-8 -*-
"""台本を見せる前に、機械で見られる過去の指摘を1コマンドで全部当てる（2026-10-06 ユーザー
「過去指摘内容は聞かれないで平気な作りにして」）。

    python tools/precheck.py scripts/20261006_team_brazil.md            # 1本
    python tools/precheck.py scripts/20261006_*.md                      # その日の全部
    python tools/precheck.py scripts/20261006_*.md --no-preview         # 4コマの下見（時間がかかる）を飛ばす

**Gemini は呼ばない**（`tools/preshow.py`・`tools/flow.py` は回さない。手で見る表は preshow の
`table_hand_rules` を import して出すだけ）。VOICEVOX が起きていれば `audio_query` で人名の読みを
聞く（合成はしない）。起きていなければ読みの項目は辞書との突き合わせだけになる。

台本ごとに 1〜10 を当てて ✓（通る）／×（直してから見せる）／△（見て判断する）を並べ、
× が1つでもあれば終了コード1。最後に CLAUDE.md の表で「手」と書いた行を一覧に出す。

  1. draft の点検（取材メモ research/<名前>.yaml に `draft --check-only` と同じ検査＋台本そのものの点検）
     止める指摘（■ 直したほうがよい指摘）・取材メモの不備・台本そのものの点検は ×、ほかのヒントは △
     シリーズの回の「ネットの反応が1件もありません」は △（シリーズは反応なしでよい）
  2. 語りの行（キャスター・解説、no_telop でない）が40字を超えていないか（10/5「字幕が4行になり口にかかった」）
  3. 言ってはいけない言い方：媒体名・「どの記事にも」・まとめ／掲示板・自分のチャンネルの過去回・
     埋め草（review.FILLER）・ハイフンのスコア（「2-1」）・選手を小さく見せる言い方（「それだけです」「最下位」）
  4. ネットの反応は3件まで（cont を除いたかたまりの数）、長い反応は cont で分けてあるか
  5. 本と本のあいだの重なり（`variety._cross_repeats` を、その日と前日・前々日の台本に当てる）。
     言い回しの重なりは ×、数字＋単位だけの重なり（「36%」「5000人」）は △
  6. 読み：日本人の名前で config/reading.yaml に無いもの（△。audio_query の読みを添える）
  7. 写真：本編・ショート・サムネの写真の (a) 左右の端のぼかし埋め・べた塗り（9/17・9/25・10/6）
     (b) credits.json の代理店（Getty・AFLO・AFP・ロイター・共同・IMAGO・AP・PA・Lusa・EPA・Pixsell）
     (c) 引き伸ばし（1.6倍超）
  8. 4コマの下見（`tools/preview4.py` の preview を本編・ショートで回す。× は ×、△ は △）
  9. シリーズの決まり（冒頭の強い一点・見立てのこの回だけの数字。本編の言葉の早さは見ない）
 10. 流れの点検の控え output/flow/<名前>.md が台本より新しいか
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

OK, BAD, WARN = "✓", "×", "△"
NARRATORS = ("キャスター", "解説", "ナレーター")
CROWD = ("ネット民", "現地サポ", "海外のファン")


@dataclass
class Item:
    """1つの項目の結果。found は [(印, 文)]。印が無ければ ✓。"""

    no: int
    name: str
    found: list = field(default_factory=list)
    note: str = ""          # ✓ のときに添える一言
    skipped: bool = False

    def add(self, mark: str, text: str) -> None:
        self.found.append((mark, text))

    @property
    def mark(self) -> str:
        marks = {m for m, _ in self.found}
        return BAD if BAD in marks else WARN if WARN in marks else OK

    def count(self, mark: str) -> int:
        return sum(1 for m, _ in self.found if m == mark)


# ---------------------------------------------------------------- 1. draft の点検

def notes_path(script: Path) -> Path:
    return ROOT / "research" / f"{script.stem}.yaml"


# 1 で出すヒントのうち、ほかの項目が台本そのものから見るもの（二重に出さない）
COVERED_ELSEWHERE = re.compile(
    r"長い反応が分かれていません|ネットの反応が\d+件です|2026-10-06 ⑩")
# 出典の数え方・空の引き（2026-09-24 から空が正）・反応の登録アカウントの知らせは、ユーザーの指摘の型ではない。
# 10/6 の11本で △ の6割がこれだった。件数だけ添える
QUIET_HINTS = re.compile(
    r"theme\.hook が空です|同じ記事を\d+つの節で使っています|出典\d+本のうち\d+本が"
    r"|は登録済みのアカウントではありません")


def check_draft(script_path: Path, script) -> Item:
    item = Item(1, "draft の点検（取材メモ＋台本そのもの）")
    from src.cli import MUST_FIX
    from src.plan import load_plan
    from src.research import (YARD_STRONG_MARK, advise, check_repeats, load_notes, verify,
                              wants_reactions)

    path = notes_path(script_path)
    if not path.exists():
        item.add(WARN, f"取材メモ research/{path.name} がありません（draft の点検はできません）")
        return item
    plan = load_plan()
    notes = load_notes(path)
    for problem in verify(notes, plan):
        item.add(BAD, f"取材メモの不備: {problem}")
    for problem in check_repeats(notes, plan):
        item.add(BAD, f"重複: {problem}")
    hints = list(advise(notes, plan))
    series = bool((notes.series or "").strip())
    quiet = 0
    for hint in hints:
        if COVERED_ELSEWHERE.search(hint):
            continue
        if QUIET_HINTS.search(hint):
            quiet += 1
            continue
        if MUST_FIX.search(hint):
            item.add(BAD, hint)
        elif hint.startswith(YARD_STRONG_MARK):
            item.add(WARN, hint)
        else:
            item.add(WARN, f"ヒント: {hint}")
    if wants_reactions(notes.series) and not any(
            "ネット民" in str(v) for sec in notes.sections for v in sec.voices):
        text = "ネットの反応が1件もありません"
        if series:
            item.add(WARN, text + "（シリーズの回なので反応なしでよい）")
        else:
            item.add(BAD, text + "。`xread.py <検索語>` で実在の投稿を探して節を足してください")

    # draft の「台本そのものの点検」。check_filler・check_outlet_talk・check_board_mention は 3 が行ごとに見る
    from src import review, shorts
    for name in ("check_title_subject", "check_overseas_voices"):
        found = getattr(review, name)(script)
        if found.ok is False:
            item.add(BAD, f"{found.label}: {found.detail}")
    try:
        short = shorts.trim(script)
    except shorts.ShortError as err:
        item.add(BAD, f"ショート: {err}")
    else:
        for problem in shorts.voice_tail_problems(short, script) + shorts.subject_problems(short, script):
            item.add(BAD, f"ショート（見積もり）: {problem}")
    if notes_newer(path, script_path):
        item.add(WARN, "取材メモが台本より新しい（draft を掛け直していない？台本は古い中身のまま）")
    if quiet:
        item.note = f"出典の数え方・空の引きなどのヒント {quiet}件は出していない（draft で見られる）"
    return item


def notes_newer(notes: Path, script: Path) -> bool:
    try:
        return notes.stat().st_mtime > script.stat().st_mtime + 1
    except OSError:
        return False


# ---------------------------------------------------------------- 2. 語りの行の長さ

NARRATION_MAX = 40


def _shown(line) -> str:
    return re.sub(r"\*\*", "", line.telop_text() or "")


def check_line_length(script) -> Item:
    item = Item(2, f"語りの行は{NARRATION_MAX}字まで")
    for scene in script.scenes:
        for line in scene.lines:
            if (line.speaker or "") not in NARRATORS or line.no_telop:
                continue
            text = _shown(line)
            if len(text) > NARRATION_MAX:
                item.add(BAD, f"節『{scene.title}』{len(text)}字『{text[:30]}…』")
    if not item.found:
        longest = max((len(_shown(l)) for l in script.lines
                       if (l.speaker or "") in NARRATORS and not l.no_telop), default=0)
        item.note = f"最長 {longest}字"
    return item


# ---------------------------------------------------------------- 3. 言ってはいけない言い方

# 媒体名（読み上げに出すと「どの記事で扱ってるか」の話になる。2026-09-21）。短い名前は字面がぶつかるので、
# 紙・誌・『』で挟んだ形だけ見る
OUTLETS = (
    "マルカ", "ムンド・デポルティーボ", "スポルト", "ガゼッタ", "コリエレ・デッロ・スポルト", "トゥット・スポルト",
    "レキップ", "キッカー", "ビルト", "スカイスポーツ", "スカイ・スポーツ", "ESPN", "BBC", "ジ・アスレティック",
    "アスレティック紙", "ガーディアン", "デイリー・メール", "デイリーメール", "テレグラフ", "ザ・サン",
    "タイムズ紙", "ミラー紙", "トークスポーツ", "サッカーダイジェスト", "ゲキサカ", "スポーツ報知", "日刊スポーツ",
    "スポニチ", "スポーツニッポン", "サンケイスポーツ", "サンスポ", "デイリースポーツ", "東京スポーツ", "中日スポーツ",
    "フットボールチャンネル", "サッカーキング", "超ワールドサッカー", "フットボールゾーン", "サッカーマガジン",
    "共同通信", "時事通信", "ロイター", "ヤフーニュース", "Yahoo!ニュース", "ゴール・ドットコム", "Goal.com",
    "トランスファーマルクト", "フォットモブ", "オプタ", "ア・ボラ", "レコルド", "オ・ジョゴ", "グローボ",
)
OUTLET_SHORT = re.compile(r"(?:『|「)(?:AS|アス|スポルト|ビルト|キッカー|マルカ|オーレ)(?:』|」)|(?:AS|アス)紙")
NO_ARTICLE_TALK = re.compile(
    r"どの記事|記事には|記事に(?:は|も)?書かれ|日本語の記事|伝えているのは[^。]{0,12}(?:媒体|社|紙)"
    r"|(?:1つ|ひとつ|一つ)の媒体|一行も書かれ|報じた(?:媒体|メディア)はまだ")
# ハイフンのスコア（「2-1」は「ニー、イチ」と読まれる）。年月日・季（2025-26）・時刻は外す
HYPHEN_SCORE = re.compile(r"(?<![\d/／.-])(\d{1,2})\s*[-－‐–−]\s*(\d{1,2})(?![\d/／.-]|年|月|日|シーズン|季|時)")
# 選手を小さく見せる言い方（2026-10-02「選手にリスペクトはもとう」）
BELITTLE = re.compile(
    r"それだけ(?:です|だ|でした|。|$)|最下位|しない選手|できない選手|だけの選手|に過ぎ(?:ない|ません)"
    r"|でしかな|期待外れ|物足りな|衰え|落ちぶれ|お荷物|戦力外の")


def _outlet_names(script) -> list[str]:
    names = set(OUTLETS)
    for entry in (script.meta or {}).get("quote_sources") or []:
        head = str(entry).split("http")[0].strip()
        if 2 <= len(head) <= 20:
            names.add(head)
    return sorted(names, key=len, reverse=True)


def check_wording(script) -> Item:
    from src.reading import apply as apply_reading
    from src.reading import load_dictionary
    from src.review import BOARD, FILLER, OUTLET, PRIMARY

    item = Item(3, "言ってはいけない言い方")
    readings = load_dictionary()
    names = _outlet_names(script)
    flat = [(scene, line) for scene in script.scenes for line in scene.lines]
    for index, (scene, line) in enumerate(flat):
        text = (line.text or "").strip()
        where = f"節『{scene.title}』『{text[:26]}…』"
        narrator = (line.speaker or "") in NARRATORS
        # ハイフンのスコアは誰の行でも読み違える（反応は文を変えず、辞書で開く）
        spoken = apply_reading(text, readings)
        for hit in HYPHEN_SCORE.finditer(spoken):
            item.add(BAD, f"ハイフンのスコア『{hit.group(0)}』は「{hit.group(1)}対{hit.group(2)}」と書く"
                          f"（反応なら config/reading.yaml で開く）{where}")
        if not narrator:
            continue
        nxt = flat[index + 1][1] if index + 1 < len(flat) else None
        quoting = nxt is not None and (nxt.speaker or "") not in NARRATORS
        named = [n for n in names if n in text] or [m.group(0) for m in OUTLET_SHORT.finditer(text)]
        if named and not quoting:
            item.add(BAD, f"媒体名『{named[0]}』（引用の前置きでない）{where}")
        if OUTLET.search(text) and not PRIMARY.search(text) and not quoting and not named:
            item.add(BAD, f"出どころの説明（「によると」「メディア」など。引用の前置きでない）{where}")
        if NO_ARTICLE_TALK.search(text):
            item.add(BAD, f"記事・媒体の話（「どの記事にも」など。人の側から言う）{where}")
        if BOARD.search(text):
            item.add(BAD, f"掲示板・まとめへの言及 {where}")
        for pattern, label in FILLER:
            if pattern.search(text):
                item.add(BAD, f"{label} {where}")
                break
        hit = BELITTLE.search(text)
        if hit:
            item.add(BAD, f"小さく見せる言い方『{hit.group(0)}』（「いちばん少ない側」「磨いてきた」のように）{where}")
    return item


# ---------------------------------------------------------------- 4. ネットの反応

def check_reactions(script) -> Item:
    from src.research import REACTION_MAX, REACTION_SPLIT_AT
    from src.review import _crowd_groups

    item = Item(4, f"ネットの反応は{REACTION_MAX}件まで・長い反応は cont で分ける")
    groups = _crowd_groups(script)
    if groups > REACTION_MAX:
        item.add(BAD, f"ネットの反応が{groups}件あります（{REACTION_MAX}件まで）")
    for scene in script.scenes:
        lines = scene.lines
        for i, line in enumerate(lines):
            if (line.speaker or "") not in CROWD:
                continue
            text = line.text or ""
            nxt_cont = i + 1 < len(lines) and lines[i + 1].cont
            if len(text) > REACTION_SPLIT_AT and not nxt_cont and "。" in text[:-1]:
                item.add(BAD, f"節『{scene.title}』長い反応が分かれていません（{len(text)}字）『{text[:24]}…』。"
                              "文の終わりで分け、2行目以降に cont: true")
    if not item.found:
        item.note = f"{groups}件"
    return item


# ---------------------------------------------------------------- 5. 本と本のあいだ

DAY = re.compile(r"^(\d{8})")
NUMBER_ONLY = re.compile(
    r"\d[\d,.]*(?:万|億|点|ゴール|試合|本|人|回|位|歳|分|秒|月|日|戦|失点|得点|勝|敗|ユーロ|ポンド|円|%)")
CROSS_LEAST = 10
# 前日・前々日の台本との重なりは、続けて聞く人が少ないぶん長さで絞る。10/6 の11本に当てると、
# 10〜11字の重なりは「こう説明しています」「ゴールを決めています」のような言い回しの型がほとんどだった。
# 同じ日の本とは 10字から ×、前の日の本とは 14字から ×（10〜13字は △）
CROSS_OTHER_DAY = 14
# ただし固有名詞（3字以上のカタカナ。普通名詞は review.COMMON_KATAKANA と下の語）が入っていれば、短くても ×
# （10/6 のベリンガムの回が 10/4 のイングランド対クロアチアの「トゥヘル監督はこう」「チェコと戦います」を言い直していた）
COMMON_KATAKANA_MORE = ("フォワード", "ペース", "ボール", "ゴール", "チーム", "シーズン", "リーグ", "スタメン",
                        "ディフェンダー", "ミッドフィールダー", "ゴールキーパー", "ポジション", "アシスト", "プレー")
KATAKANA_RUN = re.compile(r"[ァ-ヴー・]{3,}")


def _has_proper_noun(text: str) -> bool:
    from src.review import COMMON_KATAKANA

    common = set(COMMON_KATAKANA) | set(COMMON_KATAKANA_MORE)
    return any(run.strip("・") not in common and not any(run.strip("・") in c for c in common)
               for run in KATAKANA_RUN.findall(text))


def neighbours(scripts: list[Path]) -> list[Path]:
    """見せる台本の日付と、その前日・前々日の台本（同じファイルは1回だけ）。"""
    seen: dict[Path, None] = {}
    for script in scripts:
        seen[script.resolve()] = None
    days = set()
    for script in scripts:
        m = DAY.match(script.name)
        if not m:
            continue
        day = datetime.strptime(m.group(1), "%Y%m%d")
        days.update((day - timedelta(days=k)).strftime("%Y%m%d") for k in range(3))
    for day in sorted(days):
        for other in sorted((ROOT / "scripts").glob(f"{day}_*.md")):
            seen.setdefault(other.resolve(), None)
    return list(seen)


def check_cross(targets: list[Path], loaded: dict) -> dict[Path, Item]:
    from src.script_model import load_script
    from src.variety import _cross_repeats

    pool = neighbours(targets)
    scripts = {}
    for path in pool:
        if path in loaded:
            scripts[path] = loaded[path]
            continue
        try:
            scripts[path] = load_script(path)
        except Exception:
            continue
    by_name = {}
    for path, s in scripts.items():
        by_name.setdefault(str((s.meta or {}).get("title") or s.title or "")[:12], []).append(path)
    focus = [scripts[t.resolve()] for t in targets if t.resolve() in scripts]
    found = _cross_repeats(list(scripts.values()), least=CROSS_LEAST, focus=focus)
    items = {}
    others = len(scripts) - len(focus)
    for target in targets:
        s = scripts.get(target.resolve())
        item = Item(5, f"本と本のあいだの重なり（その日と前日・前々日の{len(scripts)}本）")
        if s is None:
            items[target] = item
            continue
        mine = str((s.meta or {}).get("title") or s.title or "")[:12]
        day = DAY.match(target.name).group(1) if DAY.match(target.name) else ""
        for entry in found:
            m = re.match(r"『(.+)』（(.+) と (.+)）$", entry)
            if not m or mine not in (m.group(2), m.group(3)):
                continue
            other = m.group(3) if m.group(2) == mine else m.group(2)
            files = [p.stem for p in by_name.get(other, [])] or [other]
            token = m.group(1)
            same_day = bool(day) and any(f.startswith(day) for f in files)
            if NUMBER_ONLY.fullmatch(token.strip()):
                item.add(WARN, f"同じ数字『{token}』（{', '.join(files)}）")
            elif same_day or len(token.strip()) >= CROSS_OTHER_DAY or _has_proper_noun(token):
                item.add(BAD, f"同じ言い回し『{token}』（{', '.join(files)}）")
            else:
                item.add(WARN, f"前の日の本と短い言い回しが重なる『{token}』（{', '.join(files)}）")
        item.note = f"ほかの{others}本と比べた"
        items[target] = item
    return items


# ---------------------------------------------------------------- 6. 読み

NAME_SUFFIX = re.compile(r"(?:元|前|新|現)?(?:代表)?(?:監督|選手|コーチ|会長|主将|キャプテン|氏|さん|くん|社長|理事|GM)$")
# 地の文から拾うのは敬称・役職の前の漢字だけ（「選手」は「中心選手」「交代選手」で鳴るので見ない。
# 選手は config の日本人の名簿で拾う）
NAME_BEFORE = re.compile(r"([一-龥々]{2,5})(?=監督|コーチ|会長|主将|氏|さん|くん)")
NOT_NAME = re.compile(r"代表|日本|協会|連盟|クラブ|当時|歴代|初代|外国|主力|若手|守備|攻撃|同|両|各|副|総|名|新|前|元|現|代理|専任|就任|"
                      r"後任|同国|自国|他|全|若|監|督|選|手|チーム|地元|本人|今季|昨季|欧州|中心|交代|途中|先発|暫定|技術|育成|強化")
KANJI = re.compile(r"[一-龥々]")


def _known_japanese() -> set[str]:
    import yaml

    names: set[str] = set()
    for file in ("config/japan_abroad.yaml", "config/players.yaml"):
        path = ROOT / file
        if not path.exists():
            continue
        raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        players = raw.get("players") or []
        if isinstance(players, dict):
            for value in players.values():
                names.update(str(v) for v in (value or []))
        else:
            names.update(str(p.get("name")) for p in players if isinstance(p, dict) and p.get("name"))
    try:
        from src.plan import load_plan

        names.update(str(n) for n in (load_plan().scoring.get("japanese") or []))
    except Exception:
        pass
    return {n for n in names if KANJI.search(n)}


def candidate_names(script, notes_people: list[str], known: set[str]) -> list[str]:
    found: dict[str, None] = {}
    for person in notes_people:
        person = str(person).strip()
        if KANJI.search(person) and not re.search(r"[ァ-ヴ]", person):
            found[person] = None
    text = "".join(l.text or "" for l in script.lines)
    for line in script.lines:
        who = (line.speaker or "").strip()
        if who and who not in NARRATORS and who not in CROWD:
            bare = NAME_SUFFIX.sub("", who)
            if KANJI.search(bare) and not re.search(r"[ァ-ヴA-Za-z]", bare) and len(bare) >= 2:
                found[bare] = None
    for name in known:
        if name in text:
            found[name] = None
    for hit in NAME_BEFORE.finditer(text):
        name = hit.group(1)
        if not NOT_NAME.search(name):
            found[name] = None
    # 長い名前に含まれる短い呼び方（「森保一」と「森保」）は、長いほうが辞書で開ければ要らない
    return list(found)


def _kana(text: str, speaker: int) -> str | None:
    try:
        import requests

        r = requests.post("http://127.0.0.1:50021/audio_query",
                          params={"text": text, "speaker": speaker}, timeout=4)
        r.raise_for_status()
        return str(r.json().get("kana") or "")
    except Exception:
        return None


def _speaker_id() -> int:
    try:
        from src.config import load_config

        return int(load_config().resolve_speaker("キャスター").style_id)
    except Exception:
        return 13


def check_readings(script_path: Path, script, known: set[str], use_engine: bool) -> Item:
    from src.reading import apply as apply_reading
    from src.reading import load_dictionary

    item = Item(6, "読み（日本人の名前が config/reading.yaml にあるか）")
    people: list[str] = []
    path = notes_path(script_path)
    if path.exists():
        try:
            from src.research import load_notes

            people = list(load_notes(path).people or [])
        except Exception:
            people = []
    readings = load_dictionary()
    speaker = _speaker_id() if use_engine else 0
    names = candidate_names(script, people, known)
    missing = [n for n in names if KANJI.search(apply_reading(n, readings))]
    # 長い名前が辞書に無くて、その一部だけが挙がるのは同じ人。長いほうだけ出す
    missing = [n for n in missing if not any(n != m and n in m for m in missing)]
    for name in missing:
        kana = _kana(name, speaker) if use_engine else None
        how = f"いまの読み {kana}" if kana else "（VOICEVOX が起きていないので読みは聞けません）"
        item.add(WARN, f"『{name}』が辞書にありません。{how}")
    if not item.found:
        item.note = f"名前 {len(names)}件、辞書で開ける"
    return item


# ---------------------------------------------------------------- 7. 写真

AGENCY = re.compile(
    r"getty|aflo|アフロ|\bAFP\b|ロイター|reuters|共同通信|kyodo|imago|"
    r"\bAP\b|associated press|\bPA\b|pa images|pa wire|lusa|\bEPA\b|epa-efe|pixsell", re.I)
AGENCY_URL = re.compile(r"gettyimages|aflo|afp\.|reuters|kyodo|imago-images|apimages|paimages|lusa\.|epa\.eu|pixsell",
                        re.I)
ZOOM_MAX = 1.6
# ショートの縦写真は facecrop の `_w_v.jpg`（608x1080 前後＝1.78倍）が決まりの形なので、1.6〜2.0倍は △、
# 2.0倍を超えたら ×（10/6 の11本で、1.6倍を超えたショートの写真9枚のうち6枚が `_w_v` の1.7倍台だった）
SHORT_ZOOM_BAD = 2.0
VIDEO = (1920, 1080)
SHORT = (1080, 1920)
THUMB = (1280, 720)
# 端の帯の判定（下の _edge_fill を参照）。10/5〜10/6 の台本20本の写真180枚と、縦写真をぼかし・べた塗りで
# 16:9 に埋めた見本で決めた。見本は near 0.59〜0.98・flat 0.00〜0.06、自然な写真（背景がぼけた試合の写真）は
# near 0.41 まで・flat 0.15 から
FILL_NEAR = 0.5
FILL_FLAT = 0.10
FILL_POS = 0.04
# 片側だけのときは厳しく見る（10/2 久保の 02_w.jpg：背景のぼけた試合の写真で、左だけ near 0.60・flat 0.09 になった。
# 10/1〜10/6 の写真698枚で当たったのはこの1枚だけ）。記事の og:image のぼかし埋めは縦写真を真ん中に置くので、
# ふつうは左右の両方に出る
FILL_ONE_SIDE_NEAR = 0.6
FILL_ONE_SIDE_FLAT = 0.07


def edge_fill_verdict(path: Path) -> tuple[str, str] | None:
    """(印, 文)。左右の両方が埋めた帯なら ×、片側だけでも強く当たれば △、それ以外は None。"""
    sides = _edge_fill(path)
    if len(sides) == 2:
        where = "・".join(f"{side} {share:.0%}" for side, share, _, _ in sides)
        return BAD, f"左右の端（{where}）がぼかし・べた塗りで埋められています"
    strong = [x for x in sides if x[2] >= FILL_ONE_SIDE_NEAR and x[3] <= FILL_ONE_SIDE_FLAT]
    if strong:
        side, share, _, _ = strong[0]
        return WARN, f"{side}の端 {share:.0%} がぼかし・べた塗りで埋められているかもしれません（開いて見る）"
    return None


def _edge_fill(path: Path) -> list[tuple[str, float, float, float]]:
    """左右の端が、ぼかし・べた塗りで埋められていないか。[(左|右, 幅の割合, 揃い, 鋭さの比)]。

    ぼかし埋めは「ほとんど何も写っていない帯」と「くっきりした写真」の境が、**どの行でも同じ列**に
    まっすぐ縦に立つ。背景がぼけた本物の写真は、くっきりし始める列が行ごとにばらばら（人の輪郭に沿う）。
    行ごとに、ラプラシアンの強さが中央の6割の点を超える最初の列を取り、
    (1) その列の中央値が幅の4%より内側、(2) 7割近い行がそこから幅1.5%以内に揃う、
    (3) その手前の帯の鋭さが中央の10%以下、の3つで「埋めた帯」とみなす。
    """
    import numpy as np
    from PIL import Image

    try:
        import cv2
    except ImportError:
        return []
    with Image.open(path) as opened:
        gray = opened.convert("L")
        w, h = gray.size
        width = 480
        gray = gray.resize((width, max(8, round(h * width / w))), Image.LANCZOS)
    arr = np.asarray(gray, dtype=np.float32)
    out = []
    for side, g in (("左", arr), ("右", arr[:, ::-1])):
        lap = cv2.blur(np.abs(cv2.Laplacian(np.ascontiguousarray(g), cv2.CV_32F, ksize=3)), (5, 5))
        rows, cols = lap.shape
        center = lap[:, int(cols * .35):int(cols * .65)]
        threshold = max(2.0, float(np.percentile(center, 60)))
        hit = lap > threshold
        first = np.where(hit.any(axis=1), hit.argmax(axis=1), cols)
        med = float(np.median(first))
        if med < cols * FILL_POS:
            continue
        near = float(np.mean(np.abs(first - med) <= cols * 0.015))
        band = lap[:, :max(1, int(med) - 3)]
        flat = float(band.mean()) / max(1e-6, float(center.mean()))
        if near >= FILL_NEAR and flat <= FILL_FLAT:
            out.append((side, med / cols, near, flat))
    return out


def _credits_for(path: Path) -> dict | None:
    """その写真の credits.json の行。_w・_v・_t・_r などの切り抜きは元の名前でも探す。"""
    stems = [path.name]
    base = re.sub(r"(?:_(?:w|v|t|r|wr|p|s|side))+(?=\.)", "", path.name)
    stems += [base, Path(base).stem]
    for folder in (path.parent, path.parent.parent):
        credits = folder / "credits.json"
        if not credits.exists():
            continue
        try:
            rows = json.loads(credits.read_text(encoding="utf-8"))
        except ValueError:
            continue
        for row in rows if isinstance(rows, list) else []:
            name = str(row.get("file") or "")
            rel = (path.parent.name + "/" + path.name) if folder != path.parent else path.name
            if name in stems or name == rel or Path(name).stem == Path(base).stem:
                return row
    return None


def _zoom(path: Path, frame: tuple[int, int], portrait: bool) -> float:
    from PIL import Image

    with Image.open(path) as opened:
        w, h = opened.size
    W, H = frame
    if portrait:
        return max(W / w, H / h)
    if w >= h * 0.95:
        return max(W / w, H / h)
    return max(W / 2 / w, H / h)          # 縦写真は右半分に立てる（render._photo_stage）


def photos_used(script_path: Path, script) -> dict[str, set[str]]:
    """{写真: {本編|ショート|サムネ}}。書き出し済みの script.json が台本より新しければそれを使う。"""
    from src import shorts
    from src.pipeline import drop_short_only
    from src.render import opening_photo

    used: dict[str, set[str]] = {}

    def put(path, kind):
        if path and str(path).strip():
            used.setdefault(str(path).strip(), set()).add(kind)

    def from_json(path: Path, kind: str) -> bool:
        if not path.exists() or path.stat().st_mtime < script_path.stat().st_mtime:
            return False
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except ValueError:
            return False
        for scene in data.get("scenes") or []:
            for line in scene.get("lines") or []:
                put(line.get("image"), kind)
        return True

    out = ROOT / "output" / script_path.stem
    import copy
    if not from_json(out / "script.json", "本編"):
        for line in drop_short_only(copy.deepcopy(script)).lines:
            put(line.image, "本編")
    put(opening_photo(script.meta), "本編")
    if not from_json(ROOT / "output" / f"{script_path.stem}_short" / "script.json", "ショート"):
        try:
            for line in shorts.trim(copy.deepcopy(script)).lines:
                put(line.image, "ショート")
        except shorts.ShortError:
            pass
    put((script.meta or {}).get("short_photo"), "ショート")
    put((script.meta or {}).get("thumbnail_photo"), "サムネ")
    for x in (script.meta or {}).get("thumbnail_photos") or []:
        put(x, "サムネ")
    return used


def check_photos(script_path: Path, script) -> Item:
    from src.render import _is_board

    item = Item(7, "写真（端のぼかし埋め・代理店・引き伸ばし）")
    used = photos_used(script_path, script)
    looked = 0
    for name, kinds in sorted(used.items()):
        path = (ROOT / name) if not Path(name).is_absolute() else Path(name)
        if not path.exists():
            # 台本が指している写真が無い（取り直しの途中で消した、など）。書き出すと下地のまま出る
            item.add(BAD, f"写真がありません {name}（{'・'.join(sorted(kinds))}）")
            continue
        if path.suffix.lower() not in (".jpg", ".jpeg", ".png", ".webp"):
            continue
        if _is_board(name) or "assets/stats/" in name.replace("\\", "/"):
            continue
        looked += 1
        label = f"{name}（{'・'.join(sorted(kinds))}）"
        try:
            verdict = edge_fill_verdict(path)
            if verdict:
                item.add(verdict[0], f"{verdict[1]} {label}")
        except Exception as err:
            item.add(WARN, f"端の判定ができません（{err}）{label}")
        row = _credits_for(path)
        if row is not None:
            words = " ".join(str(row.get(k) or "") for k in ("source", "title", "author", "credit", "outlet",
                                                             "license", "caption", "agency"))
            urls = " ".join(str(row.get(k) or "") for k in ("image_url", "page_url"))
            hit = AGENCY.search(words) or AGENCY_URL.search(urls)
            if hit:
                item.add(BAD, f"代理店の写真（{hit.group(0)}）{label}")
        elif "assets/images/" in name.replace("\\", "/"):
            item.add(WARN, f"credits.json に行がありません（出どころを確かめられない）{label}")
        zooms = []
        if "本編" in kinds:
            zooms.append(("本編", _zoom(path, VIDEO, False)))
        if "ショート" in kinds:
            zooms.append(("ショート", _zoom(path, SHORT, True)))
        if "サムネ" in kinds:
            zooms.append(("サムネ", _zoom(path, THUMB, False)))
        for kind, zoom in zooms:
            if zoom <= ZOOM_MAX:
                continue
            soft = kind == "ショート" and zoom <= SHORT_ZOOM_BAD
            item.add(WARN if soft else BAD,
                     f"{kind}で {zoom:.2f}倍に引き伸ばします（{ZOOM_MAX}倍まで"
                     f"{f'。ショートは{SHORT_ZOOM_BAD}倍を超えたら×' if kind == 'ショート' else ''}）{label}")
    item.note = f"{looked}枚"
    return item


# ---------------------------------------------------------------- 8. 4コマの下見

def _preview_one(args: tuple[str, bool]) -> tuple[str, bool, list, str, float]:
    script, short = args
    import tools.preview4 as p4

    began = time.perf_counter()
    try:
        result = p4.preview(script, short=short)
    except Exception as err:          # ShortError など。× として返す
        return script, short, [("×", f"{type(err).__name__}: {err}")], "", time.perf_counter() - began
    found = [(m, f"{name} {text}") for name, m, text in result.problems]
    return script, short, found, str(result.path), time.perf_counter() - began


def run_previews(scripts: list[Path], jobs: int) -> dict[Path, Item]:
    tasks = [(str(s), short) for s in scripts for short in (False, True)]
    items = {s: Item(8, "4コマの下見（tools/preview4.py）") for s in scripts}
    by_str = {str(s): s for s in scripts}
    notes: dict[Path, list[str]] = {s: [] for s in scripts}
    if jobs > 1 and len(tasks) > 1:
        with ProcessPoolExecutor(max_workers=jobs) as pool:
            results = list(pool.map(_preview_one, tasks))
    else:
        results = [_preview_one(t) for t in tasks]
    for script, short, found, path, seconds in results:
        kind = "ショート" if short else "本編"
        item = items[by_str[script]]
        for mark, text in found:
            item.add(BAD if mark == "×" else WARN, f"{kind}: {text}")
        if path:
            shown = Path(path)
            try:
                shown = shown.relative_to(ROOT)
            except ValueError:
                pass
            notes[by_str[script]].append(f"{kind} {shown.as_posix()}")
    for s, item in items.items():
        item.note = "絵: " + "／".join(notes[s]) if notes[s] else ""
    return items


# ---------------------------------------------------------------- 9. シリーズの決まり

def check_series(script_path: Path) -> Item:
    item = Item(9, "シリーズの決まり（冒頭の強い一点・見立てのこの回だけの数字）")
    path = notes_path(script_path)
    if not path.exists():
        item.skipped = True
        item.note = "取材メモが無い"
        return item
    from src.research import _advise_series_numbers, _advise_series_opening, load_notes

    notes = load_notes(path)
    if not (notes.series or "").strip():
        item.skipped = True
        item.note = "シリーズではない"
        return item
    for hint in _advise_series_opening(notes):
        item.add(WARN, hint)
    for hint in _advise_series_numbers(notes):
        item.add(WARN, hint)
    item.note = f"シリーズ『{notes.series}』。本編の言葉の早さは見ない（10/6）"
    return item


# ---------------------------------------------------------------- 10. 流れの点検の控え

def check_flow(script_path: Path) -> Item:
    item = Item(10, "流れの点検の控え（output/flow/<名前>.md が台本より新しいか）")
    record = ROOT / "output" / "flow" / f"{script_path.stem}.md"
    if not record.exists():
        item.add(BAD, f"output/flow/{record.name} がありません（flow.py --prompt で点検して控えを書く）")
    elif record.stat().st_mtime < script_path.stat().st_mtime:
        item.add(BAD, "控えが台本より古い（台本を直したあとに流れを読み直していない）")
    else:
        item.note = "控えあり"
    return item


# ---------------------------------------------------------------- まとめ

def _short(text: str, width: int = 150) -> str:
    text = re.sub(r"\s+", " ", str(text))
    return text if len(text) <= width else text[:width - 1] + "…"


def report(script_path: Path, items: list[Item]) -> tuple[int, int]:
    bad = sum(i.count(BAD) for i in items)
    warn = sum(i.count(WARN) for i in items)
    print(f"\n■ {script_path.stem}　× {bad}　△ {warn}")
    for item in sorted(items, key=lambda i: i.no):
        mark = "－" if item.skipped else item.mark
        extra = f"　{item.note}" if item.note else ""
        counts = ""
        if item.found:
            counts = "　" + "・".join(f"{m}{item.count(m)}" for m in (BAD, WARN) if item.count(m))
        print(f"  {mark} {item.no:>2}. {item.name}{counts}{extra}")
        for m, text in sorted(item.found, key=lambda f: f[0] != BAD):
            print(f"       {m} {_short(text)}")
    return bad, warn


def hand_rules() -> list[tuple[str, str]]:
    try:
        from tools.preshow import table_hand_rules
    except Exception:
        return []
    return table_hand_rules()


# 書き出したあと（動画を見せる前）に見る行。台本を見せる段では答えなくてよいので、頭の言葉だけまとめる
AFTER_BUILD = re.compile(r"書き出したら|書き出しは本編|動画を送る|動画は|720p|frames\.py|facecheck|承認のあと|approve")
# 手の行のうち、この道具が一部を機械で見ているもの（答えるときに、上の結果を引けばよい）
PARTLY = ((re.compile(r"cont: true"), 4), (re.compile(r"報道・まとめ"), 1), (re.compile(r"敬意"), 3),
          (re.compile(r"preview4|4コマ"), 8), (re.compile(r"型の定型文"), 5), (re.compile(r"横長|写真は記事"), 7),
          (re.compile(r"主役の名前が出ない節"), 1), (re.compile(r"反応が見つからない"), 1))


def _head(rule: str, width: int = 48) -> str:
    """決まりの頭の1文（太字のところ）だけ。"""
    head = re.split(r"(?<=。)", rule.replace("**", ""), maxsplit=1)[0].rstrip("。")
    return _short(head, width)


def print_hand_rules(rules: list[tuple[str, str]]) -> None:
    """表の「手」の行。台本を見せる前に答える行は番号つきで、書き出したあとの行は1行にまとめる。"""
    if not rules:
        return
    now = [r for r, _ in rules if not AFTER_BUILD.search(r)]
    later = [r for r, _ in rules if AFTER_BUILD.search(r)]
    print(f"\n■ 手で見る行（CLAUDE.md の表で「手」の{len(rules)}行。台本を見せるメッセージに、答えを1行ずつ添える）")
    for index, rule in enumerate(now, start=1):
        seen = sorted({no for pattern, no in PARTLY if pattern.search(rule)})
        mark = f"　〔一部は上の {'・'.join(map(str, seen))} が見た〕" if seen else ""
        print(f"  {index:>2}. {_head(rule)}{mark}")
    if later:
        print(f"  書き出したあと（動画を見せる前）に見る{len(later)}行: " + "／".join(_head(r, 22) for r in later))


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scripts", nargs="+", help="台本（scripts/<名前>.md）")
    ap.add_argument("--no-preview", action="store_true", help="4コマの下見（8）を飛ばす（1本で本編・ショート計1分前後）")
    ap.add_argument("--no-voicevox", action="store_true", help="読み（6）で audio_query を聞かない")
    ap.add_argument("--jobs", type=int, default=3, help="4コマの下見を並べて回す数（既定3）")
    ap.add_argument("--no-hand", action="store_true", help="最後の「手で見る行」の一覧を出さない")
    args = ap.parse_args(argv)

    from src.script_model import load_script

    began = time.perf_counter()
    scripts = []
    for raw in args.scripts:
        path = Path(raw)
        if not path.is_absolute():
            path = (Path.cwd() / path)
        if not path.exists():
            print(f"台本がありません: {raw}", file=sys.stderr)
            return 2
        if path.resolve() not in [s.resolve() for s in scripts]:
            scripts.append(path)
    import os
    os.chdir(ROOT)          # 取材メモ・台本の写真のパスは ROOT から見る（draft と同じ）
    loaded = {s.resolve(): load_script(s) for s in scripts}

    use_engine = not args.no_voicevox and _kana("テスト", 13) is not None
    known = _known_japanese()
    cross = check_cross(scripts, loaded)
    previews = {} if args.no_preview else run_previews(scripts, max(1, args.jobs))

    total_bad = total_warn = 0
    stopped = []
    for path in scripts:
        script = loaded[path.resolve()]
        items = []
        for fn in (lambda: check_draft(path, script), lambda: check_line_length(script),
                   lambda: check_wording(script), lambda: check_reactions(script),
                   lambda: check_readings(path, script, known, use_engine),
                   lambda: check_photos(path, script), lambda: check_series(path), lambda: check_flow(path)):
            try:
                items.append(fn())
            except Exception as err:      # 点検が動かないことを ✓ に見せない
                broken = Item(0, "点検が動きませんでした")
                broken.add(BAD, f"{type(err).__name__}: {err}")
                items.append(broken)
        items.append(cross.get(path, Item(5, "本と本のあいだの重なり")))
        if args.no_preview:
            skipped = Item(8, "4コマの下見", note="--no-preview で飛ばした", skipped=True)
            items.append(skipped)
        else:
            items.append(previews[path])
        bad, warn = report(path, items)
        total_bad += bad
        total_warn += warn
        if bad:
            stopped.append(path.stem)

    print(f"\n■ まとめ　{len(scripts)}本　× {total_bad}　△ {total_warn}　（{time.perf_counter() - began:.0f}秒）")
    if stopped:
        print("  × がある台本: " + "、".join(stopped) + "　→ 直してから見せる")
    else:
        print("  × はありません。△ は見て判断し、直さないものは理由を1行添える")
    if not use_engine and not args.no_voicevox:
        print("  ※ VOICEVOX（127.0.0.1:50021）が起きていないので、読みは辞書との突き合わせだけ")

    if not args.no_hand:
        print_hand_rules(hand_rules())
    return 1 if total_bad else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
