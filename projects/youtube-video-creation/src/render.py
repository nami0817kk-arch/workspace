"""1フレームぶんの画面を描き、静止画の並びとして動画を組み立てる。

各セリフは「口を閉じた絵」と「開けた絵」の2枚だけを作り、concat demuxer で
交互に並べることで口パクにする。フレームは内容ハッシュでキャッシュするので、
同じ画面が続いても PNG は増えない。
"""

from __future__ import annotations

import hashlib
import math
import re
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from . import cards, emphasis, ffmpeg
from . import marks as marks_mod
from .backgrounds import moving_background
from .inserts import Inserts
from .ffmpeg import is_video
from .config import CastMember, ProjectConfig, _resolve
from .script_model import Line, Scene, Script

MOUTH_INTERVAL = 0.14  # 口パクの切り替え間隔（秒）
TELOP_RISE = 46        # テロップが せり上がる 距離(px)

# 情報の確度バッジ。ニュース系で「確定」と「噂」を見た目で分けるためのもの
SOURCE_BADGES = {
    "official": ("確定", (61, 200, 120)),
    "report": ("報道", (235, 165, 40)),
    "rumor": ("未確認", (150, 152, 158)),
    "context": ("背景", (124, 148, 184)),
}
SPEAKER_HOP = 24       # 話し始めに立ち絵が跳ねる高さ(px)
TELOP_MARGIN = 110
TELOP_HEIGHT = 250
TELOP_MAX_SHARE = 0.42   # 字が多いとき、テロップ枠が使ってよい画面の高さ
TELOP_BOTTOM = 58

# **見た目の作り直し**（2026-09-28 ユーザー「全体的に画面描画の質を上げたい／目でも楽しめるように」
# →見本を2回見せて「よくなってきた」）。色はチャンネルの2色で通す
BRAND_GREEN = (11, 61, 46)
BRAND_GOLD = (255, 213, 74)
MEDIA_FLOOR = 0.64       # 立ち絵なしのとき、表や写真が使ってよい下限（画面の高さの割合）
# **進捗バーは出さない**（2026-09-29 ユーザー「これからは外して」）。9/28 に入れた画面下端の黄色い線。
# 仕組み（ffmpeg の overlay で時間で伸ばす）は残してあり、8 に戻せばまた出る。蒸し返さない
PROGRESS_HEIGHT = 0
PHOTO_MAX_ZOOM = 1.25    # 写真の寄りの上限（背景の 1.45 だと顔が荒れる）
PILL_IN = 0.35           # 節の頭で左上のピルとテロップが滑り込む秒数（動きの段3）
IMAGE_FADE = 0.35        # 写真が別の写真に替わる行は、前の絵から溶かして切り替える（品質100回の11）
ROW_IN = 0.14            # 表・棒グラフの行が1本ずつ現れる間隔（動きの段2）
# **書き込み（赤ペン）を描き進める秒数とコマ数**（2026-10-07、src/marks.py）。線が伸び、添え書きが1字ずつ出る。
# 読み上げの内側から取るので尺は変わらない
MARK_IN = 0.5
MARK_STEPS = 7
# 読み上げの数字は自動で黄色にする（「22点」「75.5%」「4試合」）。囲みで指定した強調があればそちらを優先
AUTO_STRONG = re.compile(r"\d[\d,.]*(?:[億万千])?(?:[点本人%回分秒位歳勝敗年倍]|試合|ゴール|アシスト|ユーロ|パーセント|メートル|キロ|センチ|km|m)?")   # 2文字の単位は字の集合に入れない（「キロ」が「キ」で切れた）


@dataclass
class Layout:
    width: int
    height: int
    with_characters: bool = True
    # **横のどこを残すか**（2026-09-18）。縦型に横長の写真を敷くと、
    # 横は真ん中で切られる。端に写っている人を残したいときだけ台本から指定する
    focus_x: float | None = None

    @property
    def telop_box(self) -> tuple[int, int, int, int]:
        top = self.height - TELOP_BOTTOM - TELOP_HEIGHT
        return (TELOP_MARGIN, top, self.width - TELOP_MARGIN, top + TELOP_HEIGHT)

    @property
    def is_portrait(self) -> bool:
        """縦型（ショート）か。**横型の割合をそのまま使うと文字が切れる。**

        実測（2026-09-06）で、幅1080の縦型にカードを64%（691px）で作ったところ、
        選手名が右端で切れた。横1920なら同じ64%で1228pxあり、収まっていた。
        """
        return self.height > self.width

    @property
    def media_slot(self) -> tuple[int, int]:
        """画像やカードを置く縦の範囲。文字の上を使う。

        立ち絵なしのときの見出しは下寄せなので、2行なら画面の 0.69 より下にしか来ない。
        表の下限を 0.58 → 0.64 に下げて、表を大きく出す（2026-09-28）。
        """
        floor = (int(self.height * MEDIA_FLOOR) if not self.with_characters else self.telop_box[1])
        return (int(self.height * 0.11), floor - 34)

    @property
    def headline_box(self) -> tuple[int, int, int, int]:
        """立ち絵なしのときの見出し領域。下寄せで、画面の幅をたっぷり使う。

        **縦型は余白を削る。**伸びている参考チャンネルは見出しが画面幅いっぱいで、
        こちらは幅1080に対して余白が左右75pxずつあった（2026-09-07 に並べて確認）。
        """
        left = int(self.width * (0.042 if self.is_portrait else 0.075))
        return (left, int(self.height * 0.58), self.width - left, int(self.height * 0.88))

    def character_anchor(self, position: str) -> tuple[int, int]:
        """立ち絵の中心 x と足元 y。"""
        x = int(self.width * (0.24 if position == "left" else 0.76))
        return x, self.telop_box[1] - 20


# 台本の構造につけた名前で、視聴者には情報にならないもの。左上のラベルには出さない
INTERNAL_SCENE_TITLES = ("オープニング", "イントロ", "まとめ", "エンディング", "締め")


class Renderer:
    def __init__(self, config: ProjectConfig, work_dir: Path):
        self.config = config
        self.layout = Layout(
            config.video.width, config.video.height, config.video.show_characters
        )
        self.frame_dir = work_dir / "frames"
        self._stages: dict[str, Image.Image | None] = {}
        # **画面いっぱいに敷いた横長の絵**（一覧板・数字の図）の控え。
        # その上にはカードも節の名前も重ねない（2026-09-17）
        self._wide_stages: set[str] = set()
        # **カードを止めるのは「板」のときだけ**（2026-09-18 に踏んだ）。
        # 9/17 に「一覧板の上にはカードも節の名前も重ねない」と決めたとき、
        # **横長の絵すべて**を対象にしてしまった。報道写真を使えるように
        # なってからは写真がほぼ16:9なので、**写真を使う回はカードが1枚も出ない**。
        # クロップの選手の表も、久保の表も、画面に出ていなかった
        self._board_stages: set[str] = set()
        # 冒頭の節で敷く写真（frame_entries が台本から入れる）
        self.opening_photo: str = ""
        self.nameplate: str = ""
        self.opening_scene: str = ""
        self.opening_points: list[str] = []
        # 節の番号（左上のピルに「02」と出す）と、右上の点（何節目か）
        self.scene_order: dict[str, int] = {}
        self.scene_total: int = 0
        # 書き込みの的：いま描いたカードの置き場（名前・幅・画面の枠）と、写真ごとの顔の位置
        self._card_place: tuple[str, int, tuple[float, float, float, float]] | None = None
        self._mark_heads: dict[str, list] = {}
        self._card_layouts: dict[str, dict] = {}
        self.frame_dir.mkdir(parents=True, exist_ok=True)

        font_path = str(config.video.font_path())
        self.font_telop = ImageFont.truetype(font_path, config.video.telop_size)
        self.font_headline = ImageFont.truetype(font_path, config.video.headline_size)
        self.font_name = ImageFont.truetype(font_path, config.video.name_size)
        self.font_scene = ImageFont.truetype(font_path, 36)
        self.font_title = ImageFont.truetype(font_path, config.video.title_size)
        # 冒頭のタイトルは全画面なので大きめに組む
        self.font_title_big = ImageFont.truetype(font_path, int(config.video.title_size * 1.4))
        self.font_label = ImageFont.truetype(font_path, 32)
        self.font_date = ImageFont.truetype(font_path, 30)
        self.font_pill = ImageFont.truetype(font_path, 38)

        self.script_background: str | None = None  # 台本 frontmatter の bg
        self.script_cards: dict = {}
        self.script_date = ""
        self.card_dir = work_dir / "cards"
        # 背景に動画が1つでも混ざる場合、フレームは透過で描いて後から重ねる
        self.over_video = False
        self._backgrounds: dict[str, Image.Image] = {}
        self._sprites: dict[tuple[str, str, bool], Image.Image | None] = {}

    # ------------------------------------------------------------------ 画面

    def frame(
        self,
        line: Line,
        scene: Scene,
        mouth_open: bool,
        telop_t: float = 1.0,
        hop_t: float = 1.0,
        panel: tuple[str, str | None, str | None] | None = None,
        stack: tuple[str, ...] = (),
        reveal: int | None = None,
        marks: tuple | None = None,
        mark_new: int = 0,
        mark_t: float = 1.0,
    ) -> Path:
        """1枚の画面を描いて PNG のパスを返す。

        marks は画面に出ている書き込み（赤ペン、src/marks.py）。後ろの mark_new 個は
        この行で足したもので、mark_t（0→1）まで描き進める。panel を渡さないときは行の書き込み。

        reveal は表・棒グラフの行を何本まで出すか（出現アニメの1コマ）。
        節の頭の行では telop_t で左上のピルも滑り込む（2026-09-28 動きの段3）。

        telop_t / hop_t は 0→1 のアニメーション進捗。同じ絵は使い回すので、
        アニメーションを入れてもフレーム数は必要なぶんしか増えない。

        panel に (見出し, 確度, カード名) を渡すと、その行の telop / source / card
        ではなくそちらを描く。ニュース風レイアウトで見出しやカードを次の行にも
        残すために使う。
        """
        member = self.config.resolve_speaker(line.speaker, line.text or '')
        text, source, card = (
            (line.telop_text(), line.source, line.card) if panel is None else panel
        )
        if marks is None:
            marks = tuple(line.marks) if panel is None else ()
        background = scene.background or self.script_background or self.config.video.background
        opening = scene.title == self.opening_scene and self.opening_photo
        stage_path = line.image or (self.opening_photo if opening else None)
        over_video = self.over_video
        key = "|".join(
            [
                background,
                scene.title,
                member.key if self.layout.with_characters else "-",
                line.emotion if self.layout.with_characters else "-",
                text,
                source or "",
                card or "",
                line.image or "",
                (self.opening_photo if scene.title == self.opening_scene else ""),
                f"moving:{self.moving_photo(stage_path) and over_video}",
                # チャンネル名が空なら絵は変わらないので、鍵にも入れない
                ("card:" + self.config.video.channel_name
                 if self.config.video.channel_name.strip()
                 and scene.title == self.opening_scene and scene.lines
                 and line is scene.lines[0] else ""),
                ("hook:" + "/".join(self.opening_points)
                 if self.opening_points and scene.title == self.opening_scene
                 and scene.lines and line is scene.lines[0] else ""),
                ("plate:" + self.nameplate
                 if self.nameplate and scene.title == self.opening_scene
                 and scene.lines and line in scene.lines[:2] else ""),
                # 立ち絵を出さないなら口パクも跳ねも絵に影響しない
                ("open" if mouth_open else "close") if self.layout.with_characters else "-",
                f"{telop_t:.2f}/{hop_t if self.layout.with_characters else 1.0:.2f}",
                f"{self.layout.width}x{self.layout.height}",
                "|".join(stack),
                f"s{self.scene_order.get(scene.title, 0)}/{self.scene_total}",
                f"r{reveal if reveal is not None else '-'}",
                (f"m{marks_mod.dump(list(marks))}/{mark_new}/{mark_t:.2f}" if marks else ""),
                # 節の頭かどうかは、滑り込みの途中（telop_t<1）でだけ絵に効く。それ以外は同じ絵を使い回す
                f"head{bool(scene.lines and line is scene.lines[0]) and telop_t < 1.0}",
            ]
        )
        target = self.frame_dir / f"{hashlib.sha1(key.encode('utf-8')).hexdigest()[:16]}.png"
        if target.exists():
            return target

        # **冒頭の節はサムネの写真を敷く**（2026-09-08）。ぼかした夜景に黒い板では、
        # 最初の3秒が止まって見えた。参考は0秒目からその人の実写が出ている
        stage = self._photo_stage(stage_path)
        # **画面いっぱいのカード（versus）は下地そのものにする**（2026-10-07）。
        # 板（一覧板・数字の図）と同じで、それ自体が読ませる絵。上に節の名前・見出し・
        # ほかのカードを重ねない。ショート（縦）は上下に割った絵を描く
        full = self._full_card(card)
        if full is not None:
            stage, stage_path = full, None
        # **板を出している間は、その上に何も重ねない**（2026-09-17 ユーザー指示
        # 「松木の顔ではなくて、サムネ画面をだしておいて」）。板は文字でできた絵なので、
        # カードや節の名前を乗せると板の文字が読めなくなる。
        # 実際、齋藤俊輔と松木玖生がカードの下に隠れていた
        wide = bool(stage is not None and stage_path
                    and str(stage_path) in self._wide_stages)
        # 板（一覧板・数字の図）はそれ自体が読ませる絵なので、上に何も重ねない。
        # ふつうの写真は重ねてよい
        board = bool(stage is not None and stage_path
                     and str(stage_path) in self._board_stages) or full is not None
        if stage is not None and over_video and self.moving_photo(stage_path):
            # 写真は背景側の動画がゆっくり寄っている。絵の側は透明にして、その上に文字と表だけ描く
            canvas = self._transparent()
        elif stage is not None:
            # 写真を主役にした下地。動画背景の上でも不透明に敷く
            canvas = stage.copy()
        else:
            canvas = self._transparent() if over_video else self._background(background).copy()
        if self.layout.with_characters:
            self._draw_characters(canvas, member, line.emotion, mouth_open, hop_t)
        # 写真を下地にしたときは小さなカードを重ねない。図表だけ左半分に置く。
        # **縦型は左半分に寄せない。**写真が画面いっぱいなので、寄せる相手がいない
        # （2026-09-09。1080の幅をさらに半分にすると図表が読めなくなる）
        self._card_place = None
        if not board:
            # 表は見出しの帯の上に収める（3行の見出しで表の最後の行が隠れた。2026-09-28）。
            # 反応の積み上げのときは帯が無い
            compact = bool(card) and not self.layout.is_portrait
            floor = self.headline_band_top(text, compact) if (not stack and not self.layout.with_characters) else None
            self._draw_media(canvas, None if stage is not None else line.image, card, telop_t,
                             left_half=(stage is not None and not wide
                                        and not self.layout.is_portrait),
                             floor=floor,
                             # 横長の写真の上では左に寄せる（真ん中に置くと人の顔にかかる）
                             align_left=(stage is not None and wide and not self.layout.is_portrait),
                             reveal=reveal)
            # **書き込み（赤ペン）**（2026-10-07）。表の行が出きってから（reveal 中は描かない）。
            # 見出しの帯・節の名前より下に描くので、帯と名前は書き込みの上に乗る
            if marks and reveal is None and not self.layout.with_characters:
                self._draw_marks(canvas, marks, mark_new, mark_t, stage, stage_path, floor, telop_t)
        # **縦型では制作側の言葉を画面に出さない**（2026-09-07 の方針）。
        # 「オープニング」「まとめ」は章の目印で、視聴者には意味が無い。
        # 一等地の左上を、本編の作業用ラベルで埋めない。
        # 中身のある節名（「監督は何と言ったか」など）は残す
        if not board and not (self.layout.is_portrait and scene.title in INTERNAL_LABELS):
            head = bool(scene.lines and line is scene.lines[0])
            self._draw_scene_title(canvas, scene.title, telop_t if head else 1.0)
        if scene.title == self.opening_scene and scene.lines and line is scene.lines[0]:
            self._draw_channel_card(canvas)
        if self.nameplate and scene.title == self.opening_scene and scene.lines and line in scene.lines[:2] and not board:
            self._draw_nameplate(canvas, self.nameplate)
            self._draw_hook_points(canvas, self.opening_points)
        if self.layout.with_characters:
            self._draw_telop(canvas, member, text, telop_t, source)
        else:
            # **前の反応を画面に残す**（2026-09-07）。参考チャンネルは白い吹き出しを
            # 4〜5件積み上げていて、途中から見た人も文脈を拾える。こちらは1行ずつ
            # 消えていた
            # **反応の最中はテロップを出さない**（2026-09-14 指示
            # 「ネット民の声の時は複数の声が並ぶ感じで、その時にテロップは不要」）。
            # 声は白い箱に並ぶので、同じ一文を下でもう一度読ませる意味がない
            if full is not None:
                # **左右の比べの上に見出しを重ねない**（2026-10-07）。名前と数字が画面の字で、
                # 下の帯を出すと名前・数字に重なる（板の行の no_telop と同じ考え。review の
                # 「画面に出る字」は、この行を画面に出たと数える）
                pass
            elif stack:
                self._draw_stack(canvas, stack)
            else:
                self._draw_headline(canvas, text, telop_t, source,
                                    compact=bool(card) and not board and not self.layout.is_portrait)
        # 動画背景のときは重ねる前提なのでアルファを残す
        canvas.save(target) if over_video else canvas.convert("RGB").save(target)
        return target

    def _black(self) -> Path:
        target = self.frame_dir / "black_rgba.png"
        if not target.exists():
            Image.new("RGBA", (self.layout.width, self.layout.height), (0, 0, 0, 255)).save(target)
        return target

    def blend(self, first: Path, second: Path, ratio: float) -> Path:
        """2枚の画面を混ぜた中間フレーム。シーン転換のクロスフェードに使う。"""
        # **透過つき（RGBA）で保存する**（2026-10-01 ユーザー「エクアドルの本編でスタジアムの背景が入る」）。
        # フレーム列は RGBA の PNG を concat して背景動画に重ねている。ここだけ RGB で保存していたため、
        # 形式が切り替わるところで ffmpeg がコマを落とし、写真が替わる瞬間に下地（スタジアム）が見えていた
        key = f"{first.name}|{second.name}|{ratio:.3f}|rgba"
        target = self.frame_dir / f"x{hashlib.sha1(key.encode('utf-8')).hexdigest()[:15]}.png"
        if target.exists():
            return target
        a = Image.open(first).convert("RGBA")
        b = Image.open(second).convert("RGBA")
        Image.blend(a, b, ratio).save(target)
        return target

    def _transparent(self) -> Image.Image:
        """動画背景に重ねるための透過キャンバス。

        実写のうえに白文字を置くと読めないので、下側だけ暗くする幕を先に敷く。
        """
        canvas = Image.new("RGBA", (self.layout.width, self.layout.height), (0, 0, 0, 0))
        scrim, draw = _layer(canvas.size)
        start = int(self.layout.height * 0.45)
        for y in range(start, self.layout.height):
            ratio = (y - start) / max(1, self.layout.height - start)
            draw.line([(0, y), (self.layout.width, y)], fill=(4, 8, 14, int(215 * ratio**1.3)))
        canvas.alpha_composite(scrim)
        return canvas

    def _stage_file(self, image_path: str) -> Path | None:
        """写真の下地（_photo_stage の絵）を PNG にして返す。背景側の動画（ズーム）の元にする。"""
        stage = self._photo_stage(image_path)
        if stage is None:
            return None
        stage_dir = self.frame_dir.parent / "stages"
        stage_dir.mkdir(parents=True, exist_ok=True)
        key = hashlib.sha1(f"{image_path}|{self.layout.width}x{self.layout.height}|{self.layout.focus_x}".encode("utf-8")).hexdigest()[:16]
        target = stage_dir / f"{key}.png"
        if not target.exists():
            stage.convert("RGB").save(target)
        return target

    def moving_photo(self, image_path: str | None) -> bool:
        """この写真の下地を、絵に焼き込まず背景側の動画（ズーム）で出すか（2026-09-28）。

        板（一覧板・数字の図）は寄せない（字が滲む）。縦型も寄せる。
        """
        if not image_path or self.config.motion.photo_zoom <= 1.0:
            return False
        if self._photo_stage(image_path) is None:
            return False
        return not _is_board(image_path)

    def _photo_stage(self, image_path: str | None) -> Image.Image | None:
        """写真を画面の主役にした下地（2026-09-08）。

        参考チャンネルは人物の実写が画面いっぱいで、こちらは枠付きの小さな
        カード（画面の1割強）だった。サムネと同じ作りにする: 同じ写真をぼかして
        暗くした敷き布の上に、右半分いっぱいに写真を立てる（縦長は上寄りに切る）。
        下側は見出しが乗るぶんだけ暗く落とす。

        **縦型では画面いっぱいに敷く**（2026-09-09 ユーザー指示）。それまでは
        縦型を素通ししていて、冒頭は枠付きの小さな写真カードだった。
        ショートの一覧が出しているのは `oar2.jpg` ——
        **こちらが設定したサムネイルではなく、YouTube が動画から自動で作る
        縦の1コマ**（一覧の img の src を読んで確かめた）。つまり
        **冒頭の絵がそのまま一覧の絵になる。**サムネだけ直しても届かない。
        """
        if not image_path or self.layout.with_characters:
            return None
        if image_path in self._stages:
            return self._stages[image_path]
        path = _resolve(image_path)
        if not path.exists():
            self._stages[image_path] = None
            return None
        from PIL import ImageEnhance, ImageFilter

        width, height = self.layout.width, self.layout.height
        photo = Image.open(path).convert("RGBA")
        # **写真をごく軽く補正**（2026-09-28「背景の画像をもっと向上」）。Commons の写真は眠いものが多い
        photo = ImageEnhance.Contrast(photo).enhance(1.06)
        photo = ImageEnhance.Sharpness(photo).enhance(1.15)
        bed = _cover(photo, width, height).filter(ImageFilter.GaussianBlur(30))
        bed = ImageEnhance.Brightness(bed).enhance(0.55)
        if self.layout.is_portrait and _is_board(image_path):
            # **縦の板は、そのまま画面いっぱいに敷く**（2026-09-23）。
            # ショート用に作った 1080x1920 の基礎DATAの板は「横長」ではないので
            # 下の網から漏れ、写真と同じ扱いになっていた。その結果、
            # **板の上に節の名前とカードが重なり**、板の字が読めなかった。
            # 下を暗く落とすのもやめる（最後の行が沈む）
            self._wide_stages.add(image_path)
            self._board_stages.add(image_path)
            stage = _cover(photo, width, height)
            self._stages[image_path] = stage
            return stage
        if self.layout.is_portrait:
            # 縦型は横に並べる余地が無い。**写真で画面を埋める**
            bed.alpha_composite(_cover(photo, width, height, focus=0.18,
                                       focus_x=self.layout.focus_x))
            shade = Image.new("RGBA", (width, height), (0, 0, 0, 0))
            shade_draw = ImageDraw.Draw(shade)
            start = int(height * 0.60)
            for y in range(start, height):
                alpha = int(196 * (y - start) / (height - start))
                shade_draw.line([(0, y), (width, y)], fill=(0, 0, 0, alpha))
            bed.alpha_composite(shade)
            self._stages[image_path] = bed
            return bed
        # **横長の絵は画面いっぱいに敷く**（2026-09-17 ユーザー指摘
        # 「動画の画面の左側がぼやけている」）。右半分に立てる作りは
        # **人物の縦写真のためのもの**で、16:9 の絵（一覧板・数字の図）を
        # 入れると左半分がぼかしだけになり、しかも絵の左半分が切り落とされる。
        # 代表発表の一覧板では、齋藤と松木が画面から消えていた
        # **1.4倍では足りなかった**（2026-09-17 夜）。佐野の回に使った写真は
        # 800x600＝1.33倍で、この網に掛からず、公開した動画の左が暗いままだった。
        # 縦写真だけを右半分に立てたいので、**横長も正方形に近いものも全面**にする
        # **1.15 → 0.95**（2026-09-23 指摘「レアルの背景の左がぼやけている」）。
        # 上に「正方形に近いものも全面にする」と書いてあるのに、条件が
        # 「横が縦の1.15倍以上」だったので**正方形が漏れていた**。
        # テバスの写真は 1920x1924 で、ちょうどこの隙間に落ちていた。
        # 右半分に立てたいのは**はっきり縦長の写真だけ**なので、そこまで下げる
        if photo.width >= photo.height * 0.95:
            self._wide_stages.add(image_path)
            if _is_board(image_path):
                # **横の板も下を暗くしない**（2026-09-30 ユーザー「下の方黒くなってない？」）。
                # 縦の板は 09-23 に外していたのに、横の板だけ写真と同じ幕を掛けていた。
                # ソシエダの回で、選手一覧の最後の段と順位表の17〜20位が黒く沈んでいた。
                # 板の行は見出しを出さない（no_telop）ので、幕は要らない
                self._board_stages.add(image_path)
                stage = _cover(photo, width, height)
                self._stages[image_path] = stage
                return stage
            bed = _cover(photo, width, height)
            shade = Image.new("RGBA", (width, height), (0, 0, 0, 0))
            shade_draw = ImageDraw.Draw(shade)
            start = int(height * 0.40)
            for y in range(start, height):
                t = (y - start) / (height - start)
                alpha = int(215 * t ** 1.3)
                shade_draw.line([(0, y), (width, y)], fill=(0, 0, 0, alpha))
            bed.alpha_composite(shade)
            self._stages[image_path] = bed
            return bed
        # **左はぼかさず、写真から拾った色のべた塗りにする**（2026-09-23 ユーザー選択）。
        # サムネは 2026-09-20 に同じ形へ変えてあった（`thumbnail._flat_bed`）のに、
        # 動画の中だけ「同じ写真をぼかした敷き布」が残っていた。今日2回
        # 「左がぼやけている」と言われたのは、どちらもこの作りが出たところ。
        # 別の絵を持ってこないので権利は変わらず、ぼけた絵も出ない
        bed = _flat_bed(photo, width, height)
        column_w = int(width * 0.5)
        column = _cover(photo, column_w, height)
        # 左端をなじませる。切り口が立つと貼り付けたように見える
        mask = Image.new("L", (column_w, height), 255)
        edge = 90
        mask_draw = ImageDraw.Draw(mask)
        for x in range(edge):
            mask_draw.line([(x, 0), (x, height)], fill=int(255 * x / edge))
        column.putalpha(mask)
        bed.alpha_composite(column, (width - column_w, 0))
        # 見出しの乗る下側を落とす
        shade = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        shade_draw = ImageDraw.Draw(shade)
        start = int(height * 0.40)
        for y in range(start, height):
            t = (y - start) / (height - start)
            shade_draw.line([(0, y), (width, y)], fill=(0, 0, 0, int(215 * t ** 1.3)))
        bed.alpha_composite(shade)
        self._stages[image_path] = bed
        return bed

    def _background(self, name: str) -> Image.Image:
        if name not in self._backgrounds:
            path = _resolve(name)
            if path.exists():
                image = Image.open(path).convert("RGBA")
                self._backgrounds[name] = _cover(image, self.layout.width, self.layout.height)
            else:
                self._backgrounds[name] = Image.new(
                    "RGBA", (self.layout.width, self.layout.height), (20, 26, 40, 255)
                )
        return self._backgrounds[name]

    def _sprite(self, member: CastMember, emotion: str, mouth_open: bool) -> Image.Image | None:
        cache_key = (member.key, emotion, mouth_open)
        if cache_key in self._sprites:
            return self._sprites[cache_key]
        directory = member.sprite_dir()
        suffix = "open" if mouth_open else "close"
        for name in (f"{emotion}_{suffix}.png", f"normal_{suffix}.png", f"{emotion}.png"):
            path = directory / name
            if path.exists():
                self._sprites[cache_key] = Image.open(path).convert("RGBA")
                return self._sprites[cache_key]
        self._sprites[cache_key] = None
        return None

    def _draw_characters(
        self,
        canvas: Image.Image,
        speaking: CastMember,
        emotion: str,
        mouth_open: bool,
        hop_t: float = 1.0,
    ) -> None:
        """左右の立ち絵を配置する。話していない側は少し縮めて暗くする。

        話し始めの一瞬だけ、喋る側をひょいと跳ねさせる（hop_t が 0→1 の間）。
        """
        for member in self.config.cast.values():
            if member.position not in ("left", "right"):
                continue
            is_active = member.key == speaking.key
            sprite = self._sprite(
                member,
                emotion if is_active else "normal",
                mouth_open and is_active,
            )
            if sprite is None:
                continue

            target_height = int(self.layout.height * (0.62 if is_active else 0.55))
            scale = target_height / sprite.height
            sprite = sprite.resize(
                (int(sprite.width * scale), target_height), Image.LANCZOS
            )
            if not is_active:
                sprite = _dim(sprite, 0.55)

            cx, base_y = self.layout.character_anchor(member.position)
            hop = 0
            if is_active and hop_t < 1.0:
                hop = int(-SPEAKER_HOP * math.sin(math.pi * max(0.0, hop_t)))
            canvas.alpha_composite(
                sprite, (cx - sprite.width // 2, base_y - sprite.height + hop)
            )

    def _draw_media(
        self,
        canvas: Image.Image,
        image_path: str | None,
        card_name: str | None,
        progress: float = 1.0,
        left_half: bool = False,
        floor: int | None = None,
        align_left: bool = False,
        reveal: int | None = None,
    ) -> None:
        """画像とカードを文字の上のスペースに置く。両方あれば左右に並べる。

        left_half は写真を右半分に敷いたときに、図表を左半分の中央に置く。
        floor は見出しの帯の上端。align_left は横長の写真の上で左に寄せる（2026-09-28）。

        以前は縦に積んでいたが、カードが高いぶん写真が潰れた。実測
        （2026-09-04）で、顔が判別できない大きさ（横120px）になっていた。
        画面は横1920あるので、両方あるときは幅を使う。
        """
        slot_top, slot_bottom = self.layout.media_slot
        if floor is not None:
            slot_bottom = min(slot_bottom, floor - 24)
        slot_height = max(80, slot_bottom - slot_top)
        # **縦型は縦に積む。**横に並べると1つあたりの幅が半分になり、
        # ただでさえ狭い1080がさらに割れる。上下は余っている
        side_by_side = (bool(image_path) and bool(card_name)
                        and not self.layout.is_portrait)
        items: list[Image.Image] = []
        card_at: tuple[int, int] | None = None     # (items の中の番号, 描いた幅)。書き込みの的に使う

        if image_path:
            picture = self._picture(image_path, slot_height, beside=side_by_side)
            if picture is not None:
                items.append(picture)
        if card_name:
            # **縮小して貼らない**（2026-09-23 指摘「表をもう少し大きく」）。
            # 左半分に置くカードは、大きく描いてから 0.63 倍に縮めていたので、
            # 34px で描いた字が**21px になっていた**。はじめからその幅で描く
            # 写真の左90pxはぼかして馴染ませてあるので、そこまで使ってよい
            # 表は幅の 58% まで（2026-09-28）。写真の左端はなじませてあるので少し重なってよい
            limit = int(self.layout.width * 0.58) if left_half else None
            card = self._card(card_name, beside=side_by_side, limit=limit, reveal=reveal)
            if card is not None:
                card_at = (len(items), card.width)
                items.append(card)
        if not items:
            return

        gap = 26
        if side_by_side and len(items) == 2:
            placed = self._place_beside(canvas, items, slot_top, slot_height, gap, progress)
            if card_at is not None and placed:
                self._card_place = (card_name, card_at[1], placed[card_at[0]])
            return
        total = sum(item.height for item in items) + gap * (len(items) - 1)
        if total > slot_height:  # 入りきらないときは全体を縮める
            ratio = slot_height / total
            items = [
                item.resize(
                    (int(item.width * ratio), int(item.height * ratio)), Image.LANCZOS
                )
                for item in items
            ]
            total = sum(item.height for item in items) + gap * (len(items) - 1)

        y = slot_top + (slot_height - total) // 2
        span = self.layout.width // 2 if left_half else self.layout.width
        for number, item in enumerate(items):
            if item.width > span - 60 and left_half:
                ratio = (span - 60) / item.width
                item = item.resize((int(item.width * ratio), int(item.height * ratio)),
                                   Image.LANCZOS)
            if progress < 1.0:
                item = item.copy()
                item.putalpha(
                    item.getchannel("A").point(lambda a: int(a * _ease_out(progress)))
                )
            x = 48 if align_left else (span - item.width) // 2
            self._drop_shadow(canvas, item, (x, y))
            canvas.alpha_composite(item, (x, y))
            if card_at is not None and number == card_at[0]:
                self._card_place = (card_name, card_at[1], (x, y, x + item.width, y + item.height))
            y += item.height + gap

    def _place_beside(
        self,
        canvas: Image.Image,
        items: list[Image.Image],
        slot_top: int,
        slot_height: int,
        gap: int,
        progress: float,
    ) -> list[tuple[int, int, int, int]]:
        """写真とカードを左右に並べる。高さは各自の中央でそろえる。置いた枠を返す。"""
        total_w = sum(item.width for item in items) + gap
        if total_w > self.layout.width - 96:  # 端に寄りすぎないよう全体を縮める
            ratio = (self.layout.width - 96) / total_w
            items = [
                item.resize((int(item.width * ratio), int(item.height * ratio)), Image.LANCZOS)
                for item in items
            ]
            total_w = sum(item.width for item in items) + gap
        x = (self.layout.width - total_w) // 2
        placed = []
        for item in items:
            if progress < 1.0:
                item = item.copy()
                item.putalpha(item.getchannel("A").point(lambda a: int(a * _ease_out(progress))))
            y = slot_top + (slot_height - item.height) // 2
            canvas.alpha_composite(item, (x, y))
            placed.append((x, y, x + item.width, y + item.height))
            x += item.width + gap
        return placed

    def _picture(
        self, image_path: str, slot_height: int, beside: bool = False
    ) -> Image.Image | None:
        """差し込む写真。白フチを付けて画面になじませる。

        ``beside`` はカードと横に並べるとき。幅は譲るが、**高さは枠いっぱい
        使う**。縦長の人物写真はここで効く。
        """
        path = _resolve(image_path)
        if not path.exists():
            return None
        picture = Image.open(path).convert("RGBA")
        if beside:
            max_w = int(self.layout.width * 0.26)
            max_h = int(slot_height * 0.98)
        else:
            max_w = int(self.layout.width * (0.62 if not self.layout.with_characters else 0.42))
            # **縦型は顔を大きく見せる。**縦1920では高さ側が先に頭打ちになり、
            # 幅 0.62 を使い切っていなかった（実測で写真の幅が画面の3割）。
            # 縦画面は顔が主役で、「サムネに顔を必ず入れる」方針とも揃う。
            # **横型の値は触らない。**本編の画面設計は変えない
            max_h = int(slot_height * (0.92 if self.layout.is_portrait else 0.72))
        scale = min(max_w / picture.width, max_h / picture.height)
        picture = picture.resize(
            (int(picture.width * scale), int(picture.height * scale)), Image.LANCZOS
        )
        framed = Image.new(
            "RGBA", (picture.width + 16, picture.height + 16), (255, 255, 255, 235)
        )
        framed.alpha_composite(picture, (8, 8))
        return framed

    def _full_card(self, name: str | None) -> Image.Image | None:
        """その名前のカードが画面いっぱいの絵（versus）なら、画面の大きさで描いた絵を返す。"""
        spec = self.script_cards.get(name or "")
        if not cards.is_full_screen(spec):
            return None
        size = (self.layout.width, self.layout.height)
        target = self.card_dir / f"full_{cards.card_key(spec, size[0] * 10000 + size[1])}.png"
        if str(target) in self._stages:
            return self._stages[str(target)]
        if not target.exists():
            cards.render_versus(spec, size, str(self.config.video.font_path()), target,
                                str(self.config.video.latin_font_path()))
        stage = Image.open(target).convert("RGBA")
        self._stages[str(target)] = stage
        return stage

    def is_full_card(self, name: str | None) -> bool:
        return cards.is_full_screen(self.script_cards.get(name or ""))

    # ------------------------------------------------------------------ 書き込み（2026-10-07）

    def mark_heads(self, stage_path: str | None, stage: Image.Image | None) -> list:
        """写真の下地の頭の枠（x, y, w, h）。書き込みが顔を囲む・顔を避けるのに使う。同じ写真は1回だけ探す。"""
        if stage is None or not stage_path:
            return []
        key = f"{stage_path}|{self.layout.width}x{self.layout.height}|{self.layout.focus_x}"
        if key not in self._mark_heads:
            from . import faces

            heads = []
            try:
                for box in faces.find_faces(stage.convert("RGB")):
                    heads.append(faces.head_box(box))
            except Exception:       # 顔が取れなくても書き込み（表の上）は描く
                heads = []
            self._mark_heads[key] = heads
        return self._mark_heads[key]

    def _card_layout(self, name: str, width: int) -> dict | None:
        spec = self.script_cards.get(name)
        if not spec or str(spec.get("type", "")).lower() not in cards.MARKABLE_TYPES:
            return None
        key = cards.card_key(spec, width)
        if key not in self._card_layouts:
            self._card_layouts[key] = cards.layout(spec, width, str(self.config.video.font_path()),
                                                   str(self.config.video.latin_font_path()))
        return self._card_layouts[key]

    def mark_targets(self, marks, stage_path: str | None = None, stage: Image.Image | None = None) -> list:
        """書き込みごとの的（画面の座標）。指した先が今の画面に無ければ None（描かない）。"""
        out = []
        for mark in marks:
            if marks_mod.is_photo(mark):
                out.append(marks_mod.photo_target(mark, self.mark_heads(stage_path, stage)))
                continue
            if self._card_place is None:
                out.append(None)
                continue
            name, drawn, (x0, y0, x1, _) = self._card_place
            geo = self._card_layout(name, drawn)
            if geo is None:
                out.append(None)
                continue
            out.append(marks_mod.card_target(mark, self.script_cards[name], geo, (x0, y0), (x1 - x0) / drawn))
        return out

    def _draw_marks(self, canvas: Image.Image, marks, fresh: int, t: float, stage, stage_path,
                    floor: int | None, progress: float) -> None:
        """書き込みを、透明の層に描いてから重ねる（RGB に落とさない＝黒い枠が出ない）。"""
        targets = self.mark_targets(marks, stage_path, stage)
        if not any(targets):
            return
        width, height = self.layout.width, self.layout.height
        band = floor if floor is not None else self.layout.media_slot[1] + 34
        avoid = [(0, 0, width, marks_mod.TOP_BAND), (0, band, width, height)]
        avoid += [(x, y, x + w, y + h) for x, y, w, h in self.mark_heads(stage_path, stage)]
        planned = marks_mod.plan(list(marks), targets, (width, height), avoid,
                                 str(self.config.video.font_path()))
        layer = marks_mod.render_layer((width, height), planned, fresh, t,
                                       str(self.config.video.font_path()))
        if layer is None:
            return
        if progress < 1.0:
            layer.putalpha(layer.getchannel("A").point(lambda a: int(a * _ease_out(progress))))
        canvas.alpha_composite(layer)

    def card_rows(self, name: str | None) -> int:
        spec = self.script_cards.get(name or "")
        return cards.row_count(spec) if spec else 0

    def same_table(self, first: str | None, second: str | None) -> bool:
        """光らせる行（highlight_row）だけが違う、同じ表か。

        **同じ表なら行を1本ずつ出し直さない**（2026-10-01 ユーザー「表が毎回開き直しになっていて目に悪い」）。
        話している行を光らせるために行ごとに別のカードを持たせているので、カードの名前は毎行変わる。
        名前で比べると、行が替わるたびに表が空から組み直されていた
        """
        # 散らばり図の highlight（2026-10-07 夜）も同じ。決まりは cards.same_table の1か所に置く
        return cards.same_table(self.script_cards.get(first or ""), self.script_cards.get(second or ""))

    def _card(self, name: str, beside: bool = False, limit: int | None = None,
              reveal: int | None = None) -> Image.Image | None:
        spec = self.script_cards.get(name)
        if not spec:
            return None
        if self.layout.is_portrait:
            # **縦型は幅をほぼ使い切る。**割合で決めると横型より狭くなり、
            # 同じ文字量が入らない。上下は余っているので、幅を優先する
            width = int(self.layout.width * 0.90)
        elif beside:  # 写真と横に並べるぶん、カードは幅を譲る
            width = int(self.layout.width * (0.52 if not self.layout.with_characters else 0.40))
        else:
            # **表を大きく**（2026-09-23 指摘）。0.64 → 0.74。
            # 板の字（34px から縮む）が小さく、耳で追えなかった人が目で追えなかった
            width = int(self.layout.width * (0.74 if not self.layout.with_characters else 0.46))
        if limit:
            width = min(width, limit)
        target = self.card_dir / f"{cards.card_key(spec, width, reveal)}.png"
        if not target.exists():
            cards.render(
                spec,
                width,
                str(self.config.video.font_path()),
                target,
                str(self.config.video.latin_font_path()),
                reveal=reveal,
            )
        return Image.open(target).convert("RGBA")

    def _draw_hook_points(self, canvas: Image.Image, points: list[str]) -> None:
        """冒頭の1行目に、サムネと同じ伏せ字の一言を左側に積む（2026-09-09）。

        Gemini（2026-09-08）の答え3: タイトルで伏せた答えを、動画の最初の3秒の
        絵にも同期させる。サムネの thumbnail_points をそのまま使うので、クリック
        した人が同じ言葉を見て「合っている」と確かめられる。登録カードの下に置く。
        """
        points = [str(x).strip() for x in points if str(x).strip()][:3]
        if not points:
            return
        from PIL import ImageFont

        layer, draw = _layer(canvas.size)
        size = 72 if not self.layout.is_portrait else 60
        font = ImageFont.truetype(str(self.config.video.font_path()), size)
        x, y = 64, 150
        for text in points:
            draw.text((x + 4, y + 4), text, font=font, fill=(0, 0, 0, 200))
            draw.text((x, y), text, font=font, fill=(255, 255, 255, 255),
                      stroke_width=6, stroke_fill=(0, 0, 0, 220))
            width = draw.textlength(text, font=font)
            draw.line([(x, y + size + 14), (x + width, y + size + 14)],
                      fill=(232, 210, 31, 255), width=6)
            y += size + 46
        canvas.alpha_composite(layer)

    def _draw_channel_card(self, canvas: Image.Image) -> None:
        """左上にチャンネル名と登録ボタンの小さなカード（2026-09-08）。

        参考チャンネルは冒頭0.5〜2.5秒だけこれを出す。読み上げで「登録して」とは
        言わない。冒頭の節はタイトルを読んでいて左上が空いているので、そこに置く。
        """
        name = (self.config.video.channel_name or "").strip()
        if not name:
            return
        layer, draw = _layer(canvas.size)
        font = self.font_scene
        name_w = draw.textlength(name, font=font)
        button = "チャンネル登録"
        button_w = draw.textlength(button, font=font)
        left, top = 48, 42
        height = 68
        total = 24 + name_w + 22 + button_w + 40 + 24
        draw.rounded_rectangle([left, top, left + total, top + height],
                               radius=34, fill=(0, 0, 0, 165))
        draw.text((left + 24, top + 16), name, font=font, fill=(240, 240, 240, 255))
        bx = left + 24 + name_w + 22
        draw.rounded_rectangle([bx, top + 10, bx + button_w + 40, top + height - 10],
                               radius=24, fill=(204, 0, 0, 255))
        draw.text((bx + 20, top + 16), button, font=font, fill=(255, 255, 255, 255))
        canvas.alpha_composite(layer)

    def _drop_shadow(self, canvas: Image.Image, item: Image.Image, at: tuple[int, int]) -> None:
        """表や板の下に、ぼかした影を敷く（品質100回の12）。写真の上で板が浮いて見える。"""
        from PIL import ImageFilter

        x, y = at
        pad = 40
        shadow = Image.new("RGBA", (item.width + pad * 2, item.height + pad * 2), (0, 0, 0, 0))
        alpha = item.getchannel("A").point(lambda a: int(a * 0.55))
        shadow.paste((0, 0, 0, 255), (pad, pad + 10), alpha)
        shadow = shadow.filter(ImageFilter.GaussianBlur(18))
        canvas.alpha_composite(shadow, (x - pad, y - pad))

    def _draw_nameplate(self, canvas: Image.Image, text: str) -> None:
        """冒頭の2行に出す名前の板（2026-09-28 選手紹介）。「名前｜所属 位置」を左の中ほどに大きく。

        名前は白の大きな字、下に黄色の線、その下に所属を小さく。左上の登録カードと、下の見出しの帯のあいだに置く。
        """
        name, _, sub = text.partition("｜")
        layer, draw = _layer(canvas.size)
        font_path = str(self.config.video.font_path())
        big = ImageFont.truetype(font_path, 96 if not self.layout.is_portrait else 72)
        small = ImageFont.truetype(font_path, 38 if not self.layout.is_portrait else 34)
        x, y = 48, int(self.layout.height * (0.16 if not self.layout.is_portrait else 0.14))
        # 長い名前（「アーリング・ブラウト・ハーランド」）は字を縮めて右端に収める（品質100回の65）。縦画面は 1080 幅しか無い
        limit = self.layout.width - x - 64
        while draw.textlength(name, font=big) > limit and big.size > 40:
            big = ImageFont.truetype(font_path, big.size - 4)
        w = draw.textlength(name, font=big)
        # 字の裏に暗い帯（写真の上でも読める）
        draw.rounded_rectangle([x - 16, y - 16, x + w + 32, y + (big.size + 30) + (small.size + 22 if sub else 0)],
                               radius=18, fill=(6, 10, 14, 150))
        draw.text((x, y), name, font=big, fill=(255, 255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0, 160))
        bar_y = y + big.size + 16
        draw.rounded_rectangle([x, bar_y, x + w, bar_y + 8], radius=4, fill=BRAND_GOLD + (255,))
        if sub:
            draw.text((x, bar_y + 18), sub.strip(), font=small, fill=(230, 234, 240, 255))
        canvas.alpha_composite(layer)

    def _draw_scene_title(self, canvas: Image.Image, title: str, slide_t: float = 1.0) -> None:
        # RGBA の canvas に直接半透明の図形を描くと下地を「置き換えて」しまうため、
        # 透明レイヤーに描いてから alpha_composite する。
        layer, draw = _layer(canvas.size)
        # 節の頭では左から滑り込む（2026-09-28 動きの段3。章カードは 9/10 に外したので時間は足さない）
        slide = int(-(1.0 - _ease_out(slide_t)) * 420)
        # **制作側の言葉は画面に出さない**（2026-09-07）。「オープニング」は
        # 台本の構造の名前で、視聴者には何の情報でもない。しかも冒頭の
        # いちばん見られる位置に出ていた。日付は残す
        if title.strip() not in INTERNAL_SCENE_TITLES:
            # 緑のピルに番号つき（「02　22点の中身」）。左に黄色の縦帯（2026-09-28）
            number = self.scene_order.get(title, 0)
            label = f"{number:02d}　{title}" if number else title
            text_w = draw.textlength(label, font=self.font_pill)
            x0 = 48 + slide
            draw.rounded_rectangle(
                [x0, 42, x0 + text_w + 70, 42 + 68], radius=34, fill=BRAND_GREEN + (235,)
            )
            draw.rounded_rectangle([x0, 42, x0 + 14, 42 + 68], radius=7, fill=BRAND_GOLD + (255,))
            draw.text((x0 + 34, 54), label, font=self.font_pill, fill=(255, 255, 255, 255))
        # 右上に「何節目か」の点（節の数が2つ以上のとき）
        if self.scene_total >= 2 and not self.layout.is_portrait:
            number = self.scene_order.get(title, 0)
            for index in range(self.scene_total):
                cx = self.layout.width - 48 - (self.scene_total - 1 - index) * 26
                lit = number and index < number
                draw.ellipse([cx - 8, 68, cx + 8, 84],
                             fill=BRAND_GOLD + (255,) if lit else (255, 255, 255, 110))

        # **日付は画面に出さない**（2026-09-14 指示「日付入れなくて良い」）。
        # 右上に「2026年9月14日」と出していたが、いつの話かは中身で言っている。
        # 台本の `date` は残す（題材の重複を見るのに使っている）
        canvas.alpha_composite(layer)

    def _draw_telop(
        self,
        canvas: Image.Image,
        member: CastMember,
        text: str,
        telop_t: float = 1.0,
        source: str | None = None,
    ) -> None:
        if not text:
            return
        layer, draw = _layer(canvas.size)
        left, top, right, bottom = self.layout.telop_box
        # せり上がりながらフェードインする
        rise = int(TELOP_RISE * (1.0 - _ease_out(telop_t)))
        top, bottom = top + rise, bottom + rise

        # **枠は字の量に合わせて上へ伸ばす**（2026-09-10）。
        # テロップを2行ぶんに広げたので、高さ250pxの決め打ちだと3行目から
        # はみ出す。縦型は1行13.3字しか入らないので、とくに効く
        # **強調の囲みを外してから折り返す**（2026-09-15）。囲みを付けても
        # 行の割れ方が1文字も変わらないようにする。大きさを変えないのも同じ理由
        plain, spans = emphasis.split(text)
        lines = wrap_text(draw, plain, self.font_telop, right - left - 88)
        line_height = self.config.video.telop_size + 16
        need = line_height * len(lines) + 44
        if need > bottom - top:
            top = bottom - min(need, int(self.layout.height * TELOP_MAX_SHARE))

        draw.rounded_rectangle([left, top, right, bottom], radius=28, fill=(12, 14, 22, 205))
        draw.rounded_rectangle([left, top, right, bottom], radius=28, outline=(255, 255, 255, 60), width=3)

        # 話者名タグ
        name_w = draw.textlength(member.name, font=self.font_name)
        tag = [left + 26, top - 34, left + 26 + name_w + 48, top + 30]
        draw.rounded_rectangle(tag, radius=22, fill=_hex(member.color) + (255,))
        draw.text((tag[0] + 24, tag[1] + 8), member.name, font=self.font_name, fill=(20, 20, 24, 255))

        # 確度バッジは話者名の右隣に置く
        badge = SOURCE_BADGES.get(source or "")
        if badge:
            label, color = badge
            label_w = draw.textlength(label, font=self.font_name)
            box = [tag[2] + 16, tag[1], tag[2] + 16 + label_w + 44, tag[3]]
            draw.rounded_rectangle(box, radius=22, fill=color + (255,))
            draw.text((box[0] + 22, box[1] + 8), label, font=self.font_name, fill=(16, 16, 20, 255))

        y = top + (bottom - top - line_height * len(lines)) // 2 + 12
        accent = _hex(self.config.video.telop_accent) + (255,)
        offset = 0
        for chunk in lines:
            x = left + 44
            for segment, strong in _emphasis_segments(
                chunk, emphasis.spans_in(chunk, offset, spans)
            ):
                draw.text(
                    (x, y),
                    segment,
                    font=self.font_telop,
                    fill=accent if strong else (255, 255, 255, 255),
                    stroke_width=4,
                    stroke_fill=(0, 0, 0, 220),
                )
                width = draw.textlength(segment, font=self.font_telop)
                if strong:
                    # **下線も引く。**色だけだと、明るい写真の上で差が薄れる
                    bar = y + self.config.video.telop_size + 4
                    draw.rounded_rectangle(
                        [x, bar, x + width, bar + 6], radius=3, fill=accent
                    )
                x += width
            offset += len(chunk)
            y += line_height
        if telop_t < 1.0:
            layer.putalpha(layer.getchannel("A").point(lambda a: int(a * _ease_out(telop_t))))
        canvas.alpha_composite(layer)

    # 積み上げる反応の見た目。**白い箱に色つきの字**（2026-09-14 にユーザーが
    # まとめ動画の画面を見本として提示）。1件ごとに色を変えるので、
    # どこからどこまでが1つの書き込みかが、読まなくても分かる。
    # 何件残すかは、見出しの上に入る高さから決めた（実測で3件）
    # **全部出す**（2026-09-14 指示「ネットのコメントは、画面に全部出す」）。
    # 5件で切っていたので、6件以上ある節では最初の書き込みが消えていた。
    # 入りきらないぶんは**字を小さくして収める**（下の _draw_stack）
    STACK_KEEP = 99
    # **もっと大きく**（2026-09-14 指示）。見本は1行が画面幅の半分以上あった。
    # ここは上限で、件数が多い節では自動で下がる
    # **もう少し大きく**（2026-09-14 指摘）。件数が多い節では自動で下がる
    STACK_SIZE = 72
    STACK_SIZE_MIN = 34
    # 見本は箱が左右にずれて置かれていた。**同じ左端に揃えない。**
    # 画面幅に対する割合で、積んだ通し番号ごとにこの順で寄せる
    STACK_INDENT = (0.04, 0.16, 0.02, 0.22, 0.10)
    # 見本と同じ並び。白地で読める濃さにしてある
    STACK_COLORS = (
        (0, 132, 160, 255),     # 青緑
        (176, 122, 0, 255),     # 山吹
        (22, 132, 48, 255),     # 緑
        (188, 88, 16, 255),     # 橙
        (168, 32, 136, 255),    # 紅紫
    )

    def _draw_stack(self, canvas: Image.Image, stack: tuple[str, ...]) -> None:
        """直前までの反応を、見出しの上に白い吹き出しで積む。

        参考チャンネルは反応を4〜5件そのまま画面に残していて、**途中から見た人も
        文脈を拾える**（2026-09-07 に再生して確認）。こちらは1行ずつ消えていた。

        古いものほど薄くする。新しいものが下（見出しのすぐ上）に来る。
        """
        if not stack:
            return
        from PIL import ImageFont

        layer, draw = _layer(canvas.size)
        _left, _top, right, bottom = self.layout.headline_box
        pad = int(self.layout.width * 0.014)
        kept = list(stack[-self.STACK_KEEP:])
        # **反応の最中はテロップを出さない**ので、見出しの居場所を空ける必要がない。
        # 画面の下まで使えるぶん、字を大きくできる（2026-09-14 指摘「字が小さい」）
        room_h = int(self.layout.height * 0.92) - int(self.layout.height * STACK_TOP)
        scale = self.layout.width / 1920
        size = int(self.STACK_SIZE * scale)
        floor = max(12, int(self.STACK_SIZE_MIN * scale))
        # **字を小さくせず、古いほうから落とす**（2026-09-15 指示
        # 「一番最初のコメントは削除して、大きさが小さくならないようにして」）。
        # 2026-09-14 は逆に「全部出す。入りきらないぶんは字を小さくして収める」と
        # 決めていたが、**件数の多い節で字が読めない大きさまで落ちていた**。
        # 見せたいのは新しいほうなので、あふれたら**いちばん古い1件から捨てる**
        font = ImageFont.truetype(str(self.config.video.font_path()), size)
        while len(kept) > 1:
            total = _stack_height(draw, kept, font, pad, right - _left,
                                  self.STACK_INDENT, self.layout.width,
                                  len(stack) - len(kept))
            if total <= room_h:
                break
            kept.pop(0)
        # 1件だけになっても入らないとき（とても長い書き込み）は、そこで初めて縮める
        while True:
            font = ImageFont.truetype(str(self.config.video.font_path()), size)
            total = _stack_height(draw, kept, font, pad, right - _left,
                                  self.STACK_INDENT, self.layout.width,
                                  len(stack) - len(kept))
            if total <= room_h or size <= floor:
                break
            size -= 3
        # 色と寄せ方は**積んだ通し番号**で決める。画面から消えた分も数に入れるので、
        # 隣り合う書き込みが同じ色・同じ位置にならない
        first = len(stack) - len(kept)

        # **書き込みごとに幅も折り返しも変わる。**先に組んでから、
        # 全体の高さぶんだけ上へ戻して置く（見出しの居場所には入らない）
        room = right - _left
        boxes: list[tuple[int, int, list[str], tuple[int, int, int, int]]] = []
        total = 0
        for depth, text in enumerate(kept):
            index = first + depth
            indent = int(self.layout.width * self.STACK_INDENT[index % len(self.STACK_INDENT)])
            body = _strip_speaker(text)
            # **切らない**（2026-09-15 指摘「文字が切れてる」）。_stack_height と同じ
            lines = balanced_wrap(draw, body, font, room - indent - pad * 3)
            height = font.size * len(lines) + int(font.size * 0.42) * (len(lines) - 1) + pad * 2
            width = pad * 3 + max(int(draw.textlength(chunk, font=font)) for chunk in lines)
            boxes.append((indent, min(width, room - indent), lines,
                          self.STACK_COLORS[index % len(self.STACK_COLORS)]))
            total += height + pad
        # 上から積む。**下に余白が残っても、字の大きさを優先する**
        y = int(self.layout.height * STACK_TOP)
        # **縦型（ショート）は下に寄せる**（2026-10-03「動画の質を上げる仕組み ②」の facecheck で発見）。
        # 縦の写真は顔が上の3分の1に来るので、上から積むと白い箱がちょうど顔に重なっていた
        # （三笘・フランス対イタリア・レヴァンドフスキ・ポルトガルのショートの最後、顔の枠の100%）。
        # 反応の最中はテロップを出さないので、下端（92%）まで使ってよい
        if self.layout.height > self.layout.width:
            y = max(y, int(self.layout.height * 0.92) - total)

        for indent, width, lines, ink in boxes:
            height = font.size * len(lines) + int(font.size * 0.42) * (len(lines) - 1) + pad * 2
            box_left = _left + indent
            draw.rounded_rectangle([box_left, y, box_left + width, y + height],
                                   radius=int(font.size * 0.26),
                                   fill=(255, 255, 255, 246))
            text_y = y + pad
            for chunk in lines:
                draw.text((box_left + pad + pad // 2, text_y), chunk, font=font, fill=ink)
                text_y += font.size + int(font.size * 0.42)
            y += height + pad
        canvas.alpha_composite(layer)

    def _headline_metrics(self, draw: ImageDraw.ImageDraw, text: str, compact: bool = False):
        """見出しの字の大きさ・行・上端を決める。描く前に高さを知りたいとき（表の下限）にも使う。

        **読み上げる文はぜんぶ出す**（2026-09-14 指示）。3行で切っていたので、
        長い一文は「…アンドレス・」で終わっていた。4行を超えるようなら字を小さくして、全部を入れる
        """
        from PIL import ImageFont as _IF
        left, top, right, bottom = self.layout.headline_box
        font_path = str(self.config.video.font_path())
        size = self.config.video.headline_size
        if compact:
            # **表や板が出ている行は見出しを一回り小さく**（品質100回の21）。3行に伸びると表が縮んで読めない
            size = int(size * 0.84)
        floor = max(22, int(size * 0.52))
        font = _IF.truetype(font_path, size) if compact else self.font_headline
        # **強調の囲みを外してから折り返す**（2026-09-15）。囲みで割れ方が変わらない
        plain, spans = emphasis.split(text)
        while True:
            # **右の余白は文字の始まり（left+34）と釣り合う分だけ**（2026-09-18）。
            # 90 だと縦型（幅1080）で 900px しか使えず、画面の83%で折り返していた
            lines = balanced_wrap(draw, plain, font, right - left - 48)
            if len(lines) <= HEADLINE_LINES_MAX or size <= floor:
                break
            size -= 4
            font = _IF.truetype(font_path, size)
        line_height = size + 26
        text_top = bottom - line_height * len(lines)
        return font, size, plain, spans, lines, line_height, text_top

    def headline_band_top(self, text: str, compact: bool = False) -> int | None:
        """見出しの帯の上端（px）。表や写真はこれより上に収める（2026-09-28）。"""
        if not text or self.layout.with_characters:
            return None
        draw = ImageDraw.Draw(Image.new("RGBA", (8, 8)))
        _, _, _, _, _, _, text_top = self._headline_metrics(draw, text, compact)
        return text_top - 26

    def _draw_headline(
        self,
        canvas: Image.Image,
        text: str,
        telop_t: float = 1.0,
        source: str | None = None,
        compact: bool = False,
    ) -> None:
        """立ち絵なしのときの見出し。幅いっぱいの帯に、左は確度の色の縦帯（2026-09-28）。"""
        if not text:
            return
        layer, draw = _layer(canvas.size)
        left, top, right, bottom = self.layout.headline_box
        rise = int(TELOP_RISE * (1.0 - _ease_out(telop_t)))
        font, size, plain, spans, lines, line_height, text_top = self._headline_metrics(draw, text, compact)
        self.font_headline_fit = font
        text_top += rise

        badge = SOURCE_BADGES.get(source or "")
        # 話者ではなく情報の確度で色を決める。会話が続くあいだ見出しを動かさないため
        accent = badge[1] if badge else BRAND_GOLD

        # 文字の下に暗い帯を敷く。**縁取りだけでは背景に沈む**（2026-09-07 に
        # 参考チャンネルと並べて確認）。63万回のチャンネルは白文字＋黒帯で、
        # 実写の上でも見出しが読めていた。こちらは白文字＋細い縁だけだった。
        # **幅いっぱいの帯に、下へ向かって濃くなるグラデ**（2026-09-28）。
        # 字の幅だけの黒い箱は、写真の上で「貼った紙」に見えた
        band_top = text_top - 26
        band_bottom = text_top + line_height * len(lines) + 2
        band = Image.new("RGBA", (right - left + 16, band_bottom - band_top), (0, 0, 0, 0))
        band_draw = ImageDraw.Draw(band)
        for yy in range(band.height):
            band_draw.line([(0, yy), (band.width, yy)],
                           fill=(8, 12, 18, int(190 + 50 * yy / max(1, band.height))))
        layer.alpha_composite(band, (left - 8, band_top))

        # 左の太い縦帯。色は確度（報道＝橙、確定＝緑…）
        draw.rounded_rectangle([left - 8, band_top, left + 8, band_bottom], radius=8, fill=accent + (255,))

        if badge:
            # 確度の札は帯の左肩に（帯の上端にまたがせる）
            label, color = badge
            label_w = draw.textlength(label, font=self.font_name)
            chip = [left + 34, band_top - 26, left + 34 + label_w + 46, band_top + 26]
            draw.rounded_rectangle(chip, radius=26, fill=color + (255,))
            draw.text((chip[0] + 23, chip[1] + 6), label, font=self.font_name,
                      fill=(16, 16, 20, 255))

        y = text_top
        strong_color = BRAND_GOLD + (255,)
        # 囲みで指定した強調が無ければ、数字を自動で強調する
        if not spans:
            spans = [(m.start(), m.end()) for m in AUTO_STRONG.finditer(plain)]
        offset = 0
        for chunk in lines:
            # 折り返しが空白を落とすことがあるので、位置は全文から探して合わせる
            found = plain.find(chunk, offset)
            offset = found if found >= 0 else offset
            x = left + 40
            for segment, strong in _emphasis_segments(
                chunk, emphasis.spans_in(chunk, offset, spans)
            ):
                # 縁取りは縦型で太くする。実写や模様の上でも輪郭が残るように
                # 帯が濃くなったので縁取りは細く（太い縁は字を太らせて読みにくい）
                draw.text(
                    (x, y), segment, font=font,
                    fill=strong_color if strong else (255, 255, 255, 255),
                    stroke_width=5 if self.layout.is_portrait else 2,
                    stroke_fill=(0, 0, 0, 200),
                )
                width = draw.textlength(segment, font=font)
                x += width
            offset += len(chunk)
            y += line_height

        if telop_t < 1.0:
            layer.putalpha(layer.getchannel("A").point(lambda a: int(a * _ease_out(telop_t))))
        canvas.alpha_composite(layer)

    def title_frame(
        self,
        background: str,
        heading: str,
        sub: str,
        progress: float,
        kind: str,
        label: str = "",
    ) -> Path:
        """冒頭タイトル / 章タイトルの1枚。progress は 0→1 のフェード。"""
        key = f"title|{kind}|{background}|{heading}|{sub}|{label}|{progress:.2f}|{self.over_video}"
        target = self.frame_dir / f"t{hashlib.sha1(key.encode('utf-8')).hexdigest()[:15]}.png"
        if target.exists():
            return target

        stage = self._photo_stage(background) if kind == "intro" else None
        if stage is not None and self.over_video and self.moving_photo(background):
            base = self._transparent()
        elif stage is not None:
            base = stage.copy()
        else:
            base = self._transparent() if self.over_video else self._background(background).copy()
        layer, draw = _layer(base.size)

        # 背景を落として文字を主役にする。落としすぎると背景が死ぬので控えめに。
        # 写真を舞台にしたときは人物が見えるよう、落とし方を弱める
        # **本編の最後（終了画面の置き場）は明るめ**（2026-10-03 ユーザー「もう少し明るく」）
        shade = 70 if stage is not None else (0 if kind == "outro" else 178)
        draw.rectangle([0, 0, base.width, base.height], fill=(6, 10, 18, shade))

        accent = _hex(self.config.video.accent)
        font = self.font_title_big if kind == "intro" else self.font_title
        lines = wrap_text(draw, heading, font, int(base.width * 0.76))[:3]
        line_height = font.size + 26
        block = line_height * len(lines)
        top = (base.height - block) // 2 - (34 if sub else 0)
        if kind == "outro" and base.width > base.height:
            # **本編の最後は終了画面の置き場**（2026-10-03）。文字を上に寄せ、真ん中から下を空ける
            top = int(base.height * 0.08)

        left = int(base.width * 0.11)
        if label:
            draw.text(
                (left, top - 60), label, font=self.font_label, fill=accent + (255,),
                stroke_width=3, stroke_fill=(0, 0, 0, 190),
            )
        draw.rounded_rectangle(
            [left - 36, top + 6, left - 22, top + block - 14], radius=7, fill=accent + (255,)
        )
        y = top
        for chunk in lines:
            draw.text(
                (left, y), chunk, font=font, fill=(255, 255, 255, 255),
                stroke_width=6, stroke_fill=(0, 0, 0, 205),
            )
            y += line_height

        if sub:
            draw.text((left, y + 14), sub, font=self.font_scene, fill=(190, 200, 216, 255))

        if progress < 1.0:
            layer.putalpha(layer.getchannel("A").point(lambda a: int(a * _ease_out(progress))))
        base.alpha_composite(layer)
        base.save(target) if self.over_video else base.convert("RGB").save(target)
        return target

    def _title_entries(
        self,
        background: str,
        heading: str,
        sub: str,
        seconds: float,
        kind: str,
        label: str = "",
    ) -> list[tuple[Path, float]]:
        """フェードイン → 静止 → フェードアウト。静止部分は1枚を使い回す。"""
        fade = min(self.config.titles.fade, seconds / 2.5)
        steps = max(1, round(fade * self.config.motion.fps))
        step = fade / steps
        entries: list[tuple[Path, float]] = []

        for i in range(steps):
            entries.append(
                (self.title_frame(background, heading, sub, (i + 1) / steps, kind, label), step)
            )
        hold = max(0.0, seconds - fade * 2)
        if hold > 0:
            entries.append((self.title_frame(background, heading, sub, 1.0, kind, label), hold))
        for i in range(steps):
            entries.append(
                (self.title_frame(background, heading, sub, 1 - (i + 1) / steps, kind, label), step)
            )
        return entries

    # ------------------------------------------------------------ タイムライン

    def frame_entries(
        self, script: Script, inserts: Inserts | None = None
    ) -> list[tuple[Path, float]]:
        """(画像, 表示秒数) の並びを作る。タイトルカード・口パク・演出をここで展開する。

        セリフの尺は動かさない。演出に使う時間は発話時間の内側から取り、
        タイトルカードのぶんは音声側に無音が入っているので、ここでも同じ秒数を使う。
        """
        self.script_background = script.background
        self.script_cards = script.cards
        self.script_date = script.date
        motion = self.config.motion
        inserts = inserts or Inserts()
        entries: list[tuple[Path, float]] = []
        previous: Path | None = None
        prev_stage: str | None = None
        # **横のどこを残すか**（2026-09-18）。縦型は写真を画面いっぱいに敷くので、
        # 端に写っている人が落ちる。台本の `thumbnail_focus_x` で寄せる
        _fx = script.meta.get("thumbnail_focus_x")
        self.layout.focus_x = float(_fx) if _fx not in (None, "") else None
        self._stages.clear()
        self.opening_photo = opening_photo(script.meta)
        self.opening_scene = script.scenes[0].title if script.scenes else ""
        self.opening_points = [str(x) for x in (script.meta.get("thumbnail_points") or [])]
        # 名前の板（選手紹介の冒頭。「名前｜所属 位置」）
        self.nameplate = str(script.meta.get("nameplate") or "").strip()
        # 写真の下地（focus_x を反映したもの）を背景側に並べてから、動画の上に描くかを決める
        self.over_video = any(is_video(bg) for bg, _ in self.background_segments(script, inserts))
        self.scene_order = {scene.title: index + 1 for index, scene in enumerate(script.scenes)}
        self.scene_total = len(script.scenes)

        if inserts.intro > 0 and script.scenes:
            first_bg = script.scenes[0].background or script.background or self.config.video.background
            # **冒頭からその人の写真**（2026-09-08）。ぼかした夜景に黒い板では、
            # 最初の3秒が止まって見えた。サムネの写真があればそれを舞台にする
            photo = str(script.meta.get("thumbnail_photo") or "")
            if self._photo_stage(photo) is not None:
                first_bg = photo
            entries += self._title_entries(
                first_bg,
                script.intro_title(),
                script.date,
                inserts.intro,
                "intro",
                str(script.meta.get("intro_label") or ""),
            )

        for scene_index, scene in enumerate(script.scenes):
            gap = inserts.before_scene(scene_index)
            if gap > 0:
                background = scene.background or script.background or self.config.video.background
                entries += self._title_entries(
                    background,
                    scene.title,
                    f"{scene_index + 1} / {len(script.scenes)}",
                    gap,
                    "chapter",
                )
                previous = None  # 章タイトル直後は転換の溶かしを入れない
            headline: tuple[str, str | None] = ("", None)
            card: str | None = None
            # **書き込みは前の行から積もる**（2026-10-07）。カードが替われば消える（同じ表のあいだは残る）
            board = marks_mod.Board()
            # **反応は画面に積む**（2026-09-07）。匿名の書き込みが続くあいだ、
            # 前の行を見出しの上に残す。別の話者が入ったら積み直す
            stack: list[str] = []
            for index, line in enumerate(scene.lines):
                # 立ち絵なしのニュース風では、見出しは telop を書いた行でだけ差し替え、
                # それ以外の行は直前の見出しを出したままにする（生のセリフは出さない）
                changed = True
                current: tuple[str, str | None, str | None] | None = None
                if not self.layout.with_characters:
                    before = (headline, card)
                    if line.no_telop:
                        headline = ("", None)
                    elif line.telop is not None:
                        # 見出しと確度はセットで差し替える
                        headline = (line.telop, line.source)
                    if line.card is not None:
                        # カードも指定した行で差し替え、それ以外は出したまま
                        card = None if line.card in ("none", "なし") else line.card
                    current = (headline[0], headline[1], card)
                    changed = (headline, card) != before

                crowd = (line.speaker or "").strip() in self.config.voice_crowd
                # **いま読んでいる行も箱に入れる**（2026-09-14）。テロップを
                # 出さない決まりにしたので、ここに入れないと読んでいる声が
                # 画面のどこにも出なくなる
                shown = tuple(stack + [emphasis.strip(line.telop_text() or line.text)]) if crowd else ()
                new_marks = list(line.marks) if not self.layout.with_characters else []
                drawn = (tuple(board.step(card, self.script_cards.get(card or ""),
                                          line.image or (self.opening_photo if scene.title == self.opening_scene else None),
                                          new_marks))
                         if not self.layout.with_characters else None)
                ink = {"marks": drawn, "mark_new": len(new_marks)}
                closed = self.frame(line, scene, mouth_open=False, panel=current,
                                    stack=shown, **ink)
                opened = self.frame(line, scene, mouth_open=True, panel=current,
                                    stack=shown, **ink)
                # 出現のアニメ・行の出現のあいだは、この行の書き込みはまだ描かない
                ink_before = dict(ink, mark_t=0.0)
                # 積むのは匿名の反応だけ。語りが入ったらいったん流す
                stack = (stack + [emphasis.strip(line.telop_text() or line.text)]) if crowd else []
                pause = line.pause or 0.0
                speaking = max(0.0, line.duration - pause)
                is_scene_head = index == 0

                intro = 0.0
                card_changed = bool(current and current[2] and current[2] != before[1]) if not self.layout.with_characters else False
                rows = (self.card_rows(current[2])
                        if card_changed and not self.same_table(before[1], current[2]) else 0)
                stage_now = line.image or (self.opening_photo if scene.title == self.opening_scene else None)
                image_changed = bool(previous is not None and stage_now and stage_now != prev_stage)
                prev_stage = stage_now
                if not self.layout.with_characters and previous is not None and (
                        self.is_full_card(current[2]) or self.is_full_card(before[1])) \
                        and current[2] != before[1]:
                    # **左右の比べ（versus）に入る・出るところも溶かす**（2026-10-07）。画面が丸ごと替わる
                    image_changed = True
                if motion.enabled:
                    if image_changed and IMAGE_FADE > 0:
                        # **写真が替わる行は前の絵から溶かす**（品質100回の11）。ぶつ切りだと編集していないように見える
                        intro = min(IMAGE_FADE, speaking * 0.4)
                        entries += self._transition_crossfade(previous, closed, intro)
                    elif is_scene_head and previous is not None and motion.scene_fade > 0:
                        # シーン転換。前の画面から新しい画面へ溶かす
                        intro = min(motion.scene_fade, speaking * 0.5)
                        entries += self._transition(previous, closed, intro)
                    elif changed and motion.telop_in > 0 and (
                        (current[0] or current[2]) if current else line.telop_text()
                    ):
                        # 見出しやカードが変わったときだけ、出現のアニメを入れる
                        intro = min(motion.telop_in, speaking * 0.5)
                        entries += self._intro(line, scene, intro, current, shown, ink=ink_before)
                    elif is_scene_head and not stack and PILL_IN > 0:
                        # **節の頭ではピルとテロップが滑り込む**（2026-09-28 動きの段3）。時間は足さない
                        intro = min(PILL_IN, speaking * 0.4)
                        entries += self._intro(line, scene, intro, current, shown,
                                               reveal=0 if rows else None, ink=ink_before)
                    if rows and motion.enabled and not stack:
                        # **表の行が1本ずつ現れる**（2026-09-28 動きの段2）。読み上げの内側から取る
                        step = min(ROW_IN, max(0.0, speaking * 0.5 - intro) / rows)
                        if step > 0.02:
                            for k in range(1, rows + 1):
                                entries.append((self.frame(line, scene, False, panel=current, stack=shown,
                                                           reveal=k if k < rows else None,
                                                           **ink_before), step))
                            intro += step * rows
                    if new_marks and MARK_IN > 0 and MARK_STEPS > 1:
                        # **書き込みを描き進める**（2026-10-07）。線が伸び、添え書きが1字ずつ出る。読み上げの内側から取る
                        step = min(MARK_IN / MARK_STEPS, max(0.0, speaking * 0.6 - intro) / MARK_STEPS)
                        if step > 0.02:
                            for k in range(1, MARK_STEPS):
                                entries.append((self.frame(line, scene, False, panel=current, stack=shown,
                                                           **dict(ink, mark_t=k / MARK_STEPS)), step))
                            intro += step * (MARK_STEPS - 1)

                entries += self._mouth_loop(closed, opened, speaking - intro)
                if pause > 0.01:
                    entries.append((closed, pause))
                previous = closed

        if inserts.outro > 0 and script.scenes:
            last_bg = (
                script.scenes[-1].background or script.background or self.config.video.background
            )
            entries += self._title_entries(
                last_bg,
                str(script.meta.get("outro_title") or "ご視聴ありがとうございました"),
                str(script.meta.get("outro_sub") or "チャンネル登録で続報をチェック"),
                inserts.outro,
                "outro",
                str(script.meta.get("intro_label") or ""),
            )

        return entries

    def _transition_crossfade(self, before: Path, after: Path, seconds: float) -> list[tuple[Path, float]]:
        """写真の切り替え用。scene_transition の設定にかかわらず、前後を直接混ぜる。"""
        steps = max(2, round(seconds * self.config.motion.fps))
        step = seconds / steps
        return [(self.blend(before, after, (i + 1) / steps), step) for i in range(steps)]

    def _transition(self, before: Path, after: Path, seconds: float) -> list[tuple[Path, float]]:
        """シーン転換。

        crossfade は前後の画面を直接混ぜるので、テロップが一瞬二重に見える。
        既定の dip は一度黒に落としてから次の画面を出すため、文字が重ならない。
        """
        style = self.config.motion.scene_transition
        steps = max(2, round(seconds * self.config.motion.fps))
        step = seconds / steps

        if style == "crossfade":
            return [(self.blend(before, after, (i + 1) / steps), step) for i in range(steps)]

        black = self._black()
        half = steps // 2
        entries = [
            (self.blend(before, black, (i + 1) / half), step) for i in range(half)
        ]
        rest = steps - half
        entries += [(self.blend(black, after, (i + 1) / rest), step) for i in range(rest)]
        return entries

    def _intro(
        self,
        line: Line,
        scene: Scene,
        seconds: float,
        panel: tuple[str, str | None, str | None] | None = None,
        stack: tuple[str, ...] = (),
        reveal: int | None = None,
        ink: dict | None = None,
    ) -> list[tuple[Path, float]]:
        steps = max(1, round(seconds * self.config.motion.fps))
        step = seconds / steps
        entries = []
        for i in range(steps):
            progress = (i + 1) / steps
            # 出現中は口を閉じたままにして、フレームの種類が増えすぎないようにする
            entries.append(
                (
                    # **積み上げもここへ渡す**（2026-09-14 指摘「一瞬だけ映る部分は不要」）。
                    # テロップの出現アニメだけ stack を渡しておらず、
                    # 反応の行でも0.3秒だけ大テロップが描かれていた
                    self.frame(
                        line, scene, False, telop_t=progress, hop_t=progress,
                        panel=panel, stack=stack, reveal=reveal, **(ink or {})
                    ),
                    step,
                )
            )
        return entries

    def _mouth_loop(self, closed: Path, opened: Path, seconds: float) -> list[tuple[Path, float]]:
        entries: list[tuple[Path, float]] = []
        remaining = max(0.0, seconds)
        mouth_open = False
        while remaining > 1e-6:
            step = min(MOUTH_INTERVAL, remaining)
            entries.append((opened if mouth_open else closed, step))
            mouth_open = not mouth_open
            remaining -= step
        return entries

    def background_segments(
        self, script: Script, inserts: Inserts | None = None
    ) -> list[tuple[Path, float]]:
        """シーンごとの (背景, 表示秒数)。静止画と動画を混ぜてよい。

        タイトルカードのぶんも、そのシーンの背景で埋める。
        """
        inserts = inserts or Inserts()
        # **写真の下地は背景側に移して、ゆっくり寄せる**（2026-09-28）。行ごとに
        # 「その行の写真の下地」か「節の背景」を並べ、同じものが続くあいだは1つにまとめる
        # （まとめないとズームが行ごとに始まり直す）。タイトルカードのぶんは最初・最後の行に足す
        raw: list[tuple[Path, float, bool]] = []   # (素材, 秒, 写真か)
        opening_scene = script.scenes[0].title if script.scenes else ""
        opening_photo = opening_photo_of(script.meta)
        for index, scene in enumerate(script.scenes):
            name = scene.background or script.background or self.config.video.background
            # 既に書いた台本は .png を指している。書き出しのたびに実写を探す
            name = moving_background(name)
            extra = inserts.before_scene(index)
            if index == 0:
                extra += inserts.intro
            if index == len(script.scenes) - 1:
                extra += inserts.outro
            if not scene.lines:
                raw.append((_resolve(name), scene.duration + extra, False))
                continue
            for line_index, line in enumerate(scene.lines):
                stage_path = line.image or (opening_photo if scene.title == opening_scene else None)
                seconds = max(0.0, line.duration)
                if line_index == 0 and index == 0:
                    seconds += inserts.intro + inserts.before_scene(index)
                elif line_index == 0:
                    seconds += inserts.before_scene(index)
                if line_index == len(scene.lines) - 1 and index == len(script.scenes) - 1:
                    seconds += inserts.outro
                if stage_path and self.moving_photo(stage_path):
                    raw.append((self._stage_file(stage_path), seconds, True))
                else:
                    raw.append((_resolve(name), seconds, False))
        merged: list[tuple[Path, float, bool]] = []
        for path, seconds, is_photo in raw:
            if merged and merged[-1][0] == path:
                merged[-1] = (path, merged[-1][1] + seconds, is_photo)
            else:
                merged.append((path, seconds, is_photo))
        segments: list[tuple[Path, float]] = []
        for index, (path, seconds, is_photo) in enumerate(merged):
            if seconds <= 0:
                continue
            if is_photo:
                segments.append((self._moving(path, seconds, self.config.motion.photo_zoom), seconds))
            else:
                segments += self._split_long(str(path), seconds, index)
        return segments

    # 1枚の絵をこれ以上見せ続けない。実測で「まとめ」が24秒あり、
    # 同じ画面が3カット続いていた。
    # 2026-09-05 に 12秒 → 7秒。参考3チャンネルは尺そのものが1〜2分で、
    # 絵が変わらない時間が長いと**間が持たない**。背景が切り替わるだけでも
    # 画面は動いて見える
    MAX_STILL_SECONDS = 7.0

    def _split_long(self, name: str, seconds: float, index: int) -> list[tuple[Path, float]]:
        """シーンの背景は1枚のまま出す。

        **途中で割らない**（2026-09-14 指示「背景を何度も変更するのはやめて。
        変更は一度まで」）。それまでは静止画が長いと BACKGROUNDS の並びから
        別の絵を選んで半分で入れ替えていた。台本の側で下地を1つに固めても、
        **ここが勝手に差し替えるので節の途中で絵が変わっていた**
        （エンブレムの下地にしたショートで、25秒あたりからスタジアムに戻った）。
        画面の動きは `background_zoom` のゆっくりした寄りで作る。
        """
        return [(self._moving(_resolve(name), seconds), seconds)]

    def _moving(self, path: Path, seconds: float, zoom: float | None = None) -> Path:
        """静止画の背景を、ゆっくり寄っていくクリップに置き換える。

        止まった絵が続くと動画に見えないので既定で有効。同じ画と長さの
        組み合わせは作り直さない。写真の下地は `photo_zoom`、それ以外は `background_zoom`。
        """
        # 写真は寄りすぎると顔が荒れるので上限を低く（1本を通して最大 1.25 倍）
        max_zoom = ffmpeg.MAX_ZOOM if zoom is None else PHOTO_MAX_ZOOM
        zoom = self.config.motion.background_zoom if zoom is None else zoom
        if zoom <= 1.0 or is_video(path) or not path.exists():
            return path

        length = max(4.0, math.ceil(seconds))
        cache = _resolve("assets/backgrounds/.motion")
        # 名前に**元画像の中身の指紋**を入れる。名前が同じだと古いクリップが
        # 使い回され、背景を描き直しても反映されない（2026-09-05 に実際に
        # 起きた。背景の模様を増やしたのに、動画は前のまま静止していた）。
        # 寄り方を変えたときも同じことが起きるので、版（r2）も残す。
        stamp = hashlib.sha1(path.read_bytes()).hexdigest()[:8]
        target = cache / f"{path.stem}_{int(length)}s_{int(zoom * 100)}r2_{int(max_zoom * 100)}_{stamp}.mp4"
        if not target.exists():
            cache.mkdir(parents=True, exist_ok=True)
            ffmpeg.still_to_clip(
                path, target, length,
                (self.layout.width, self.layout.height), zoom, self.config.video.fps,
                max_zoom=max_zoom,
            )
        return target

    def build_video(
        self,
        script: Script,
        audio_path: Path | None,
        out_path: Path,
        work_dir: Path,
        inserts: Inserts | None = None,
    ) -> Path:
        entries = self.frame_entries(script, inserts)
        list_path = ffmpeg.write_concat_list(entries, work_dir / "frames.txt")
        out_path.parent.mkdir(parents=True, exist_ok=True)
        size = (self.layout.width, self.layout.height)

        if self.over_video:
            # 背景をつないだ1本の動画にしてから、透過フレームを重ねる
            track = ffmpeg.build_background_track(
                self.background_segments(script, inserts),
                work_dir / "background.mp4",
                size,
                self.config.video.fps,
            )
            return ffmpeg.encode_video_over_clip(
                list_path, track, audio_path, out_path, size, self.config.video.fps,
                progress=self._progress_spec(entries),
            )
        return ffmpeg.encode_video(list_path, audio_path, out_path, self.config.video.fps,
                                   size=size, progress=self._progress_spec(entries))

    def _progress_spec(self, entries: list[tuple[Path, float]]) -> tuple[float, int] | None:
        """画面下端の進捗バー（2026-09-28）。ffmpeg が時間で動かすので、フレームは増えない。

        縦型（ショート）には出さない。一覧の1コマ目に線が入る
        """
        if self.layout.is_portrait:
            return None
        total = sum(seconds for _, seconds in entries)
        return (total, PROGRESS_HEIGHT) if total > 1.0 and PROGRESS_HEIGHT > 0 else None


def _emphasis_segments(chunk: str, spans: list[tuple[int, int]]
                       ) -> list[tuple[str, bool]]:
    """1行を「ふつう／強調」の連なりに割る。囲みが無ければ1つだけ返す。"""
    if not spans:
        return [(chunk, False)]
    out: list[tuple[str, bool]] = []
    at = 0
    for start, end in spans:
        if start > at:
            out.append((chunk[at:start], False))
        out.append((chunk[start:end], True))
        at = end
    if at < len(chunk):
        out.append((chunk[at:], False))
    return [(text, strong) for text, strong in out if text]


def _is_board(image_path: str) -> bool:
    """その絵は「板」か。**一覧板・数字の図はそれ自体が読ませる絵**。

    ふつうの写真と見分ける手がかりは置き場所と控え:
      ・`assets/stats/` … `squadboard.py` と `statboard` の書き出し先
      ・`<絵>.statboard.txt` … 数字の図が残す控え（review が顔の代わりに認める印）
    **写真（assets/photos, assets/images）は板ではない。**
    2026-09-18 に、ここを分けずに「横長なら板」としていたせいで、
    報道写真の回のカードが全部消えていた
    """
    from pathlib import Path as _P
    text = str(image_path).replace("\\", "/")
    if "/assets/stats/" in text or text.startswith("assets/stats/"):
        return True
    try:
        return _P(str(image_path) + ".statboard.txt").exists()
    except OSError:
        return False


def balanced_wrap(
    draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: float
) -> list[str]:
    """折り返した行の長さをそろえる。

    素直に詰めると最後の行だけ数文字になりがちで、見出しとして落ち着かない。
    行数を変えずに幅を狭めて配り直す。
    """
    lines = wrap_text(draw, text, font, max_width)
    if len(lines) < 2:
        return lines

    # 行数が同じ候補の中から、切れ目のいちばん良いものを選ぶ。
    # 幅だけで詰めると「チェルシーが激怒した、移／籍期限…」のように
    # 熟語の途中で割れる。句読点の直後で切れているほうが読みやすい。
    # 幅を少しずつ狭めて候補を作る。刻みが粗いと、良い切れ目の幅を飛ばす。
    # 実測（2026-09-04）で、5段階だと「12月まで／戻らない」で切れる幅
    # （上限の約0.88倍）が候補に入らず、「まで戻／らない」しか選べなかった。
    best = lines
    best_score = _break_score(lines)
    for step in range(60, 100, 2):
        candidate = wrap_text(draw, text, font, max_width * step / 100)
        if len(candidate) != len(lines):
            continue
        score = _break_score(candidate)
        if score > best_score:
            best, best_score = candidate, score
    return best


# 行末がこの文字なら、切れ目として良い（意味の区切りで改行できている）
GOOD_BREAK_END = "、。！？」』）・"


def _is_kanji(char: str) -> bool:
    return "一" <= char <= "鿿"


def _is_hiragana(char: str) -> bool:
    return "ぁ" <= char <= "ん"


def _is_katakana(char: str) -> bool:
    return "ァ" <= char <= "ヴ"


# 行頭に来ても読みを壊さないひらがな（助詞・助動詞の頭）。
# 「選手が／外れた」は読めるが、「戻／らない」は動詞が割れて読めない。
# どちらも「漢字のあとにひらがな」で、字種だけでは見分けられないので、
# 助詞として使われる字を挙げて区別する。
PARTICLE_HEAD = "がをにはへもとやでかねよ"


def _break_score(lines: list[str]) -> int:
    """行の切れ目の良さ。大きいほど読みやすい。

    - 句読点や閉じ括弧で終わっていれば +2（意味の区切りで改行できている）
    - 漢字が続く途中で割ったら -3（「移／籍」「成／立」のような熟語の分断）
    - カタカナが続く途中で割ったら -3（「シー／ズン」。外来語は1語で読む）
    - ひらがなが続く途中で割ったら -2（「12月ま／で」「動くかど／うか」）
    - 送り仮名を置き去りにしたら -2（「戻／らない」。助詞なら減点しない）

    分断のほうを重く見る。多少 行末がそろわなくても、語が割れないほうが読める。

    ひらがなを漢字より軽くしているのは、助詞の切れ目（「遠藤選手が／外れた」）は
    実際には読めるため。同じ減点にすると、まともな切れ目まで避けてしまう。
    """
    score = 0
    for index, line in enumerate(lines[:-1]):
        if not line:
            continue
        if line[-1] in GOOD_BREAK_END:
            score += 2
        next_line = lines[index + 1]
        if not next_line:
            continue
        tail, head = line[-1], next_line[0]
        if _is_kanji(tail) and _is_kanji(head):
            score -= 3
        elif _is_katakana(tail) and _is_katakana(head):
            score -= 3
        elif _is_hiragana(tail) and _is_hiragana(head):
            score -= 2
        elif _is_kanji(tail) and _is_hiragana(head) and head not in PARTICLE_HEAD:
            score -= 2
    return score


# 行頭に置いてはいけない文字（行頭禁則）。
# 約物だけでは足りない。実測で「チェルシー」が「チ／ェルシー」に割れ、
# 行頭が小文字の「ェ」になっていた。拗音・促音・長音符も行頭に来てはいけない。
LINE_START_FORBIDDEN = (
    "、。，．・：；！？」』）］｝〉》"      # 約物
    "ぁぃぅぇぉっゃゅょゎゕゖ"              # ひらがなの小書き
    "ァィゥェォッャュョヮヵヶ"              # カタカナの小書き
    "ーヽヾゝゞ々〻"                        # 長音符・繰り返し記号
    ",.!?:;)]}’”"                # 欧文の約物
)

# 行末に置いてはいけない文字（行末禁則）。開き括弧はぶら下げない
LINE_END_FORBIDDEN = "「『（［｛〈《([{‘“"


# 途中で割ってはいけない連なり。数字（小数点・カンマ・時刻の区切りを含む）と英字。
# **「後半38分」が「後半3／8分」になっていた**（2026-09-18 に画面で見つかった）
# **助数詞まで一緒に運ぶ**（2026-09-18）。「72」は割れなくなったが、
# 今度は「アトレティコ・マドリード戦は72／分から」と単位が離れて読みにくかった
_COUNTER = "分秒時日月年人名位点個回戦歳億万千円点本勝敗試合"
_UNBREAKABLE = re.compile(
    r"[0-9０-９]+(?:[.,．，:：][0-9０-９]+)*[%％]?"
    rf"(?:試合|[{_COUNTER}])?|[A-Za-zＡ-Ｚａ-ｚ]+")


def _unbreakable(text: str):
    """折り返しの単位。**数字と英字のかたまりは1つとして扱う。**"""
    at = 0
    for found in _UNBREAKABLE.finditer(text):
        yield from text[at:found.start()]
        yield found.group(0)
        at = found.end()
    yield from text[at:]


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: float) -> list[str]:
    """日本語向けに1文字ずつ幅を見て折り返す。行頭・行末の禁則を守る。

    幅だけで切ると、単語や拗音の途中で改行されて読みにくくなる。
    実測では「チェルシー」が「チ／ェルシー」に、「成立」が「成／立」に割れていた。
    """
    forbidden = LINE_START_FORBIDDEN
    lines: list[str] = []
    current = ""
    # **数字と英字は途中で割らない**（2026-09-18 ユーザー指摘）。
    # 1文字ずつ幅を見て折り返していたので、「後半38分」が
    # **「後半3」「8分」**に割れて、読んでも意味が取れない画面になっていた。
    # 拗音や熟語の途中で割れる問題は直してあったのに、**数字は見ていなかった**
    for char in _unbreakable(text):
        if char == "\n":
            lines.append(current)
            current = ""
            continue
        if draw.textlength(current + char, font=font) > max_width and current:
            if char in forbidden:
                # 行頭に来てはいけない文字は、はみ出しても前の行にぶら下げる
                current += char
                lines.append(current)
                current = ""
                continue
            # 行末に来てはいけない文字（開き括弧）は、次の行へ送る
            if current[-1] in LINE_END_FORBIDDEN:
                lines.append(current[:-1])
                current = current[-1] + char
                continue
            lines.append(current)
            current = char
        elif not current and lines and char in forbidden:
            # **ぶら下げた直後の約物も前の行へ**（2026-10-05、鈴木彩艶の回）。
            # 「…特長」」をぶら下げたあと、続く「。」が次の行の頭に来ていた
            # （「」。決勝の前日…」「なるけど、／」」）
            prev = lines[-1]
            if draw.textlength(prev, font=font) > max_width:
                # **2文字目はぶら下げず、追い出す**（2026-10-07、「ロジャー」の
                # 「ャ」をぶら下げたあと「ー」も足して、右端の外へ切れていた）。
                # 前の行の最後の「頭に来てよい文字」から後ろを、次の行へ送る
                cut = len(prev)
                while cut > 1 and prev[cut - 1] in forbidden:
                    cut -= 1
                cut -= 1
                if cut > 0:
                    lines[-1] = prev[:cut]
                    current = prev[cut:] + char
                    continue
            lines[-1] += char
        else:
            current += char
    if current:
        lines.append(current)
    return lines


# 積んだ箱の上端。**節名の帯（上から42〜110px）の下**から始める
STACK_TOP = 0.17
# 見出しの行数の上限。超えたら字を小さくして全部入れる
HEADLINE_LINES_MAX = 4

_SPEAKER_WRAP = re.compile(r"^[^「]{1,12}「(.+)」$", re.S)


def _stack_height(draw, rows, font, pad, room, indents, width, first) -> int:
    """積んだ箱ぜんぶの高さ。**字の大きさを決めるために先に測る**（2026-09-14）。"""
    total = 0
    for depth, text in enumerate(rows):
        indent = int(width * indents[(first + depth) % len(indents)])
        # **3行で切っていた**（2026-09-15 指摘「文字が切れてる」）。
        # 「ネットのコメントは、画面に全部出す」と決めてあるのに、
        # 4行必要な書き込みが**黙って途中で終わっていた**
        # （「行為として蹴ってる以上、そこは同」）。切らずに測って、
        # 入りきらなければ上の while が字を小さくする
        lines = balanced_wrap(draw, _strip_speaker(text), font,
                              max(60, room - indent - pad * 3))
        total += (font.size * len(lines)
                  + int(font.size * 0.42) * (len(lines) - 1) + pad * 2 + pad)
    return total


def _strip_speaker(text: str) -> str:
    """「ネット民「〜」」から中身だけ取り出す（2026-09-14）。

    積んだ箱に毎回おなじ話者名が付くと、**4件並べたときに同じ字が4回**出る。
    見本の画面も、書き込みの本文だけを置いている。
    """
    found = _SPEAKER_WRAP.match(text.strip())
    return found.group(1) if found else text


def _ease_out(t: float) -> float:
    """最後にゆっくり止まるイージング。"""
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) ** 3


def _layer(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    """合成用の透明レイヤーと描画ハンドルを返す。"""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    return layer, ImageDraw.Draw(layer)


# 制作の都合で付けている章の名前。視聴者に見せる意味が無い
INTERNAL_LABELS = ("オープニング", "まとめ")


def opening_photo_of(meta: dict) -> str:
    return opening_photo(meta)


def opening_photo(meta: dict) -> str:
    """冒頭に敷く写真を決める。

    **顔を並べた回で抜けていた**（2026-09-09 実測）。`thumbnail_photos`
    （2〜3枚）だけを書いた台本は `thumbnail_photo` が空になり、
    冒頭が写真の無いぼかしだけになっていた。ショートの一覧は動画から作った
    1コマ（`oar2.jpg`）を出すので、ここが空だと一覧の絵まで抜ける。
    """
    single = str((meta or {}).get("thumbnail_photo") or "").strip()
    if single:
        return single
    tiles = [str(x).strip() for x in ((meta or {}).get("thumbnail_photos") or [])]
    tiles = [x for x in tiles if x]
    return tiles[0] if tiles else ""


def _flat_bed(photo: Image.Image, width: int, height: int) -> Image.Image:
    """縦写真の左に敷く、**写真から拾った色のべた塗り**（2026-09-23 ユーザー選択）。

    ぼかした敷き布は 2026-09-20 にサムネからは外してあったが、動画の中には
    残っていた。上から下へのグラデーションにして、写真と地続きの色にする。
    """
    small = photo.convert("RGB").resize((24, 24), Image.LANCZOS)
    pixels = [c for c in small.getdata() if 60 < sum(c) < 720] or list(small.getdata())
    top = tuple(sum(c[i] for c in pixels) // len(pixels) for i in range(3))
    top = tuple(int(c * 0.55 + 18) for c in top)
    bottom = tuple(int(c * 0.45) for c in top)
    bed = Image.new("RGBA", (width, height), top + (255,))
    draw = ImageDraw.Draw(bed)
    for y in range(height):
        ratio = y / max(1, height)
        draw.line([(0, y), (width, y)],
                  fill=tuple(round(a + (b - a) * ratio) for a, b in zip(top, bottom)) + (255,))
    return bed


def _cover(image: Image.Image, width: int, height: int, focus: float | None = None,
           focus_x: float | None = None) -> Image.Image:
    """アスペクト比を保ったまま画面いっぱいに敷き詰める。

    **縦長の写真は上寄りに切る。**人物写真は顔が上にあるので、真ん中で切ると
    顔が落ちる。実測（2026-09-05）で、サムネに選手の写真を敷いたら胴体だけが
    残り、誰なのか分からなくなった。

    **横も指定できる**（2026-09-18 ユーザー指摘「ショートのサムネのメッシが
    見切れてる」）。横は必ず真ん中で切っていたので、**横長の写真を縦型に敷くと
    端に写っている人が落ちる。**バロンドールの回で、右端のメッシが
    手と膝しか残らなかった。`focus_x` は 0.0=左端 / 1.0=右端
    """
    scale = max(width / image.width, height / image.height)
    resized = image.resize((int(image.width * scale), int(image.height * scale)), Image.LANCZOS)
    room = resized.width - width
    left = (int(room * min(1.0, max(0.0, focus_x)))
            if focus_x is not None else room // 2)
    spare = resized.height - height
    tall = image.height > image.width * 1.1
    # focus は「縦のどこを残すか」（0.0=上端 / 1.0=下端）。**顔の位置は写真ごとに
    # 違うので、割合の決め打ちでは当たらない**（2026-09-05 実測。上から12%で
    # 切ったら、顔が真ん中にある写真で目の高さから切れた）。既定は当たりで、
    # 合わないものは台本から指定する
    where = focus if focus is not None else (0.12 if tall else 0.5)
    top = int(spare * min(1.0, max(0.0, where)))
    return resized.crop((left, top, left + width, top + height))


def _dim(sprite: Image.Image, factor: float) -> Image.Image:
    overlay = Image.new("RGBA", sprite.size, (0, 0, 0, int(255 * (1 - factor))))
    result = sprite.copy()
    result.alpha_composite(overlay)
    result.putalpha(sprite.getchannel("A"))
    return result


def _hex(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    if len(value) != 6:
        return (200, 200, 200)
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))
