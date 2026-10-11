"""サムネイル(1280x720)の生成。

一覧で見たときに何の動画か一瞬で分かることを優先する。写真素材が無くても
成立するよう、文字の大きさとコントラストで見せる構成にしている。
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from . import ffmpeg
from .config import ProjectConfig, _resolve
from .ffmpeg import is_video
from .render import BRAND_GREEN, _cover, _hex, _layer, wrap_text

SIZE = (1280, 720)
MARGIN = 64

# 帯スタイル。まとめ系チャンネルで定番の、黄色帯＋赤帯の2段組み
# 2026-09-07: 最高再生の2本（64万回・25万回）を実際に見て合わせた色。
# 帯は**蛍光イエロー1枚**で、その中に黒の1行目と赤の2行目。別々の帯ではない
BAND_YELLOW = (222, 255, 0)
# 反応の小窓。白地に赤、黒の枠。帯の上に置く（「変な声出た」「一番強くて草」）
CHIP_BG = (255, 255, 255)
CHIP_INK = (222, 20, 30)
# 帯のぶんだけ、写真を切る位置を上へ（0.0=上端 / 1.0=下端）
BAND_FOCUS = 0.38
BAND_INK_RED = (222, 20, 30)
BAND_RED = (222, 20, 30)
BAND_TEXT_DARK = (12, 12, 14)
BAND_TEXT_LIGHT = (255, 255, 255)
BAND_SIZES = (104, 94, 86, 78, 70, 62, 56, 50, 44, 40)
# 左に積む言葉（thumbnail_points）。右の写真に食い込まない幅で縮める
# **もっと目立たせる**（2026-09-10 ユーザー指示）。62px・柔らかい影だと、
# 写真の明るいところに乗ったときに沈んでいた。太くして黒で縁取る
POINTS_SIZE = 74
POINTS_MIN_SIZE = 40
POINTS_WIDTH = 620
POINTS_STROKE = 6
# 並べた顔の継ぎ目に置く印（`thumbnail.face_link`）。対立の回だけ出す
FACE_CLASH_SIZE = 96
FACE_CLASH_GROUND = (200, 22, 34)
# 印の上に置く国旗・エンブレムの高さと、印との間
FACE_CLASH_FLAG_H = 118
FACE_CLASH_GAP = 18
# 札を置く高さ（画像に対する割合）。**真ん中**（2026-09-10 ユーザー指示）
FACE_CLASH_Y = 0.50
# エンブレムを札の上に載せる回（1つだけ）は、上に詰めたまま
FACE_CLASH_Y_TOP = 0.30
# 3枚並べた回。真ん中の顔を避けて、帯のすぐ上まで下げる
FACE_CLASH_Y_TRIO = 0.62
# 角に寄せたエンブレムの余白
FACE_CLASH_EDGE = 24
BADGE_HEIGHT = 62
SUBTITLE_HEIGHT = 70
DATE_HEIGHT = 40
TITLE_GAP = 18
TITLE_SIZES = (116, 104, 94, 84, 76, 68, 60)

# ニューススタイル。テレビの報道テロップの組み方に寄せる。
# 帯で画面を割らず、行ごとにプレートを敷いて、下にティッカーを通す
NEWS_FLAG = (198, 18, 28)          # 速報フラグの赤
NEWS_PLATE = (9, 13, 21, 219)      # 見出しの下敷き
NEWS_TICKER = (7, 10, 17, 238)     # 下部の帯
NEWS_INK = (255, 255, 255, 255)
NEWS_SUB_INK = (222, 228, 238, 255)
NEWS_META_INK = (150, 160, 176, 255)
NEWS_FLAG_HEIGHT = 64
NEWS_TICKER_HEIGHT = 78
NEWS_BAR = 10                      # 見出し左の縦棒の太さ
NEWS_HEAD_SIZES = (96, 88, 80, 72, 64, 58, 52)
NEWS_SUB_SIZES = (64, 58, 52, 48, 44, 40, 36)
NEWS_LABEL = "海外サッカーニュース"

# 縦型（ショート）のサムネイル（2026-09-09 ユーザー「他のチャンネルを参考にして」）。
# **参考4チャンネルのショートは全部が縦（9:16）だった。**こちらだけが本編と
# 同じ 16:9 の画像を使い回していて、縦のタイルでは左半分の文字が切られていた。
# KOALA SOCCER / 熱狂サッカーSAMURAIブルー / R Football / ブラボーまとめch の
# 直近15本を落として並べたところ、共通していたのは次の4つ:
#   1. 写真が全面。人物が画面の主役で、帯で画面を割らない
#   2. 見出しは**上端**に小さめの2〜3行。16:9 のときのような極太1行ではない
#   3. 下端に**動画の中の一言**を置く（「シュートは自分の武器」「ボールを受けた瞬間」）
#   4. 色は1色だけ強く差す
# **エンブレムを主役にする**（2026-09-09 ユーザー指示「一にして」）。
# それまでは「小さく添えるだけ。サムネの主役にしない」と決めていた
# （2026-09-08 ユーザー判断）。**その決まりをユーザーが変えた。**
# 権利の見立ては変わっていない——CC の表示は当てにならず、なぞって上げた人に
# クラブの商標を解放する権利は無い。**引き受ける危険が一段増える。**
#
# 使うのは、その話に出てくる人のクラブ姿の写真が無いとき。
# 実際、アーセナル対ヴィラの誤審の回で、関係者の誰にも使える
# クラブユニフォーム姿の写真が無かった
CREST_MAIN_HEIGHT = 410      # 1280x720 の中での高さ
# 2つ並べて間に「対」を置くときの間隔。字は132pxなので左右に余白を取る
CREST_LINK_GAP = 232
# **暗すぎると `サムネの黒` の点検が止める**（実測で顔の段の75%が黒だった）。
# 一覧で沈まない明るさにする
CREST_MAIN_GROUND = (34, 58, 96, 255)
# **暗いエンブレムのときに使う明るい地**（2026-09-13）。
# 紺の地に紺のロゴだと何のクラブか分からなかった
CREST_MAIN_GROUND_LIGHT = (232, 236, 242, 255)

SHORT_SIZE = (1080, 1920)
SHORT_MARGIN = 56
SHORT_HEAD_SIZES = (86, 78, 72, 66, 60, 54, 48, 44)
SHORT_QUOTE_SIZES = (60, 54, 48, 44, 40, 36)
SHORT_EYEBROW_SIZE = 40
SHORT_HEAD_LINES = 3          # 上に置く見出しの最大行数
SHORT_QUOTE_MAX = 24          # 下の一言。長いと縦でも2行になって写真を潰す


def _short_scrim(canvas: Image.Image) -> None:
    """上下だけ沈める。**真ん中は触らない**（顔が主役なので）。"""
    width, height = SHORT_SIZE
    scrim, draw = _layer(SHORT_SIZE)
    top = int(height * 0.34)
    for y in range(top):
        alpha = int(238 * (1 - y / top) ** 1.5)
        draw.line([(0, y), (width, y)], fill=(6, 9, 16, alpha))
    bottom = int(height * 0.26)
    for y in range(bottom):
        alpha = int(226 * (y / bottom) ** 1.6)
        draw.line([(0, height - bottom + y), (width, height - bottom + y)],
                  fill=(6, 9, 16, alpha))
    canvas.alpha_composite(scrim)


def _fit_short(draw: ImageDraw.ImageDraw, text: str, font_path: str,
               sizes, room: int, max_lines: int):
    """縦幅ではなく**行数**で字の大きさを決める。

    **まず1行に収める。**大きさを先に決めて折り返すと
    「行き先が土壇場で変わっ／た」のように1文字だけの行ができる
    （2026-09-09 実測）。字を小さくしてでも1行のほうが読める。
    """
    for want in range(1, max_lines + 1):
        for size in sizes:
            font = ImageFont.truetype(font_path, size)
            lines = wrap_text(draw, text, font, room)
            if len(lines) <= want:
                return font, lines
    font = ImageFont.truetype(font_path, sizes[-1])
    return font, wrap_text(draw, text, font, room)[:max_lines]


def _short_crest_stage(names: list[str], font_path: str,
                       link: str = "対") -> Image.Image | None:
    """縦型の下地に、エンブレムを大きく置く（2026-09-14）。

    横型の `_crest_stage` は 1280x720 前提で、縦に切ると端が落ちる。
    縦型は**上下に積む**。あいだに「対」を入れる。
    """
    from . import crest as crest_mod

    found = [p for p in (crest_mod.find(n) for n in names[:2]) if p is not None]
    if not found:
        return None
    width, height = SHORT_SIZE
    bright = _crest_brightness(found)
    dark_marks = bright < 150
    ground = CREST_MAIN_GROUND_LIGHT if dark_marks else CREST_MAIN_GROUND
    canvas = Image.new("RGBA", SHORT_SIZE, tuple(ground))

    marks = []
    room = int(width * 0.62)
    for path in found:
        with Image.open(path) as source:
            mark = source.convert("RGBA")
        ratio = min(room / mark.width, (height * 0.26) / mark.height)
        marks.append(mark.resize((max(1, int(mark.width * ratio)),
                                  max(1, int(mark.height * ratio))), Image.LANCZOS))
    gap = int(height * 0.08)
    total = sum(m.height for m in marks) + gap * (len(marks) - 1)
    # **画面の真ん中に置く**（2026-09-14 指摘「ロゴが上によってる」）。
    # 0.30 だと題名に重なり、0.42 でも上に寄って下が空いていた。
    # 上は題名2行、下は引用1行ぶんを空ける
    y = int(height * 0.52) - total // 2
    middles = []
    for index, mark in enumerate(marks):
        canvas.alpha_composite(mark, ((width - mark.width) // 2, y))
        y += mark.height
        if index < len(marks) - 1:
            middles.append(y + gap // 2)
            y += gap
    if len(marks) == 2 and link and middles:
        font = ImageFont.truetype(font_path, 120)
        draw = ImageDraw.Draw(canvas)
        text_w = draw.textlength(link, font=font)
        draw.text(((width - text_w) / 2, middles[0] - 66), link, font=font,
                  fill=(40, 56, 84, 240) if dark_marks else (255, 255, 255, 235))
    return canvas


def _short_thumbnail(
    config: ProjectConfig,
    out_path: Path,
    background: str | None,
    lines: tuple[str, str],
    tags: list[str],
    focus: float | None,
    quote: str,
    photos: list[str],
    crest_main: list[str] | None = None,
    crest_link: str = "対",
    focus_x: float | None = None,
) -> Path:
    """1080x1920 のサムネイル。ショート専用。"""
    font_path = str(config.video.font_path())
    accent = _hex(config.video.accent)
    width, height = SHORT_SIZE

    # **エンブレムが主役の回は、まずエンブレム**（2026-09-14 指摘）。
    # 写真が無いと下地（自前で描いた緑のピッチ）が拾われ、
    # エンブレムの3本が同じ絵に見えていた。写真があればそちらを優先する
    # **板を指定した回は、縦版の板を敷く**（2026-09-24 指摘「ショートのサムネが
    # おかしい」）。エンブレムだけの地は、**白っぽい面に紋章が1つ**で一覧では
    # 何の動画か分からなかった。板の縦版（`<名前>_v.png`）があればそれを使う
    from .render import _is_board

    stage = None
    board = str(background or "")
    if _is_board(board):
        name = Path(board.replace("\\", "/"))
        for tall in (name.with_name(name.stem + "_v.png"),
                     Path("assets/stats") / (name.stem + "_v.png")):
            if _resolve(tall.as_posix()).exists():
                background = tall.as_posix()
                break
        else:
            background = None
    if background is None and not (photos or []) and (crest_main or []):
        stage = _short_crest_stage(crest_main, font_path, crest_link)
    elif not _is_board(board) and not (photos or []) and (crest_main or []):
        stage = _short_crest_stage(crest_main, font_path, crest_link)

    source = None
    for candidate in ([] if stage is not None else [*(photos or []), background]):
        if not candidate:
            continue
        path = _resolve(candidate)
        if path.exists() and is_video(path.name):
            still = out_path.parent / "thumbnail_bg.png"
            still.parent.mkdir(parents=True, exist_ok=True)
            path = ffmpeg.grab_frame(path, still)
        if path.exists():
            source = path
            break
    if source is not None:
        with Image.open(source) as image:
            # **横のどこを残すか**（2026-09-18）。横長の写真を縦の画面に
            # 敷くと真ん中で切られ、端に写っている人が落ちる
            canvas = _cover(image.convert("RGBA"), width, height,
                            focus=focus if focus is not None else 0.18,
                            focus_x=focus_x)
    elif stage is not None:
        canvas = stage
    else:
        canvas = Image.new("RGBA", SHORT_SIZE, (14, 20, 32, 255))
    _short_scrim(canvas)

    layer, draw = _layer(SHORT_SIZE)
    room = width - SHORT_MARGIN * 2
    y = SHORT_MARGIN

    # 眉。クラブ名や選手名の札を1つだけ、アクセント色で小さく
    eyebrow = next((str(t).strip() for t in (tags or []) if str(t).strip()), "")
    if eyebrow:
        font = ImageFont.truetype(font_path, SHORT_EYEBROW_SIZE)
        text_width = draw.textlength(eyebrow, font=font)
        draw.rounded_rectangle(
            [SHORT_MARGIN, y, SHORT_MARGIN + text_width + 40, y + SHORT_EYEBROW_SIZE + 22],
            radius=8, fill=accent + (255,),
        )
        draw.text((SHORT_MARGIN + 20, y + 9), eyebrow, font=font,
                  fill=BAND_TEXT_DARK + (255,))
        y += SHORT_EYEBROW_SIZE + 22 + 20

    # 見出し。**上端に置く。**参考はどれも上で、真ん中を空けて顔を見せていた。
    # **1行目と2行目は別々に組む。**つなげて折り返すと
    # 「行き先が土壇場で変わっ／た 合流寸前だったのは」のように
    # 2つの文が1行の中で混ざる（2026-09-09 実測）
    drew_head = False
    for index, part in enumerate([str(x or "").strip() for x in lines]):
        if not part:
            continue
        rest = SHORT_HEAD_LINES - (1 if drew_head else 0)
        font, rows = _fit_short(draw, part, font_path, SHORT_HEAD_SIZES,
                                room, max(1, rest))
        for row in rows:
            draw.text((SHORT_MARGIN, y), row, font=font,
                      fill=(BAND_YELLOW + (255,)) if index else (255, 255, 255, 255),
                      stroke_width=max(5, font.size // 10),
                      stroke_fill=(8, 10, 16, 255))
            y += int(font.size * 1.26)
        drew_head = True
    if drew_head:
        # 見出しの下の短い罫。**行送りより下に置く。**y+8 だと2行目の
        # 文字の足に重なっていた（2026-09-09 実測）
        draw.rectangle([SHORT_MARGIN, y + 22, SHORT_MARGIN + 190, y + 32],
                       fill=BAND_YELLOW + (255,))

    # 下の一言。動画の中で実際に読み上げる文から取る。
    # **見出しの繰り返しは置かない**（2026-09-09 実測。反応が無い回で
    # 2行目がそのまま下にも出て、同じ文が画面に2つ並んだ）
    quote = (quote or "").strip()
    if quote and any(quote == str(x or "").strip() for x in lines):
        quote = ""
    if quote:
        if len(quote) > SHORT_QUOTE_MAX:
            quote = quote[:SHORT_QUOTE_MAX]
        font, rows = _fit_short(draw, quote, font_path, SHORT_QUOTE_SIZES, room, 2)
        rows = rows[:2]
        block = int(font.size * 1.3) * len(rows)
        top = height - SHORT_MARGIN - block
        draw.rounded_rectangle(
            [SHORT_MARGIN - 18, top - 24, width - SHORT_MARGIN + 18, height - SHORT_MARGIN + 16],
            radius=14, fill=(8, 10, 16, 214),
        )
        for row in rows:
            text_width = draw.textlength(row, font=font)
            draw.text(((width - text_width) / 2, top), row, font=font,
                      fill=(255, 255, 255, 255))
            top += int(font.size * 1.3)

    canvas.alpha_composite(layer)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, quality=95)
    return out_path



def _prefix_of(title: str) -> str:
    """タイトル先頭の【…】を返す。無ければ空。"""
    text = (title or "").strip()
    if text.startswith("【") and "】" in text:
        return text[1:text.index("】")].strip()
    return ""


# 並べる顔の上限。**取り上げた選手を全員並べる回がある**（2026-09-22 ユーザー
# 「一人の写真ではなくて取り上げた選手を並べて」。日本代表の上位5人）
PHOTOS_MAX = 5


def from_meta(meta: dict, title: str) -> dict:
    """台本の frontmatter からサムネの引数を取り出す。

    draft が書くのは thumbnail_line1 / line2 / tags。手書きの古い台本は
    thumbnail_title / thumbnail_subtitle なので、どちらでも読めるようにする。
    ここを1か所にまとめないと、CLI とビルドで指定が食い違う。
    """
    line1 = str(meta.get("thumbnail_line1") or meta.get("thumbnail_title") or title)
    line2 = str(meta.get("thumbnail_line2") or meta.get("thumbnail_subtitle") or "")
    return {
        "title": line1,
        "subtitle": line2,
        # 構図を書いた回は、2行に構図の指定を持たせる（ThumbLines の説明を参照）
        "lines": _lines_with_layout((line1, line2), layout_spec(meta)),
        "tags": [str(t) for t in (meta.get("thumbnail_tags") or [])],
        # 指定が無ければ、タイトルの【】をそのままバッジにする。
        # **既定の「速報」を出しっぱなしにすると、悲報の記事に速報と出る**
        # （2026-09-06 実測。マルティネッリ退団の回で食い違っていた）
        "badge": str(meta.get("thumbnail_badge", "")) or _prefix_of(title),
        "date": str(meta.get("date", "")),
        # サムネの下地。**選手の顔を敷けるようにする。**参考3チャンネルは
        # どれも人の顔を全面に出しており、文字だけのサムネは一覧で埋もれる
        # （2026-09-05 実測）。指定が無ければ台本の背景を使う
        # **サムネだけに使う絵**（2026-09-17）。`thumbnail_photo` は動画の中でも
        # 使われるので、一覧板や数字の図を入れると**カードと節の名前が板の文字に
        # 重なる**（代表発表の回で、齋藤と松木がカードの下に隠れていた）。
        # `thumbnail_board` を書くと、**サムネイルだけ**それを敷く。
        # 動画のほうは `thumbnail_photo`（人の顔）のまま
        "photo": str(meta.get("thumbnail_board")
                     or meta.get("thumbnail_photo") or ""),
        # 写真のどこを残すか（0.0=上端 / 1.0=下端）。顔が中央にある写真で使う
        "focus": meta.get("thumbnail_focus"),
        "focus_x": meta.get("thumbnail_focus_x"),
        # 帯の上に出す反応のひとこと（2026-09-07）。最高再生の2本はどちらも
        # 「変な声出た」「一番強くて草」のような**書き込みの断片**を小窓で出して
        # いた。反応を集めたチャンネルであることが、一覧の時点で分かる
        # **一覧板の回は小窓を出さない**（2026-09-17）。板そのものが絵なので、
        # 書き込みの断片を重ねると板の文字が隠れる（松木の所属と年齢が
        # 「松木遂に代表デビューか！」の小窓の下に入っていた）。
        # 手で `thumbnail_reaction` を書いたときだけ、板の回でも出す
        "reaction": str(meta.get("thumbnail_reaction") or ""),
        # 板そのものが絵なので、台本から拾った小窓を重ねない
        "no_auto_reaction": bool(meta.get("thumbnail_board")
                                 and not meta.get("thumbnail_reaction")),
        # 左の余白に積む短い言葉（2026-09-08）。縦長の写真を右に置くと
        # 左がぼかしだけになり「ただのぼかし」に見えた（ユーザー指摘）。
        # **中身を置けば余白が情報になる。**3つまで、1つ10字くらい
        "points": [str(x) for x in (meta.get("thumbnail_points") or [])][:3],
        # **赤で1行だけ足せる口**（2026-09-14 指示「サムネに、佐藤龍之介の
        # 未来は？？を赤字で入れてください」）。エンブレムの回は points を
        # 出さないので、言いたい一言を置く場所が帯しか無かった
        "note_red": str(meta.get("thumbnail_note_red") or ""),
        # **帯を下いっぱいに広げる**（2026-09-14 指示「サムネの黄色い枠を
        # 下いっぱいに広げて／久保のサムネみたいな感じ」）。縦長の写真は
        # 自動で「右に置いて左はぼかし」になり、帯が左半分で止まっていた
        "band_full": bool(meta.get("thumbnail_band_full", False)),
        # 顔を並べる（2026-09-08）。2〜3枚あれば全面が写真になり、
        # ぼかしの下地が要らない。参考チャンネルは全面が写真だった
        "photos": [str(x) for x in (meta.get("thumbnail_photos") or [])][:PHOTOS_MAX],
        # **エンブレムを主役にする**（2026-09-09 ユーザー指示）。
        # 出てくる人のクラブ姿の写真が無いときの逃げ道。写真より優先する
        "crest_main": [str(x) for x in (meta.get("thumbnail_crest_main") or [])][:3],
        # **エンブレムだけ止めたいことがある**（2026-09-09 ユーザー「レアルは不要」）。
        # tags を削ると YouTube のタグからも消えるので、絵のほうだけ別に持つ。
        # 書いていなければ tags をそのまま使う
        "crests": ([str(x) for x in meta["thumbnail_crests"]]
                   if "thumbnail_crests" in meta else None),
        # エンブレム2つの間に置く字。対戦以外の回では「対」だと誤解を招く
        "crest_link": str(meta.get("thumbnail_crest_link", "対")),
        # 並べた顔の継ぎ目に置く印。対立の回だけ
        "face_link": str(meta.get("thumbnail_face_link", "")),
        # **構図**（2026-10-08）。書かなければ None＝今の形（classic）。画素まで今と同じ
        "layout": layout_spec(meta),
    }


# 小窓に入る長さ。実測で、これ以上は帯より横に長くなる
CHIP_MAX = 12
NARRATORS = ("キャスター", "解説", "ナレーター", "")


def reaction_line(script, limit: int = CHIP_MAX) -> str:
    """台本から、小窓に出せる反応をひとつ選ぶ。

    `thumbnail_reaction` の指定が無いときに使う。**短いものだけ**。
    長い引用を縮めると意味が変わるので、入らなければ何も出さない。
    """
    for scene in script.scenes:
        for line in scene.lines:
            if (line.speaker or "") in NARRATORS:
                continue
            text = (line.text or "").strip().rstrip("。")
            if 3 <= len(text) <= limit:
                return text
    return ""


def short_quote(script, limit: int = SHORT_QUOTE_MAX) -> str:
    """縦サムネの下に置く一言を台本から選ぶ（2026-09-09）。

    順に、匿名の反応 → 誰かの発言 → 節のテロップ。**地の文は使わない。**
    参考チャンネルが下に置いていたのは、どれも動画の中の「声」だった。
    """
    said = reaction_line(script, limit)
    if said:
        return said
    for scene in getattr(script, "scenes", []) or []:
        for line in getattr(scene, "lines", []) or []:
            who = (getattr(line, "speaker", "") or "").strip()
            text = (getattr(line, "text", "") or "").strip()
            if who and who not in NARRATORS and 0 < len(text) <= limit:
                return text
    # テロップは最後の逃げ道。**冒頭の1行は飛ばす。**そこは本編の題名を
    # そのまま読む行なので、下に置くと題名が2回出る（2026-09-09 実測。
    # ハーランドの回で「ハーランドがCLで並んだ相手、誰か分かりますか」が出た）
    skip = 1
    for scene in getattr(script, "scenes", []) or []:
        for line in getattr(scene, "lines", []) or []:
            if skip > 0:
                skip -= 1
                continue
            # 強調の囲みはサムネに持ち込まない（2026-09-15）
            telop = re.sub(r"\*\*", "", (getattr(line, "telop", "") or "")).strip()
            if 0 < len(telop) <= limit:
                return telop
    return ""


def contact_sheet(paths: list[Path], out_path: Path) -> Path:
    """案を縦に並べた1枚を作る。実際に並ぶのは一覧なので、並べて比べる。"""
    images = [Image.open(path).convert("RGB") for path in paths]
    gap = 16
    sheet = Image.new(
        "RGB",
        (SIZE[0], sum(i.height for i in images) + gap * (len(images) - 1)),
        (18, 22, 30),
    )
    y = 0
    for image in images:
        sheet.paste(image, (0, y))
        y += image.height + gap
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, quality=95)
    return out_path


def variants(meta: dict, title: str) -> list[dict]:
    """サムネの案を並べて返す。

    1案しか作らないと良し悪しを比べられない。台本に thumbnail_alt を書くと、
    その数だけ案が増える。並べて見て、一覧で目を引くほうを選ぶ。
    """
    base = from_meta(meta, title)
    found = [dict(base, name="案1")]

    for number, entry in enumerate(meta.get("thumbnail_alt") or [], start=2):
        entry = dict(entry or {})
        line1 = str(entry.get("line1") or base["title"])
        line2 = str(entry.get("line2") or base["subtitle"])
        # **案ごとに構図を替えられる**（2026-10-08）。YouTube の「テストと比較」に
        # 構図違いを並べる。`alt: [{layout: face}]` か `{layout: {layout: number, number: …}}`
        spec = base.get("layout")
        if entry.get("layout") is not None:
            spec = _merge_layout(spec, entry["layout"])
        found.append(
            {
                **base,
                "name": f"案{number}",
                "title": line1,
                "subtitle": line2,
                "lines": _lines_with_layout((line1, line2), spec),
                "layout": spec,
                "tags": [str(t) for t in (entry.get("tags") or base["tags"])],
                "badge": str(entry.get("badge") or base["badge"]),
            }
        )
    return found


def build_thumbnail(
    config: ProjectConfig,
    title: str,
    out_path: Path,
    subtitle: str = "",
    background: str | None = None,
    badge: str = "",
    date: str = "",
    style: str = "",
    lines: tuple[str, str] | None = None,
    tags: list[str] | None = None,
    focus: float | None = None,
    # **横のどこを残すか**（2026-09-18）。縦のサムネだけで効く
    focus_x: float | None = None,
    reaction: str = "",
    points: list[str] | None = None,
    note_red: str = "",
    band_full: bool = False,
    photos: list[str] | None = None,
    quote: str = "",
    crest_main: list[str] | None = None,
    crests: list[str] | None = None,
    crest_link: str = "対",
    face_link: str = "",
    layout: dict | None = None,
) -> Path:
    """サムネイルを1枚作る。

    style="band" にすると、写真の上に黄色帯と赤帯を重ねる形になる。
    lines は (黄色帯の文字, 赤帯の文字)。省略時は title / subtitle を使う。
    layout は構図の指定（`from_meta` の "layout"）。None か classic なら今の形。
    渡さなくても、`from_meta` の lines（ThumbLines）が持っていればそれを使う。
    """
    chosen = style or config.video.thumbnail_style
    # **縦の動画には縦のサムネ**（2026-09-09）。ショートは portrait() で
    # width < height の設定になるので、そこで切り替える
    if config.video.height > config.video.width:
        return _short_thumbnail(
            config, out_path, (photos or [None])[0] or background,
            lines or (title, subtitle), tags or [], focus,
            quote or reaction, photos or [], crest_main or [], crest_link,
            focus_x=focus_x,
        )
    # **構図を書いた回だけ**、ここで別の描き方へ（2026-10-08）。classic は下へ素通り
    spec = layout if layout is not None else getattr(lines, "layout", None)
    if spec and str(spec.get("layout") or "classic") != "classic":
        return _layout_thumbnail(
            config, out_path, background, lines or (title, subtitle), tags or [],
            crests, photos or [], focus, focus_x, face_link, spec,
        )
    if chosen == "news":
        return _news_thumbnail(
            config, out_path, background,
            lines or (title, subtitle), tags or [], badge, date, focus,
        )
    if chosen == "band":
        return _band_thumbnail(
            config, out_path, background,
            lines or (title, subtitle), tags or [], focus, reaction, points or [],
            note_red, band_full, photos or [], crest_main or [], crests, crest_link,
            face_link,
        )

    font_path = str(config.video.font_path())
    accent = _hex(config.video.accent)

    canvas = _base(config, background, out_path, focus)
    _scrim(canvas, accent)

    layer, draw = _layer(SIZE)

    # 先に上下の固定要素の高さを確保し、残りをタイトルに割り当てる
    badge_height = (BADGE_HEIGHT + 26) if badge else 0
    subtitle_height = (SUBTITLE_HEIGHT + 18) if subtitle else 0
    date_height = (DATE_HEIGHT + 10) if date else 0
    available = SIZE[1] - MARGIN * 2 - badge_height - subtitle_height - date_height

    font, lines = _fit_title(draw, title, font_path, available)
    block = (font.size + TITLE_GAP) * len(lines)

    y = MARGIN + 8
    if badge:
        y = _draw_badge(draw, badge, y, accent, font_path)
    # タイトルは確保した領域の中で上寄せにする
    for chunk in lines:
        draw.text(
            (MARGIN, y), chunk, font=font, fill=(255, 255, 255, 255),
            stroke_width=max(6, font.size // 9), stroke_fill=(8, 10, 16, 255),
        )
        y += font.size + TITLE_GAP

    bottom = SIZE[1] - MARGIN
    if date:
        _draw_date(draw, date, font_path, bottom - DATE_HEIGHT)
        bottom -= date_height
    if subtitle:
        _draw_subtitle(draw, subtitle, bottom - SUBTITLE_HEIGHT, font_path, accent)

    canvas.alpha_composite(layer)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, quality=95)
    return out_path


def _band_thumbnail(
    config: ProjectConfig,
    out_path: Path,
    background: str | None,
    lines: tuple[str, str],
    tags: list[str],
    focus: float | None = None,
    reaction: str = "",
    points: list[str] | None = None,
    note_red: str = "",
    band_full: bool = False,
    photos: list[str] | None = None,
    crest_main: list[str] | None = None,
    crests: list[str] | None = None,
    crest_link: str = "対",
    face_link: str = "",
) -> Path:
    """写真の上に蛍光イエローの帯を重ねる。**最高再生の型に合わせてある。**

    2026-09-07 に、参考チャンネルの最高再生2本（64万回・25万回）を実際に
    見て作り直した。前は黄色帯と赤帯を別々に積んでいたが、向こうは
    **1枚の蛍光イエローの中に黒の行と赤の行**を入れている。文字は画面幅
    いっぱいで、帯の上に**書き込みの断片**が白い小窓で乗る。

    縦長の写真は右に置く（`news` と同じ扱い）。全面に敷くと 16:9 に切った
    時点で顔が残らない。
    """
    font_path = str(config.video.font_path())
    # **板を下地に指定した回は、板をそのまま使う**（2026-09-24 指示
    # 「もっと、背景は、データを利用」）。プレミア20クラブ紹介は基礎DATAの板を
    # 背景にする。エンブレムの地（`_crest_stage`）を先に作ると板が捨てられ、
    # **右下のエンブレムも板の字に重なる**ので、どちらも出さない
    from .render import _is_board

    on_board = _is_board(str(background or ""))
    if on_board:
        crests = []
    # **正方形に近い写真も右に置く。**全面に敷くと顔が帯に隠れる
    stage = None if on_board else _crest_stage(crest_main or [], font_path, crest_link,
                                               note_room=bool(note_red))
    tiles = [] if stage is not None else [q for q in (photos or []) if _resolve(q).exists()]
    if stage is not None:
        canvas = stage
        portrait = False
    elif len(tiles) >= 2:
        # **並べれば全面が写真になる。**ぼかしの下地が要らない
        canvas = _tile_photos(tiles)
        if face_link:
            _face_clash(canvas, face_link, font_path,
                        tags if crests is None else crests, tiles=len(tiles))
            crests = []          # 上に置いたので、右下には出さない
        portrait = False
    else:
        # **左のぼかしは禁止**（2026-09-20 ユーザー指示「サムネについて、
        # 左がぼやけるのは禁止」）。縦長の写真は、左に**べた塗りの面**を敷いて
        # その上に文字を置く。全面に敷く案は試したが、幅を埋めるまで拡大すると
        # **顎から下が帯に隠れた**（鈴木・前田で実際に起きた）
        portrait = False if band_full else _is_portrait(background, ratio=1.05)
    if stage is not None:
        pass
    elif portrait:
        canvas = _flat_bed(background, crests if crests is not None else tags)
        _paste_side(canvas, background)
    elif len(tiles) < 2:
        # **帯が下の4割を覆うので、顔を上に寄せる。**真ん中で切ると、
        # 額と目だけが残って口から下が帯に隠れた（2026-09-07 に書き出して発見）。
        # 指定があればそちらを優先する
        canvas = _base(config, background, out_path,
                       _photo_focus(background) if focus is None else focus)

    # 写真をそのまま活かすので、暗幕は下側だけ薄くかける
    scrim, draw = _layer(SIZE)
    for y in range(int(SIZE[1] * 0.45), SIZE[1]):
        ratio = (y - SIZE[1] * 0.45) / (SIZE[1] * 0.55)
        draw.line([(0, y), (SIZE[0], y)], fill=(0, 0, 0, int(120 * ratio)))
    canvas.alpha_composite(scrim)

    layer, draw = _layer(SIZE)
    if portrait and points:
        _draw_points(draw, points, font_path)
    if note_red:
        _draw_note_red(draw, note_red, font_path)

    top_text = (lines[0] or "").replace(chr(92) + "n", " ")
    bottom_text = lines[1] or ""
    # **帯はいつも全幅**（2026-09-20）。左半分だけにすると字が小さくなり、
    # 左のべた塗りが広く空いて見えた。顔は写真の上のほうにあるので隠れない
    right = SIZE[0] - 16
    # **2行は同じ大きさで描く。**入る字の大きさは行ごとに違うので、
    # 小さいほうに合わせる。1行目だけで決めていたら、2行目が枠を超えて
    # 「GKコーチ」が「G / Kコーチ」に泣き別れた（2026-09-07 に書き出して発見）
    band_top = None
    texts = [(t, ink) for t, ink in
             ((top_text, BAND_TEXT_DARK), (bottom_text, BAND_INK_RED)) if t]
    font = _fit_one_line(draw, [t for t, _ in texts], font_path, right - 56)

    rows: list[tuple[str, tuple[int, int, int]]] = []
    if font is not None:
        for text, ink in texts:
            for row in wrap_text(draw, text, font, right - 56):
                rows.append((row, ink))

    if rows:
        # **帯の中に余白を残す**（2026-09-13、Gemini にサムネ6枚を見せて指摘された）。
        # 「上下左右ぎりぎりまで文字が詰まっていて、蛍光イエローで目を引く効果を
        # 文字自体が塗りつぶしている」。字の高さに合わせて余白も広げる
        pad_x, pad_y = 46, int(font.size * 0.26)
        line_height = font.size + 10
        height = line_height * len(rows) + pad_y * 2
        bottom = SIZE[1] - 22
        top = bottom - height
        draw.rectangle([16, top, right, bottom], fill=BAND_YELLOW + (255,))
        y = top + pad_y
        for row, ink in rows:
            draw.text((16 + pad_x, y), row, font=font, fill=ink + (255,))
            y += line_height
        if reaction:
            _draw_chip(draw, reaction, font_path, top - 12)
        band_top = top

    # **エンブレムは右下**（2026-09-10 ユーザー指示）。左に置いていた頃は、
    # 同じ左側の `thumbnail.points` と場所を取り合い、バルコラの回で
    # 速度ランキングの真上に重なって数字が読めなくなった。
    # 帯を描いたあとに置くので、**帯に隠れない位置**を自分で選べる
    # （縦長の回は帯が左半分だけなので床まで使える。横長は帯の上に載せる）
    # **主役にしたときは、小さいほうを出さない。**同じ絵が2つ並ぶ
    if stage is None:
        floor = SIZE[1] - 28
        if band_top is not None:
            floor = band_top - 16
        _draw_tags(layer, tags if crests is None else crests, floor)

    canvas.alpha_composite(layer)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, quality=95)
    return out_path


# エンブレムの下地に敷くスタジアムの写真（2026-09-13、Gemini 指摘）。
# 「無地のグレーだと、素人がパワポで作った画像に見える」。
# stadium_night.mp4 の1コマ。出どころは assets/grounds/credits.json
CREST_GROUND_PHOTO = Path("assets/grounds/stadium.jpg")
# 写真をどれだけ地の色へ寄せるか。**強く寄せる。**
# 写真をそのまま出すとエンブレムが読めない。欲しいのは「무地ではない」ことだけ
CREST_GROUND_BLEND = 0.78


def _crest_ground(ground: tuple[int, int, int, int], dark_marks: bool) -> Image.Image:
    """エンブレムを置く下地。**平らな一色にしない**（2026-09-13）。

    スタジアムの写真を敷いてから、地の色へ強く寄せる。
    暗いエンブレムなら明るい地へ、明るいエンブレムなら暗い地へ寄せるので、
    **コントラストは今までどおり保ったまま、質感だけ足せる。**
    写真が無ければ今までどおり一色（取り込んでいない環境でも壊れない）。
    """
    flat = Image.new("RGBA", SIZE, ground)
    if not CREST_GROUND_PHOTO.exists():
        return flat
    try:
        with Image.open(CREST_GROUND_PHOTO) as source:
            photo = source.convert("RGBA")
    except Exception:
        return flat
    ratio = max(SIZE[0] / photo.width, SIZE[1] / photo.height)
    photo = photo.resize((max(1, int(photo.width * ratio)),
                          max(1, int(photo.height * ratio))), Image.LANCZOS)
    left = (photo.width - SIZE[0]) // 2
    top = (photo.height - SIZE[1]) // 2
    photo = photo.crop((left, top, left + SIZE[0], top + SIZE[1]))
    if dark_marks:
        # 明るい地に寄せるときは、写真も先に明るく持ち上げる
        photo = ImageEnhance.Brightness(photo).enhance(1.25)
    return Image.blend(photo, flat, CREST_GROUND_BLEND)


def _crest_brightness(paths) -> float:
    """エンブレムの明るさ（0=真っ黒 / 255=真っ白）。透けている所は数えない。"""
    total, count = 0.0, 0
    for path in paths:
        with Image.open(path) as source:
            mark = source.convert("RGBA").resize((64, 64), Image.LANCZOS)
        for r, g, b, a in mark.getdata():
            if a < 40:
                continue
            total += 0.299 * r + 0.587 * g + 0.114 * b
            count += 1
    return total / count if count else 128.0


def _crest_stage(names: list[str], font_path: str, link: str = "対",
                 note_room: bool = False) -> Image.Image | None:
    """エンブレムを大きく並べた下地。写真の代わりに使う。

    **元の画像が小さい**（実測で 112x132 など）。拡大するとどうしても
    眠くなるので、暗い地に置いてコントラストで見せる。
    """
    from . import crest as crest_mod

    found = [(n, crest_mod.find(n)) for n in names]
    found = [(n, p) for n, p in found if p is not None]
    if not found:
        return None
    # **地の色はエンブレムの明るさで決める**（2026-09-13 ユーザー
    # 「白枠ではなく背景色をかえて」）。紺の地に紺のトッテナムを置いて
    # 沈んでいた。白い丸を敷く案は、丸が並んで見た目がうるさかった
    bright = _crest_brightness([p for _, p in found[:3]])
    dark_marks = bright < 150
    ground = CREST_MAIN_GROUND_LIGHT if dark_marks else CREST_MAIN_GROUND
    canvas = _crest_ground(ground, dark_marks)
    # 中央をうっすら濃く（明るい地）／明るく（暗い地）。**平らな一色は一覧で沈む**
    glow, glow_draw = _layer(SIZE)
    tint = (150, 168, 196, 18) if dark_marks else (96, 132, 186, 16)
    for step in range(14):
        radius = int(SIZE[0] * (0.62 - step * 0.04))
        glow_draw.ellipse(
            [SIZE[0] // 2 - radius, int(SIZE[1] * 0.32) - radius // 2,
             SIZE[0] // 2 + radius, int(SIZE[1] * 0.32) + radius // 2],
            fill=tint,
        )
    canvas.alpha_composite(glow)
    marks = []
    for _, path in found[:3]:
        with Image.open(path) as source:
            mark = source.convert("RGBA")
        # **赤い一言を置く回は、その分だけ小さくして下げる**（2026-09-14）。
        # そうしないとエンブレムの上端に字がかぶる
        height = int(CREST_MAIN_HEIGHT * (0.84 if note_room else 1.0))
        ratio = height / mark.height
        marks.append(mark.resize((max(1, int(mark.width * ratio)), height),
                                 Image.LANCZOS))
    # **「対」が入るだけ間を空ける**（2026-09-14 指摘「サムネの対がロゴと
    # 被っている」）。110 だと 132px の字が両側のエンブレムに食い込んでいた。
    # 字の幅＋左右の余白ぶんを確保する
    gap = CREST_LINK_GAP if (len(marks) == 2 and link) else 110
    total = sum(m.width for m in marks) + gap * (len(marks) - 1)
    # 広げたぶん、はみ出すなら全体を縮める。**エンブレムが切れるほうが悪い**
    room = SIZE[0] - 80
    if total > room:
        shrink = (room - gap * (len(marks) - 1)) / max(1, sum(m.width for m in marks))
        marks = [m.resize((max(1, int(m.width * shrink)), max(1, int(m.height * shrink))),
                          Image.LANCZOS) for m in marks]
        total = sum(m.width for m in marks) + gap * (len(marks) - 1)
    x = (SIZE[0] - total) // 2
    # 帯が下を覆うので、少し上に置く
    centre = 0.36 if note_room else 0.30
    top = int(SIZE[1] * centre) - max(m.height for m in marks) // 2
    middles = []
    for index, mark in enumerate(marks):
        canvas.alpha_composite(mark, (x, top))
        x += mark.width
        # **間の中央**を覚えておく。エンブレムの中点どうしの真ん中だと、
        # 幅の違う2枚のときに字が片方へ寄る
        if index < len(marks) - 1:
            middles.append(x + gap // 2)
            x += gap
    if len(marks) == 2 and link:
        # **間の字は「対」だけではない**（2026-09-10）。アラウホの回は
        # 対戦ではなく**バルサからリヴァプールへのレンタル**の話なのに、
        # 「リヴァプール 対 バルセロナ」に見えていた。取材メモの
        # `thumbnail.crest_link` で変えられる（"対" / "→" / 空文字で消す）
        # **親指の大きさだと 72px の「対」は消える**（2026-09-13、Gemini に
        # サムネ4枚を見せて指摘された）。一覧で見る前提の大きさにする
        font = ImageFont.truetype(font_path, 132)
        draw = ImageDraw.Draw(canvas)
        text = link
        width = draw.textlength(text, font=font)
        # middles[0] は**空けた間の中央**（2026-09-14 に意味を変えた）
        draw.text((middles[0] - width / 2,
                   top + max(m.height for m in marks) / 2 - 44),
                  # **地の色に合わせる**（2026-09-13）。明るい地に白の「対」だと
                  # 消える。エンブレムが暗いときは地が明るいので、字は濃く
                  text, font=font,
                  fill=(40, 56, 84, 240) if dark_marks else (255, 255, 255, 235))
    return canvas


def _draw_chip(draw: ImageDraw.ImageDraw, text: str, font_path: str, bottom: int) -> None:
    """書き込みの断片を、白い小窓で帯の上に出す。

    向こうは1〜2枚だが、長い文は入らないので1枚だけにする。
    """
    text = text.strip()
    if not text:
        return
    font = ImageFont.truetype(font_path, 56)
    width = int(draw.textlength(text, font=font))
    top = bottom - 78
    draw.rectangle([34, top, 34 + width + 44, bottom], fill=CHIP_BG + (255,))
    draw.rectangle([34, top, 34 + width + 44, bottom], outline=(10, 10, 12, 255), width=4)
    draw.text((56, top + 6), text, font=font, fill=CHIP_INK + (255,))


def _is_portrait(background: str | None, ratio: float = 1.1) -> bool:
    """下地の写真が縦長か。全面に敷くか、右に置くかの分かれ目。

    `ratio` は「縦が横の何倍から縦長とみなすか」。**帯のスタイルでは 0.95**、
    つまり正方形に近いものも縦長として扱う。891×935 の写真（比 1.05）が
    1.1 に届かず全面に敷かれ、**16:9 に切った時点で額と目しか残らなかった**
    （2026-09-07 に書き出して発見）。
    """
    if not background:
        return False
    path = _resolve(background)
    if not path.exists() or is_video(path.name):
        return False
    try:
        with Image.open(path) as image:
            return image.height > image.width * ratio
    except OSError:
        return False


def _face_clash(canvas: Image.Image, text: str, font_path: str,
                crests: list[str] | None = None, tiles: int = 2) -> None:
    """並べた2枚の**継ぎ目に、ぶつかっている印を置く**（2026-09-10 ユーザー指示
    「喧嘩している感出して」）。

    2人の言い分が正面から食い違う回は、顔を並べただけだと
    「共演」に見える。**間に印を1つ入れるだけで、対立の絵になる。**
    """
    if not text:
        return
    layer, draw = _layer(canvas.size)
    font = ImageFont.truetype(font_path, FACE_CLASH_SIZE)
    marks = [_crest_image(name, FACE_CLASH_FLAG_H) for name in (crests or [])]
    marks = [mark for mark in marks if mark is not None]
    # **札の高さは、エンブレムの置き場所で決まる。**2つあるときは角へ逃がすので
    # 札を真ん中に置ける（2026-09-10 ユーザー「ロゴは左上と右上にして、交渉は真ん中に」）。
    # 1つのときは札の上に載せるため、上に詰めたまま（ブラジル国旗の回）
    cx = canvas.width // 2
    if tiles >= 3:
        # **3枚並べると、真ん中に顔が来る**（2026-09-10 ユーザー「フリアンも
        # サムネに載せたい」）。札を画面の中央に置くとその顔を隠すので、
        # 帯のすぐ上まで下げる
        cy = int(canvas.height * FACE_CLASH_Y_TRIO)
    elif len(marks) >= 2:
        cy = int(canvas.height * FACE_CLASH_Y)
    else:
        cy = int(canvas.height * FACE_CLASH_Y_TOP)
    width = draw.textlength(text, font=font)
    pad = 34
    box = [cx - width / 2 - pad, cy - FACE_CLASH_SIZE * 0.72,
           cx + width / 2 + pad, cy + FACE_CLASH_SIZE * 0.78]
    # 継ぎ目を割るように、上下へ伸びる帯
    # 継ぎ目の数だけ帯を引く（3枚なら1/3と2/3の2本）
    for index in range(1, max(2, tiles)):
        seam = int(canvas.width * index / max(2, tiles))
        draw.polygon([(seam - 26, 0), (seam + 26, 0), (seam + 26, canvas.height),
                      (seam - 26, canvas.height)], fill=(12, 14, 20, 210))
    draw.rounded_rectangle(box, radius=14, fill=FACE_CLASH_GROUND + (255,))
    draw.text((cx - width / 2, cy - FACE_CLASH_SIZE * 0.60), text, font=font,
              fill=(255, 255, 255, 255), stroke_width=5, stroke_fill=(0, 0, 0, 235))
    canvas.alpha_composite(layer)

    # **印の上に置く**（2026-09-10 ユーザー「ブラジル国旗はvsの上において」）。
    # 右下だと顔にかかるうえ、2人のどちらの持ち物かが曖昧になる。
    # 真ん中の上なら「この2人が属しているもの」として読める
    if len(marks) >= 2:
        # **2つあるときは左上と右上**（2026-09-10 ユーザー「ロゴは左上と右上にして」）。
        # 移籍の話は「どちらのクラブの人か」が分からないと絵にならない。
        # 顔の上に重ねると髪や額に食い込むので、角まで逃がす
        canvas.alpha_composite(marks[0], (FACE_CLASH_EDGE, FACE_CLASH_EDGE))
        canvas.alpha_composite(
            marks[1],
            (canvas.width - marks[1].width - FACE_CLASH_EDGE, FACE_CLASH_EDGE))
        return
    for mark in marks[:1]:
        top = int(box[1]) - mark.height - FACE_CLASH_GAP
        canvas.alpha_composite(mark, (cx - mark.width // 2, max(8, top)))


def _tile_photos(paths: list[str]) -> Image.Image:
    """顔写真を横に並べて、画面いっぱいにする（2026-09-08）。

    縦長の写真を1枚だけ右に置くと、左がぼかしで埋まる。参考チャンネル
    （2chサッカーの噂話・10.3万）は**全面が写真**で、顔を2〜3枚
    並べた回もあった。**縦長の写真は、並べれば縦のまま活きる。**
    """
    canvas = Image.new("RGBA", SIZE, (14, 20, 32, 255))
    cell = SIZE[0] // len(paths)
    for index, name in enumerate(paths):
        with Image.open(_resolve(name)) as source:
            photo = source.convert("RGBA")
        scale = max(cell / photo.width, SIZE[1] / photo.height)
        photo = photo.resize((max(1, int(photo.width * scale)) + 1,
                              max(1, int(photo.height * scale)) + 1), Image.LANCZOS)
        left = max(0, (photo.width - cell) // 2)
        top = max(0, min(photo.height - SIZE[1], int(photo.height * 0.04)))
        canvas.alpha_composite(photo.crop((left, top, left + cell, top + SIZE[1])),
                               (index * cell, 0))
    return canvas




def _news_thumbnail(
    config: ProjectConfig,
    out_path: Path,
    background: str | None,
    lines: tuple[str, str],
    tags: list[str],
    badge: str,
    date: str,
    focus: float | None = None,
) -> Path:
    """報道テロップ風。写真を帯で塗りつぶさず、情報として読ませる。

    構成は上から、速報フラグと日付 / 写真 / 見出しのプレート / ティッカー。
    煽り帯と違い、行ごとに必要な幅だけ下敷きを敷くので写真が残る。
    """
    font_path = str(config.video.font_path())
    # **正方形に近い写真も右に置く。**全面に敷くと顔が帯に隠れる
    # **左のぼかしは禁止**（2026-09-20 ユーザー指示）。縦長は左をべた塗りにする
    portrait = _is_portrait(background, ratio=1.05)
    if portrait:
        canvas = _flat_bed(background, tags)
        _paste_side(canvas, background)
    else:
        canvas = _base(config, background, out_path,
                       _photo_focus(background) if focus is None else focus)
    _news_scrim(canvas, narrow=portrait)

    layer, draw = _layer(SIZE)

    # ---- 上段: 速報フラグ と 日付
    x = MARGIN - 16
    flag = (badge or "速報").strip()
    flag_font = ImageFont.truetype(font_path, 38)
    flag_w = draw.textlength(flag, font=flag_font) + 48
    draw.rectangle([x, 44, x + flag_w, 44 + NEWS_FLAG_HEIGHT], fill=NEWS_FLAG + (255,))
    _centered(draw, flag, flag_font, x + 24, 44, NEWS_FLAG_HEIGHT, NEWS_INK)

    stamp = _news_date(date)
    if stamp:
        # 日付は数字だけなので欧文フォントのほうが締まる
        meta_font = ImageFont.truetype(str(config.video.latin_font_path()), 32)
        left = x + flag_w + 14
        width = draw.textlength(stamp, font=meta_font) + 40
        draw.rectangle(
            [left, 44, left + width, 44 + NEWS_FLAG_HEIGHT], fill=NEWS_PLATE
        )
        _centered(draw, stamp, meta_font, left + 20, 44, NEWS_FLAG_HEIGHT, NEWS_SUB_INK)

    # ---- 下段: ティッカー
    ticker_top = SIZE[1] - NEWS_TICKER_HEIGHT
    draw.rectangle([0, ticker_top, SIZE[0], SIZE[1]], fill=NEWS_TICKER)
    draw.rectangle([0, ticker_top, SIZE[0], ticker_top + 4], fill=NEWS_FLAG + (255,))

    label_font = ImageFont.truetype(font_path, 30)
    mark_y = ticker_top + 30
    draw.rectangle([MARGIN - 16, mark_y, MARGIN - 16 + 14, mark_y + 14], fill=NEWS_FLAG + (255,))
    draw.text((MARGIN + 12, ticker_top + 22), NEWS_LABEL, font=label_font, fill=NEWS_INK)

    if tags:
        keywords = "　".join(str(t) for t in tags[:2])
        width = draw.textlength(keywords, font=label_font)
        draw.text(
            (SIZE[0] - MARGIN + 16 - width, ticker_top + 22),
            keywords, font=label_font, fill=NEWS_META_INK,
        )

    # ---- 見出し: 下から積む。行ごとに必要なぶんだけ下敷きを敷く
    head, sub = (lines[0] or "").replace("\\n", " "), (lines[1] or "")
    bottom = ticker_top - 26
    rows = [(sub, NEWS_SUB_SIZES, NEWS_SUB_INK)] if sub else []
    rows.append((head, NEWS_HEAD_SIZES, NEWS_INK))

    for text, sizes, ink in rows:
        font, wrapped = _fit_news(draw, text, font_path, sizes)

        # 折り返した2行は同じ見出しなので、下敷きは1枚にする。
        # 行ごとに敷くと行間から背景が覗いて、別々の見出しに見えてしまう
        line_height = font.size + 18
        block = line_height * len(wrapped) + 14
        top = bottom - block
        width = max(draw.textlength(chunk, font=font) for chunk in wrapped)

        left = MARGIN - 16
        draw.rectangle([left, top, MARGIN + 16 + NEWS_BAR + width + 24, bottom], fill=NEWS_PLATE)
        draw.rectangle([left, top, left + NEWS_BAR, bottom], fill=NEWS_FLAG + (255,))

        y = top + 7
        for chunk in wrapped:
            draw.text((MARGIN + 6 + NEWS_BAR, y), chunk, font=font, fill=ink)
            y += line_height
        bottom = top - 10

    canvas.alpha_composite(layer)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, quality=95)
    return out_path


def _centered(draw, text, font, x: int, top: int, height: int, fill) -> None:
    """箱の高さに対して字を縦中央に置く。フォントごとの余白差を吸収する。"""
    box = draw.textbbox((0, 0), text, font=font)
    draw.text((x, top + (height - (box[3] - box[1])) // 2 - box[1]), text, font=font, fill=fill)


def _news_scrim(canvas: Image.Image, narrow: bool = False) -> None:
    """写真は残しつつ、上下だけ沈めて文字を読ませる。

    ``narrow`` は写真を右に置いたとき。左は元から暗いので、沈めすぎない。
    """
    if narrow:
        return
    scrim, draw = _layer(SIZE)
    for y in range(SIZE[1]):
        ratio = y / SIZE[1]
        if ratio < 0.24:                      # 上: フラグのぶんだけ軽く
            alpha = int(140 * (1 - ratio / 0.24) ** 1.4)
        elif ratio > 0.30:                    # 下: 見出しが乗るので濃く
            # 二乗で効かせると、境目が線に見えずになじむ
            alpha = int(185 * ((ratio - 0.30) / 0.70) ** 1.8)
        else:
            alpha = 0
        if alpha:
            draw.line([(0, y), (SIZE[0], y)], fill=(4, 7, 13, alpha))
    canvas.alpha_composite(scrim)


def _news_date(date: str) -> str:
    """「2026年8月30日」を「2026.08.30」にする。報道テロップの見え方に寄せる。"""
    numbers = re.findall(r"\d+", str(date or ""))
    if len(numbers) < 3:
        return str(date or "").strip()
    year, month, day = numbers[:3]
    return f"{year}.{int(month):02d}.{int(day):02d}"


def _fit_news(draw: ImageDraw.ImageDraw, text: str, font_path: str, sizes):
    """見出しを2行以内に収める。幅は測って確かめる。"""
    width = SIZE[0] - MARGIN * 2 - 90
    fallback = None
    for size in sizes:
        font = ImageFont.truetype(font_path, size)
        rows = wrap_text(draw, text, font, width)
        if any(draw.textlength(row, font=font) > width for row in rows):
            continue
        if len(rows) == 1:
            return font, rows
        if len(rows) == 2 and fallback is None:
            fallback = (font, rows)
    if fallback:
        return fallback
    font = ImageFont.truetype(font_path, sizes[-1])
    return font, wrap_text(draw, text, font, width)[:2]


def _fit_one_line(draw: ImageDraw.ImageDraw, texts: list[str], font_path: str,
                  width: int) -> ImageFont.FreeTypeFont | None:
    """**どの行も1行に収まる**いちばん大きい字を返す。

    行ごとに大きさを変えると帯が不ぞろいになるので、そろえる。
    2行に折り返すと「チ」だけが3行目に残った（2026-09-07 に書き出して発見）。
    どうしても収まらないときは、いちばん小さい字で折り返す。
    """
    texts = [t for t in texts if t]
    if not texts:
        return None
    for size in BAND_SIZES:
        font = ImageFont.truetype(font_path, size)
        if all(draw.textlength(text, font=font) <= width for text in texts):
            return font
    return ImageFont.truetype(font_path, BAND_SIZES[-1])


def _fit_band(draw: ImageDraw.ImageDraw, text: str, font_path: str, room: int = 0):
    """帯に入る中でいちばん大きい字を選ぶ。

    帯は1行に収めるのが基本。入らないときだけ2行にするが、
    2行目が数文字だけになる（泣き別れ）ときはさらに字を詰める。
    """
    # 縦長の写真を右に置いた回は、帯が画面幅より狭い（顔を隠さないため）
    # **帯の左右に余白を残す**（2026-09-13、Gemini にサムネ6枚を見せて指摘された）。
    # 「帯の端まで文字が詰まっていて、蛍光イエローで目を引く効果を
    # 文字自体が塗りつぶしている」。40/80 では1文字ぶんも空いていなかった
    width = (room - 96) if room else SIZE[0] - 180
    fallback = None
    for size in BAND_SIZES:
        font = ImageFont.truetype(font_path, size)
        rows = wrap_text(draw, text, font, width)

        # 禁則で改行できないと、収まらない1行がそのまま返ってくる。
        # 行数だけ見て採用すると帯からはみ出すので、幅を測って確かめる
        if any(draw.textlength(row, font=font) > width for row in rows):
            continue

        if len(rows) == 1:
            return font, rows
        if len(rows) == 2 and len(rows[-1]) > 3:
            # **泣き別れしていない2行だけを控えにする**（2026-09-12）。
            # ここで行数だけ見て控えていたので、「入」1文字が2行目に残った割り方が
            # いちばん大きい字として返っていた（ギュレルの回で書き出して発見）。
            if fallback is None:
                fallback = (font, rows)
            return font, rows
    if fallback:
        return fallback
    font = ImageFont.truetype(font_path, BAND_SIZES[-1])
    return font, wrap_text(draw, text, font, width)[:2]


def _draw_tags(layer: Image.Image, tags: list[str], floor: int) -> None:
    """**右下にエンブレムを並べる**（2026-09-10 ユーザー「ロゴは右下にして」）。

    前は赤い札にクラブ名を書き、その左にエンブレムを添えていた。
    **その文字は要らない**（2026-09-08 ユーザー指摘）。クラブ名は
    タイトルにも帯にも出ているので、もう一度書くと画面が混むだけだった。
    残すのはエンブレムだけで、無いクラブは何も出ない。

    置き場所は左上（44px）→ 左の中ほど（300px、2026-09-09）→ **右下**と動いた。
    左に置いていた頃は `thumbnail.points` と同じ場所を取り合い、バルコラの回で
    速度ランキングの真上に重なって数字が読めなくなった。右下は、縦長の写真を
    右に置いても顔より下、帯より右で、**どの型でも空いている**。

    `floor` は下端。帯が全幅にかかる回は、呼ぶ側が帯の上を渡してくる
    """
    if not tags:
        return
    size = _crest_px()
    right = SIZE[0] - 28
    for tag in tags[:2]:
        width = _paste_crest(layer, tag, right, floor)
        if width:
            right -= width + 26


def _draw_points(draw: ImageDraw.ImageDraw, points: list[str], font_path: str) -> None:
    """左の余白に短い言葉を積む（2026-09-08）。

    縦長の写真を右に置くと左がぼかしだけになり、「ただのぼかし」に見えた
    （ユーザー指摘）。余白を埋めるのではなく、言葉を置く。

    **ただし答えは置かない**（同日、ユーザーの指摘で作り直した）。
    最初は「挙げられた3人の名前」をそのまま並べたが、それでは
    タイトルで答えを隠している意味が消える。参考チャンネル
    （2chサッカーの噂話・10.3万）の実物を見ると、答えの位置は
    **●● で伏せてある**（「唯一やりたくないポジションは●●です」）。
    ここに置くのは、**引きになる断片**であって答えではない。
    """
    rows = points[:3]
    # **入る大きさまで縮める**（2026-09-10）。62 の決め打ちだったので、
    # 「時速」と「キロ」を足したとたん右の写真に食い込んだ
    size = POINTS_SIZE
    font = ImageFont.truetype(font_path, size)
    while size > POINTS_MIN_SIZE and max(
            draw.textlength(t, font=font) for t in rows) > POINTS_WIDTH:
        size -= 4
        font = ImageFont.truetype(font_path, size)
    step = int(size * 1.74)
    rule = int(size * 1.32)
    y = 96
    for text in rows:
        # **影ではなく縁取り**。影は明るい写真の上で効かない
        draw.text((60, y), text, font=font, fill=(255, 255, 255, 255),
                  stroke_width=POINTS_STROKE, stroke_fill=(0, 0, 0, 235))
        draw.line([(60, y + rule), (60 + draw.textlength(text, font=font), y + rule)],
                  fill=(232, 210, 31, 255), width=7)
        y += step


def _draw_note_red(draw: ImageDraw.ImageDraw, text: str, font_path: str) -> None:
    """赤い一言を上に置く（2026-09-14）。

    エンブレムの回は `points` を描かないので、帯のほかに言葉を置く場所が
    無かった。**帯の外に出す**ので、一覧では帯と2段で読める。
    """
    size = 72
    font = ImageFont.truetype(font_path, size)
    while size > 40 and draw.textlength(text, font=font) > SIZE[0] - 120:
        size -= 4
        font = ImageFont.truetype(font_path, size)
    width = draw.textlength(text, font=font)
    x = (SIZE[0] - width) / 2
    y = 26
    # 赤は背景に負けるので、白で太く縁取る
    draw.text((x, y), text, font=font, fill=(214, 16, 38, 255),
              stroke_width=10, stroke_fill=(255, 255, 255, 245))


def _crest_px() -> int:
    from . import crest as crest_mod
    return crest_mod.CREST_PX


def _crest_image(tag: str, height: int) -> Image.Image | None:
    """エンブレム・国旗を、指定の高さで読み込む。無ければ None。"""
    from . import crest as crest_mod

    path = crest_mod.find(tag)
    if path is None:
        return None
    with Image.open(path) as source:
        mark = source.convert("RGBA")
    ratio = height / mark.height
    return mark.resize((max(1, int(mark.width * ratio)), height), Image.LANCZOS)


def _paste_crest(layer: Image.Image, tag: str, right: int, bottom: int) -> int:
    """エンブレムを1つ置く。**右下を合わせる**（2026-09-10）。

    上端で合わせていた頃は、**横長のエンブレムだけ浮いて見えた**。
    高さは元の縦横比で決まるので、上を揃えると下が揃わない。
    置けたときだけ、使った幅を返す（置けなければ 0）。

    権利は晴れていない（src/crest.py に経緯）。
    """
    from . import crest as crest_mod

    path = crest_mod.find(tag)
    if path is None:
        return 0
    with Image.open(path) as source:
        mark = source.convert("RGBA")
    size = crest_mod.CREST_PX
    ratio = size / max(mark.width, mark.height)
    mark = mark.resize((max(1, int(mark.width * ratio)),
                        max(1, int(mark.height * ratio))), Image.LANCZOS)
    layer.alpha_composite(mark, (int(right - mark.width), int(bottom - mark.height)))
    return mark.width


# ------------------------------------------------------------------ パーツ


def _flat_bed(background: str | None, tags: list[str] | None = None) -> Image.Image:
    """縦長の写真の左に敷く、**べた塗りの面**（2026-09-20）。

    ぼかしは禁止（ユーザー指示）。代わりに、**その写真から拾った色**で
    上から下へのグラデーションを作る。別の絵を持ってこないので権利は変わらず、
    ぼけた絵も出ない。2026-09-08 に却下された濃紺のベタとは違い、
    写真と地続きの色になる。
    """
    base = Image.new("RGBA", SIZE, (14, 20, 32, 255))
    # **まずクラブの色**。エンブレムがあれば、そこから拾うほうが写真の芝より映える
    source_image = None
    for tag in tags or []:
        crest = _crest_image(tag, 64)
        if crest is not None:
            source_image = crest.convert("RGB")
            break
    if source_image is None:
        path = _resolve(background or "")
        if not path.exists():
            return base
        with Image.open(path) as opened:
            source_image = opened.convert("RGB")
    top = _vivid_color(source_image)
    bottom = _with_lightness(top, 0.13)
    draw = ImageDraw.Draw(base)
    for y in range(SIZE[1]):
        t = y / SIZE[1]
        draw.line([(0, y), (SIZE[0], y)],
                  fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    return base



def _vivid_color(image: Image.Image) -> tuple[int, int, int]:
    """その絵の中で、いちばん「色らしい」色を1つ選ぶ（2026-09-24）。

    **平均を取ってはいけない。**平均は必ず灰色に寄る。実際、9/24 のサムネは
    べた塗りの面が全部くすんだ灰色になり、ユーザーに「ぐれーはダメだよ」と言われた。
    色の数を8つに減らしてから、**鮮やかさ×面積**でいちばん強いものを取る。
    黒に近い色と白に近い色は、地の色にならないので外す。
    """
    import colorsys

    small = image.convert("RGB").resize((48, 48), Image.LANCZOS)
    counts: dict[tuple[int, int, int], int] = {}
    for color in small.quantize(colors=8, method=Image.MEDIANCUT).convert("RGB").getdata():
        counts[color] = counts.get(color, 0) + 1

    def strength(color: tuple[int, int, int], n: int) -> float:
        _, light, sat = colorsys.rgb_to_hls(*[v / 255 for v in color])
        if light < 0.12 or light > 0.92:
            return 0.0
        return (sat ** 1.5) * n

    best = max(counts, key=lambda c: strength(c, counts[c]))
    if strength(best, counts[best]) <= 0:
        return (18, 26, 42)          # 色らしい色が無い絵。濃紺に逃がす
    return _with_lightness(best, 0.27)


def _with_lightness(color: tuple[int, int, int], light: float) -> tuple[int, int, int]:
    """色みは残したまま、明るさだけ決める。文字が乗るので暗く、でも灰色にしない。"""
    import colorsys

    hue, _, sat = colorsys.rgb_to_hls(*[v / 255 for v in color])
    sat = max(sat, 0.45)
    return tuple(int(round(v * 255)) for v in colorsys.hls_to_rgb(hue, light, sat))


def _paste_side(canvas: Image.Image, background: str | None) -> None:
    """縦長の写真を、画面の右側に置く。高さいっぱいに使う。

    **左端はぼかさない**（2026-09-20 ユーザー指示）。境目は、べた塗りの面と
    写真がそのまま隣り合う。
    """
    path = _resolve(background or "")
    if not path.exists():
        return
    with Image.open(path) as source:
        photo = source.convert("RGBA")
    width = int(SIZE[0] * 0.56)
    scale = max(width / photo.width, SIZE[1] / photo.height)
    photo = photo.resize((max(1, int(photo.width * scale)) + 1,
                          max(1, int(photo.height * scale)) + 1), Image.LANCZOS)
    left = max(0, (photo.width - width) // 2)
    top = max(0, min(photo.height - SIZE[1], int(photo.height * 0.04)))
    canvas.alpha_composite(photo.crop((left, top, left + width, top + SIZE[1])),
                           (SIZE[0] - width, 0))


def _photo_focus(background: str | None) -> float:
    """切る高さの中心。**縦長の写真は上寄りで切る**（2026-09-20）。

    左のぼかしをやめて全面に敷いたら、既定の 0.38 では**頭の上が切れた**
    （鈴木・前田・ラフィーニャで実際に起きた）。顔は上のほうにあるので、
    縦長のときだけ上端寄りにする。
    """
    if _is_portrait(background, ratio=1.05):
        return 0.10
    return BAND_FOCUS


def _base(config: ProjectConfig, background: str | None, out_path: Path,
          focus: float | None = None) -> Image.Image:
    source = _resolve(background or config.video.background)
    if source.exists() and is_video(source.name):
        # 背景が動画なら1フレーム抜いて下地にする
        still = out_path.parent / "thumbnail_bg.png"
        still.parent.mkdir(parents=True, exist_ok=True)
        source = ffmpeg.grab_frame(source, still)
    if source.exists():
        return _cover(Image.open(source).convert("RGBA"), *SIZE, focus=focus)
    return Image.new("RGBA", SIZE, (14, 20, 32, 255))


def _scrim(canvas: Image.Image, accent: tuple[int, int, int]) -> None:
    """左を濃く、右をうっすら。文字を置く側だけ確実に沈める。"""
    scrim, draw = _layer(SIZE)
    for x in range(SIZE[0]):
        ratio = x / SIZE[0]
        alpha = int(232 - 150 * min(1.0, ratio * 1.35))
        draw.line([(x, 0), (x, SIZE[1])], fill=(6, 10, 18, alpha))
    canvas.alpha_composite(scrim)

    # 右下から差し込むアクセントの帯
    band, band_draw = _layer(SIZE)
    band_draw.polygon(
        [(SIZE[0] - 210, SIZE[1]), (SIZE[0], SIZE[1] - 260), (SIZE[0], SIZE[1])],
        fill=accent + (52,),
    )
    canvas.alpha_composite(band)


def _draw_badge(
    draw: ImageDraw.ImageDraw, badge: str, y: int, accent, font_path: str
) -> int:
    font = ImageFont.truetype(font_path, 40)
    width = draw.textlength(badge, font=font)
    draw.rounded_rectangle(
        [MARGIN, y, MARGIN + width + 52, y + 62], radius=10, fill=accent + (255,)
    )
    draw.text((MARGIN + 26, y + 8), badge, font=font, fill=(10, 14, 22, 255))
    return y + 62 + 26


def _fit_title(
    draw: ImageDraw.ImageDraw, title: str, font_path: str, available: int
) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    """入る中でいちばん大きい字を選ぶ。

    3行以内かつ確保した高さに収まること。最後の行が1〜2文字だけになる
    （泣き別れ）ときは、1段階小さくして行の頭を揃える。
    """
    text = title.replace("\\n", "\n")
    width = SIZE[0] - MARGIN * 2 - 150

    fallback = None
    for size in TITLE_SIZES:
        font = ImageFont.truetype(font_path, size)
        lines = wrap_text(draw, text, font, width)
        if len(lines) > 3 or (font.size + TITLE_GAP) * len(lines) > available:
            continue
        if fallback is None:
            fallback = (font, lines)
        if len(lines) == 1 or len(lines[-1]) > 2:
            return font, lines
    if fallback:
        return fallback
    font = ImageFont.truetype(font_path, TITLE_SIZES[-1])
    return font, wrap_text(draw, text, font, width)[:3]


def _draw_subtitle(
    draw: ImageDraw.ImageDraw, subtitle: str, y: int, font_path: str, accent
) -> None:
    font = ImageFont.truetype(font_path, 44)
    width = draw.textlength(subtitle, font=font)
    draw.rounded_rectangle(
        [MARGIN, y, MARGIN + width + 56, y + SUBTITLE_HEIGHT], radius=12, fill=accent + (255,)
    )
    draw.text((MARGIN + 28, y + 10), subtitle, font=font, fill=(12, 16, 24, 255))


def _draw_date(draw: ImageDraw.ImageDraw, date: str, font_path: str, y: int) -> None:
    font = ImageFont.truetype(font_path, 32)
    draw.text(
        (MARGIN, y), date, font=font, fill=(214, 222, 234, 255),
        stroke_width=4, stroke_fill=(0, 0, 0, 210),
    )


# ------------------------------------------------------------------ 構図（2026-10-08）
#
# **そろえるのは目印だけ、構図は回ごとに選ぶ**（2026-10-08 ユーザー承認）。
# 毎回「写真＋下の蛍光イエローの帯に黒と赤の2行」で同じ形だった。収益化の審査は
# 「テンプレートで作ったように見える・続けて見ると繰り返しに感じる」ものを対象外にする。
# 別チャンネル「歴史の地層」が 10-07 に同じことをした（chiso/thumb.py・thumbfx.py）。
#
# そろえる目印（どの構図でも同じ）:
#   - **字体**：config の video.font（いまは Meiryo Bold）
#   - **色**：主役の語は蛍光イエロー（BAND_YELLOW）、伏せ字の ● は赤（BAND_RED）、
#     名前の札は深い緑（BRAND_GREEN）に黄色の縦帯（本編の節の名前のピルと同じ作り）
#   - **下端の細い線**：蛍光イエロー 10px ＋ その上に緑 5px（帯の代わり）
#
# 構図（取材メモの `thumbnail.layout:`、台本の `thumbnail_layout:`）:
#   classic … 今の形（書かない＝これ）。画素まで今と同じ
#   face    … 顔の大写し（写真を顔に寄せて片側へ）＋反対側に2段の極太の字（1行目は白、2行目は黄）
#   scene   … 試合や場面の全景＋上か下の黒い帯に1行（2行目）。1行目は帯の縁の緑の札
#   versus  … 左右に2人（photos の2枚）、真ん中に VS（face_link）か数字の対（numbers）
#   number  … 数字（number）が画面の半分。写真は暗く後ろに
#
# **左はぼかさない**（2026-09-20）。どの構図も写真をぼかさない。文字の側は暗くするだけ。
# 周辺のぼかし（ビネット）も入れない（「左がぼやける」と取られる）。

LAYOUTS = ("classic", "face", "scene", "versus", "number")
# 取材メモの thumbnail: から台本の thumbnail_layout へ持ち越す項目
LAYOUT_KEYS = ("layout", "side", "band", "number", "names", "numbers",
               "fx", "light", "rays", "tint", "cutout")
# 写真が要る構図（thumbnail.photo。横に広いもの）
PHOTO_LAYOUTS = ("face", "scene", "number")

WHITE = (255, 255, 255)
TEXT_DARK = BAND_TEXT_DARK
RULE_YELLOW_H = 10        # 下端の目印：蛍光イエローの線
RULE_GREEN_H = 5          # その上の緑の線
LAYOUT_ZOOM_MAX = 1.5     # 顔に寄せるときの拡大の上限（決まりは1.6倍まで。少し手前で止める）
WIDE_MIN = 1.2            # 横に広い写真とみなす横÷縦（face・scene・number は全面に敷くので要る）

# 作り込みの既定（構図ごと）。台本で light・rays・tint・cutout を書けば上書き、fx: false で全部外す
FX_DEFAULTS = {
    "face": {"light": "auto", "rays": False, "tint": "none", "cutout": True},
    "scene": {"light": "none", "rays": False, "tint": "none", "cutout": False},
    "versus": {"light": "none", "rays": True, "tint": "right", "cutout": True},
    "number": {"light": "none", "rays": True, "tint": "none", "cutout": False},
}


class ThumbLines(tuple):
    """(1行目, 2行目) に、構図の指定（`.layout`）を持たせた tuple。

    書き出しの経路（pipeline.py・cli の thumbnail）は `lines=look["lines"]` を渡すだけで、
    構図の引数をまだ持たない。**ここに載せれば、その2か所を触らずに構図が届く。**
    中身はただの2つ組なので、今までの使い方（比べる・添字で取る）はそのまま通る。
    呼ぶ側が `layout=look["layout"]` を渡すようになれば、そちらが優先される。
    """

    layout: dict | None = None

    def __new__(cls, lines, layout: dict | None = None):
        obj = super().__new__(cls, tuple(lines))
        obj.layout = layout
        return obj


def _lines_with_layout(lines, spec):
    return ThumbLines(lines, spec) if spec else tuple(lines)


def layout_of(spec) -> str:
    """構図の名前（書いていなければ classic）。"""
    if isinstance(spec, str):
        return spec.strip() or "classic"
    if isinstance(spec, dict):
        return str(spec.get("layout") or "classic").strip()
    return "classic"


def layout_spec(meta: dict) -> dict | None:
    """台本の `thumbnail_layout` を読む。classic・未指定は None（今の形）。

    `thumbnail_layout: face` と名前だけでも、`{layout: face, side: left, …}` でも書ける。
    """
    raw = (meta or {}).get("thumbnail_layout")
    if not raw:
        return None
    spec = {"layout": str(raw)} if isinstance(raw, str) else dict(raw)
    return None if layout_of(spec) == "classic" else spec


def _merge_layout(base: dict | None, extra) -> dict | None:
    spec = dict(base or {})
    if isinstance(extra, str):
        spec["layout"] = extra
    else:
        spec.update(dict(extra or {}))
    return None if layout_of(spec) == "classic" else spec


def notes_layout(thumb: dict) -> dict | None:
    """取材メモの thumbnail: から、台本へ持ち越す構図の指定を抜く（classic なら None）。"""
    thumb = thumb or {}
    if layout_of(thumb.get("layout")) == "classic":
        return None
    return {k: thumb[k] for k in LAYOUT_KEYS if k in thumb}


def layout_problems(thumb: dict, root: Path | None = None) -> list[str]:
    """構図の名前の誤り・構図に要る項目の不足（draft が止める）。thumb は取材メモの thumbnail:。"""
    thumb = thumb or {}
    name = layout_of(thumb.get("layout"))
    if name not in LAYOUTS:
        return [f"thumbnail.layout の『{name}』は分かりません（{'・'.join(LAYOUTS)} のどれか）"]
    out: list[str] = []
    for alt in thumb.get("alt") or []:
        if isinstance(alt, dict) and alt.get("layout") is not None:
            merged = dict(thumb, **(alt["layout"] if isinstance(alt["layout"], dict)
                                    else {"layout": alt["layout"]}))
            merged.pop("alt", None)
            out += [f"thumbnail.alt の案: {p}" for p in layout_problems(merged, root)]
    if name == "classic":
        return out
    where = f"（構図 {name}）"
    if thumb.get("crest_main"):
        out.append(f"thumbnail.crest_main と layout は一緒に使えません{where}。"
                   "エンブレムが主役の回は layout を書かない（今の形）")
    if thumb.get("board"):
        out.append(f"thumbnail.board と layout は一緒に使えません{where}。"
                   "板が主役の回は layout を書かない（今の形）か、number で数字を出す")
    if name in PHOTO_LAYOUTS:
        photo = str(thumb.get("photo") or "").strip()
        if not photo:
            out.append(f"thumbnail.photo（横に広い写真）がありません{where}")
        else:
            size = _image_size(photo, root)
            if size and size[0] < size[1] * WIDE_MIN:
                out.append(f"thumbnail.photo {Path(photo).name} は {size[0]}×{size[1]} で横に広くありません{where}。"
                           "全面に敷くので横長（og:image や _w.jpg）を使う（縦長を切ると頭のてっぺんだけになる）")
    if name == "versus":
        photos = [str(x) for x in (thumb.get("photos") or []) if str(x).strip()]
        if len(photos) != 2:
            out.append(f"thumbnail.photos に2枚（左・右の順）が要ります{where}。いまは{len(photos)}枚")
        for key in ("names", "numbers"):
            value = thumb.get(key)
            if value is not None and not (isinstance(value, (list, tuple)) and len(value) == 2):
                out.append(f"thumbnail.{key} は [左, 右] の2つで書く{where}")
    if name == "number":
        number = str(thumb.get("number") or "").strip()
        if not number:
            out.append(f"thumbnail.number（大きく出す数字。例: 125試合・●●位）がありません{where}")
        elif not re.search(r"[0-9０-９●]", number):
            out.append(f"thumbnail.number『{number}』に数字も伏せ字（●）もありません{where}")
    for key, allowed in (("side", ("left", "right")), ("band", ("bottom", "top")),
                         ("light", ("left", "right", "top", "none", "auto")),
                         ("tint", ("left", "right", "none"))):
        if key in thumb and thumb[key] not in allowed and thumb[key] not in (False, None):
            out.append(f"thumbnail.{key} は {'／'.join(allowed)} のどれか（いまは {thumb[key]}）")
    for key in ("fx", "rays", "cutout"):
        if key in thumb and not isinstance(thumb[key], bool):
            out.append(f"thumbnail.{key} は true か false")
    return out


def _image_size(path: str, root: Path | None = None) -> tuple[int, int] | None:
    file = (root / path) if root else _resolve(path)
    if not file.exists() or is_video(file.name):
        return None
    try:
        with Image.open(file) as image:
            return image.size
    except OSError:
        return None


def fx_options(spec: dict) -> dict:
    """作り込みの設定。書いていないものは構図の既定。fx: false なら全部切る。"""
    name = layout_of(spec)
    if name not in FX_DEFAULTS or (spec or {}).get("fx") is False:
        return {"on": False, "light": "none", "rays": False, "tint": "none", "cutout": False}
    o = dict(FX_DEFAULTS[name])
    for key in ("light", "rays", "tint", "cutout"):
        if key in spec and spec[key] is not None:
            o[key] = spec[key]
    o["on"] = True
    o["layout"] = name
    return o


# ---- 部品


def _open_photo(background: str | None, out_path: Path) -> Image.Image | None:
    if not background:
        return None
    source = _resolve(background)
    if source.exists() and is_video(source.name):
        still = out_path.parent / "thumbnail_bg.png"
        still.parent.mkdir(parents=True, exist_ok=True)
        source = ffmpeg.grab_frame(source, still)
    if not source.exists():
        return None
    with Image.open(source) as image:
        return image.convert("RGB")


def _main_face(image: Image.Image):
    """いちばん大きい顔の枠（x, y, w, h）。OpenCV が無い・見つからなければ None。"""
    from . import faces

    if not faces.available():
        return None
    try:
        return faces.main_face(image, min_face=0.035)
    except Exception:
        return None


def _place(image: Image.Image, size, anchor, face=None, face_h: float = 0.0,
           focus: float | None = None, focus_x: float | None = None):
    """写真を size に切り出す。顔（face）が size の中の anchor（割合）に来るように寄せる。

    寄せる大きさは顔の高さが face_h（size の高さに対する割合）になるまで。ただし
    **元の写真の LAYOUT_ZOOM_MAX 倍まで**（引き伸ばすとぼやける）。画面を埋めるのが先。
    顔が分からなければ focus・focus_x（0〜1）を中心に、埋める大きさで切る。
    返すのは (切った絵, 切った絵の中の顔の枠 or None)。
    """
    width, height = size
    cover = max(width / image.width, height / image.height)
    if face is not None:
        scale = (height * face_h) / max(1, face[3]) if face_h else cover
        cx, cy = face[0] + face[2] / 2, face[1] + face[3] / 2
    else:
        scale = cover
        cx = image.width * (0.5 if focus_x is None else float(focus_x))
        cy = image.height * (0.35 if focus is None else float(focus))
    scale = max(cover, min(scale, LAYOUT_ZOOM_MAX))
    rw, rh = max(width, round(image.width * scale)), max(height, round(image.height * scale))
    resized = image.resize((rw, rh), Image.LANCZOS)
    left = int(min(max(0, cx * scale - anchor[0] * width), rw - width))
    top = int(min(max(0, cy * scale - anchor[1] * height), rh - height))
    tile = resized.crop((left, top, left + width, top + height))
    moved = None
    if face is not None:
        moved = (round(face[0] * scale - left), round(face[1] * scale - top),
                 round(face[2] * scale), round(face[3] * scale))
    return tile, moved


def _spans(text: str, fill) -> list[tuple[str, tuple]]:
    """伏せ字の ● だけ赤にする区切り。"""
    out: list[tuple[str, tuple]] = []
    for part in re.split(r"(●+)", text):
        if part:
            out.append((part, BAND_RED if part.startswith("●") else tuple(fill)))
    return out


def _say(canvas: Image.Image, o: dict, xy, text: str, font, fill, main: bool = False,
         anchor: str = "la", angle: float = 0.0) -> None:
    """1行描く。作り込みが入なら二重の縁取り＋影（主役の語は外に白い縁）。切なら黒い縁だけ。

    anchor は左寄せ（la・lm・ls）だけ。真ん中に置くときは呼ぶ側で幅を引いておく。
    """
    from . import thumbfx

    if not text:
        return
    size = getattr(font, "size", 60)
    stroke = max(6, size // 9) if main else max(5, size // 10)
    spans = _spans(text, fill)
    if o.get("on"):
        outer = max(3, size // 30) if main else 0
        thumbfx.text(canvas, xy, text, font, fill=fill, inner=TEXT_DARK, inner_w=stroke,
                     outer=WHITE if outer else None, outer_w=outer, shadow=True,
                     angle=angle, anchor=anchor, spans=spans)
        return
    draw = ImageDraw.Draw(canvas)
    x, y = xy
    for part, color in spans:
        draw.text((x, y), part, font=font, fill=tuple(color) + (255,), anchor=anchor,
                  stroke_width=stroke, stroke_fill=TEXT_DARK + (255,))
        x += font.getlength(part)


# 2行に割るときに、そこで切ってよい所（この字のあと）。助詞・読点・中黒
BREAK_AFTER = set("はがをにでともへや、。・！？!?")
# 「0本だった／シュートは」のように、過去の形で名詞に続く所も切ってよい
BREAK_AFTER_WORDS = ("より", "から", "まで", "ので", "のに", "けど", "ても", "った", "した", "れた", "いた")


def _natural_split(text: str) -> list[tuple[str, str]]:
    """2行に割る候補（左右の長さが近い順）。空白・助詞・読点のあとだけで切る（語の途中で割らない）。"""
    found: list[tuple[str, str]] = []
    for i in range(1, len(text)):
        before, after = text[:i], text[i:]
        if after[0] in " 　":
            found.append((before.rstrip(), after.strip()))
        elif before[-1] in " 　":
            continue
        elif ((before[-1] in BREAK_AFTER or before.endswith(BREAK_AFTER_WORDS))
              and after[0] not in BREAK_AFTER and not after[0].isdigit()):
            found.append((before, after))
    found = [(a, b) for a, b in found if len(a) > 1 and len(b) > 2]
    return sorted(set(found), key=lambda ab: (max(len(ab[0]), len(ab[1])), -len(ab[0])))


def _fit_rows(text: str, font_path: str, sizes, width: float, max_rows: int):
    """入る中でいちばん大きい字と、その行。

    2行に割るときは**空白か助詞のあとで切る**（「最後のパスを／託した相手は●●」。
    1字ずつ幅で割ると「託／した」のように語の途中で切れる）。どこで切っても入らないときだけ幅で割る。
    """
    text = (text or "").replace("\\n", " ").replace("\n", " ").strip()
    probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    if not text:
        return ImageFont.truetype(font_path, sizes[-1]), []
    splits = _natural_split(text) if max_rows >= 2 else []
    for size in sizes:
        font = ImageFont.truetype(font_path, size)
        if font.getlength(text) <= width:
            return font, [text]
        for head, tail in splits:
            if font.getlength(head) <= width and font.getlength(tail) <= width:
                return font, [head, tail]
    for size in sizes:
        font = ImageFont.truetype(font_path, size)
        rows = wrap_text(probe, re.sub(r"[ 　]+", "", text), font, width)
        if len(rows) <= max_rows and all(font.getlength(r) <= width for r in rows):
            return font, rows
    font = ImageFont.truetype(font_path, sizes[-1])
    return font, wrap_text(probe, text, font, width)[:max_rows]


def _tag(canvas: Image.Image, o: dict, x: float, y: float, text: str, font_path: str,
         size: int = 50, centre: bool = False) -> tuple[int, int, int, int]:
    """名前の札：深い緑に黄色の縦帯、白い字（本編の節の名前のピルと同じ作り）。範囲を返す。"""
    font = ImageFont.truetype(font_path, size)
    width = font.getlength(text)
    box_w, box_h = int(width + 64), int(size * 1.5)
    if centre:
        x -= box_w / 2
    x, y = int(x), int(y)
    if o.get("on"):
        shadow = Image.new("L", canvas.size, 0)
        ImageDraw.Draw(shadow).rectangle([x + 6, y + 6, x + box_w + 6, y + box_h + 6], fill=150)
        canvas.paste((0, 0, 0, 255), (0, 0), shadow.filter(ImageFilter.GaussianBlur(4)))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle([x, y, x + box_w, y + box_h], fill=BRAND_GREEN + (255,))
    draw.rectangle([x, y, x + 12, y + box_h], fill=BAND_YELLOW + (255,))
    draw.text((x + 36, y + box_h / 2), text, font=font, fill=WHITE + (255,), anchor="lm")
    return x, y, x + box_w, y + box_h


def _brand_rule(canvas: Image.Image) -> None:
    """どの構図でも同じ目印：下端に蛍光イエローの細い線、その上に緑の細い線。"""
    width, height = canvas.size
    draw = ImageDraw.Draw(canvas)
    draw.rectangle([0, height - RULE_YELLOW_H - RULE_GREEN_H, width, height - RULE_YELLOW_H - 1],
                   fill=BRAND_GREEN + (255,))
    draw.rectangle([0, height - RULE_YELLOW_H, width, height], fill=BAND_YELLOW + (255,))


def _shade(canvas: Image.Image, top: int = 0, top_alpha: int = 0,
           bottom: int = 0, bottom_alpha: int = 0) -> None:
    """上・下の端だけ暗くする（字を読ませる）。ぼかさない。"""
    width, height = canvas.size
    layer, draw = _layer(canvas.size)
    for y in range(top):
        draw.line([(0, y), (width, y)], fill=(0, 0, 0, int(top_alpha * (1 - y / top) ** 1.3)))
    for y in range(bottom):
        draw.line([(0, height - 1 - y), (width, height - 1 - y)],
                  fill=(0, 0, 0, int(bottom_alpha * (1 - y / bottom) ** 1.3)))
    canvas.alpha_composite(layer)


def _side_shade(canvas: Image.Image, side: str, alpha: int, reach: float) -> None:
    """字を置く側（side）を暗くする。写真は透けて見える（灰色の面にしない・ぼかさない）。"""
    width, height = canvas.size
    layer, draw = _layer(canvas.size)
    span = int(width * reach)
    for i in range(span):
        a = int(alpha * (1 - i / span) ** 1.2)
        x = i if side == "left" else width - 1 - i
        draw.line([(x, 0), (x, height)], fill=(0, 0, 0, a))
    canvas.alpha_composite(layer)


# 角に添えるエンブレムの高さ（1280x720 の中で）。**84px では一覧でどのクラブか分からなかった**
# （2026-10-11 ユーザー「クラブロゴ大きくして」）。classic の右下は `crest.CREST_PX` = 300。
# 2026-09-09 に 44px → 300px へ上げたのと同じ所で、新しい構図だけ小さいまま残っていた
CORNER_CREST_HEIGHT = 180


def _corner_crests(canvas: Image.Image, names: list[str], side: str, top: int = 30,
                   height: int = 92) -> int:
    """エンブレム・国旗を上の角に並べる（2つまで）。使った下端を返す（置けなければ top）。"""
    marks = [m for m in (_crest_image(n, height) for n in (names or [])[:2]) if m is not None]
    if not marks:
        return top
    x = 40 if side == "left" else canvas.width - 40
    for mark in marks:
        if side == "left":
            canvas.alpha_composite(mark, (x, top))
            x += mark.width + 18
        else:
            x -= mark.width
            canvas.alpha_composite(mark, (x, top))
            x -= 18
    return top + height


def _pop(canvas: Image.Image, o: dict, tile: Image.Image, pos, source: str | None,
         face=None, outline=WHITE, clip=None, salt=()) -> bool:
    """主役の写真から人物を切り抜いて前に浮かせる（cutout）。rembg が無い・抜けが悪ければ何もしない。"""
    from . import thumbfx

    if not (o.get("on") and o.get("cutout")) or not source:
        return False
    try:
        mask = thumbfx.person_mask(tile, thumbfx.key_of(tile, *salt), face=face)
    except Exception:
        return False
    if mask is None:
        return False
    thumbfx.pop_out(canvas, tile, pos, mask, outline=outline, clip=clip)
    return True


# ---- 構図


def _layout_thumbnail(config: ProjectConfig, out_path: Path, background: str | None,
                      lines, tags: list[str], crests: list[str] | None, photos: list[str],
                      focus, focus_x, face_link: str, spec: dict) -> Path:
    font_path = str(config.video.font_path())
    name = layout_of(spec)
    if name not in LAYOUTS:
        raise ValueError(f"サムネの構図『{name}』は分かりません（{'・'.join(LAYOUTS)}）")
    o = fx_options(spec)
    marks = tags if crests is None else crests
    pair = tuple(lines or ("", ""))
    line1 = str(pair[0] or "").replace("\\n", " ")
    line2 = str(pair[1] or "") if len(pair) > 1 else ""
    if name == "versus":
        canvas = _layout_versus(spec, o, photos, line1, line2, marks, face_link, font_path, out_path)
    else:
        photo = _open_photo(background, out_path)
        draw_fn = {"face": _layout_face, "scene": _layout_scene, "number": _layout_number}[name]
        canvas = draw_fn(spec, o, photo, background, line1, line2, marks, focus, focus_x, font_path)
    _brand_rule(canvas)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, quality=95)
    return out_path


def _blank() -> Image.Image:
    return Image.new("RGBA", SIZE, (14, 20, 32, 255))


FACE_TEXT_W = 0.52        # face：字を置く側の幅（画面に対する割合）
FACE_LEAD_MAX = 1.15      # face：1行目（白）の字は、2行目（主役）のこの倍まで


def _layout_face(spec, o, photo, source, line1, line2, marks, focus, focus_x, font_path):
    """顔の大写し＋反対側に2段の極太の字。顔は side（既定 right）の側へ寄せる。"""
    from . import thumbfx

    right = str(spec.get("side") or "right") == "right"
    face = _main_face(photo) if photo is not None else None
    tile = moved = None
    if photo is not None:
        tile, moved = _place(photo, SIZE, (0.72 if right else 0.28, 0.40), face, 0.30,
                             focus, focus_x)
        canvas = tile.convert("RGBA")
    else:
        canvas = _blank()
    text_side = "left" if right else "right"
    if o.get("on"):
        light = o.get("light")
        light = ("right" if right else "left") if light == "auto" else str(light)
        thumbfx.light(canvas, light)
        if o.get("tint") in ("left", "right"):
            thumbfx.tint(canvas, o["tint"])
        if o.get("rays"):
            thumbfx.rays(canvas, (int(SIZE[0] * (0.70 if right else 0.30)), 260))
        if tile is not None:
            _pop(canvas, o, tile, (0, 0), source, face=moved)
    _side_shade(canvas, text_side, 195, 0.62)
    _shade(canvas, bottom=150, bottom_alpha=110)
    width = int(SIZE[0] * FACE_TEXT_W)
    x0 = 48 if right else SIZE[0] - width - 40
    top = _corner_crests(canvas, marks, text_side, top=34, height=CORNER_CREST_HEIGHT)
    f1, rows1 = _fit_rows(line1, font_path, (104, 96, 88, 80, 72, 64, 58, 52), width, 2)
    f2, rows2 = _fit_rows(line2, font_path, (156, 144, 132, 120, 110, 100, 92, 84, 76, 68, 60),
                          width, 2)
    if rows2 and f1.size > int(f2.size * FACE_LEAD_MAX):
        # **主役は2行目**。1行目（白）がずっと大きいと、どちらを読めばいいか分からない
        f1, rows1 = _fit_rows(line1, font_path, tuple(x for x in (104, 96, 88, 80, 72, 64, 58, 52)
                                                     if x <= int(f2.size * FACE_LEAD_MAX)) or (52,),
                              width, 2)
    gap = 22
    step1, step2 = int(f1.size * 1.16), int(f2.size * 1.14)
    floor = SIZE[1] - RULE_YELLOW_H - RULE_GREEN_H - 30
    ceiling = top + 20
    y = max(ceiling, ceiling + (floor - ceiling - step1 * len(rows1) - gap - step2 * len(rows2)) // 2)
    for row in rows1:
        _say(canvas, o, (x0, y), row, f1, WHITE)
        y += step1
    y += gap
    for row in rows2:
        _say(canvas, o, (x0 - 4, y), row, f2, BAND_YELLOW, main=True)
        y += step2
    return canvas


SCENE_BAND = 168


def _layout_scene(spec, o, photo, source, line1, line2, marks, focus, focus_x, font_path):
    """場面の全景（暗くしない）＋上か下の黒い帯に1行（2行目）。1行目は帯の縁の緑の札。"""
    from . import thumbfx

    bottom = str(spec.get("band") or "bottom") == "bottom"
    if photo is not None:
        canvas = _cover(photo.convert("RGBA"), *SIZE,
                        focus=(0.35 if focus is None else focus), focus_x=focus_x)
    else:
        canvas = _blank()
    if o.get("on"):
        if o.get("light") in ("left", "right", "top"):
            thumbfx.light(canvas, str(o["light"]), dark=0.8)
        if o.get("tint") in ("left", "right"):
            thumbfx.tint(canvas, o["tint"])
        if o.get("rays"):
            thumbfx.rays(canvas, (SIZE[0] // 2, SIZE[1] // 2))
    rule = RULE_YELLOW_H + RULE_GREEN_H
    y0 = SIZE[1] - rule - SCENE_BAND if bottom else 0
    band, draw = _layer(SIZE)
    if o.get("on"):
        # 帯の縁に薄い影（帯が写真から浮く）
        for i in range(28):
            yy = (y0 - 1 - i) if bottom else (y0 + SCENE_BAND + i)
            draw.line([(0, yy), (SIZE[0], yy)], fill=(0, 0, 0, int(110 * (1 - i / 28))))
    draw.rectangle([0, y0, SIZE[0], y0 + SCENE_BAND], fill=(6, 8, 12, 232))
    canvas.alpha_composite(band)
    _corner_crests(canvas, marks, "right", top=(30 if bottom else SCENE_BAND + 30), height=CORNER_CREST_HEIGHT)
    if line1:
        size = 50
        tag_h = int(size * 1.5)
        _tag(canvas, o, 40, (y0 - tag_h) if bottom else (y0 + SCENE_BAND), line1, font_path, size)
    font, rows = _fit_rows(line2 or line1, font_path,
                           (124, 116, 108, 100, 92, 84, 76, 68, 60, 54), SIZE[0] - 96, 1)
    if rows:
        _say(canvas, o, (48, y0 + SCENE_BAND // 2 + 4), rows[0], font, BAND_YELLOW, main=True,
             anchor="lm")
    return canvas


def _layout_versus(spec, o, photos, line1, line2, marks, face_link, font_path, out_path):
    """左右に2人。斜めの黄色い線で分け、真ん中に VS（face_link）か、各自の数字（numbers）。"""
    from PIL import ImageChops

    from . import thumbfx

    half = SIZE[0] // 2 + 60
    slant = 50
    tiles, faces_in = [], []
    for index in range(2):
        path = photos[index] if index < len(photos) else None
        photo = _open_photo(path, out_path)
        if photo is None:
            tiles.append(Image.new("RGB", (half, SIZE[1]), (14, 20, 32)))
            faces_in.append(None)
            continue
        tile, moved = _place(photo, (half, SIZE[1]), (0.5, 0.42), _main_face(photo), 0.22)
        tiles.append(tile)
        faces_in.append(moved)
    canvas = Image.new("RGBA", SIZE, (14, 20, 32, 255))
    canvas.paste(tiles[0].convert("RGBA"), (0, 0))
    split = Image.new("L", SIZE, 0)
    ImageDraw.Draw(split).polygon([(SIZE[0] // 2 + slant, 0), (SIZE[0], 0), (SIZE[0], SIZE[1]),
                                   (SIZE[0] // 2 - slant, SIZE[1])], fill=255)
    right = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    right.paste(tiles[1].convert("RGBA"), (SIZE[0] // 2 - 60, 0))
    canvas.paste(right, (0, 0), split)
    numbers = [str(x) for x in (spec.get("numbers") or [])][:2]
    numbers = numbers if len(numbers) == 2 and all(numbers) else []
    mark = str(face_link or "").strip() or ("" if numbers else "VS")
    if o.get("on"):
        if o.get("tint") in ("left", "right"):
            thumbfx.tint(canvas, o["tint"], split=(SIZE[0] // 2 + slant, SIZE[0] // 2 - slant),
                         strength=0.32)
        if o.get("light") in ("left", "right", "top"):
            thumbfx.light(canvas, str(o["light"]), dark=0.8)
        if o.get("rays"):
            thumbfx.rays(canvas, (SIZE[0] // 2, 350), alpha=0.12, hole=170)
        for index in range(2):
            clip = split if index else ImageChops.invert(split)
            source = photos[index] if index < len(photos) else None
            pos = (SIZE[0] // 2 - 60, 0) if index else (0, 0)
            _pop(canvas, o, tiles[index], pos, source, face=faces_in[index],
                 outline=BAND_YELLOW, clip=clip, salt=("versus", index))
    _shade(canvas, top=170, top_alpha=200, bottom=250, bottom_alpha=215)
    draw = ImageDraw.Draw(canvas)
    seam = [(SIZE[0] // 2 + slant, 0), (SIZE[0] // 2 - slant, SIZE[1])]
    draw.line(seam, fill=TEXT_DARK + (255,), width=22)
    draw.line(seam, fill=BAND_YELLOW + (255,), width=12)
    # 上：1行目（白）
    font, rows = _fit_rows(line1, font_path, (92, 86, 80, 74, 68, 62, 56, 50), SIZE[0] - 120, 1)
    if rows:
        _say(canvas, o, ((SIZE[0] - font.getlength(rows[0])) / 2, 74), rows[0], font, WHITE,
             anchor="lm")
    # 真ん中：VS（または face_link の字）
    crest_floor = 300
    if mark:
        big = ImageFont.truetype(font_path, 190 if len(mark) <= 2 else 120)
        _say(canvas, o, (SIZE[0] / 2 - big.getlength(mark) / 2, 350), mark, big, BAND_YELLOW,
             main=True, anchor="lm", angle=(-6.0 if o.get("on") else 0.0))
        crest_floor = int(350 - big.size * 0.62)
    crest_marks = [m for m in (_crest_image(n, 96) for n in (marks or [])[:2]) if m is not None]
    if len(crest_marks) == 1:
        piece = crest_marks[0]
        canvas.alpha_composite(piece, (SIZE[0] // 2 - piece.width // 2,
                                       max(130, crest_floor - piece.height - 14)))
    elif len(crest_marks) == 2:
        canvas.alpha_composite(crest_marks[0], (30, 140))
        canvas.alpha_composite(crest_marks[1], (SIZE[0] - crest_marks[1].width - 30, 140))
    # 各自の数字と名前（左右の真ん中）
    names = [str(x) for x in (spec.get("names") or [])][:2]
    for index in range(2):
        cx = SIZE[0] // 4 + (SIZE[0] // 2) * index + (-10 if index else 10)
        if numbers:
            nf, nrows = _fit_rows(numbers[index], font_path, (132, 120, 108, 96, 84, 72),
                                  SIZE[0] // 2 - 120, 1)
            if nrows:
                _say(canvas, o, (cx - nf.getlength(nrows[0]) / 2, 440), nrows[0], nf,
                     BAND_YELLOW, main=True, anchor="lm")
        if index < len(names) and names[index]:
            _tag(canvas, o, cx, 500, names[index], font_path, 44, centre=True)
    # 下：2行目（黄）
    if line2:
        font, rows = _fit_rows(line2, font_path, (100, 92, 86, 80, 74, 68, 62, 56), SIZE[0] - 120, 1)
        rule = RULE_YELLOW_H + RULE_GREEN_H
        if rows:
            _say(canvas, o, ((SIZE[0] - font.getlength(rows[0])) / 2, SIZE[1] - rule - 62),
                 rows[0], font, BAND_YELLOW, main=True, anchor="lm")
    return canvas


_NUMBER_PART = re.compile(r"[0-9０-９●][0-9０-９,，.．●]*")


def _number_parts(text: str) -> list[tuple[str, bool]]:
    """数字（と伏せ字）の所と、それ以外（位・試合・年）に分ける。数字は大きく、ほかは小さく。"""
    out, i = [], 0
    for m in _NUMBER_PART.finditer(text):
        if m.start() > i:
            out.append((text[i:m.start()], False))
        out.append((m.group(0), True))
        i = m.end()
    if i < len(text):
        out.append((text[i:], False))
    return out or [(text, True)]


def _part_font(text: str, is_number: bool, big, small):
    """数字は大きく、ほかは小さく。**伏せ字の ● は数字の7割**（同じ大きさだと赤い丸が画面を埋める）。"""
    if not is_number:
        return small
    if text and set(text) <= {"●"}:
        return ImageFont.truetype(big.path, int(big.size * 0.7))
    return big


def _layout_number(spec, o, photo, source, line1, line2, marks, focus, focus_x, font_path):
    """数字が画面の半分。写真は暗く後ろに（ぼかさない）。上に1行目、下に2行目。"""
    from . import thumbfx

    if photo is not None:
        canvas = _cover(photo.convert("RGBA"), *SIZE, focus=focus, focus_x=focus_x)
    else:
        canvas = _blank()
    # 字の側（左）を濃く、右は顔が見える程度に
    dark, draw = _layer(SIZE)
    for x in range(SIZE[0]):
        draw.line([(x, 0), (x, SIZE[1])], fill=(0, 0, 0, int(190 - 80 * (x / SIZE[0]))))
    canvas.alpha_composite(dark)
    parts = _number_parts(str(spec.get("number") or "").strip())
    room = SIZE[0] - 96
    size = 330

    def measure(big, small) -> float:
        return sum(_part_font(s, n, big, small).getlength(s) + (0 if n else 8) for s, n in parts)

    while size > 120:
        if measure(ImageFont.truetype(font_path, size),
                   ImageFont.truetype(font_path, int(size * 0.42))) <= room:
            break
        size -= 10
    big, small = ImageFont.truetype(font_path, size), ImageFont.truetype(font_path, int(size * 0.42))
    baseline = 468
    x = 48
    if o.get("on"):
        light = o.get("light")
        if light in ("left", "right", "top"):
            thumbfx.light(canvas, str(light), dark=0.8)
        if o.get("tint") in ("left", "right"):
            thumbfx.tint(canvas, o["tint"])
        if o.get("rays"):
            thumbfx.rays(canvas, (int(x + measure(big, small) / 2), int(baseline - size * 0.38)),
                         color=(255, 240, 120), alpha=0.20, hole=150)
    _corner_crests(canvas, marks, "right", top=34, height=CORNER_CREST_HEIGHT)
    f1, rows1 = _fit_rows(line1, font_path, (84, 78, 72, 66, 60, 54, 48), SIZE[0] - 96 - 230, 1)
    if rows1:
        _say(canvas, o, (48, 92), rows1[0], f1, WHITE, anchor="lm")
    for text, is_number in parts:
        if is_number:
            font = _part_font(text, True, big, small)
            _say(canvas, o, (x, baseline), text, font, BAND_YELLOW, main=True, anchor="ls")
            x += font.getlength(text)
        else:
            x += 8
            _say(canvas, o, (x, baseline), text, small, WHITE, anchor="ls")
            x += small.getlength(text)
    if line2:
        f2, rows2 = _fit_rows(line2, font_path, (92, 86, 80, 74, 68, 62, 56), SIZE[0] - 96, 1)
        rule = RULE_YELLOW_H + RULE_GREEN_H
        if rows2:
            _say(canvas, o, (48, SIZE[1] - rule - 84), rows2[0], f2, WHITE, anchor="lm")
    return canvas
