"""話と画面の一致（10-08 ユーザー指摘「会話している内容と画面の内容が合ってない」）。

見本の台本で、「京都の本能寺」と話す行に京都の町の屏風、「1568年、堺に矢銭」と話す行に長篠の屏風、
「次回は江戸の鎖国」に江戸の地図が出ていた。行ごとに、話していること（年・地名・出来事）と、
そのとき映っているもの（節の題・背景の絵の出典と絵の一覧の説明・絵の一部の名札・図・肖像の説明・札）を照らす。

- 話していること：3〜4桁の「○○年」、places.yaml の地名、出来事の語（本能寺・長篠・〜の変・〜の戦い・〜城…。
  台本の本文・節の題・用語から集める）
- 映っているもの：節の題・背景の出典・絵の一覧（research/*_assets.md の「何か」「台本で合う場面」）・
  絵の一部（detail）の名札・図の中身・肖像の説明・いまの札。年は節の題・札・図・名札からだけ取る
  （出典や肖像の「1882年」は絵を描いた年で、場面の年ではない）
- 知らせるのは、行が具体的なことを言っていて、映っているものが別のことを指しているときだけ：
  別の出来事（言った出来事が映っているものに無い）／別の場所（言った地名も出来事も映っているものに無く、
  映っているものは別の場所・出来事を指す）／別の年（映っている年と10年以上違う）。一般の話は知らせない
- 次回予告の行（「次回」を含む）は見ない（場所の地図も出さない。chiso/script.py）
"""
from __future__ import annotations

import json
import re
from pathlib import Path

YEAR_GAP = 10            # 映っている年とこれ以上違えば「別の年」
CARRY_LINES = 3          # 食い違った行のあと、画面が替わらず話が続く行もこの数まで並べる
_YEAR = re.compile(r"(?<![0-9０-９])([0-9]{3,4})年(?![代後前間分続ぶほもか])")
# 出来事の語：「本能寺の変」「長篠の戦い」「桶狭間合戦」「比叡山焼き討ち」。頭（本能寺・長篠）を鍵にする
_EVENT = re.compile(r"([一-鿿ヶ]{2,6})(?:の変(?![わえ化更身動貌])|の戦い|の乱(?![れし暴雑])|の役(?![人目割者所立柄職])|合戦"
                    r"|焼き討ち|焼討|の陣|宗論|事件|の和議)")
_LANDMARK = re.compile(r"[一-鿿]{1,4}(?:寺|城)(?![下主])")
FIXED_EVENTS = ("本能寺", "長篠", "桶狭間", "関ヶ原", "関ケ原", "比叡山")
TEASER = "次回"
# 鍵にしない語（「寺」「城」で終わるが場所を指さない・広すぎる）
NOT_EVENTS = {"お寺", "山城", "築城", "落城", "居城", "本城", "入城", "開城", "籠城", "名城", "寺城", "宮城", "大寺", "社寺",
              "寺社", "古寺", "茶城"}


def is_teaser(text: str) -> bool:
    """次回予告・締めの行（「次回は江戸の鎖国」）。話は次の回のことで、いまの画面と照らさない。"""
    return TEASER in text


# --- 絵の一覧（research/*_assets.md）-----------------------------------------------
_catalog_cache: dict | None = None


def load_catalog(research: Path) -> dict[str, tuple[str, str]]:
    """絵のファイル名 → (「何か」, 「台本で合う場面」)。一覧の表の見出しで列を探す。
    「合う場面」は使い道の案なので、地名を拾うのにだけ使う（出来事は「何か」＝描かれているものから）。"""
    out: dict[str, tuple[str, str]] = {}
    if not research.exists():
        return out
    for md in sorted(research.glob("*_assets.md")):
        cols = None
        for row in md.read_text(encoding="utf-8").splitlines():
            if not row.startswith("|"):
                continue
            cells = [c.strip() for c in row.strip().strip("|").split("|")]
            if cells and cells[0] == "ファイル名":
                cols = (cells.index("何か") if "何か" in cells else None,
                        next((i for i, c in enumerate(cells) if "合う場面" in c), None))
                continue
            if cols is None or not cells or not re.search(r"\.(jpe?g|png|webp)$", cells[0], re.I):
                continue
            out[cells[0]] = tuple(cells[i] if i is not None and i < len(cells) else "" for i in cols)
    return out


def default_catalog() -> dict[str, tuple[str, str]]:
    """config.yaml の assets_dir の隣の research/ から読む（CI には無いので空になる）。"""
    global _catalog_cache
    if _catalog_cache is None:
        try:
            import os
            import yaml
            root = Path(__file__).resolve().parent.parent
            cfg = yaml.safe_load((root / "config.yaml").read_text(encoding="utf-8")) or {}
            assets = Path(os.environ.get("CHISO_ASSETS") or (root / cfg.get("assets_dir", "")))
            _catalog_cache = load_catalog(assets.parent / "research")
        except Exception:
            _catalog_cache = {}
    return _catalog_cache


def _about(catalog: dict, image: str | None, fits: bool = False) -> str:
    """絵の一覧の説明（fits=True で「合う場面」）。"""
    if not image:
        return ""
    v = catalog.get(Path(image).name)
    if v is None:
        return ""
    if isinstance(v, str):
        return "" if fits else v
    return v[1] if fits else v[0]


# --- 語を拾う -----------------------------------------------------------------
def event_words(script) -> list[str]:
    """その回の出来事の語：決まった語（本能寺・長篠…）＋本文・節の題・用語から「〜の変」「〜の戦い」「〜合戦」の頭を拾ったもの。"""
    words = set(FIXED_EVENTS)
    for t in _texts(script):
        words.update(m.group(1) for m in _EVENT.finditer(t))
    return sorted((w for w in words if w not in NOT_EVENTS and len(w) >= 2), key=len, reverse=True)


def landmark_words(script, events: list[str]) -> list[str]:
    """その回に出る寺・城の名（坂本城・西教寺・紫禁城）。場所として扱う（出来事の語にある本能寺は除く）。"""
    words = set()
    for t in _texts(script):
        words.update(m.group(0) for m in _LANDMARK.finditer(t))
    return sorted((w for w in words if w not in NOT_EVENTS and w not in events and len(w) >= 2), key=len, reverse=True)


def _texts(script) -> list[str]:
    texts = [l.text for l in script.lines] + [s.title for s in script.sections] + _terms(script)
    return [re.sub(r"[《》]", "", t) for t in texts]


def _terms(script) -> list[str]:
    """その回に出た用語の札の言葉（terms.yaml と台本の terms:）。"""
    return list(dict.fromkeys(l.term[0] for l in script.lines if getattr(l, "term", None)))


def years_in(text: str) -> set[int]:
    return {int(m.group(1)) for m in _YEAR.finditer(text) if 500 <= int(m.group(1)) <= 2100}


def _found(text: str, words: list[str], masks: list[str] = ()) -> set[str]:
    plain = re.sub(r"[《》]", "", text)
    for m in sorted(masks, key=len, reverse=True):
        plain = plain.replace(m, "＿" * len(m))
    out = set()
    for w in words:                                          # 長い語を先に。拾った所は消す（「本能寺の変」の中の「本能寺」を二重に数えない）
        if w in plain:
            out.add(w)
            plain = plain.replace(w, "＿" * len(w))
    return out


def shown_texts(line, section_title: str, catalog: dict) -> dict[str, str]:
    """映っているものの文。scene＝節の題・背景の絵（出典と絵の一覧の「何か」）・絵の一部／over＝上に重なる肖像・札・図／
    fits＝絵の一覧の「合う場面」（地名を拾うだけ）／dated＝場面の年を読んでよい文
    （節の題・札・図・絵の一部の名札。出典や肖像の「1882年」は描いた年で、場面の年ではない）。"""
    detail = json.loads(line.detail) if getattr(line, "detail", None) else None
    scene, over, fits, dated = [section_title], [], [], [section_title]
    pics = []
    if line.background is not None:
        scene.append(line.background.credit)
        pics.append((scene, line.background.image))
    if detail:
        scene.append(detail.get("label", ""))
        dated.append(detail.get("label", ""))
        pics.append((scene, detail.get("image")))
    if line.portrait is not None:
        over.append(line.portrait.caption)
        pics.append((over, line.portrait.image))
    if line.card is not None:
        over += [line.card.head, line.card.body]
        dated += [line.card.head, line.card.body]
    if line.figure:
        fig = json.loads(line.figure)
        over.append(line.figure)
        dated.append(line.figure)
        pics += [(over, fig[k].get("image")) for k in ("left", "right") if isinstance(fig.get(k), dict)]   # 左右比べの絵
    for where, image in pics:
        where.append(_about(catalog, image))
        fits.append(_about(catalog, image, fits=True))
    join = lambda xs: "　".join(x for x in xs if x)
    return {"scene": join(scene), "over": join(over), "fits": join(fits), "dated": join(dated)}


def _meets(a: set[str], b: set[str]) -> bool:
    """同じものを指す語があるか（「四条本能寺」と「本能寺」、「江戸城」と「江戸」は同じ所）。"""
    return any(x in y or y in x for x in a for y in b)


def _in_story(years: set[int], script) -> set[int]:
    """台本の年表の範囲に入る年（「2014年の研究」「1973年の大河ドラマ」のような後の時代の話は場面の年にしない）。"""
    lo, hi = getattr(script, "timeline_start", None), getattr(script, "timeline_end", None)
    if lo is None or hi is None:
        return set(years)
    return {y for y in years if lo <= y <= hi}


def line_notes(script, catalog: dict | None = None, places: list[str] | None = None) -> list[tuple[int, str]]:
    """行ごとの食い違い [(行の番号0始まり, 理由)]。

    既存7本に掛けて決めた（10-08）。年を言わずに地名・出来事に触れるだけの行（「のちに本能寺で信長を討つ光秀」
    「ロンドンの大英博物館に」）まで数えると1本に5〜15件出て、ほとんどが話のついでの言及だった。
    そこで「年＋場所・出来事」で場面を言い出した行（「1582年6月、京都の本能寺」）だけを見る。
    場面を言い出した行が食い違っていれば、続く行も画面が替わらず別の場面を言わないあいだ（3行まで）同じ食い違いとして並べる。"""
    from .check import place_names
    from .script import ERA_TAILS
    catalog = default_catalog() if catalog is None else catalog
    events = event_words(script)
    places = (place_names() if places is None else list(places)) + landmark_words(script, events)
    places = sorted(dict.fromkeys(places), key=len, reverse=True)
    eras = [p + t for p in places for t in ERA_TAILS]
    masks = eras + [t for t in _terms(script) if t not in places]
    titles = {s.index: s.title for s in script.sections}
    summary = {s.index for s in script.sections if re.match(r"(まとめ|見立て)", s.title)}
    out = []
    carry = None                                            # (理由, 画面, 残りの行数)
    for l in script.lines:
        title = titles.get(l.section, "")
        shown = shown_texts(l, title, catalog)
        scene, over = shown["scene"], shown["over"]
        if is_teaser(l.text):
            carry = None
            continue
        said_ev = _found(l.text, events)
        said_pl = _found(l.text, places, masks + list(said_ev)) - said_ev
        said_yr = _in_story(years_in(l.text), script)
        if not (said_ev or said_pl or said_yr):
            if carry and carry[1] == (scene, over) and carry[2] > 0:   # 同じ画面のまま、前の行の話が続いている
                out.append((l.index, carry[0]))
                carry = (carry[0], carry[1], carry[2] - 1)
            else:
                carry = None
            continue
        carry = None
        if not said_yr or l.section in summary:
            continue                                          # 年を言っていない＝話のついで。まとめは年をまたいで振り返る
        said = said_ev | said_pl
        scene_ev = _found(scene, events)
        scene_pl = _found(scene + "　" + shown["fits"], places, eras) | scene_ev
        over_ev = _found(over, events)
        over_pl = _found(over, places, eras) | over_ev
        shown_yr = years_in(shown["dated"])
        title_yr = years_in(title)
        near = lambda ys: any(abs(y - s) <= 1 for y in said_yr for s in ys)
        far = lambda ys: bool(ys) and all(abs(y - s) >= YEAR_GAP for y in said_yr for s in ys)
        other_scene = bool(scene_ev) and not _meets(said, scene_pl)      # 背景は別の出来事の絵
        why = []
        if said_ev and ((not _meets(said_ev, scene_ev | over_ev) and (scene_pl or over_pl)) or other_scene):
            why.append("出来事")
        elif said_pl and (other_scene or ((scene_pl or over_pl) and not _meets(said, scene_pl | over_pl)
                                          and not near(shown_yr))):
            why.append("場所")
        if (l.section not in summary and far(title_yr)) or (far(shown_yr) and not _meets(said, scene_pl | over_pl)):
            why.append("年")
        if not why:
            continue
        what = "・".join(sorted(scene_pl) + [f"{y}年" for y in sorted(years_in(title))]) or "別のもの"
        extra = "・".join(sorted(over_pl - scene_pl) + [f"{y}年" for y in sorted(shown_yr - years_in(title))])
        if extra:
            what += f"（重ねた札・図・肖像：{extra}）"
        heard = "・".join([f"{y}年" for y in sorted(said_yr)] + sorted(said))
        reason = f"「{heard}」と話すあいだ、画面は「{what}」（{'・'.join(why)}が違う）"
        out.append((l.index, reason))
        carry = (reason, (scene, over), CARRY_LINES)
    return out


def notes(script, catalog: dict | None = None, places: list[str] | None = None) -> list[str]:
    """check に並べる知らせ。続いた行の同じ食い違いは1件に（「30〜32行目」）。"""
    from .check import span
    out, run = [], []
    for idx, why in line_notes(script, catalog, places) + [(None, None)]:
        if run and (idx != run[-1][0] + 1 or why != run[-1][1]):
            out.append(f"話と画面：{span([i + 1 for i, _ in run])}行目 {run[0][1]}"
                       "（その場面の絵に替えるか detail で寄せる。話題が節と変わったら節を分ける）")
            run = []
        if idx is not None:
            run.append((idx, why))
    return out
