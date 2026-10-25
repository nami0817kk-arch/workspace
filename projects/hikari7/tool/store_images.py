"""App Store の掲載画像に、うたい文句を付けて並べ直す（1.0.1、2026-10-25）。

tool/screenshots.py が撮った画面（build/screenshots）を、上に見出し・下に縮めた画面の形に組む。
見せ場（合格発表・講評・エンドロール）を先に置く（1.0 はタイトル画面が1枚目で、何のゲームか伝わらなかった）。
書体：見出し Dela Gothic One（fonts/、OFL）、添え書き BIZ UDゴシック Bold（Windows 同梱、OFL）。
使い方: python tool/store_images.py   （先に tool/screenshots.py）→ build/store/<端末>/ に出す
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent.parent
SRC = HERE / 'build' / 'screenshots'
OUT = HERE / 'build' / 'store'
HEAD_FONT = str(HERE / 'fonts' / 'DelaGothicOne-Regular.ttf')
SUB_FONT = r'C:\Windows\Fonts\BIZ-UDGothicB.ttc'

# 並び順・見出し・添え書き（「アイドル」は使わない。実在の名前を出さない）
ORDER = [
    ('06_call', '名前を呼ぶのは、あなた。', '合格者は、視聴者投票ではなく あなたが選ぶ'),
    ('08_crit', '言葉ひとつで、伸びるか折れるか', '気質で受け止め方が変わる 8通りの講評'),
    ('09_ending', 'デビューの、その先の10年まで', '結末は23種類。評価が低ければ解散も'),
    ('03_plan', '番組を作るのも、あなた', '審査の順番、チーム、制作費の使い道'),
    ('05_stage', 'ステージの出来を見届ける', 'チーム課題・ポジション別・公開ライブ'),
    ('04_talk', '一人ひとりに、物語がある', '33の物語。支えきった子は「覚醒」する'),
    ('10_enddex', '結末の図鑑を埋めていく', '伝説の10年、再結成、ひとりの星…'),
    ('02_select', '40人の応募者から始まる', '書類と応募動画で、24人を見極める'),
]
DEVICES = ['1_iPhone_6.3', '2_iPad_13']
BG_TOP, BG_BOT = (44, 22, 84), (14, 8, 30)
GOLD, WHITE = (236, 190, 84), (240, 236, 250)


def fit(draw, text, font_path, max_w, size):
    while size > 20:
        f = ImageFont.truetype(font_path, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 4
    return ImageFont.truetype(font_path, size)


def compose(shot, head, sub):
    W, H = shot.size
    img = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):  # 縦のグラデーション
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3)))
    pad = int(W * 0.07)
    top = int(H * 0.055)
    hf = fit(d, head, HEAD_FONT, W - pad * 2, int(W * 0.078))
    d.text((W / 2, top), head, font=hf, fill=GOLD, anchor='ma')
    sf = fit(d, sub, SUB_FONT, W - pad * 2, int(W * 0.040))
    hb = d.textbbox((W / 2, top), head, font=hf, anchor='ma')
    d.text((W / 2, hb[3] + int(H * 0.018)), sub, font=sf, fill=WHITE, anchor='ma')
    # 画面を縮めて下に置く（角を丸め、うしろに光）
    area_top = int(H * 0.19)
    sc = min((H - area_top - int(H * 0.03)) / H, (W - pad) / W)
    sw, sh = int(W * sc), int(H * sc)
    small = shot.resize((sw, sh), Image.LANCZOS)
    r = int(sw * 0.06)
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=r, fill=255)
    x = (W - sw) // 2
    glow = Image.new('L', (W, H), 0)
    ImageDraw.Draw(glow).rounded_rectangle([x - 6, area_top - 6, x + sw + 6, area_top + sh + 6], radius=r + 6, fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(int(W * 0.025)))
    img.paste(Image.new('RGB', (W, H), (170, 120, 255)), (0, 0), glow)
    img.paste(small, (x, area_top), mask)
    return img


def main():
    for dev in DEVICES:
        out = OUT / dev
        out.mkdir(parents=True, exist_ok=True)
        for i, (name, head, sub) in enumerate(ORDER, 1):
            shot = Image.open(SRC / dev / f'{name}.png').convert('RGB')
            img = compose(shot, head, sub)
            assert img.size == shot.size
            p = out / f'{i:02d}_{name}.png'
            img.save(p)
            print('ok', p.relative_to(HERE), img.size)


if __name__ == '__main__':
    main()
