"""物語完結型のショート（10-22 ユーザー決定。伸びている他チャンネルの型に作り替える）。

    python -m chiso.cli story-short scripts/story/oichi_s3.yaml [--kana] [--stills]

型：冒頭1文＝感情の結末予告／起こり→事件→結末まで50〜60秒で語り切る／画面は全面のAI人物絵＋中央に特大の1フレーズ／
3〜5秒ごとに別の絵／語りは1人（剣崎雌雄・抑えめ）／キャラ立ち絵・枠・年表・字幕の2行目は出さない／BGM・効果音なし。

台本（scripts/story/*.yaml）：行ごとに「語り」（｜で絵の替わり目を示す）と shots（使う絵）。
第3版（10-22 ユーザー「画面の文字が話している内容と違う」）：画面の中央の文字は語りの文そのもの。語りを8〜16字のかたまりに自動で分け、
VOICEVOX のモーラ長から求めた時刻に、声が言っている間だけ出す（chunk_text・mora_timeline・chunk_onsets）。要約・言い換え・省略はしない。
第2版（10-22 ユーザー「絵と話が合ってない・パラパラ漫画みたい」）：カットは kind＝real（assets の著作権切れの絵）／composite（肖像を横に並べる）／
ai（FLUX。tools/gen_story_art.py）。全カットにゆっくりした寄り・パン（毎コマ、小数点の位置で切り出すのでガタつかない）、替わり目は0.4秒の溶け合い、
全体に同じ色調補正（彩度・色味・ビネット・粒子）をかけて実在の絵と AI 絵をなじませる。
絵は tools/gen_story_art.py で作る（out/story/<名前>/NN.jpg、リポジトリには入れない）。
既存の shorts.py（本編から切り出すショート）とは別物で、本編の台本・Painter は使わない。
字形・VOICEVOX・音声のつなぎ・ffmpeg は既存（render の字体設定・voice・tts・mix・cli.encode）を使う。
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

W, H = 1080, 1920
FPS = 30
FADE = 0.4                 # 絵の替わり目の溶け合い（秒）。0.3〜0.5
ZOOM = 0.08                # 寄りの量（7%）
PAN = 0.14                 # パンの量（切り出し幅の14%）
LEAD = 0.0                 # 声は0秒から（最初の約0.2秒の無音は build で詰める）
HOOK_CLEAR = 2.5           # 最初の2.5秒は見出し帯・「AI生成画像」・出典を出さない（掴みの邪魔をしない）。そのあと0.4秒で出す
LOOP_FADE = 0.3            # 最後の0.3秒で最初の画面に溶け合い、ループがつながる
FIRST_SCALE = 1.15         # 最初のブロックだけ大きく
GAP = 0.12                 # 行と行のあいだ（第8版：もっと早口に。0.12〜0.15秒）
MIN_BLOCK = 1.0            # 1ブロックの最短の表示時間（秒）。これより短い句は隣のブロックと結ぶ（plan が声の時刻を見て結ぶ）
GAP_HEAVY = 0.15           # 重い・しみじみの行のあと
END_HOLD = 1.2             # 最後の声のあとに残す秒数（最初の0.4秒は余白＝BGM だけ、そのあと「本編は概要欄から」）
CTA_SECONDS = 0.8          # 「本編は概要欄から」を出す秒数（最後の0.8秒）
PEAK_SCALE = 1.15          # 感情の頂点の語（《!…》）の字を大きくする倍率
DIP_DEPTH = 0.55           # 頂点の直前に絵を暗くする深さ（最大）
MAX_SECONDS = 59.0         # 60秒以内で余裕1秒
IMG_MIN, IMG_MAX = 8.0, 12.0       # 1枚の絵を見せる長さの目安（8〜12秒。ユーザー 10-22「そんなに絵いらないよ」）
PHRASE_SIZES = (170, 156, 142, 128, 116)
ROW_MAX = 10               # 画面の文字は1行10字まで・2行まで（10-22 他チャンネルの調べ）
TEXT_SIZE = 86             # 1行10字が画面幅の約8割（1080×0.8÷10）
TEXT_Y = 0.66              # 文字の中心の高さ（画面の縦の割合。60〜72%）
ROW_STEP = 1.28
UNIT_FADE = 0.10           # 文節が足されるときのフェード（秒）
BLOCK_FADE = 0.20          # ブロックが丸ごと替わるフェード（秒。0.15〜0.2）
PHRASE_WIDTH = W - 120
PHRASE_CENTER_Y = int(H * 0.60)    # 中央〜やや下
WHITE, YELLOW, BLACK = (255, 255, 255), (255, 214, 0), (0, 0, 0)
AI_LABEL = "AI生成画像"
CTA_TEXT = "本編は概要欄から"
MERGE_BELOW, MERGE_MAX = 6, 16   # 6字未満の句は同じ文の隣の句とつなぎ、合わせて16字まで（1ブロックが短すぎないように。第6版）
CONJ = ("だが", "しかし", "そして", "そのとき")      # 転換の言葉は短くても1ブロックにする（前後とつなげない）
HEAD_PARTICLES = "をはがにでへのも"
BREAK_AFTER = "はがをにでともへのてた"   # 文節の切れ目になる字（この後ろで2行に分ける）
NO_HEAD = "、。，．・！？!?」』）)ーっゃゅょッャュョ…"
_EMPH = re.compile(r"《(!?)(.+?)》")          # 《語》＝黄色、《!語》＝黄色で1.15倍（感情の頂点）


# --- 台本 -----------------------------------------------------------------

@dataclass
class Unit:
    """画面に足される文節（《》つき）。声が言い始めた時刻に出て、ブロックが替わるまで残る。"""
    text: str
    row: int                # ブロックの中の何行目か（0 始まり）
    start: float = 0.0      # 話し始めの時刻（plan が入れる）


@dataclass
class Block:
    """画面に一度に出る文字のまとまり（1〜2行、1行10字まで）。語りの文の句点ごとに1〜3ブロック。"""
    rows: list              # 行ごとの Unit の並び
    shot: str = ""
    line: int = 0
    start: float = 0.0
    end: float = 0.0
    big: bool = False       # 最初のブロックだけ大きく（掴み）

    @property
    def units(self) -> list:
        return [u for r in self.rows for u in r]


@dataclass
class Part:
    """1つの絵の間に話す語り（｜で分けた断片）。"""
    shot: str
    text: str
    blocks: list


@dataclass
class Line:
    index: int
    text: str           # 読み上げる文（《》｜なし。声には強調をかけない）
    tone: str
    parts: list
    pause: float | None = None   # この行の前の間（秒）。転換の前に0.4〜0.6秒入れる
    dip: bool = False            # その間のあいだ絵を暗くする（頂点の直前）
    zoom: float | None = None    # この行から始まる絵の寄りの量（頂点で 0.14）
    boom: bool = False           # この行の頭に低い響きを入れる（転換点）
    voice: dict | None = None    # この行だけの声の上書き（例：強調行は speed を上げる）
    riser: bool = False          # 転換点（pause の前）に、上がっていく音を入れる

    @property
    def units(self) -> list:
        return [u for p in self.parts for b in p.blocks for u in b.units]


def load(path: str | Path) -> dict:
    doc = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    doc["_path"] = Path(path)
    return doc


def strip_marks(s: str) -> str:
    return s.replace("《!", "").replace("《", "").replace("》", "").replace("｜", "")


def screen_plain(s: str) -> str:
    """画面に出る字だけ（《》｜と「、」「。」を除く）。"""
    return strip_marks(s).replace("、", "").replace("。", "")


def lines_of(doc: dict) -> list[Line]:
    out = []
    for i, row in enumerate(doc["lines"]):
        texts = [t.strip() for t in str(row["語り"]).strip().split("｜")]
        ids = row.get("shots") or [row.get("shot")] * len(texts)
        if len(ids) != len(texts) or not all(ids):
            raise ValueError(f"{i + 1}行目：｜で分けた数（{len(texts)}）と shots の数（{len(ids)}）が違います")
        parts = []
        for k, t in zip(ids, texts):
            blocks = blocks_of(t)
            for b in blocks:
                b.shot, b.line = k, i
            parts.append(Part(k, t, blocks))
        out.append(Line(i, strip_marks("".join(texts)), row.get("tone", "普通"), parts, row.get("pause"),
                        bool(row.get("dip")), row.get("zoom"), bool(row.get("boom")), row.get("voice"), bool(row.get("riser"))))
    return out


def phrase_plain(phrase: str) -> tuple[str, list[bool]]:
    """《》を外した文字列と、黄色にする字の印。"""
    plain, mask, pos = "", [], 0
    for m in _EMPH.finditer(phrase):
        seg = phrase[pos:m.start()]
        plain += seg
        mask += [False] * len(seg)
        plain += m.group(2)
        mask += [2 if m.group(1) else 1] * len(m.group(2))             # 1＝黄色、2＝頂点（黄色で大きく）
        pos = m.end()
    tail = phrase[pos:]
    return plain + tail, mask + [False] * len(tail)


def mark_up(s: str, m: list[bool]) -> str:
    """字と黄色の印から《》つきの文字列に戻す。"""
    o, i = "", 0
    while i < len(s):
        if m[i]:
            j = i
            while j < len(s) and m[j] == m[i]:
                j += 1
            o += ("《!" if m[i] == 2 else "《") + s[i:j] + "》"
            i = j
        else:
            o += s[i]
            i += 1
    return o


# --- 語りを「語順に増える」ブロックに分ける ------------------------------------------

_TAGGER = None


def _tagger():
    global _TAGGER
    if _TAGGER is None:
        try:
            import fugashi
            _TAGGER = fugashi.Tagger()
        except Exception:                                   # noqa: BLE001 - 辞書が無い環境では助詞で切る
            _TAGGER = False
    return _TAGGER


def bunsetsu(piece: str) -> list[int]:
    return _protect(piece, _bunsetsu(piece))


def _bunsetsu(piece: str) -> list[int]:
    """1片（句読点を含まない文字列）の文節の切れ目（各文節の字数）。fugashi があれば品詞で、無ければ助詞の後ろで切る。"""
    tg = _tagger()
    if tg:
        sizes: list[int] = []
        prev = None
        prev_surface = ""
        for w in tg(piece):
            pos = w.feature.pos1
            dep = pos in ("助詞", "助動詞", "接尾辞", "補助記号") or (pos == "動詞" and w.feature.pos2 == "非自立可能") \
                or (pos == "形容詞" and w.feature.pos2 == "非自立可能")
            joins_noun = pos in ("名詞", "代名詞", "接頭辞") and prev in ("名詞", "代名詞", "接頭辞")
            if prev_surface in ("年", "月", "日") and w.feature.pos2 != "数詞":
                joins_noun = False                  # 「1583年4月／北ノ庄」のように年月日のあとで切る
            if sizes and (dep or joins_noun or prev == "接頭辞"):
                sizes[-1] += len(w.surface)
            else:
                sizes.append(len(w.surface))
            prev = pos
            prev_surface = w.surface
        if sum(sizes) == len(piece):
            return sizes
    sizes, cur = [], 0
    for i, ch in enumerate(piece):
        cur += 1
        if ch in "はがをにでともへのて" and i + 1 < len(piece):
            sizes.append(cur)
            cur = 0
    if cur:
        sizes.append(cur)
    return sizes


NOSPLIT = ("北ノ庄城", "小谷城", "北ノ庄", "大坂城", "高野山", "徳川秀忠", "京極高次", "柴田勝家", "浅井長政", "織田信長")   # 行の途中で割らない名前


def _protect(piece: str, sizes: list[int]) -> list[int]:
    """名前（NOSPLIT）の途中に文節の切れ目があれば、その名前が1つの文節になるようにつなぐ。"""
    for name in NOSPLIT:
        k = piece.find(name)
        while k >= 0:
            lo, hi = k, k + len(name)
            starts, pos = [], 0
            for n in sizes:
                starts.append(pos)
                pos += n
            inside = [i for i, st in enumerate(starts) if lo < st < hi]
            if inside:
                first = max(i for i, st in enumerate(starts) if st <= lo)
                last = inside[-1]
                sizes = sizes[:first] + [sum(sizes[first:last + 1])] + sizes[last + 1:]
            k = piece.find(name, k + 1)
    return sizes


def _two_rows(sizes: list[int]) -> int:
    """文節の字数の並びを2行に分ける切れ目（文節の境で、行の長さがそろう所。どちらも ROW_MAX 以内）。"""
    best = None
    for i in range(1, len(sizes)):
        l1, l2 = sum(sizes[:i]), sum(sizes[i:])
        if l1 > ROW_MAX or l2 > ROW_MAX:
            continue
        key = (max(l1, l2), abs(l1 - l2))
        if best is None or key < best[0]:
            best = (key, i)
    return best[1] if best else len(sizes) // 2


def _clause_blocks(s: str, m: list[bool]) -> list[tuple[list, ...]]:
    """1つの句（読点・句点で区切られた1片）を、1〜2行のブロックにする。1行10字まで・1ブロック20字まで。
    21字以上は文節の境でなるべく等分して複数ブロックにする。"""
    sizes = bunsetsu(s)
    fixed = []
    for n in sizes:                                         # 10字を超える文節は10字で切る
        while n > ROW_MAX:
            fixed.append(ROW_MAX)
            n -= ROW_MAX
        fixed.append(n)
    sizes = fixed
    total = len(s)

    def fits_two_rows(sz: list) -> bool:                    # 文節の境で、どちらの行も10字以内に分けられるか
        if sum(sz) <= ROW_MAX:
            return True
        i = _two_rows(sz)
        return sum(sz[:i]) <= ROW_MAX and sum(sz[i:]) <= ROW_MAX

    if (total > 2 * ROW_MAX or not fits_two_rows(sizes)) and len(sizes) > 1:      # 21字以上、または2行に収まらない句は複数のブロックに
        best = min(range(1, len(sizes)), key=lambda i: abs(sum(sizes[:i]) - total / 2))
        cut = sum(sizes[:best])
        return _clause_blocks(s[:cut], m[:cut]) + _clause_blocks(s[cut:], m[m.__len__() - (total - cut):])
    rows = [sizes] if total <= ROW_MAX else [sizes[:_two_rows(sizes)], sizes[_two_rows(sizes):]]
    out, pos = [], 0
    for r in rows:
        units = []
        for n in r:
            units.append((s[pos:pos + n], m[pos:pos + n]))
            pos += n
        out.append(units)
    return [tuple(out)]


def blocks_of(text: str) -> list[Block]:
    """語りの断片（《》・「、」「。」つき）を、画面に一度に出すブロックに分ける（10-22 第4版）。
    読点・句点で切った句を1ブロックにする（句をまたがない）。4字に満たない句（「と」など）だけは同じ文の前の句につなぐ。
    1ブロックは1〜2行・1行10字まで。2行になるときは文節の境で、行の長さがそろう所で折り返す。
    つなげると、語りから「、」「。」を除いたものと一字一句同じになる。"""
    plain, mask = phrase_plain(text)
    sentences: list[list[tuple[str, list[bool]]]] = []     # 文ごとの句
    clauses: list[tuple[str, list[bool]]] = []
    piece, pm = "", []
    for ch, on in zip(plain, mask):
        if ch in "、。":
            if piece:
                clauses.append((piece, pm))
            piece, pm = "", []
            if ch == "。" and clauses:
                sentences.append(clauses)
                clauses = []
        else:
            piece += ch
            pm.append(on)
    if piece:
        clauses.append((piece, pm))
    if clauses:
        sentences.append(clauses)
    blocks: list[Block] = []
    for sent in sentences:
        merged: list[tuple[str, list[bool]]] = []
        for s, m in sent:
            if (merged and s not in CONJ and merged[-1][0] not in CONJ and (len(s) < MERGE_BELOW or len(merged[-1][0]) < MERGE_BELOW)
                    and len(merged[-1][0]) + len(s) <= (MERGE_MAX + 4 if min(len(s), len(merged[-1][0])) < 4 else MERGE_MAX)):
                merged[-1] = (merged[-1][0] + s, merged[-1][1] + m)
            else:
                merged.append((s, m))
        for s, m in merged:
            for rows in _clause_blocks(s, m):
                blocks.append(Block([[Unit(mark_up(a, b), ri) for a, b in row] for ri, row in enumerate(rows)]))
    return blocks


def problems(doc: dict) -> list[str]:
    """台本の点検。(×)＝止める。絵は5〜7枚・AI絵は3枚まで・実在の絵には出典・画面の文字は語りと一致・1行10字以内・1ブロック2行以内。"""
    out = []
    try:
        lines = lines_of(doc)
    except ValueError as e:
        return [str(e)]
    shots = doc.get("shots", {})
    used = list(dict.fromkeys(p.shot for l in lines for p in l.parts))
    max_shots, max_ai = int(doc.get("max_shots", 7)), int(doc.get("max_ai", 3))       # 第7版：12〜14カットなので台本で広げる
    if not 5 <= len(used) <= max_shots:
        out.append(f"絵が{len(used)}枚です（5〜{max_shots}枚）")
    if sum(shots[k].get("kind", "ai") == "ai" for k in used if k in shots) > max_ai:
        out.append(f"AI絵が{max_ai}枚を超えています")
    for k in used:
        s = shots.get(k)
        if s is None:
            out.append(f"shot「{k}」の定義がありません")
            continue
        kind = s.get("kind", "ai")
        if kind == "ai" and not str(s.get("prompt", "")).strip() and not s.get("file"):
            out.append(f"絵{k}に prompt がありません")
        if kind in ("real", "composite") and not str(s.get("credit", "")).strip():
            out.append(f"絵{k}（実在の絵）に credit（出典）がありません")
        if kind == "real" and not s.get("image"):
            out.append(f"絵{k}に image がありません")
        if kind == "composite" and not s.get("images"):
            out.append(f"絵{k}に images がありません")
    total = sum(len(l.text) for l in lines)
    if not 200 <= total <= 460:
        out.append(f"語りが{total}字です（380〜450字が目安。200〜460字）")
    all_said = "".join(screen_plain(u.text) for l in lines for u in l.units)
    for spec in doc.get("cards", []) or []:
        keys = [spec.get(k) for k in ("from", "until")] + [it.get("at") for it in spec.get("items", [])]
        for key in [k for k in keys if k]:
            if key not in all_said:
                out.append(f"図解（{spec.get('type')}）の指定「{key}」が語りの中にありません")
        if spec.get("type") not in ("year", "columns", "versus", "map", "table"):
            out.append(f"図解の種類「{spec.get('type')}」が分かりません")
    first = lines[0].parts[0].blocks[0]
    if sum(len(screen_plain(u.text)) for u in first.rows[0]) > 9:
        out.append("最初のブロックの1行目が9字を超えています（掴みは短く。1.15倍の字で画面幅に収まる上限）")
    for l in lines:
        said = screen_plain("".join(p.text for p in l.parts))
        shown = "".join(screen_plain(u.text) for u in l.units)
        if said != shown:
            out.append(f"{l.index + 1}行目：画面の文字が語りと一致しません")
        for p in l.parts:
            for b in p.blocks:
                if len(b.rows) > 2:
                    out.append(f"{l.index + 1}行目：ブロックが{len(b.rows)}行です（2行まで）")
                for r in b.rows:
                    n = sum(len(screen_plain(u.text)) for u in r)
                    if n > ROW_MAX:
                        out.append(f"{l.index + 1}行目：1行が{n}字です（{ROW_MAX}字以内）")
    return out


# --- 時間割 -----------------------------------------------------------------

@dataclass
class Span:
    """同じ絵を見せ続ける区間。"""
    shot: str
    start: float
    end: float
    cuts: list          # この区間に出るブロック
    zoom: float | None = None   # この区間の寄りの量（頂点の絵だけ強める）


def dips_of(lines: list, voice: list) -> list[tuple[float, float]]:
    """頂点の直前に絵を暗くする区間（行の pause のあいだ）。(開始, 終了)。"""
    out = []
    for line, (a, _b) in zip(lines, voice):
        if line.dip and line.pause and line.index > 0:
            out.append((a - line.pause, a))
    return out


def riser_times(lines: list, voice: list) -> list[float]:
    """上がっていく音が終わる時刻：転換の行の pause の前（そこから pause のあいだ BGM を消し、行の頭で低い響き）。"""
    return [a - (line.pause or 0.0) for line, (a, _b) in zip(lines, voice) if line.riser]


def boom_times(lines: list, voice: list) -> list[float]:
    """低い響きを入れる時刻（行の頭）。"""
    return [a for line, (a, _b) in zip(lines, voice) if line.boom]


def chunk_onsets(mora_starts: list[float], counts: list[int]) -> tuple[list[float], bool]:
    """各文節の話し始めの時刻。counts＝文節ごとのモーラ数（文節だけを VOICEVOX に読ませた数）。
    全体のモーラ数と合わなければ、比例させて当てはめる（2つ目の戻り値 True＝合わなかった）。"""
    n, total = len(mora_starts), sum(counts)
    out, cum = [], 0
    for c in counts:
        idx = cum if total == n else round(cum * n / total)
        out.append(mora_starts[min(idx, n - 1)])
        cum += c
    return out, total != n


def mora_timeline(query: dict, seconds: float) -> list[tuple[float, float, str]]:
    """合成に渡した audio_query から、モーラごとの (開始, 終了, カナ)。声の長さ seconds に合わせて伸縮させる。
    VOICEVOX は子音・母音・間の長さを speedScale で割る。頭の無音（prePhonemeLength）は割らない。"""
    sp = float(query.get("speedScale") or 1.0)
    t = float(query.get("prePhonemeLength") or 0.0)
    raw = []
    for ph in query["accent_phrases"]:
        for m in ph["moras"]:
            d = ((m.get("consonant_length") or 0.0) + (m.get("vowel_length") or 0.0)) / sp
            raw.append((t, t + d, m["text"]))
            t += d
        if ph.get("pause_mora"):
            t += (ph["pause_mora"].get("vowel_length") or 0.0) / sp
    t += float(query.get("postPhonemeLength") or 0.0)
    k = seconds / t if t > 0 else 1.0
    return [(a * k, b * k, x) for a, b, x in raw]


def merge_short_blocks(lines: list, total: float, min_sec: float) -> None:
    """声の時刻から求めた表示時間が min_sec 秒に満たないブロックを、同じ絵の隣のブロックと結ぶ（1行10字・2行・20字まで）。
    前のブロックと先に、無理なら次のブロックと結ぶ。結べなければそのまま（読点・句点を優先した区切りは保つ）。"""
    changed = True
    while changed:
        changed = False
        flat = [(p, bi, b) for l in lines for p in l.parts for bi, b in enumerate(p.blocks)]
        for k, (p, bi, b) in enumerate(flat):
            end = flat[k + 1][2].units[0].start if k + 1 < len(flat) else total
            if end - b.units[0].start >= min_sec:
                continue
            for j in (bi - 1, bi + 1):
                if not 0 <= j < len(p.blocks):
                    continue
                first, second = (p.blocks[j], b) if j < bi else (b, p.blocks[j])
                units = first.units + second.units
                sizes = [len(screen_plain(u.text)) for u in units]
                if sum(sizes) > 2 * ROW_MAX:
                    continue
                n1 = sum(len(screen_plain(u.text)) for u in first.units)
                if sum(sizes) <= ROW_MAX:
                    rows = [units]
                elif n1 <= ROW_MAX and sum(sizes) - n1 <= ROW_MAX:
                    rows = [first.units, second.units]               # 結ぶ2つのブロックを、そのまま上下の行にする（句の切れ目を保つ）
                else:
                    cut = _two_rows(sizes)
                    if sum(sizes[:cut]) > ROW_MAX or sum(sizes[cut:]) > ROW_MAX:
                        continue
                    rows = [units[:cut], units[cut:]]
                for ri, row in enumerate(rows):
                    for u in row:
                        u.row = ri
                lo = min(bi, j)
                p.blocks[lo:lo + 2] = [Block(rows, first.shot, first.line, first.start, 0.0)]
                changed = True
                break
            if changed:
                break


def plan(lines: list[Line], seconds: list[float], onsets: list[list[float]] | None = None, min_block: float = MIN_BLOCK):
    """(各行の声の (開始, 終了), ブロック, 絵の区間, 全体の長さ)。

    onsets[行][文節] = その行の声の頭から数えた、文節の話し始め（chunk_onsets）。省くと字数に比例（声を作らない確認用）。
    文節は話し始めに足され、ブロックが替わるまで残る。ブロックの開始＝その最初の文節の話し始め（間が空いても前のブロックが残る）。
    絵の替わり目は、行をまたぐときは行のあいだの真ん中、行の中（｜）ならそのブロックの話し始め。"""
    voice, t, prev = [], LEAD, None
    for line, sec in zip(lines, seconds):
        if prev is not None:
            t = voice[-1][1] + (line.pause if line.pause is not None else (GAP_HEAVY if prev.tone in ("重い", "しみじみ") else GAP))
        voice.append((t, t + sec))
        prev = line
    total = round(voice[-1][1] + END_HOLD, 3)
    blocks: list[Block] = []
    part_first: list[tuple[int, int]] = []              # (ブロック番号, 行番号)
    for i, line in enumerate(lines):
        a, b = voice[i]
        units = line.units
        if onsets is None:
            lens = [len(screen_plain(u.text)) for u in units]
            acc, rel = 0, []
            for n in lens:
                rel.append((b - a) * acc / sum(lens))
                acc += n
        else:
            rel = onsets[i]
        for u, r in zip(units, rel):
            u.start = a + r
    if min_block > 0:
        merge_short_blocks(lines, total, min_block)
    for i, line in enumerate(lines):
        for p in line.parts:
            part_first.append((len(blocks), i))
            for blk in p.blocks:
                blk.start = blk.units[0].start
                blocks.append(blk)
    blocks[0].start = 0.0
    blocks[0].units[0].start = 0.0
    blocks[0].big = True
    for k, blk in enumerate(blocks):
        blk.end = blocks[k + 1].start if k + 1 < len(blocks) else total
    spans: list[Span] = []
    for n, (k, i) in enumerate(part_first):
        first_of_line = k == 0 or blocks[k - 1].line != i
        start = 0.0 if k == 0 else ((voice[i - 1][1] + voice[i][0]) / 2 if first_of_line else blocks[k].start)
        nxt = part_first[n + 1][0] if n + 1 < len(part_first) else len(blocks)
        shot = blocks[k].shot
        if spans and spans[-1].shot == shot:
            spans[-1].cuts += blocks[k:nxt]
            continue
        spans.append(Span(shot, start, 0.0, list(blocks[k:nxt]), lines[i].zoom))
    for n, sp in enumerate(spans):
        sp.end = spans[n + 1].start if n + 1 < len(spans) else total
    return voice, blocks, spans, total


# --- 絵 -------------------------------------------------------------------

def trim_bars(im: Image.Image) -> Image.Image:
    """生成した絵の上下左右の白い帯を切る（FLUX がときどき付ける）。"""
    import numpy as np
    a = np.asarray(im.convert("L"), dtype=float)
    rows, cols = a.mean(1), a.mean(0)
    def edge(v):
        return next((i for i, x in enumerate(v) if x < 235), 0)
    t, b, l, r = edge(rows), edge(rows[::-1]), edge(cols), edge(cols[::-1])
    if max(t, b, l, r) < 6:
        return im
    pad = 4
    return im.crop((l + pad if l else 0, t + pad if t else 0, im.width - (r + pad if r else 0), im.height - (b + pad if b else 0)))


def crop_vertical(im: Image.Image) -> Image.Image:
    """正方形の絵の中央を縦 9:16 に切って 1080x1920 にする。"""
    im = trim_bars(im.convert("RGB"))
    w, h = im.size
    cw = min(w, int(h * W / H))
    x0 = (w - cw) // 2
    im = im.crop((x0, 0, x0 + cw, h)).resize((W, H), Image.LANCZOS)
    return ImageEnhance.Sharpness(im).enhance(1.25)


def shade(im: Image.Image) -> Image.Image:
    """文字が読めるように、フレーズの帯だけ少し暗くする（絵は動かさない・全面のまま）。"""
    lin = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(lin)
    top, bot = int(H * 0.43), int(H * 0.78)
    for y in range(top, bot):
        k = 1 - abs((y - (top + bot) / 2) / ((bot - top) / 2))
        d.line([(0, y), (W, y)], fill=int(110 * min(1.0, k * 1.6)))
    dark = Image.new("RGB", (W, H), (8, 6, 4))
    return Image.composite(dark, im, lin)


# --- 文字 -----------------------------------------------------------------

def split_rows(plain: str, mask: list[bool], font) -> list[tuple[str, list[bool]]]:
    """フレーズを2行に。幅が釣り合い、黄色と白の境で切れ、1字だけの行を作らない所で切る。"""
    best = None
    for k in range(1, len(plain)):
        if plain[k] in NO_HEAD:
            continue
        cost = max(font.getlength(plain[:k]), font.getlength(plain[k:]))
        if mask[k - 1] and mask[k]:
            cost += 250                      # 黄色の語の途中
        if mask[k - 1] != mask[k]:
            cost -= 60                       # 色の境
        if plain[k - 1] not in BREAK_AFTER:
            cost += 600                      # 語の途中（助詞・「た」の後ろ以外）では切らない（10-22「江は徳／川の側に」）
        if plain[k] in HEAD_PARTICLES:
            cost += 600                      # 助詞で行を始めない（「を悔やんでいた」）
        if k < 2 or len(plain) - k < 2:
            cost += 300
        if best is None or cost < best[0]:
            best = (cost, k)
    k = best[1]
    return [(plain[:k], mask[:k]), (plain[k:], mask[k:])]


def phrase_layout(phrase: str, font_of) -> tuple[int, list]:
    """1行で特大に収まればそのまま、収まらなければ2行にして収まる最大の大きさ。"""
    plain, mask = phrase_plain(phrase)
    for size in PHRASE_SIZES[:2]:                  # 1行は特大（156 以上）のときだけ。それ以下なら2行にして大きく
        if font_of(size).getlength(plain) <= PHRASE_WIDTH:
            return size, [(plain, mask)]
    for size in PHRASE_SIZES:
        f = font_of(size)
        rows = split_rows(plain, mask, f)
        if all(f.getlength(r) <= PHRASE_WIDTH for r, _ in rows):
            return size, rows
    return PHRASE_SIZES[-1], split_rows(plain, mask, font_of(PHRASE_SIZES[-1]))


def draw_phrase(img: Image.Image, phrase: str, font_of, center_y: int = PHRASE_CENTER_Y) -> None:
    """中央〜やや下に特大の太いゴシック。白＋黒の縁取り、強調語だけ黄。"""
    size, rows = phrase_layout(phrase, font_of)
    f = font_of(size)
    step = int(size * 1.18)
    top = center_y - step * len(rows) / 2
    sw = max(8, size // 14)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for pass_ in ("stroke", "fill"):
        for i, (row, mask) in enumerate(rows):
            x = W / 2 - f.getlength(row) / 2
            y = top + step * i
            for ch, on in zip(row, mask):
                if pass_ == "stroke":
                    d.text((x + 4, y + 6), ch, font=f, fill=(0, 0, 0, 150), stroke_width=sw, stroke_fill=(0, 0, 0, 150))
                    d.text((x, y), ch, font=f, fill=BLACK + (255,), stroke_width=sw, stroke_fill=BLACK + (255,))
                else:
                    d.text((x, y), ch, font=f, fill=(YELLOW if on else WHITE) + (255,))
                x += f.getlength(ch)
    img.paste(layer, (0, 0), layer)


def draw_label(img: Image.Image, font_of, y: int = 40, right: bool = False) -> None:
    f = font_of(30)
    tw = int(f.getlength(AI_LABEL))
    d = ImageDraw.Draw(img, "RGBA")
    x0 = W - 28 - tw - 32 if right else 28                      # 「いま」の札が左にあるときは右寄せ
    d.rounded_rectangle([x0, y, x0 + tw + 32, y + 52], radius=10, fill=(0, 0, 0, 130))
    d.text((x0 + 16, y + 26), AI_LABEL, font=f, fill=(255, 255, 255, 235), anchor="lm")


def draw_cta(img: Image.Image, font_of, y: int | None = None) -> None:
    f = font_of(62)
    tw = int(f.getlength(CTA_TEXT))
    d = ImageDraw.Draw(img, "RGBA")
    y = int(H * 0.80) if y is None else y
    d.rounded_rectangle([W / 2 - tw / 2 - 36, y, W / 2 + tw / 2 + 36, y + 110], radius=55, fill=(0, 0, 0, 150),
                        outline=(255, 255, 255, 220), width=3)
    d.text((W / 2, y + 55), CTA_TEXT, font=f, fill=(255, 255, 255, 255), anchor="mm")


def make_font_of(fonts: dict):
    cache = {}

    def font_of(size: int):
        if size not in cache:
            f = ImageFont.truetype(fonts["gothic"], size)
            try:
                f.set_variation_by_name("Bold")
            except Exception:
                pass
            cache[size] = f
        return cache[size]
    return font_of


# --- 切り出しと動き ------------------------------------------------------------

def _ease(u: float) -> float:
    u = min(1.0, max(0.0, u))
    return u * u * (3 - 2 * u)


def motion(move: str, u: float, zoom: float = ZOOM, ease: str = "") -> tuple[float, float, float]:
    """絵の進み u（0〜1）から (寄り倍率, 窓の横ずれ, 縦ずれ)。ずれは窓の幅・高さに対する割合。
    ゆっくり一定の速さ（線形）。in/out＝寄り・引き、left/right/up/down＝絵が左・右・上・下へ流れるパン。"""
    u = min(1.0, max(0.0, u))
    if ease == "fast":                      # 最初の数秒で寄りを効かせる（掴み）
        u = 1 - (1 - u) ** 1.9
    if move == "out":
        return 1 + zoom * (1 - u), 0.0, 0.0
    if move in ("left", "right", "up", "down"):
        s = -PAN / 2 + PAN * u
        sign = {"left": 1, "up": 1, "right": -1, "down": -1}[move]
        z = 1 + zoom * 0.7
        return (z, sign * s, 0.0) if move in ("left", "right") else (z, 0.0, sign * s)
    return 1 + zoom * u, 0.0, 0.0          # in（既定）


def cover_window(sw: float, sh: float, focus, zoom: float, dx: float = 0.0, dy: float = 0.0):
    """元絵（sw x sh）の中の縦 9:16 の切り出し窓 (x0, y0, x1, y1)（小数のまま。Image.transform が補間する）。"""
    if sw / sh > W / H:
        wh, ww = sh, sh * W / H
    else:
        ww, wh = sw, sw * H / W
    ww, wh = ww / zoom, wh / zoom
    cx = min(max(focus[0] * sw + dx * ww, ww / 2), sw - ww / 2)
    cy = min(max(focus[1] * sh + dy * wh, wh / 2), sh - wh / 2)
    return (cx - ww / 2, cy - wh / 2, cx + ww / 2, cy + wh / 2)


def _fit_cell(im: Image.Image, cw: int, ch: int, focus=(0.5, 0.5)) -> Image.Image:
    """cw x ch の枠いっぱいに（はみ出す所は切る）。"""
    s = max(cw / im.width, ch / im.height)
    r = im.resize((max(cw, round(im.width * s)), max(ch, round(im.height * s))), Image.LANCZOS)
    x0 = min(max(int(focus[0] * r.width - cw / 2), 0), r.width - cw)
    y0 = min(max(int(focus[1] * r.height - ch / 2), 0), r.height - ch)
    return r.crop((x0, y0, x0 + cw, y0 + ch))


def _frac_crop(im: Image.Image, crop) -> Image.Image:
    if not crop:
        return im
    x0, y0, x1, y1 = crop
    return im.crop((int(x0 * im.width), int(y0 * im.height), int(x1 * im.width), int(y1 * im.height)))


USE_PLACEHOLDER = False       # build(draft=True) のあいだだけ True
PLACEHOLDERS_USED: list = []


def load_source(shot: dict, key: str, assets: Path, art_dir: Path, font_of) -> Image.Image:
    """絵の元（RGB）。real＝assets の絵を crop、composite＝肖像を横に並べた縦長の画面、ai＝生成した絵（art_dir/<key>.jpg）。"""
    kind = shot.get("kind", "ai")
    if kind == "real":
        im = Image.open(assets / shot["image"]).convert("RGB")
        return _frac_crop(im, shot.get("crop"))
    if kind == "composite":
        items = shot["images"]
        n = len(items)
        gap = 14
        cw = (W - 60 - gap * (n - 1)) // n
        ch = 900
        canvas = Image.new("RGB", (W, H), (26, 20, 14))
        d = ImageDraw.Draw(canvas)
        label_font = font_of(60 if n <= 2 else 54)
        for i, it in enumerate(items):
            im = _frac_crop(Image.open(assets / it["image"]).convert("RGB"), it.get("crop"))
            cell = _fit_cell(im, cw, ch, it.get("focus", (0.5, 0.5)))
            x = 30 + i * (cw + gap)
            canvas.paste(cell, (x, 200))
            d.rectangle([x - 3, 197, x + cw + 2, 200 + ch + 2], outline=(200, 160, 70), width=3)
            d.text((x + cw / 2, 200 + ch + 62), it["label"], font=label_font, fill=WHITE, anchor="mm",
                   stroke_width=5, stroke_fill=BLACK)
        return canvas
    path = art_dir.parent / shot["file"] if shot.get("file") else art_dir / f"{key}.jpg"      # file: oichi3/P1.jpg（out/story から）
    if not path.exists():
        ph = shot.get("placeholder")
        if not (ph and USE_PLACEHOLDER):
            raise FileNotFoundError(f"絵がありません: {path}（tools/gen_story_art.py で作る。確認用は --draft で仮の絵を使う）")
        PLACEHOLDERS_USED.append(key)                       # 絵が届くまでの仮置き（確認用の書き出しだけ）
        if str(ph).startswith("assets:"):
            return _frac_crop(Image.open(assets / str(ph)[7:]).convert("RGB"), shot.get("placeholder_crop"))
        path = art_dir.parent / ph
    return trim_bars(Image.open(path).convert("RGB"))


def _prescale(im: Image.Image) -> Image.Image:
    """窓の高さが画面の2.2倍を超える大きい絵は先に縮める（EXTENT の補間は縮小の平均を取らないので、縮めすぎるとちらつく）。"""
    wh = im.height if im.width / im.height > W / H else im.width * H / W
    lim = 2.2 * H
    if wh <= lim:
        return im
    s = lim / wh
    return im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)


# --- 色調補正（実在の絵と AI 絵をなじませる。全カット同じ）---------------------------------

class Grade:
    SAT = 0.84
    TONE = (1.04, 0.975, 0.88)       # 夕暮れのくすんだ暖色
    CONTRAST = 1.06
    GRAIN = 0.032
    VIGNETTE = 0.30

    def __init__(self):
        import numpy as np
        self.np = np
        yy, xx = np.mgrid[0:H, 0:W].astype("float32")
        r = ((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2
        self.vig = (1 - self.VIGNETTE * np.clip(r / 2, 0, 1) ** 1.2)[..., None].astype("float32")
        rng = np.random.default_rng(7)
        self.noise = [rng.standard_normal((H, W, 1)).astype("float32") for _ in range(6)]
        # フレーズの帯だけ少し暗く（文字が読めるように）
        band = np.zeros(H, dtype="float32")
        top, bot = int(H * 0.40), int(H * 0.86)
        k = 1 - np.abs((np.arange(top, bot) - (top + bot) / 2) / ((bot - top) / 2))
        band[top:bot] = 0.30 * np.clip(k * 1.6, 0, 1)
        self.band = (1 - band)[:, None, None]

    def __call__(self, im: Image.Image, n: int) -> Image.Image:
        np = self.np
        a = np.asarray(im, dtype="float32") / 255.0
        g = (a * np.array([0.299, 0.587, 0.114], dtype="float32")).sum(axis=2, keepdims=True)
        a = g + (a - g) * self.SAT
        a = a * np.array(self.TONE, dtype="float32")
        a = (a - 0.5) * self.CONTRAST + 0.5
        a = a * self.vig * self.band + self.noise[n % len(self.noise)] * self.GRAIN
        return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype("uint8"))


# --- 画面 -------------------------------------------------------------------

def _wrap_text(text: str, font, width: int) -> list[str]:
    rows, cur = [], ""
    for ch in text:
        if font.getlength(cur + ch) > width and cur:
            rows.append(cur)
            cur = ch
        else:
            cur += ch
    return rows + ([cur] if cur else [])


def draw_credit(img: Image.Image, text: str, font_of, y1: int = 1736) -> None:
    """実在の絵の出典（画面の隅に小さく）。y1 は下端。"""
    f = font_of(26)
    rows = _wrap_text(text, f, W - 100)[:3]
    w = int(max(f.getlength(r) for r in rows)) + 32
    h = 38 * len(rows) + 16
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([24, y1 - h, 24 + w, y1], radius=10, fill=(0, 0, 0, 125))
    for i, r in enumerate(rows):
        d.text((40, y1 - h + 8 + 38 * i + 19), r, font=f, fill=(255, 255, 255, 225), anchor="lm")


def _fade_layer(layer: Image.Image, a: float) -> Image.Image:
    a = min(1.0, max(0.0, a))
    if a >= 0.999:
        return layer
    r, g, b, al = layer.split()
    return Image.merge("RGBA", (r, g, b, al.point(lambda v: int(v * a))))


# --- 図解（見出し帯・年号カード・数の対比カード・列が増えるカード）-------------------------------
# 10-22 ユーザー「honto のような視覚的に分かりやすいのはいいね」。絵の上に重ねる。台本の header: と cards: で指定する。
#   header: {tag: 小さい赤札の字, title: 題（《》は赤）}                     … 動画の間ずっと上部に出る見出し帯
#   cards:
#     - {type: year, from: "語りの中の字", until: "語りの中の字", big: 1615年, sub: 大坂夏の陣, text_y: 0.82}
#     - {type: columns, from: ..., until: ..., items: [{at: "語りの中の字", head: 茶々, text: 豊臣秀吉の妻}, ...]}
#     - {type: versus, from: ..., until: ..., left: {tag, big, dots, color: blue}, right: {tag, big, dots, color: red}, mid: 対}
#   from / until は語り（句読点を除いた全文）の中の字。その文節が話し始められる時刻に出入りする（語りと同じ時刻）。
#   text_y を書くと、そのカードが出ている間は語りの文字をその高さ（画面の縦の割合）に下げて、カードと重ならないようにする。
RED, RED_TEXT, BLUE = (200, 35, 40), (255, 80, 80), (40, 90, 200)
CARD_FADE = 0.20           # 図解が出入りするフェード（秒）
UNDERLINE_SECONDS = 0.40   # 赤い下線が左から引かれる時間
HEADER_H = 140


def red_marked(draw, x: float, y: float, text: str, font, fill=WHITE, red=RED_TEXT, stroke=0, anchor="lm") -> float:
    """《》の語だけ赤にして1行描く（x は左端）。右端の x を返す。"""
    plain, mask = phrase_plain(text)
    for ch, on in zip(plain, mask):
        draw.text((x, y), ch, font=font, fill=red if on else fill, anchor=anchor,
                  stroke_width=stroke, stroke_fill=BLACK)
        x += font.getlength(ch)
    return x


def draw_header(layer: Image.Image, header: dict, font_of) -> None:
    """上部の固定の見出し帯：小さい赤札＋題（《》の語だけ赤）。「実」の角印は付けない（伝承が混じるため）。"""
    d = ImageDraw.Draw(layer, "RGBA")
    for y in range(HEADER_H):                                   # 上から消える暗い帯（絵の上でも読める）
        a = int(150 * (1 - y / HEADER_H) ** 0.8)
        d.line([(0, y), (W, y)], fill=(8, 6, 4, a))
    tf = font_of(28)
    tw = int(tf.getlength(header["tag"])) + 30
    d.rounded_rectangle([36, 34, 36 + tw, 74], radius=7, fill=RED + (255,))
    d.text((36 + tw / 2, 54), header["tag"], font=tf, fill=WHITE, anchor="mm")
    red_marked(d, 36, 108, header["title"], font_of(50), stroke=4)


def _centered(d, cx: float, y: float, text: str, font, fill=WHITE, stroke=6) -> None:
    d.text((cx, y), text, font=font, fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=BLACK)


def card_year(img: Image.Image, spec: dict, t: float, t0: float, font_of) -> None:
    """年号カード：半透明の下地に特大の年号、赤い下線が左から引かれ、下に小さく呼び名。"""
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([50, 350, W - 50, 870], radius=26, fill=(10, 8, 6, 150))
    _centered(d, W / 2, 550, spec["big"], font_of(250), stroke=10)
    p = _ease((t - t0 - 0.12) / UNDERLINE_SECONDS)
    x0, x1 = 130, W - 130
    d.rounded_rectangle([x0, 696, x0 + max(1, (x1 - x0) * p), 710], radius=7, fill=RED + (255,))
    if spec.get("sub"):
        _centered(d, W / 2, 780, spec["sub"], font_of(58), stroke=4)


def draw_now(font_of, text: str) -> Image.Image:
    """見出し帯のすぐ下・左寄せの「いま」の札：赤い「いま」と、いまの年・場所。"""
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay, "RGBA")
    f, tf = font_of(36), font_of(26)
    tw = int(f.getlength(text))
    y = HEADER_H + 8
    d.rounded_rectangle([28, y, 28 + 96 + tw + 28, y + 56], radius=12, fill=(8, 6, 4, 165))
    d.rounded_rectangle([36, y + 8, 36 + 74, y + 48], radius=8, fill=RED + (255,))
    d.text((36 + 37, y + 28), "いま", font=tf, fill=WHITE, anchor="mm")
    d.text((36 + 74 + 14, y + 29), text, font=f, fill=WHITE, anchor="lm", stroke_width=3, stroke_fill=BLACK)
    return lay


def draw_timeline_bar(font_of, labels: list, active: int) -> Image.Image:
    """「いま」の札の下の小さな年表：「●1573 小谷 ─ ●1583 北ノ庄 ─ ●1615 大坂」。いまの場面の点と字が黄色に光る（ほかは白）。"""
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay, "RGBA")
    f = font_of(26)
    y = HEADER_H + 8 + 56 + 14 + 20                  # 札（高さ56）の下
    widths = [int(f.getlength(lab)) for lab in labels]
    total_w = sum(widths) + 28 * len(labels) + 70 * (len(labels) - 1) + 24
    d.rounded_rectangle([28, y - 22, 28 + total_w, y + 22], radius=12, fill=(8, 6, 4, 150))
    x = 44
    for i, (lab, wd) in enumerate(zip(labels, widths)):
        on = i == active
        r = 9 if on else 6
        d.ellipse([x - r, y - r, x + r, y + r], fill=(YELLOW if on else (255, 255, 255)) + (255 if on else 200,), outline=BLACK + (255,), width=2)
        d.text((x + 16, y + 1), lab, font=f, fill=(YELLOW if on else (255, 255, 255)) + (255 if on else 210,), anchor="lm",
               stroke_width=3, stroke_fill=BLACK)
        x += 16 + wd + 14
        if i + 1 < len(labels):
            d.line([(x, y), (x + 56, y)], fill=(255, 255, 255, 150), width=3)
            x += 70
    return lay



# ---- 第10版：上の常時表示の3案（台本の header_style: A / B / C。書かなければ B。v9 で第9版の小さい形） ----
HEADER_STYLE = "B"                                # 既定は案B（10-24 ユーザー「bかなー」）
TITLE_MAX_W = int(W * 0.80)                       # 上の字は画面の幅の8割まで（超えたら2行）


def _title_rows(title: str, font) -> list[str]:
    """題を1行で幅の8割に収まらなければ「、」の後ろで2行に（無ければ真ん中で）。《》は行をまたがない所で切る。"""
    plain = screen_plain(title)
    if font.getlength(plain) <= TITLE_MAX_W:
        return [title]
    i = title.find("、")
    if i < 0:
        i = len(title) // 2
    return [title[:i + 1], title[i + 1:]]


def _row_width(text: str, font) -> float:
    return font.getlength(screen_plain(text))


def _bar_strip(d, font_of, labels: list, active: int, x: float, y: float, size: int, max_w: float | None = None,
               box: bool = True) -> float:
    """年表のバーを (x, y) を左・縦の中心に描く。幅が max_w を超えるならつなぎの線を縮める。右端の x を返す。"""
    f = font_of(size)
    widths = [f.getlength(lab) for lab in labels]
    r_on, r_off = round(size * 0.36), round(size * 0.24)
    gap = size * 0.6                                         # 点と字のあいだ
    link = size * 2.0                                        # つなぎの線
    def total(link_):
        return sum(widths) + (r_on * 2 + gap) * len(labels) + (link_ + size * 0.7) * (len(labels) - 1) + size * 0.9
    if max_w and total(link) > max_w:
        link = max(size * 0.6, link - (total(link) - max_w) / max(1, len(labels) - 1))
    tw = total(link)
    if box:
        d.rounded_rectangle([x, y - size * 0.85, x + tw, y + size * 0.85], radius=round(size * 0.45), fill=(8, 6, 4, 160))
    cx = x + size * 0.45 + r_on
    sw = max(3, size // 9)
    for i, (lab, wd) in enumerate(zip(labels, widths)):
        on = i == active
        r = r_on if on else r_off
        d.ellipse([cx - r, y - r, cx + r, y + r], fill=(YELLOW if on else (255, 255, 255)) + (255 if on else 200,),
                  outline=BLACK + (255,), width=2)
        d.text((cx + r_on + gap * 0.5, y + 1), lab, font=f, fill=(YELLOW if on else (255, 255, 255)) + (255 if on else 215,),
               anchor="lm", stroke_width=sw, stroke_fill=BLACK)
        cx += r_on + gap * 0.5 + wd + size * 0.35
        if i + 1 < len(labels):
            d.line([(cx, y), (cx + link, y)], fill=(255, 255, 255, 160), width=max(3, size // 10))
            cx += link + size * 0.35 + r_on
    return x + tw


def _now_badge(d, font_of, x: float, y: float, text: str, size: int, box: bool = True) -> float:
    """「いま」の赤い札＋年・場所を (x, y) を左上に描く。高さは size*1.55。右端の x を返す。"""
    f, tf = font_of(size), font_of(round(size * 0.72))
    h = round(size * 1.55)
    bw = round(size * 2.05)
    tw = f.getlength(text)
    x1 = x + size * 0.25 + bw + size * 0.4 + tw + size * 0.6
    if box:
        d.rounded_rectangle([x, y, x1, y + h], radius=round(size * 0.33), fill=(8, 6, 4, 170))
    bx = x + size * 0.25
    d.rounded_rectangle([bx, y + h * 0.15, bx + bw, y + h * 0.85], radius=round(size * 0.22), fill=RED + (255,))
    d.text((bx + bw / 2, y + h / 2), "いま", font=tf, fill=WHITE, anchor="mm")
    d.text((bx + bw + size * 0.4, y + h / 2 + 1), text, font=f, fill=WHITE, anchor="lm", stroke_width=max(3, size // 12),
           stroke_fill=BLACK)
    return x1


class Overlay:
    """上の常時表示（見出し・「いま」の札・年表のバー）の案ごとの描き方と、ほかの物の逃がし方。
    style: 省略＝B（既定）／v9＝第9版の小さい形／A＝第9版の配置で字を1.5倍／B＝黒い太帯に大きな2行の題、帯の下に「いま」とバーを1行／
    C＝帯なし。題だけ白い縁取りで大きく2行、「いま」は左上の小さな札、バーは下（出典の上）。"""

    def __init__(self, style, header: dict | None, font_of, labels: list):
        st = str(style or HEADER_STYLE).upper()
        self.style = None if st in ("9", "V9") or not header else st   # "v9" と書けば第9版の小さい形。見出しの無い台本（第8版まで）は今までどおり
        self.header, self.font_of, self.labels = header, font_of, labels
        s = self.style
        # 図解カードを下げる量・語りの文字の下限（中心の y の上限）・出典の下端・「AI生成画像」の位置・CTA の y
        self.card_dy = {"A": 175, "B": 105, "C": 35}.get(s, 0)
        self.text_y_max = 0.74 if s == "C" else None
        self.credit_y1 = 1840 if s == "C" else 1736
        self.label_y = {"A": 30, "B": 30, "C": 24}.get(s)
        self.cta_y = 1700 if s == "C" else int(H * 0.80)

    def header_layer(self) -> Image.Image | None:
        if not self.header:
            return None
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        if self.style is None:
            draw_header(lay, self.header, self.font_of)
            return lay
        d = ImageDraw.Draw(lay, "RGBA")
        tag, title = self.header["tag"], self.header["title"]
        if self.style == "A":
            for y in range(300):                                          # 上から消える暗い帯（第9版と同じ形で高さを合わせる）
                a = int(170 * (1 - y / 300) ** 0.7)
                d.line([(0, y), (W, y)], fill=(8, 6, 4, a))
            tf = self.font_of(42)
            tw = int(tf.getlength(tag)) + 44
            d.rounded_rectangle([36, 30, 36 + tw, 92], radius=10, fill=RED + (255,))
            d.text((36 + tw / 2, 61), tag, font=tf, fill=WHITE, anchor="mm")
            f = self.font_of(76)
            for i, row in enumerate(_title_rows(title, f)):
                red_marked(d, 36, 152 + 88 * i, row, f, stroke=6)
        elif self.style == "B":
            d.rectangle([0, 0, W, 312], fill=(6, 5, 4, 238))                # 黒い太帯（不透明に近い）
            d.rectangle([0, 312, W, 318], fill=RED + (255,))
            tf = self.font_of(40)
            tw = int(tf.getlength(tag)) + 40
            d.rounded_rectangle([40, 28, 40 + tw, 86], radius=8, fill=RED + (255,))
            d.text((40 + tw / 2, 57), tag, font=tf, fill=WHITE, anchor="mm")
            f = self.font_of(104)
            for i, row in enumerate(_title_rows(title, f)):
                x = (W - _row_width(row, f)) / 2
                red_marked(d, x, 146 + 102 * i, row, f, stroke=0)
        elif self.style == "C":
            f = self.font_of(100)
            for i, row in enumerate(_title_rows(title, f)):
                plain = screen_plain(row)
                x = (W - f.getlength(plain)) / 2
                y = 160 + 108 * i
                d.text((x + 4, y + 6), plain, font=f, fill=(0, 0, 0, 120), anchor="lm", stroke_width=12, stroke_fill=(0, 0, 0, 120))
                d.text((x, y), plain, font=f, fill=WHITE, anchor="lm", stroke_width=10, stroke_fill=BLACK)
        return lay

    def now_layer(self, text: str) -> Image.Image:
        if self.style is None:
            return draw_now(self.font_of, text)
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay, "RGBA")
        if self.style == "A":
            _now_badge(d, self.font_of, 28, 290, text, 54)
        elif self.style == "B":
            d.rectangle([0, 318, W, 400], fill=(8, 6, 4, 175))          # 帯の下の細い段（「いま」とバーを1行に）
            right = _now_badge(d, self.font_of, 30, 330, text, 36, box=False)
            self.now_right = max(getattr(self, "now_right", 0), right)       # バーはいちばん長い「いま」の右から
        elif self.style == "C":
            _now_badge(d, self.font_of, 24, 24, text, 32)
        return lay

    def bar_layer(self, active: int) -> Image.Image:
        if self.style is None:
            return draw_timeline_bar(self.font_of, self.labels, active)
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay, "RGBA")
        if self.style == "A":
            _bar_strip(d, self.font_of, self.labels, active, 28, 290 + 84 + 18 + 34, 40, max_w=TITLE_MAX_W)
        elif self.style == "B":
            years = [lab.split()[0] for lab in self.labels]                # 1行に収めるため年だけ
            room = W - 30 - (getattr(self, "now_right", 500) + 64)
            tmp = Image.new("RGBA", (W, 200), (0, 0, 0, 0))
            right = _bar_strip(ImageDraw.Draw(tmp, "RGBA"), self.font_of, years, active, 0, 100, 32, max_w=room, box=False)
            _bar_strip(d, self.font_of, years, active, W - 30 - right, 358, 32, max_w=room, box=False)
        elif self.style == "C":
            tmp = Image.new("RGBA", (W, 200), (0, 0, 0, 0))
            right = _bar_strip(ImageDraw.Draw(tmp, "RGBA"), self.font_of, self.labels, active, 0, 100, 36, max_w=TITLE_MAX_W)
            _bar_strip(d, self.font_of, self.labels, active, (W - right) / 2, 1640, 36, max_w=TITLE_MAX_W)
        return lay



def card_rows(img: Image.Image, spec: dict, times: list, t: float, font_of) -> None:
    """年表カード（2〜3行）：「1573年 小谷城（夫・浅井長政）落城」のような行が、語りに合わせて1行ずつ出る。
    台本：{type: table, from, until, items: [{at: 語りの中の字, text: 行の字}, ...], title: 表の題（省略可）}"""
    items = spec["items"]
    if not times or t < times[0]:
        return
    f = font_of(46)
    row_h = 84
    top = spec.get("y", 300)
    head = 62 if spec.get("title") else 0
    h = head + row_h * len(items) + 36
    d = ImageDraw.Draw(img, "RGBA")
    a0 = _ease((t - times[0]) / CARD_FADE)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay, "RGBA")
    ld.rounded_rectangle([40, top, W - 40, top + h], radius=22, fill=(10, 8, 6, 190), outline=(200, 160, 70, 255), width=3)
    if spec.get("title"):
        ld.text((70, top + 38), spec["title"], font=font_of(36), fill=(255, 214, 0, 255), anchor="lm", stroke_width=3, stroke_fill=BLACK)
    img.alpha_composite(_fade_layer(lay, a0))
    for i, (it, at) in enumerate(zip(items, times)):
        a = _ease((t - at) / CARD_FADE)
        if a <= 0:
            continue
        row = Image.new("RGBA", (W, row_h), (0, 0, 0, 0))
        rd = ImageDraw.Draw(row, "RGBA")
        red_marked(rd, 70, row_h / 2, it["text"], f, stroke=4)
        if i > 0:
            rd.line([(70, 2), (W - 110, 2)], fill=(200, 160, 70, 140), width=2)
        img.alpha_composite(_fade_layer(row, a), (0, top + head + 18 + i * row_h))


def card_columns(img: Image.Image, spec: dict, times: list, t: float, font_of) -> None:
    """列が増えるカード（G の肖像3枚の下）：語りに合わせて1列ずつ増える。"""
    items = spec["items"]
    n = len(items)
    gap = 14
    cw = (W - 60 - gap * (n - 1)) // n
    y0, h = spec.get("y", 1205), 160
    for i, (it, at) in enumerate(zip(items, times)):
        a = _ease((t - at) / CARD_FADE)
        if a <= 0:
            continue
        lay = Image.new("RGBA", (cw, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay, "RGBA")
        d.rounded_rectangle([0, 0, cw - 1, h - 1], radius=16, fill=(12, 9, 7, 215), outline=(200, 160, 70, 255), width=3)
        _centered(d, cw / 2, 46, it["head"] + "  →", font_of(40), fill=(255, 214, 0), stroke=3)
        _centered(d, cw / 2, 108, it["text"], font_of(44 if len(it["text"]) <= 6 else 38), stroke=3)
        img.alpha_composite(_fade_layer(lay, a), (30 + i * (cw + gap), y0))


def card_versus(img: Image.Image, spec: dict, t: float, t0: float, font_of) -> None:
    """数の対比カード：左（青）と右（赤）に札・大きな数・点の群れ（数に応じた個数）を並べ、「対」で結ぶ。"""
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([40, 320, W - 40, 820], radius=26, fill=(10, 8, 6, 165))
    for k, side in enumerate((spec["left"], spec["right"])):
        cx = W * (0.27 if k == 0 else 0.73)
        col = BLUE if side.get("color", "blue" if k == 0 else "red") == "blue" else RED
        tf = font_of(40)
        tw = int(tf.getlength(side["tag"])) + 40
        d.rounded_rectangle([cx - tw / 2, 352, cx + tw / 2, 406], radius=10, fill=col + (255,))
        d.text((cx, 379), side["tag"], font=tf, fill=WHITE, anchor="mm")
        big = side["big"]
        size = 130 if len(big) <= 4 else (104 if len(big) <= 6 else 84)
        _centered(d, cx, 510, big, font_of(size), stroke=7)
        n = int(side["dots"])
        r = max(4, min(30, int((420 * 300 / max(n, 1)) ** 0.5 / 2.4)))
        per = max(1, int(440 // (r * 2.6)))
        for i in range(n):
            x = cx - (min(n, per) - 1) * r * 1.3 + (i % per) * r * 2.6
            y = 680 + (i // per) * r * 2.6
            d.ellipse([x - r, y - r, x + r, y + r], fill=col + (255,))
    _centered(d, W / 2, 510, spec.get("mid", "対"), font_of(70), stroke=5)


def card_map(img: Image.Image, spec: dict, t: float, t0: float, font_of, assets: Path) -> None:
    """場所の小さな地図カード：半透明の下地に、海と陸（Natural Earth・assets/maps）と地名の点。route があれば線が0.6秒で伸びる。
    台本：{type: map, bounds: [経度の西, 東, 緯度の南, 北], places: [[名, 経度, 緯度], ...], route: [名, 名], hot: 名（赤い点）}"""
    import math
    from .figures import _land
    lon0, lon1, lat0, lat1 = spec["bounds"]
    box = spec.get("box", [90, 300, W - 90, 900])
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([box[0] - 18, box[1] - 18, box[2] + 18, box[3] + 18], radius=26, fill=(10, 8, 6, 170))
    kx = math.cos(math.radians((lat0 + lat1) / 2))
    wd, hd = (lon1 - lon0) * kx, lat1 - lat0
    s = min((box[2] - box[0]) / wd, (box[3] - box[1]) / hd)
    ox = box[0] + ((box[2] - box[0]) - wd * s) / 2
    oy = box[1] + ((box[3] - box[1]) - hd * s) / 2
    P = lambda lon, lat: (ox + (lon - lon0) * kx * s, oy + (lat1 - lat) * s)
    x0, y0, x1, y1 = ox, oy, ox + wd * s, oy + hd * s
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rectangle([x0, y0, x1, y1], fill=(54, 76, 96, 255))
    for poly in _land(str(assets / "maps" / "land_50m.geojson")):
        xs, ys = [q[0] for q in poly], [q[1] for q in poly]
        if max(xs) < lon0 - 3 or min(xs) > lon1 + 3 or max(ys) < lat0 - 3 or min(ys) > lat1 + 3:
            continue
        ld.polygon([P(x, y) for x, y in poly], fill=(214, 198, 160, 255), outline=(120, 100, 70, 255))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rectangle([x0, y0, x1, y1], fill=255)
    layer.putalpha(Image.composite(layer.split()[3], Image.new("L", img.size, 0), mask))
    img.alpha_composite(layer)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([x0, y0, x1, y1], outline=(200, 160, 70, 255), width=3)
    pts = {n: P(lo, la) for n, lo, la in spec["places"]}
    route = [n for n in spec.get("route", []) if n in pts]
    if len(route) >= 2:
        p = _ease((t - t0 - 0.2) / 0.6)
        (ax, ay), (bx, by) = pts[route[0]], pts[route[1]]
        d.line([(ax, ay), (ax + (bx - ax) * p, ay + (by - ay) * p)], fill=RED + (255,), width=6)
    f = font_of(44)
    hot = spec.get("hot")
    for n, (x, y) in pts.items():
        col = RED if n == hot else (60, 60, 60)
        d.ellipse([x - 13, y - 13, x + 13, y + 13], fill=col + (255,), outline=(255, 248, 230, 255), width=4)
        right = x < (x0 + x1) / 2
        d.text((x + 24 if right else x - 24, y), n, font=f, fill=WHITE, anchor="lm" if right else "rm",
               stroke_width=6, stroke_fill=BLACK)


def card_times(units: list, spec: dict, total: float) -> tuple[float, float, list]:
    """カードが出る時刻：(from, until, 列ごとの at)。from・until・at は語りの中の字で、その文節が話し始められる時刻。"""
    said = "".join(screen_plain(u.text) for u in units)
    starts, pos = [], 0
    for u in units:
        starts.append(pos)
        pos += len(screen_plain(u.text))

    def when(key: str, after: float = -1.0) -> float:
        k = said.find(key)
        while k >= 0:
            i = max(j for j, s in enumerate(starts) if s <= k)
            if units[i].start > after:
                return units[i].start
            k = said.find(key, k + 1)
        raise ValueError(f"図解の指定「{key}」が語りの中に見つかりません")

    t0 = when(spec["from"]) if spec.get("from") else 0.0
    t1 = when(spec["until"], t0) if spec.get("until") else min(total, t0 + float(spec.get("hold", 3.0)))
    ats = [when(it["at"], t0 - 1e-6) for it in spec.get("items", []) if "at" in it]
    return t0, t1, ats


def block_layers(block: Block, font_of, center_y: int, box: bool = False) -> tuple[list, tuple[int, int]]:
    """ブロックの文字を一度に描いた透明な画像（1枚）と、その貼る位置（第4版：文字は足さない）。
    1行は10字まで・2行まで。白＋黒の太い縁取り、強調語（《》）だけ黄、頂点の語（《!》）は黄色で PEAK_SCALE 倍。"""
    sc = FIRST_SCALE if block.big else 1.0
    f = font_of(round(TEXT_SIZE * sc))
    fp = font_of(round(TEXT_SIZE * PEAK_SCALE * sc))
    step = int(TEXT_SIZE * sc * ROW_STEP)
    top = center_y - step * len(block.rows) / 2
    sw = max(6, TEXT_SIZE // 11)
    base = int(TEXT_SIZE * sc * 0.86)                       # 行の基準線（大きい字も同じ線に揃える）
    chars = []                                         # (字, 強調の種類, フォント, x, 基準線の y)
    for ri, row in enumerate(block.rows):
        items = []
        for u in row:
            s, m = phrase_plain(u.text)
            items += [(ch, on) for ch, on in zip(s, m)]
        width = sum((fp if on == 2 else f).getlength(ch) for ch, on in items)
        x = (W - width) / 2
        y = top + step * ri + base
        for ch, on in items:
            ft = fp if on == 2 else f
            chars.append((ch, on, ft, x, y))
            x += ft.getlength(ch)
    pad = sw + 18
    x0 = int(min(ch[3] for ch in chars)) - pad
    x1 = int(max(ch[3] + ch[2].size for ch in chars)) + pad
    y0 = int(top) - pad - 14
    y1 = int(top + step * len(block.rows) + TEXT_SIZE * sc * 0.4) + pad
    lay = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    if box:                                            # 絵の中の字（落款・題字）と重なる所：文字の下に半透明の黒い箱
        d.rounded_rectangle([4, 10, x1 - x0 - 4, y1 - y0 - 6], radius=28, fill=(0, 0, 0, 150))
    for pass_ in ("stroke", "fill"):
        for ch, on, ft, x, y in chars:
            if pass_ == "stroke":
                d.text((x - x0 + 3, y - y0 + 5), ch, font=ft, fill=(0, 0, 0, 140), stroke_width=sw, stroke_fill=(0, 0, 0, 140), anchor="ls")
                d.text((x - x0, y - y0), ch, font=ft, fill=BLACK + (255,), stroke_width=sw, stroke_fill=BLACK + (255,), anchor="ls")
            else:
                d.text((x - x0, y - y0), ch, font=ft, fill=(YELLOW if on else WHITE) + (255,), anchor="ls")
    return [lay], (x0, y0)


class Renderer:
    """動画の n コマ目を描く。絵は区間ぜんぶで1つの動き（ゆっくり寄る・流れる）を続ける。
    文字は「語順に増える」：声が言い始めた文節ごとに足され（UNIT_FADE 秒のフェード）、ブロックが終わると次のブロックに丸ごと替わる（BLOCK_FADE 秒）。
    絵の替わり目は FADE 秒の溶け合い。"""

    def __init__(self, blocks: list, spans: list, doc: dict, config: dict, assets: Path, art_dir: Path, total: float,
                 dips: list | None = None):
        self.blocks, self.total = blocks, total
        self.assets = assets
        self.hook_clear = float(doc.get("hook_clear", HOOK_CLEAR))
        self.dips = dips or []                          # 頂点の直前に絵を暗くする区間 (開始, 終了)
        self.spans = spans
        self.font_of = make_font_of(config["fonts"])
        self.grade = Grade()
        shots = doc["shots"]
        self.shots = [shots[sp.shot] for sp in self.spans]
        self.src, self.label = [], []
        self.overlay = ov = Overlay(doc.get("header_style"), doc.get("header"), self.font_of,
                                    [x["label"] for x in (doc.get("timeline") or [])])
        for sp, shot in zip(self.spans, self.shots):
            im0 = load_source(shot, sp.shot, assets, art_dir, self.font_of)
            if shot.get("bright"):                       # 掴みの絵は暗すぎないよう明るくする（shot の bright: 倍率）
                im0 = ImageEnhance.Brightness(im0).enhance(float(shot["bright"]))
            self.src.append(_prescale(im0))
            lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            if shot.get("kind", "ai") == "ai":
                ly = ov.label_y if ov.style else (34 if doc.get("now") else (HEADER_H + 6 if doc.get("header") else 40))
                draw_label(lay, self.font_of, ly, right=bool(doc.get("now")) or bool(ov.style))
            elif shot.get("credit"):
                draw_credit(lay, shot["credit"], self.font_of, ov.credit_y1)
            self.label.append(lay)
        # 図解：見出し帯（ずっと）とカード（語りの時刻に出入り）。カードが出ている間は語りの文字を下げて重ならないようにする
        self.now, self.bars = [], []                     # 常時の「いま」の札（時刻・札・点）と、年表バー（点ごと）
        self.timeline = doc.get("timeline") or []
        if doc.get("now"):
            nunits = [u for b in blocks for u in b.units]
            for it in doc["now"]:
                _t0, _t1, ats = card_times(nunits, {"from": it["at"], "items": []}, total)
                self.now.append((_t0, ov.now_layer(it["text"]), int(it.get("point", 0)), it["text"]))
        if self.timeline:
            self.bars = [ov.bar_layer(i) for i in range(len(self.timeline))]
        self.header, self.header_text = None, []
        if doc.get("header"):
            self.header = ov.header_layer()
            self.header_text = [doc["header"]["tag"], screen_plain(doc["header"]["title"])]
        units = [u for b in blocks for u in b.units]
        self.cards = []                                 # (種類, 仕様, 出る時刻, 消える時刻, 列ごとの時刻)
        for spec in doc.get("cards", []) or []:
            t0, t1, ats = card_times(units, spec, total)
            self.cards.append((spec["type"], spec, t0, t1, ats))
        self.text = []                                  # ブロックごとの (累積の画像の並び, 位置)
        for b in blocks:
            shot = shots[b.shot]
            y = shot.get("text_y", 0.80 if shot.get("kind") == "composite" else TEXT_Y)
            for _k, spec, t0, t1, _a in self.cards:
                if spec.get("text_y") and t0 - 1e-6 <= b.start < t1:
                    y = spec["text_y"] + ov.card_dy / H * (1 if spec["text_y"] < 0.75 else 0)   # カードを下げた分、カードの下の文字も下げる
            if ov.text_y_max:
                y = min(y, ov.text_y_max)
            self.text.append(block_layers(b, self.font_of, int(H * y), box=bool(shot.get("text_box"))))
        self.cta = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        draw_cta(self.cta, self.font_of, ov.cta_y)
        self._first = None

    def _picture(self, k: int, t: float, n: int) -> Image.Image:
        sp, shot, im = self.spans[k], self.shots[k], self.src[k]
        a, b = sp.start - FADE / 2, sp.end + FADE / 2
        z, dx, dy = motion(shot.get("move", "in"), (t - a) / (b - a), sp.zoom or shot.get("zoom", ZOOM), shot.get("ease", ""))
        box = cover_window(im.width, im.height, shot.get("focus", (0.5, 0.5)), z, dx, dy)
        return self.grade(im.transform((W, H), Image.EXTENT, box, Image.BICUBIC), n)

    def _put(self, img: Image.Image, j: int, u: int, alpha: float) -> None:
        layers, pos = self.text[j]
        if alpha > 0.002:
            img.alpha_composite(_fade_layer(layers[u], alpha), pos)

    def text_state(self, t: float) -> list[tuple[int, int, float]]:
        """時刻 t に出す文字：(ブロック, 何番目の文節まで, 不透明度) の並び。"""
        j = max([i for i, b in enumerate(self.blocks) if b.start - BLOCK_FADE / 2 <= t + 1e-9] or [0])
        b = self.blocks[j]
        if j > 0 and t < b.start + BLOCK_FADE / 2:                      # ブロックの替わり目：前の全体が消え、次の最初の文節が現れる
            e = _ease((t - (b.start - BLOCK_FADE / 2)) / BLOCK_FADE)
            prev = self.blocks[j - 1]
            return [(j - 1, 0, 1 - e), (j, 0, e)]
        return [(j, 0, 1.0)]

    def frame(self, n: int) -> Image.Image:
        """n コマ目。最後の LOOP_FADE 秒は最初の画面に溶け合わせる（ループで「最初の文」がそのまま始まる）。"""
        img = self._render(n)
        t = (n + 0.5) / FPS
        if t > self.total - LOOP_FADE:
            if self._first is None:
                self._first = self._render(0)
            img = Image.blend(img, self._first, _ease((t - (self.total - LOOP_FADE)) / LOOP_FADE))
        return img

    def _render(self, n: int) -> Image.Image:
        t = (n + 0.5) / FPS
        ramp = 1.0 if self.hook_clear <= 0 else min(1.0, max(0.0, (t - self.hook_clear) / 0.4))     # 見出し帯・ラベル・出典は掴みのあとから（hook_clear: 0 なら0秒から）
        k = max([i for i, sp in enumerate(self.spans) if sp.start <= t + 1e-9] or [0])
        sp = self.spans[k]
        # 絵：区間の替わり目の前後 FADE/2 で溶け合わせる（ラベルも同じ割合で）
        other, e = None, 0.0
        if k + 1 < len(self.spans) and t >= sp.end - FADE / 2:
            other, e = k + 1, _ease((t - (sp.end - FADE / 2)) / FADE)
        elif k > 0 and t < sp.start + FADE / 2:
            other, e = k - 1, 1 - _ease((t - (sp.start - FADE / 2)) / FADE)
        img = self._picture(k, t, n).convert("RGBA")
        labels = [(self.label[k], ramp)]                  # ラベル・出典は見出し帯の上に重ねる（案B の黒帯の下に隠れないように）
        if other is not None:
            o = self._picture(other, t, n).convert("RGBA")
            img = Image.blend(img, o, e)
            labels = [(self.label[k], (1 - e) * ramp), (self.label[other], e * ramp)]
        dim = 0.0                                        # 頂点の直前：0.4秒ほど暗くして間を作る（絵だけ。文字・見出し帯は暗くしない）
        for d0, d1 in self.dips:
            if d0 - 0.05 <= t <= d1 + 0.12:
                dim = max(dim, DIP_DEPTH * min(_ease((t - d0) / 0.15), 1 - _ease((t - d1) / 0.12)))
        if dim > 0.003:
            img.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, int(255 * dim))))
        for kind, spec, t0, t1, ats in self.cards:
            a_in = _ease((t - t0) / CARD_FADE)
            a_out = 1 - _ease((t - (t1 - CARD_FADE)) / CARD_FADE)
            a = a_out if kind in ("columns", "table") else a_in * a_out          # 列・行は個別にフェードイン、全体は最後に消える
            if a <= 0.002 or t < t0:
                continue
            lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            if kind == "year":
                card_year(lay, spec, t, t0, self.font_of)
            elif kind == "versus":
                card_versus(lay, spec, t, t0, self.font_of)
            elif kind == "columns":
                card_columns(lay, spec, ats, t, self.font_of)
            elif kind == "table":
                card_rows(lay, spec, ats, t, self.font_of)
            elif kind == "map":
                card_map(lay, spec, t, t0, self.font_of, self.assets)
            dy = self.overlay.card_dy                     # 上の常時表示が大きい案では、カードを丸ごと下げる
            if dy:
                lay = lay.crop((0, -dy, W, H - dy))
            img.alpha_composite(_fade_layer(lay, a))
        if self.header is not None and ramp > 0.002:
            img.alpha_composite(_fade_layer(self.header, ramp))
        for lay, a in labels:
            img.alpha_composite(_fade_layer(lay, a))
        if self.now and ramp > 0.002:                    # 「いま」の札と年表のバー：図解カードが出ている間も消さない。語りが年・場所を言った瞬間に0.2秒で切り替わる
            j = max([i for i, x in enumerate(self.now) if x[0] <= t + 1e-9] or [0])
            e = _ease((t - self.now[j][0]) / 0.2) if j > 0 else 1.0
            cur, prv = self.now[j], self.now[j - 1] if j > 0 else None
            if prv is not None and e < 1.0:
                img.alpha_composite(_fade_layer(prv[1], (1 - e) * ramp))
                if self.bars:
                    img.alpha_composite(_fade_layer(self.bars[prv[2]], (1 - e) * ramp))
            img.alpha_composite(_fade_layer(cur[1], e * ramp))
            if self.bars:
                img.alpha_composite(_fade_layer(self.bars[cur[2]], e * ramp))
        for j, u, a in self.text_state(t):
            self._put(img, j, u, a)
        if t >= self.total - CTA_SECONDS:
            img.alpha_composite(self.cta)
        return img.convert("RGB")


def kana_report(doc: dict, config: dict, readings: dict, engine, voice) -> list[str]:
    """全行の読みをカタカナで（誤読を音を出す前に見つけるため）。voice.py の join_n_phrases を使う。
    あわせて libs/yomi の点検（辞書との食い違い・読みが割れる語）。"""
    from .voice import apply_readings, join_n_phrases, split_emphasis
    out, items = [], []
    for line in lines_of(doc):
        spoken = apply_readings(split_emphasis(line.text)[0], readings)
        q = engine.query(spoken, voice.style_id)
        phrases, _ = join_n_phrases(q["accent_phrases"])
        kana = "／".join("".join(m["text"] for m in p["moras"]) for p in phrases)
        out.append(f"{line.index + 1:3} {kana}")
        items.append((f"{line.index + 1}行目", line.text))
    try:
        from . import reading
        out += [f"  ! 読み：{r}" for r in reading.collision_lines(readings, items)]
        src = reading.kana_source(config["voicevox_url"], voice.style_id)
        errs, warns = reading.yomi.review(items, readings, src.kana if src.available else None,
                                          reading.lexicon(), reading.strip).lines()
        src.save()
        out += [f"  {r}" for r in errs + warns]
    except Exception as e:  # noqa: BLE001 - 点検の道具が無くても kana は出す
        out.append(f"  （yomi の点検は動きませんでした: {e}）")
    return out


def estimate_seconds(lines: list) -> list:
    """声を作らずに時間割だけ見たいときの目安（約5.4字/秒）。"""
    return [len(l.text) / 5.4 for l in lines]


def art_dir_of(doc: dict, path) -> Path:
    stem = Path(path).stem
    d = Path(doc.get("art_dir", f"out/story/{stem.split('_')[0]}"))
    return d if d.is_absolute() else Path(__file__).resolve().parent.parent / d


def stills(path, config: dict, out: Path) -> Path:
    """声を作らずに、ブロックごとの完成形（全文節が出た所）を並べた一覧。絵・文字の配置を目で見るため。"""
    from .cli import assets_dir
    global USE_PLACEHOLDER
    USE_PLACEHOLDER = True                                  # 絵が届いていなくても配置を見られるように仮の絵で
    doc = load(path)
    lines = lines_of(doc)
    _v, blocks, spans, total = plan(lines, estimate_seconds(lines), None, float(doc.get("min_block", MIN_BLOCK)))
    r = Renderer(blocks, spans, doc, config, assets_dir(config), art_dir_of(doc, path), total)
    ims = []
    for b in blocks:
        n = int(((b.start + b.end) / 2) * FPS)
        ims.append(r.frame(n).resize((270, 480)))
    cols = 8
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 278 + 8, rows * 488 + 8), (24, 24, 24))
    for i, im in enumerate(ims):
        sheet.paste(im, (8 + (i % cols) * 278, 8 + (i // cols) * 488))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, quality=90)
    return out


def frames(path, config: dict, voices: dict, readings: dict, out_dir: Path, work_root: Path, times: list[float],
           styles: list | None = None, name: str | None = None) -> list[Path]:
    """動画を書き出さずに、本番と同じ声の時刻で決めたコマを PNG に（上の表示の案くらべ・配置の確認用）。
    styles を渡すと案ごと（header_style を上書き）に、同じ時刻のコマを作る。返すのは書いた PNG の並び（案×時刻）。"""
    import dataclasses
    from . import tts
    from .cli import assets_dir
    doc = load(path)
    lines = lines_of(doc)
    wd = work_root / f"{Path(path).stem}_story"
    wd.mkdir(parents=True, exist_ok=True)
    engine = tts.Voicevox(config["voicevox_url"])
    voice = dataclasses.replace(voices["語り"], **(doc.get("voice") or {}))
    tone_speed = doc.get("tone_speed") or {}
    lvoice = [dataclasses.replace(voice, **({"speed": tone_speed[l.tone]} if l.tone in tone_speed else {}), **(l.voice or {})) for l in lines]
    spoken = [tts.speak(engine, l.text, lv, l.tone, readings, wd / "voice") for l, lv in zip(lines, lvoice)]
    head_trim, new_len = trim_leading_silence(spoken[0].wav, wd / "voice_first_trim.wav")
    spoken[0] = dataclasses.replace(spoken[0], wav=wd / "voice_first_trim.wav", seconds=new_len)
    timing = [line_timing(engine, l, lv, readings, s, head_trim if i == 0 else 0.0) for i, (l, s, lv) in enumerate(zip(lines, spoken, lvoice))]
    voice_t, blocks, spans, total = plan(lines, [s.seconds for s in spoken], [t[0] for t in timing], float(doc.get("min_block", MIN_BLOCK)))
    stem = name or doc.get("out") or Path(path).stem
    out = []
    for st in (styles or [doc.get("header_style")]):
        d2 = dict(doc)
        if styles:
            d2["header_style"] = st
        r = Renderer(blocks, spans, d2, config, assets_dir(config), art_dir_of(doc, path), total, dips_of(lines, voice_t))
        for t in times:
            n = min(int(t * FPS), int(total * FPS) - 1)
            tag = f"_{st}" if styles else ""
            p = out_dir / f"{stem}{tag}_{int(round(t)):02d}s.png"
            r.frame(n).save(p)
            out.append(p)
    return out


def grid(paths: list[Path], cols: int, target: Path, labels: list[str] | None = None, cell_w: int = 540, font=None) -> Path:
    """PNG を cols 列の一覧（JPEG）に。labels は各コマの上に出す字。"""
    cell_h = cell_w * H // W
    head = 56 if labels else 0
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cell_w + 12) + 12, rows * (cell_h + head + 12) + 12), (28, 28, 28))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(str(font), 34) if font else None
    for i, p in enumerate(paths):
        x = 12 + (i % cols) * (cell_w + 12)
        y = 12 + (i // cols) * (cell_h + head + 12)
        if labels and f:
            d.text((x + 6, y + head / 2), labels[i], font=f, fill=(255, 255, 255), anchor="lm")
        sheet.paste(Image.open(p).convert("RGB").resize((cell_w, cell_h)), (x, y + head))
    target.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(target, quality=90)
    return target


def trim_leading_silence(src: Path, dst: Path, keep: float = 0.03, threshold: float = 0.01) -> tuple[float, float]:
    """声の頭の無音を詰めて dst に書く（掴み：声は0秒から）。(詰めた秒数, 新しい長さ) を返す。"""
    import numpy as np
    from . import storyaudio
    x, sr = storyaudio.read_wav(src)
    idx = int(np.argmax(np.abs(x) > threshold)) if (np.abs(x) > threshold).any() else 0
    cut = max(0, idx - int(keep * sr))
    storyaudio.write_wav(dst, x[cut:], sr)
    return cut / sr, (len(x) - cut) / sr


def line_timing(engine, line: Line, voice, readings: dict, spoken, trim: float = 0.0) -> tuple[list[float], list, bool]:
    """1行ぶんの (文節の話し始め（行の頭から）, モーラの時刻, 合わなかったか)。
    合成と同じ audio_query（tts.final_query）のモーラ長から求める。文節ごとの長さは、
    文節だけを VOICEVOX に読ませたモーラ数で全体のモーラ列に当てはめる。"""
    from . import tts
    from .voice import apply_readings
    query, _ = tts.final_query(engine, line.text, voice, line.tone, readings)
    tl = mora_timeline(query, spoken.seconds + trim)             # 詰める前の声の長さで求め、詰めた分だけ前へずらす
    tl = [(max(0.0, a - trim), max(0.0, b - trim), x) for a, b, x in tl]
    counts = []
    for u in line.units:
        q = engine.query(apply_readings(screen_plain(u.text), readings), voice.style_id)
        counts.append(sum(len(ph["moras"]) for ph in q["accent_phrases"]))
    onsets, mismatch = chunk_onsets([a for a, _b, _k in tl], counts)
    return onsets, tl, mismatch


def sync_table(lines: list, blocks: list, voice_t: list, timelines: list, mismatches: list) -> str:
    """ブロックごとの 出る時刻／画面の文字（行ごとに「／」）／その時刻から次のブロックまでに声が言っているカナ（合成に渡した audio_query から）。"""
    out = ["| 開始〜終了（秒） | 画面の文字 | その間の声（カナ） | 語りの行 |", "|---|---|---|---|"]
    for i, line in enumerate(lines):
        a, _b = voice_t[i]
        mine = [b for b in blocks if b.line == i]
        for j, b in enumerate(mine):
            nxt = mine[j + 1].start if j + 1 < len(mine) else float("inf")
            first = b.units[0].start
            kana = "".join(x for s, _e, x in timelines[i] if first - 1e-6 <= a + s < nxt - 1e-6)
            shown = " ／ ".join("".join(screen_plain(u.text) for u in r) for r in b.rows)
            out.append(f"| {b.start:5.2f}〜{b.end:5.2f} | {shown} | {kana} | {i + 1} |")
    bad = [str(i + 1) for i, m in enumerate(mismatches) if m]
    note = (chr(10) + "（文節ごとのモーラ数が全体と合わず、比例させて当てはめた行：" + "、".join(bad) + "）") if bad else ""
    return chr(10).join(out) + note + chr(10)


def card_table(r) -> str:
    """図解（見出し帯・カード）が出入りする時刻の表。語りと同じ時刻（語りの中の字から求めた）。"""
    rows = [chr(10) + "## 図解" + chr(10), "| 時刻（秒） | 図解 | 出る字 | きっかけの語り |", "|---|---|---|---|"]
    if r.header is not None:
        rows.append("| 0.00〜 | 見出し帯（ずっと） | " + " ".join(r.header_text) + " | （動画の間ずっと） |")
    for t_now, _lay, point, text in getattr(r, "now", []):
        rows.append(f"| {t_now:5.2f}〜 | 「いま」の札・年表バー（常時） | {text}（バーの点 {point + 1}） | 語りがその年・場所を言う所 |")
    for kind, spec, t0, t1, ats in r.cards:
        if kind == "year":
            body = f"{spec['big']}／{spec.get('sub', '')}（赤い下線が左から{UNDERLINE_SECONDS}秒で引かれる）"
        elif kind == "table":
            body = "年表：" + "／".join(f"{it['text']}（{a:.2f}秒）" for it, a in zip(spec['items'], ats))
        elif kind == "columns":
            body = "／".join(f"{it['head']}→{it['text']}（{a:.2f}秒）" for it, a in zip(spec['items'], ats))
        elif kind == "map":
            body = "地図：" + "・".join(n for n, _lo, _la in spec["places"])
        else:
            body = f"{spec['left']['tag']} {spec['left']['big']} 対 {spec['right']['tag']} {spec['right']['big']}"
        rows.append(f"| {t0:5.2f}〜{t1:5.2f} | {kind} | {body} | 「{spec.get('from', '')}」 |")
    return chr(10).join(rows) + chr(10)


def voice_report(engine, lines: list, lvoice: list, readings: dict, spoken: list, wav: Path, bgm: dict | None, doc: dict | None = None) -> str:
    """声の調整値の確認（聴けないので、合成に渡した audio_query の数字で異常が無いかを見る）。
    行ごとの調子・速さ・高さ・抑揚・音量・モーラの高さの最大/最小と、合成した声の最大振幅。BGM の数字も。"""
    import dataclasses
    import numpy as np
    from . import storyaudio, tts
    rows = ["| 行 | 調子 | 間（前） | 速さ | 高さ | 抑揚 | 音量 | モーラ高さ（最小〜最大） | 最短モーラ(ms) | 秒 |", "|---|---|---|---|---|---|---|---|---|---|"]
    shortest = 1e9
    worst = 0.0
    for l, s, voice in zip(lines, spoken, lvoice):
        q, _ = tts.final_query(engine, l.text, voice, l.tone, readings)
        pitches = [m["pitch"] for ph in q["accent_phrases"] for m in ph["moras"] if m.get("pitch", 0) > 0]
        worst = max(worst, max(pitches))
        mora_ms = min(((m.get("consonant_length") or 0.0) + (m.get("vowel_length") or 0.0)) / q["speedScale"] * 1000
                      for ph in q["accent_phrases"] for m in ph["moras"] if (m.get("vowel_length") or 0) > 0.02)
        shortest = min(shortest, mora_ms)
        rows.append(f"| {l.index + 1} | {l.tone} | {l.pause if l.pause is not None else '-'} | {q['speedScale']} | {q['pitchScale']} | "
                    f"{q['intonationScale']} | {q['volumeScale']} | {min(pitches):.2f}〜{max(pitches):.2f} | {mora_ms:.0f} | {s.seconds:.2f} |")
    data, _sr = storyaudio.read_wav(wav)
    chars = sum(len(l.text) for l in lines)
    total = float(doc.get("_total", 0)) if doc else 0.0
    voice = dataclasses.replace(lvoice[0], speed=float((doc or {}).get('voice', {}).get('speed', lvoice[0].speed)))
    speeds = [float(r.split("|")[4]) for r in rows[2:]]
    seconds_total = sum(float(r.split("|")[-2]) for r in rows[2:])
    cpm = f"語り {chars}字の声は合計 {seconds_total:.1f}秒（行の声だけ）。最短のモーラ {shortest:.0f}ms（70ms 未満だと聞き取りにくい目安）。"
    out = ["# 声と音の確認", "",
           f"声：剣崎雌雄（style {voice.style_id}）。基準：速さ {voice.speed}・抑揚 {voice.intonation}・調子の効き {voice.tone_strength}・"
           f"抑揚の上限 {voice.max_intonation}・速さの上限 {voice.max_speed}（行ごとの上書きあり）。", "",
           f"語り {chars}字。各行の speed：最小 {min(speeds)}・最大 {max(speeds)}。", "", *rows, "",
           f"モーラの高さの最大 {worst:.2f}（VOICEVOX の対数の高さ。6.5 を超えると裏返りやすい）。声だけの波形の最大振幅 {float(np.abs(data).max()):.3f}（1.0 未満＝割れていない）。", cpm]
    if bgm:
        out += ["", "## BGM", f"- 声（loudnorm 前）{bgm['voice_lufs']:.1f} LUFS、BGM {bgm['bgm_lufs_before']:.1f} LUFS → 倍率 {bgm['bgm_gain']:.3f} で BGM を "
                f"{bgm['bgm_lufs_after']:.1f} LUFS に（声より {bgm['voice_lufs'] - bgm['bgm_lufs_after']:.1f} LU 小さい）",
                (f"- 低い響き・上がる音・一拍の無音：{', '.join(f'{t:.2f}秒' for t in bgm['booms'])}" if bgm['booms'] or bgm['risers'] or bgm['hushes'] else "- 効果音（上がる音・低い響き・一拍の無音）：なし（BGM だけ）"),
                f"- 混ぜたあとの最大振幅 {bgm['peak']:.3f}",
                f"- BGM の帯域：スペクトル重心 {bgm['centroid_hz']:.0f}Hz・95%の音量が {bgm['rolloff95_hz']:.0f}Hz 以下。立ち上がり（最初の0.3秒）の最大振幅 {bgm['head_peak']:.4f}",
                f"- 弦のビブラート：±{bgm['vibrato_cents']:.1f}セント（0.18%）。和音の重ね（うなりの元の1.003倍）はやめた"]
    return chr(10).join(out) + chr(10)


def build(path, config: dict, voices: dict, readings: dict, out_dir: Path, work_root: Path, name=None, draft: bool = False):
    """台本から mp4（と確認用の軽い版・一致表・増え方の連続コマ）を作る。voices は cli.voices(config)、readings は readings.yaml。"""
    import dataclasses
    import shutil
    import subprocess
    from concurrent.futures import ThreadPoolExecutor
    from . import mix, storyaudio, tts, video
    from .cli import assets_dir, ffmpeg
    global USE_PLACEHOLDER
    USE_PLACEHOLDER = draft                                   # 確認用（--draft）だけ、届いていない絵を仮の絵で置き換える
    PLACEHOLDERS_USED.clear()
    doc = load(path)
    errs = problems(doc)
    if errs:
        raise ValueError("台本の点検で止まりました：" + " / ".join(errs))
    lines = lines_of(doc)
    stem = Path(path).stem
    wd = work_root / f"{stem}_story"
    wd.mkdir(parents=True, exist_ok=True)

    # 声：語りの1人だけ（剣崎雌雄。《》の強調は声にかけない）。ショートは本編より抑揚を大きく許す：
    # 台本の voice: で speed・intonation・tone_strength・max_intonation などを上書きし、行ごとの tone で
    # 「静かに始めて、転換と最後で抑揚を上げる」（調子はブロック単位＝行単位で指定）
    engine = tts.Voicevox(config["voicevox_url"])
    voice = dataclasses.replace(voices["語り"], **(doc.get("voice") or {}))
    tone_speed = doc.get("tone_speed") or {}                                                       # 調子ごとの基準の速さ（しみじみ・重いも1.28以上に）
    lvoice = [dataclasses.replace(voice, **({"speed": tone_speed[l.tone]} if l.tone in tone_speed else {}), **(l.voice or {})) for l in lines]
    spoken = [tts.speak(engine, l.text, lv, l.tone, readings, wd / "voice") for l, lv in zip(lines, lvoice)]
    head_trim, new_len = trim_leading_silence(spoken[0].wav, wd / "voice_first_trim.wav")     # 最初の声を0秒から
    spoken[0] = dataclasses.replace(spoken[0], wav=wd / "voice_first_trim.wav", seconds=new_len)
    timing = [line_timing(engine, l, lv, readings, s, head_trim if i == 0 else 0.0) for i, (l, s, lv) in enumerate(zip(lines, spoken, lvoice))]
    voice_t, blocks, spans, total = plan(lines, [s.seconds for s in spoken], [t[0] for t in timing], float(doc.get("min_block", MIN_BLOCK)))
    cues = [mix.Cue(l, round(a, 3), round(b, 3), s.wav) for l, s, (a, b) in zip(lines, spoken, voice_t)]
    audio = wd / "voice.wav"
    mix.write_audio(cues, total, audio)
    stem_out = name or doc.get("out") or "{}_story_{}".format(stem.partition("_")[0], stem.partition("_")[2] or "s1")
    if draft:
        stem_out += "_draft"
    # 控えめな BGM（台本の bgm: true。ショート用のオプション。本編は BGM なし）と、転換点の低い響き
    bgm_info = None
    if doc.get("bgm"):
        audio = wd / "voice_bgm.wav"
        sfx = bool(doc.get("sfx", False))                    # 効果音（ライザー・低い響き・一拍の無音）。既定は切（第8版：BGM だけ）
        bgm_info = storyaudio.mix_voice_bgm(wd / "voice.wav", audio, total, boom_times(lines, voice_t) if sfx else [], ffmpeg(),
                                            diff_lu=float(doc.get("bgm_diff_lu", 9.0)),
                                            risers=riser_times(lines, voice_t) if sfx else [], hushes=dips_of(lines, voice_t) if sfx else [])
    (out_dir / f"{stem_out}_audio.md").write_text(voice_report(engine, lines, lvoice, readings, spoken, wd / "voice.wav", bgm_info, doc),
                                                  encoding="utf-8")
    r = Renderer(blocks, spans, doc, config, assets_dir(config), art_dir_of(doc, path), total, dips_of(lines, voice_t))
    (out_dir / f"{stem_out}_sync.md").write_text(
        f"# {stem_out} 画面の文字と声の時刻（ブロックを一度に出す）\n\n画面のブロックをつなげると語り（「、」「。」を除く）と一致する。"
        "時刻は合成に渡した audio_query のモーラ長から求めたブロックの話し始め（0.2秒のフェードで丸ごと出て、次のブロックが始まるまで残る）。\n\n"
        + sync_table(lines, blocks, voice_t, [t[1] for t in timing], [t[2] for t in timing])
        + card_table(r), encoding="utf-8")

    # 毎コマ描く（30fps）。切り出しは小数の位置で補間するので、寄り・パンにガタつきが出ない
    seq = wd / "seq"
    shutil.rmtree(seq, ignore_errors=True)
    seq.mkdir(parents=True)
    count = int(round(total * FPS))

    def one(n: int) -> None:
        r.frame(n).save(seq / f"f{n:05d}.jpg", quality=93, subsampling=0)

    with ThreadPoolExecutor(max_workers=4) as ex:
        list(ex.map(one, range(count)))
    target = out_dir / f"{stem_out}.mp4"
    part = target.with_name(f"{target.stem}.part{target.suffix}")
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", str(seq / "f%05d.jpg"),
                    "-i", str(audio), "-vf", "scale=in_range=full:out_range=tv,format=yuv420p", "-color_range", "tv",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "23", "-maxrate", "10M", "-bufsize", "20M",
                    "-g", str(FPS * 2), "-af", video.loudnorm_filter(ffmpeg(), audio), "-c:a", "aac", "-b:a", "192k",
                    "-ar", "48000", "-movflags", "+faststart", "-shortest", str(part)], check=True)
    part.replace(target)
    shutil.rmtree(seq, ignore_errors=True)
    preview(ffmpeg(), target, out_dir / f"{stem_out}_preview.mp4")
    contact_sheet(ffmpeg(), target, out_dir / f"{stem_out}_hook.jpg", every=0.2, cols=5, font=config["fonts"]["gothic"],
                  start=0.0, end=3.0, width=216)                                  # 最初の3秒（0.2秒ごと）
    for sp in spans:
        print(f"  絵 {sp.shot:3} {sp.start:5.1f}〜{sp.end:5.1f}（{sp.end - sp.start:.1f}秒）")
    for b in blocks:
        print(f"    ブロック {b.start:5.2f}〜{b.end:5.2f}　" + " ／ ".join(
            "".join(screen_plain(u.text) for u in row) for row in b.rows))
    return target, total


def preview(ffmpeg_exe: str, src: Path, dst: Path) -> Path:
    """確認用に軽くした版（スマホに届く20MB前後）。crf27・最大3Mbps・faststart。"""
    import subprocess
    part = dst.with_name(f"{dst.stem}.part{dst.suffix}")
    subprocess.run([ffmpeg_exe, "-y", "-loglevel", "error", "-i", str(src), "-c:v", "libx264", "-preset", "medium",
                    "-crf", "27", "-maxrate", "3M", "-bufsize", "6M", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "96k",
                    "-movflags", "+faststart", str(part)], check=True)
    part.replace(dst)
    return dst


def contact_sheet(ffmpeg: str, video: Path, target: Path, every: float = 2.0, cols: int = 6, font=None,
                  start: float = 0.0, end: float | None = None, width: int = 200) -> Path:
    """start〜end 秒を every 秒ごとに1コマ、cols 列の一覧（時刻つき）。fps フィルタは丸めで1秒ほどずれるので、時刻ごとに探して1コマずつ取る。"""
    import subprocess
    import tempfile
    dur = end
    if dur is None:
        r = subprocess.run([ffmpeg, "-hide_banner", "-i", str(video)], capture_output=True, text=True, encoding="utf-8", errors="ignore")
        m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr)
        dur = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3)) if m else start + every * 60
    times = []
    t = start
    while t < dur - 0.05:
        times.append(t)
        t += every
    with tempfile.TemporaryDirectory() as td:
        ims = []
        for i, t in enumerate(times):
            f = Path(td) / f"f{i:03d}.png"
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-ss", f"{t:.3f}", "-i", str(video), "-frames:v", "1",
                            "-vf", f"scale={width}:-1", str(f)], check=True)
            ims.append(Image.open(f).convert("RGB"))
        w, h = ims[0].size
        rows = (len(ims) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * (w + 8) + 8, rows * (h + 8) + 8), (24, 24, 24))
        d = ImageDraw.Draw(sheet)
        fnt = ImageFont.truetype(font, 22) if font else ImageFont.load_default()
        label = "{:.1f}" if every < 1 else "{:.0f}"
        for i, im in enumerate(ims):
            x, y = 8 + (i % cols) * (w + 8), 8 + (i // cols) * (h + 8)
            sheet.paste(im, (x, y))
            d.rectangle([x, y + h - 30, x + 92, y + h], fill=(0, 0, 0))              # 時刻は下の隅に（上の見出し帯を隠さない）
            d.text((x + 6, y + h - 27), label.format(times[i]) + "秒", font=fnt, fill=(255, 255, 255))
        target.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(target, quality=88)
    return target
