"""立ち絵に黄色い工事用ヘルメットをかぶせる（「地層を掘る」二人の目印）。

アニメ塗りの工事用ヘルメット（正面やや上から）を4倍で描いて縮める。絵は自作の図形。
立ち絵の規約（つむぎ：加筆・加工可、剣崎雌雄：二次創作に制限なし）の範囲で重ねる。

形：丸いドーム＋細い縁＋前に出たつば。塗り：地の黄・右側の三日月の影・左上の光沢・細い茶色の線。
"""
from PIL import Image, ImageChops, ImageDraw, ImageFilter

BASE = (250, 200, 40)
SHADE = (222, 160, 24)
DEEP = (170, 110, 16)
LIGHT = (255, 244, 178)
LINE = (78, 48, 22)


def _m(size, fn):
    m = Image.new("L", size, 0)
    fn(ImageDraw.Draw(m))
    return m


def _fill(im, color, mask):
    im.paste(color + (255,), mask=mask)


def helmet(w=700, ss=4):
    W = w * ss
    H = int(W * 0.62)
    S = (W, H)
    lw = max(2, int(W * 0.011))
    thin = max(1, lw * 2 // 3)
    cx = W // 2

    dome = [int(W * 0.14), int(H * 0.04), int(W * 0.86), int(H * 1.36)]   # 上半分が見える
    base_y = int(H * 0.70)
    rim = [int(W * 0.10), int(H * 0.60), int(W * 0.90), int(H * 0.80)]   # 縁（細い輪）
    visor = [int(W * 0.21), int(H * 0.52), int(W * 0.79), int(H * 0.98)]  # 前つば

    dome_m = _m(S, lambda d: (d.pieslice(dome, 180, 360, fill=255), d.rectangle([0, base_y, W, H], fill=0)))
    rim_front = ImageChops.multiply(_m(S, lambda d: d.ellipse(rim, fill=255)),
                                    _m(S, lambda d: d.rectangle([0, int(H * 0.68), W, H], fill=255)))
    visor_m = _m(S, lambda d: d.chord(visor, 0, 180, fill=255))
    im = Image.new("RGBA", S, (0, 0, 0, 0))

    # 1. ドーム
    layer = Image.new("RGBA", S, BASE + (255,))
    crescent = ImageChops.subtract(dome_m, _m(S, lambda d: d.ellipse(
        [dome[0] - int(W * 0.10), dome[1] - int(H * 0.02), dome[2] - int(W * 0.13), dome[3] + int(H * 0.05)], fill=255)))
    _fill(layer, SHADE, crescent)
    _fill(layer, SHADE, _m(S, lambda d: d.rectangle([0, int(H * 0.62), W, base_y], fill=255)))
    gloss = _m(S, lambda d: d.arc([dome[0] + int(W * 0.07), dome[1] + int(H * 0.08), dome[2] - int(W * 0.20), dome[3]],
                                   195, 250, fill=255, width=int(W * 0.035)))
    _fill(layer, LIGHT, gloss.filter(ImageFilter.GaussianBlur(W * 0.002)))
    _fill(layer, LIGHT, _m(S, lambda d: d.ellipse([int(W * 0.235), int(H * 0.40), int(W * 0.265), int(H * 0.45)], fill=255)))
    ridge = [cx - int(W * 0.045), dome[1] + int(H * 0.005), cx + int(W * 0.045), base_y]
    ridge_m = ImageChops.multiply(_m(S, lambda d: d.rounded_rectangle(ridge, radius=int(W * 0.04), fill=255)), dome_m)
    _fill(layer, SHADE, ridge_m)
    _fill(layer, LIGHT, ImageChops.multiply(ridge_m, _m(S, lambda d: d.rectangle(
        [ridge[0], 0, ridge[0] + int(W * 0.016), H], fill=255))))
    im.paste(layer, mask=dome_m)
    d = ImageDraw.Draw(im)
    d.arc(dome, 180, 360, fill=LINE, width=lw)
    d.line([(ridge[0], ridge[1] + int(W * 0.04)), (ridge[0], base_y)], fill=LINE, width=thin)
    d.line([(ridge[2], ridge[1] + int(W * 0.04)), (ridge[2], base_y)], fill=LINE, width=thin)
    d.arc([ridge[0], ridge[1], ridge[2], ridge[1] + int(W * 0.08)], 180, 360, fill=LINE, width=thin)

    # 2. 前つば（上面は地の色、手前の厚みは深い影）
    v_layer = Image.new("RGBA", S, DEEP + (255,))
    _fill(v_layer, BASE, _m(S, lambda d: d.chord([visor[0], visor[1], visor[2], visor[3] - int(H * 0.07)], 0, 180, fill=255)))
    _fill(v_layer, LIGHT, _m(S, lambda d: d.arc(
        [visor[0] + int(W * 0.06), visor[1] + int(H * 0.02), visor[2] - int(W * 0.25), visor[3] - int(H * 0.10)],
        100, 150, fill=255, width=int(H * 0.025))))
    im.paste(v_layer, mask=visor_m)
    d = ImageDraw.Draw(im)
    d.chord(visor, 0, 180, outline=LINE, width=lw)

    # 3. 縁（手前の半分）。つばの付け根を隠す
    rim_layer = Image.new("RGBA", S, SHADE + (255,))
    _fill(rim_layer, BASE, _m(S, lambda d: d.ellipse([rim[0], rim[1], rim[2], rim[3] - int(H * 0.05)], fill=255)))
    im.paste(rim_layer, mask=rim_front)
    d = ImageDraw.Draw(im)
    d.arc(rim, 0, 180, fill=LINE, width=lw)
    d.arc(rim, 160, 180, fill=LINE, width=lw)
    d.arc(rim, 0, 20, fill=LINE, width=lw)
    return im.resize((w, int(w * 0.62)), Image.LANCZOS)


def put(base_fn, out_fn, cx, rim_y, w, angle, keep=None, pad=200):
    """立ち絵にヘルメットをかぶせる。

    座標は余白を切った立ち絵の上で測る。(cx, rim_y) はヘルメットの縁（ドームの下端）の中央が来る点で、
    そこを中心に angle 度傾ける（正の値で反時計回り＝画面の右が上がる。頭の傾きは目の高さの差で測る）。
    keep=((x0, y0, x1, y1), しきい値) を渡すと、その範囲の暗い画素（リボンなど）を
    ヘルメットの上に戻す。ヘルメットが頭の上にはみ出すので、上に pad の余白を足してから重ねる。
    """
    from PIL import ImageChops, ImageFilter  # noqa: F401
    b = Image.open(base_fn).convert("RGBA")
    b = b.crop(b.getbbox())
    canvas = Image.new("RGBA", (b.width, b.height + pad), (0, 0, 0, 0))
    canvas.alpha_composite(b, (0, pad))
    h = helmet(w)
    hh = h.height
    pivot_y = int(hh * 0.70)                      # 縁の高さ（helmet() の base_y と同じ）
    big = Image.new("RGBA", (w * 2, hh * 2), (0, 0, 0, 0))
    big.alpha_composite(h, (w // 2, hh - pivot_y))
    big = big.rotate(angle, resample=Image.BICUBIC, center=(w, hh))
    canvas.alpha_composite(big, (int(cx - w), int(rim_y + pad - hh)))
    if keep:
        (x0, y0, x1, y1), threshold = keep
        src = b.crop((x0, y0, x1, y1))
        mask = Image.eval(src.convert("L"), lambda v: 255 if v < threshold else 0)
        mask = ImageChops.multiply(mask, src.split()[3])
        canvas.paste(src, (x0, y0 + pad), mask)
    canvas.crop(canvas.getbbox()).save(out_fn)


# 公式の立ち絵（余白を切った状態）でのヘルメットの位置（cx, 縁の高さ, 幅, 傾き, 上に戻す部分）。
# 絵を差し替えたら測り直す。目の高さの差から傾きを測り、つばが眉の上に来る高さにする。
PLACEMENTS = {
    # 春日部つむぎ公式立ち絵 v2.0。頭は右が上がる向きに約6度。右側のリボンはヘルメットの外に戻す
    "tsumugi": (1115, 300, 760, 6, ((1335, 95, 1470, 310), 60)),
    # 剣崎雌雄 公式イラスト（VOICEVOX 掲載の全身図）。とがった頭の先がヘルメットを突き抜ける
    "kenzaki": (322, 118, 230, -14, None),
}
