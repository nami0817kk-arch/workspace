import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

W, H = 1280, 720
src = Image.open('out/story/kiyomori-fukuhara-if/T02_portrait.jpg').convert('RGB')
# 背景：文字側（左）に海・空が来るよう、そのまま。少し明るく彩度を上げる
bg = src.resize((W, H), Image.LANCZOS)
bg = ImageEnhance.Color(bg).enhance(1.12)
bg = ImageEnhance.Brightness(bg).enhance(1.05)

# 左上だけ薄く暗く（文字の読みやすさ。明るさは保つ）
shade = Image.new('L', (W, H), 0)
sd = ImageDraw.Draw(shade)
for x in range(W):
    a = max(0, int(14 * (1 - x / (W * 0.75))))
    sd.line([(x, 0), (x, H)], fill=a)
vert = Image.new('L', (W, H), 0)
vd = ImageDraw.Draw(vert)
for y in range(H):
    a = max(0, int(10 * (1 - y / (H * 0.7))))
    vd.line([(0, y), (W, y)], fill=a)
from PIL import ImageChops
shade = ImageChops.add(shade, vert)
black = Image.new('RGB', (W, H), (10, 12, 25))
bg = Image.composite(black, bg, shade)

FONT = 'C:/Windows/Fonts/NotoSansJP-VF.ttf'


def font(size, wght=900):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([wght])
    except Exception:
        pass
    return f


RED = (232, 28, 36)
WHITE = (255, 255, 255)
YEL = (255, 214, 64)
INK = (14, 14, 34)

canvas = bg.convert('RGBA')
shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
text = Image.new('RGBA', (W, H), (0, 0, 0, 0))
sdraw = ImageDraw.Draw(shadow)
tdraw = ImageDraw.Draw(text)


def put(x, y, s, size, fill, stroke):
    f = font(size)
    # 影（同じ向き・同じ量）
    sdraw.text((x + 7, y + 9), s, font=f, fill=(0, 0, 0, 200), stroke_width=stroke, stroke_fill=(0, 0, 0, 200))
    tdraw.text((x, y), s, font=f, fill=fill + (255,), stroke_width=stroke, stroke_fill=INK + (255,))
    return x + f.getlength(s)


X = 58            # 左端そろえ
STROKE = 9
# 行の高さ（行間一定）
y1 = 36
put(X, y1, '日本の都は、神戸になっていた？', 62, WHITE, 6)
y2 = y1 + 62 + 34
x = put(X, y2, 'もしも', 168, RED, STROKE)
put(x + 6, y2, '清盛', 168, WHITE, STROKE)
y3 = y2 + 168 + 38
put(X, y3, '福原遷都が成功？', 112, YEL, STROKE)

shadow = shadow.filter(ImageFilter.GaussianBlur(5))
canvas = Image.alpha_composite(canvas, shadow)
canvas = Image.alpha_composite(canvas, text)
out = canvas.convert('RGB')
out.save('out/kiyomori-fukuhara-if-story_thumbnail.png')
out.resize((320, 180), Image.LANCZOS).save('out/kiyomori-fukuhara-if-story_thumbnail_preview.png')
print('ok')
