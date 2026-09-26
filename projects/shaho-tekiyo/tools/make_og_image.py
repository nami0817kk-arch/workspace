"""SNS や検索で共有されたときに出る画像（static/og.png、1200×630）を作る。

文字を変えたときだけ回し直して、できた PNG をコミットする（ビルドのたびには作らない）。
フォントは BIZ UDゴシック（モリサワ、SIL Open Font License。Windows に入っているものを使う）。

    pip install pillow
    python tools/make_og_image.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = r"C:\Windows\Fonts\BIZ-UDGothicB.ttc"
OUT = Path(__file__).resolve().parent.parent / "static" / "og.png"

W, H = 1200, 630
BG = (13, 122, 108)  # base.html の --accent（ライト）
FG = (255, 255, 255)
SUB = (214, 240, 234)


def main() -> None:
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    title = ImageFont.truetype(FONT, 76)
    body = ImageFont.truetype(FONT, 40)
    small = ImageFont.truetype(FONT, 30)
    d.text((80, 150), "社会保険", font=title, fill=FG)
    d.text((80, 245), "加入判定チェッカー", font=title, fill=FG)
    d.text((80, 380), "パートの保険料・手取り・週20時間の壁を", font=body, fill=SUB)
    d.text((80, 435), "令和8年度の料率で、円単位に", font=body, fill=SUB)
    d.text((80, 540), "計算はブラウザの中だけ。入力は送信しません", font=small, fill=SUB)
    OUT.parent.mkdir(exist_ok=True)
    im.save(OUT, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
