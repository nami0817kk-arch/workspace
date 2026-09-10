"""サムネイル(1280x720)の生成。

一覧で見たときに何の動画か一瞬で分かることを優先する。写真素材が無くても
成立するよう、文字の大きさとコントラストで見せる構成にしている。
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from . import ffmpeg
from .config import ProjectConfig, _resolve
from .ffmpeg import is_video
from .render import _cover, _hex, _layer, wrap_text

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
# **暗すぎると `サムネの黒` の点検が止める**（実測で顔の段の75%が黒だった）。
# 一覧で沈まない明るさにする
CREST_MAIN_GROUND = (34, 58, 96, 255)

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


def _short_thumbnail(
    config: ProjectConfig,
    out_path: Path,
    background: str | None,
    lines: tuple[str, str],
    tags: list[str],
    focus: float | None,
    quote: str,
    photos: list[str],
) -> Path:
    """1080x1920 のサムネイル。ショート専用。"""
    font_path = str(config.video.font_path())
    accent = _hex(config.video.accent)
    width, height = SHORT_SIZE

    source = None
    for candidate in [*(photos or []), background]:
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
            canvas = _cover(image.convert("RGBA"), width, height,
                            focus=focus if focus is not None else 0.18)
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
        "lines": (line1, line2),
        "tags": [str(t) for t in (meta.get("thumbnail_tags") or [])],
        # 指定が無ければ、タイトルの【】をそのままバッジにする。
        # **既定の「速報」を出しっぱなしにすると、悲報の記事に速報と出る**
        # （2026-09-06 実測。マルティネッリ退団の回で食い違っていた）
        "badge": str(meta.get("thumbnail_badge", "")) or _prefix_of(title),
        "date": str(meta.get("date", "")),
        # サムネの下地。**選手の顔を敷けるようにする。**参考3チャンネルは
        # どれも人の顔を全面に出しており、文字だけのサムネは一覧で埋もれる
        # （2026-09-05 実測）。指定が無ければ台本の背景を使う
        "photo": str(meta.get("thumbnail_photo") or ""),
        # 写真のどこを残すか（0.0=上端 / 1.0=下端）。顔が中央にある写真で使う
        "focus": meta.get("thumbnail_focus"),
        # 帯の上に出す反応のひとこと（2026-09-07）。最高再生の2本はどちらも
        # 「変な声出た」「一番強くて草」のような**書き込みの断片**を小窓で出して
        # いた。反応を集めたチャンネルであることが、一覧の時点で分かる
        "reaction": str(meta.get("thumbnail_reaction") or ""),
        # 左の余白に積む短い言葉（2026-09-08）。縦長の写真を右に置くと
        # 左がぼかしだけになり「ただのぼかし」に見えた（ユーザー指摘）。
        # **中身を置けば余白が情報になる。**3つまで、1つ10字くらい
        "points": [str(x) for x in (meta.get("thumbnail_points") or [])][:3],
        # 顔を並べる（2026-09-08）。2〜3枚あれば全面が写真になり、
        # ぼかしの下地が要らない。参考チャンネルは全面が写真だった
        "photos": [str(x) for x in (meta.get("thumbnail_photos") or [])][:3],
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
            telop = (getattr(line, "telop", "") or "").strip()
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
        found.append(
            {
                **base,
                "name": f"案{number}",
                "title": line1,
                "subtitle": line2,
                "lines": (line1, line2),
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
    reaction: str = "",
    points: list[str] | None = None,
    photos: list[str] | None = None,
    quote: str = "",
    crest_main: list[str] | None = None,
    crests: list[str] | None = None,
    crest_link: str = "対",
) -> Path:
    """サムネイルを1枚作る。

    style="band" にすると、写真の上に黄色帯と赤帯を重ねる形になる。
    lines は (黄色帯の文字, 赤帯の文字)。省略時は title / subtitle を使う。
    """
    chosen = style or config.video.thumbnail_style
    # **縦の動画には縦のサムネ**（2026-09-09）。ショートは portrait() で
    # width < height の設定になるので、そこで切り替える
    if config.video.height > config.video.width:
        return _short_thumbnail(
            config, out_path, (photos or [None])[0] or background,
            lines or (title, subtitle), tags or [], focus,
            quote or reaction, photos or [],
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
            photos or [], crest_main or [], crests, crest_link,
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
    photos: list[str] | None = None,
    crest_main: list[str] | None = None,
    crests: list[str] | None = None,
    crest_link: str = "対",
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
    # **正方形に近い写真も右に置く。**全面に敷くと顔が帯に隠れる
    stage = _crest_stage(crest_main or [], font_path, crest_link)
    tiles = [] if stage is not None else [q for q in (photos or []) if _resolve(q).exists()]
    if stage is not None:
        canvas = stage
        portrait = False
    elif len(tiles) >= 2:
        # **並べれば全面が写真になる。**ぼかしの下地が要らない
        canvas = _tile_photos(tiles)
        portrait = False
    else:
        portrait = _is_portrait(background, ratio=0.95)
    if stage is not None:
        pass
    elif portrait:
        canvas = _blur_bed(background)
        _paste_side(canvas, background)
    elif len(tiles) < 2:
        # **帯が下の4割を覆うので、顔を上に寄せる。**真ん中で切ると、
        # 額と目だけが残って口から下が帯に隠れた（2026-09-07 に書き出して発見）。
        # 指定があればそちらを優先する
        canvas = _base(config, background, out_path,
                       BAND_FOCUS if focus is None else focus)

    # 写真をそのまま活かすので、暗幕は下側だけ薄くかける
    scrim, draw = _layer(SIZE)
    for y in range(int(SIZE[1] * 0.45), SIZE[1]):
        ratio = (y - SIZE[1] * 0.45) / (SIZE[1] * 0.55)
        draw.line([(0, y), (SIZE[0], y)], fill=(0, 0, 0, int(120 * ratio)))
    canvas.alpha_composite(scrim)

    layer, draw = _layer(SIZE)
    if portrait and points:
        _draw_points(draw, points, font_path)

    top_text = (lines[0] or "").replace(chr(92) + "n", " ")
    bottom_text = lines[1] or ""
    # 縦長の写真を右に置いた回は、帯を左だけにして顔を隠さない
    right = int(SIZE[0] * 0.52) if portrait else SIZE[0] - 16
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
        line_height = font.size + 10
        height = line_height * len(rows) + 20
        bottom = SIZE[1] - 22
        top = bottom - height
        draw.rectangle([16, top, right, bottom], fill=BAND_YELLOW + (255,))
        y = top + 8
        for row, ink in rows:
            draw.text((34, y), row, font=font, fill=ink + (255,))
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
        if band_top is not None and not portrait:
            floor = band_top - 16
        _draw_tags(layer, tags if crests is None else crests, floor)

    canvas.alpha_composite(layer)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, quality=95)
    return out_path


def _crest_stage(names: list[str], font_path: str, link: str = "対") -> Image.Image | None:
    """エンブレムを大きく並べた下地。写真の代わりに使う。

    **元の画像が小さい**（実測で 112x132 など）。拡大するとどうしても
    眠くなるので、暗い地に置いてコントラストで見せる。
    """
    from . import crest as crest_mod

    found = [(n, crest_mod.find(n)) for n in names]
    found = [(n, p) for n, p in found if p is not None]
    if not found:
        return None
    canvas = Image.new("RGBA", SIZE, CREST_MAIN_GROUND)
    # 中央をうっすら明るく。**平らな一色は一覧で沈む**
    glow, glow_draw = _layer(SIZE)
    for step in range(14):
        radius = int(SIZE[0] * (0.62 - step * 0.04))
        glow_draw.ellipse(
            [SIZE[0] // 2 - radius, int(SIZE[1] * 0.32) - radius // 2,
             SIZE[0] // 2 + radius, int(SIZE[1] * 0.32) + radius // 2],
            fill=(96, 132, 186, 16),
        )
    canvas.alpha_composite(glow)
    marks = []
    for _, path in found[:3]:
        with Image.open(path) as source:
            mark = source.convert("RGBA")
        ratio = CREST_MAIN_HEIGHT / mark.height
        marks.append(mark.resize((max(1, int(mark.width * ratio)), CREST_MAIN_HEIGHT),
                                 Image.LANCZOS))
    gap = 96
    total = sum(m.width for m in marks) + gap * (len(marks) - 1)
    x = (SIZE[0] - total) // 2
    # 帯が下を覆うので、少し上に置く
    top = int(SIZE[1] * 0.30) - CREST_MAIN_HEIGHT // 2
    middles = []
    for mark in marks:
        canvas.alpha_composite(mark, (x, top))
        middles.append(x + mark.width // 2)
        x += mark.width + gap
    if len(marks) == 2 and link:
        # **間の字は「対」だけではない**（2026-09-10）。アラウホの回は
        # 対戦ではなく**バルサからリヴァプールへのレンタル**の話なのに、
        # 「リヴァプール 対 バルセロナ」に見えていた。取材メモの
        # `thumbnail.crest_link` で変えられる（"対" / "→" / 空文字で消す）
        font = ImageFont.truetype(font_path, 72)
        draw = ImageDraw.Draw(canvas)
        text = link
        width = draw.textlength(text, font=font)
        draw.text(((middles[0] + middles[1] - width) / 2,
                   top + CREST_MAIN_HEIGHT / 2 - 44),
                  text, font=font, fill=(255, 255, 255, 235))
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


def _blur_bed(background: str | None) -> Image.Image:
    """縦長の写真を右に置くとき、**左に敷く下地**を作る。

    2026-09-08 まで、左は塗りつぶしの濃紺だった。実測すると顔の段の
    **72%が真っ黒**で、一覧に並べると沈んで見えた（ユーザー指摘）。
    同じ写真を大きく引き伸ばしてぼかし、暗くして敷く。
    別の写真を持ってこないので、権利の扱いは変わらない。
    """
    from PIL import ImageEnhance, ImageFilter

    base = Image.new("RGBA", SIZE, (14, 20, 32, 255))
    path = _resolve(background or "")
    if not path.exists():
        return base
    with Image.open(path) as source:
        photo = source.convert("RGB")
    # 画面を埋める大きさまで拡大してから、真ん中を切る
    scale = max(SIZE[0] / photo.width, SIZE[1] / photo.height) * 1.35
    photo = photo.resize((max(1, int(photo.width * scale)),
                          max(1, int(photo.height * scale))), Image.LANCZOS)
    left = max(0, (photo.width - SIZE[0]) // 2)
    top = max(0, (photo.height - SIZE[1]) // 3)
    photo = photo.crop((left, top, left + SIZE[0], top + SIZE[1]))
    photo = photo.filter(ImageFilter.GaussianBlur(28))
    photo = ImageEnhance.Brightness(photo).enhance(0.60)
    photo = ImageEnhance.Color(photo).enhance(0.85)
    base.alpha_composite(photo.convert("RGBA"))
    return base


def _paste_side(canvas: Image.Image, background: str | None) -> None:
    """縦長の写真を、画面の右側に置く。高さいっぱいに使う。"""
    path = _resolve(background or "")
    if not path.exists():
        return
    with Image.open(path) as source:
        photo = source.convert("RGBA")
    # **枠を埋めるまで拡大する。**高さだけ合わせていたので、細い縦写真だと
    # 幅が足りず、左半分がぼかしのまま残った（2026-09-08 ユーザー指摘）。
    # 顔は上にあるので、縦は上寄りに切る
    width = int(SIZE[0] * 0.58)
    scale = max(width / photo.width, SIZE[1] / photo.height)
    photo = photo.resize((max(1, int(photo.width * scale)) + 1,
                          max(1, int(photo.height * scale)) + 1), Image.LANCZOS)
    left = max(0, (photo.width - width) // 2)
    top = max(0, min(photo.height - SIZE[1], int(photo.height * 0.04)))
    photo = photo.crop((left, top, left + width, top + SIZE[1]))
    canvas.alpha_composite(photo, (SIZE[0] - width, 0))

    # 写真の左端をぼかして地になじませる（切り貼りに見せない）
    fade, draw = _layer(SIZE)
    edge = 90
    for step in range(edge):
        alpha = int(235 * (1 - step / edge))
        draw.line([(SIZE[0] - width + step, 0), (SIZE[0] - width + step, SIZE[1])],
                  fill=(10, 14, 22, alpha))
    canvas.alpha_composite(fade)


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
    portrait = _is_portrait(background, ratio=0.95)
    if portrait:
        # **縦長の写真は全面に敷けない。**16:9 に切ると顔が残らず、
        # 下の見出しとぶつかる（2026-09-05 実測。切る位置を変えても解けなかった）。
        # 右側に置いて、文字は左に寄せる。参考チャンネルもこの並び
        canvas = _base(config, None, out_path)
        _paste_side(canvas, background)
    else:
        canvas = _base(config, background, out_path, focus)
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
    width = (room - 40) if room else SIZE[0] - 80
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
        if len(rows) == 2:
            if fallback is None:
                fallback = (font, rows)
            if len(rows[-1]) > 3:
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


def _crest_px() -> int:
    from . import crest as crest_mod
    return crest_mod.CREST_PX


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
