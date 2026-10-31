"""顔パーツ（輪郭・髪・目と眉・鼻と口）を art/parts_*.png から切り出し、組み合わせの見本を作る。

  python tool/art/parts.py            … art/out/parts/ に個別のパーツと、組み合わせ見本 art/out/_combo.png を作る

build_assets.py がこのモジュールの extract() を使って imgdata.js に埋め込む。
"""
import os
import random

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, 'art')
OUT = os.path.join(ART, 'out', 'parts')

HEAD_BAD = {12, 13}  # 三角形・ハート形の輪郭は使わない
EYES_BAD = {19}  # 驚きすぎた目
MOUTH_BAD = {7, 17}  # 丸く開いた口（変な顔になる）


def load(name):
    return Image.open(os.path.join(ART, name)).convert('RGB')


def content_box(im, thr=235):
    a = np.asarray(im).astype(int)
    ys, xs = np.where(a.min(axis=2) < thr)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def grid(im, cols, rows):
    x0, y0, x1, y1 = content_box(im)
    cw, ch = (x1 - x0) / cols, (y1 - y0) / rows
    return [(int(x0 + c * cw), int(y0 + r * ch), int(x0 + (c + 1) * cw), int(y0 + (r + 1) * ch)) for r in range(rows) for c in range(cols)]


def cut_white(cell, thr=232):
    """白い背景のパーツを透過にして、中身にぴったり切る（外とつながる白だけを抜く）"""
    a = np.asarray(cell).astype(int)
    white = a.min(axis=2) >= thr
    lab, _ = ndimage.label(white)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    # 縁を少しなめらかに
    alpha = (ndimage.gaussian_filter(alpha.astype(float), 0.7)).astype(np.uint8)
    rgba = np.dstack([a.astype(np.uint8), alpha])
    ys, xs = np.where(alpha > 40)
    if len(ys) == 0:
        return None
    return Image.fromarray(rgba, 'RGBA').crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def heads():
    """輪郭：15マスのうち使えるもの。灰色の背景ごと切り、頭の位置（肌の外接枠）を測る"""
    im = load('parts_base_heads.png')
    a = np.asarray(im).astype(int)
    nw = a.min(axis=2) < 235
    cols = _runs(nw.mean(axis=0), 0.5)
    rows = _runs(nw.mean(axis=1), 0.5)
    cells = [(c0, r0, c1, r1) for r0, r1 in rows for c0, c1 in cols]
    out = []
    for i, (x0, y0, x1, y1) in enumerate(cells):
        if i in HEAD_BAD:
            continue
        cell = im.crop((x0, y0, x1, y1))
        s = min(cell.size)
        cx = cell.size[0] // 2
        sq = cell.crop((cx - s // 2, 0, cx - s // 2 + s, s))
        out.append((sq, skin_box(sq)))
    return out


def _runs(profile, thr):
    on = profile > thr
    res, st = [], None
    for i, v in enumerate(on):
        if v and st is None:
            st = i
        if not v and st is not None:
            res.append((st, i))
            st = None
    if st is not None:
        res.append((st, len(on)))
    return res


def skin_box(sq):
    """頭の肌の外接枠 (x0, y0, x1, y1)。肩（青い服）は除く"""
    a = np.asarray(sq).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    skin = (r > g + 8) & (g > b + 4) & (r > 90)
    h = a.shape[0]
    skin[int(h * 0.82):] = False
    lab, n = ndimage.label(skin)
    if n == 0:
        return (0, 0, a.shape[1], a.shape[0])
    sizes = ndimage.sum(skin, lab, range(1, n + 1))
    k = 1 + int(np.argmax(sizes))
    ys, xs = np.where(lab == k)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def parts(name, cols, rows):
    im = load(name)
    out = []
    for b in grid(im, cols, rows):
        p = cut_white(im.crop(b))
        if p is not None and p.size[0] > 8 and p.size[1] > 8:
            out.append(p)
    return out


def extract():
    eyes = [p for i, p in enumerate(parts('parts_eyes.png', 4, 5)) if i not in EYES_BAD]
    mouths = [p for i, p in enumerate(parts('parts_mouths.png', 5, 4)) if i not in MOUTH_BAD]
    return {'heads': heads(), 'hair': parts('parts_hair.png', 5, 5), 'eyes': eyes, 'mouths': mouths}


# 組み立ての位置決め（頭の肌の外接枠 box に対する比率）。JS 側（art.js）も同じ式
LAY = {
    'hair_w': 1.12,   # 髪の幅 / 頭の幅
    'hair_top': -0.12,  # 髪の上端 = 頭の上端 + この比率 × 頭の高さ
    'eyes_w': 0.80,   # 目と眉の幅 / 頭の幅
    'eyes_cy': 0.50,  # 目の中心 y = 頭の上端 + 比率 × 頭の高さ
    'mouth_w': 0.34,
    'mouth_cy': 0.74,   # 鼻と口の中心 y
}


def compose(head, parts_, size=112):
    sq, box = head
    base = sq.convert('RGBA')
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    cx = (x0 + x1) / 2

    def put(p, width, left_cx, top=None, cy=None):
        s = width / p.size[0]
        q = p.resize((max(1, int(p.size[0] * s)), max(1, int(p.size[1] * s))), Image.LANCZOS)
        ty = int(top) if top is not None else int(cy - q.size[1] / 2)
        base.alpha_composite(q, (int(left_cx - q.size[0] / 2), ty)) if (ty >= 0 and int(left_cx - q.size[0] / 2) >= 0) else base.paste(q, (int(left_cx - q.size[0] / 2), ty), q)

    hair, eyes, mouth = parts_
    put(eyes, w * LAY['eyes_w'], cx, cy=y0 + h * LAY['eyes_cy'])
    put(mouth, w * LAY['mouth_w'], cx, cy=y0 + h * LAY['mouth_cy'])
    put(hair, w * LAY['hair_w'], cx, top=y0 + h * LAY['hair_top'])
    return base.convert('RGB').resize((size, size), Image.LANCZOS)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    P = extract()
    print({k: len(v) for k, v in P.items()})
    rnd = random.Random(5)
    cols, rows, cell = 10, 4, 112
    sheet = Image.new('RGB', (cols * cell, rows * cell), 'white')
    for i in range(cols * rows):
        hd = rnd.choice(P['heads'])
        face = compose(hd, (rnd.choice(P['hair']), rnd.choice(P['eyes']), rnd.choice(P['mouths'])), cell)
        sheet.paste(face, ((i % cols) * cell, (i // cols) * cell))
    sheet.save(os.path.join(ART, 'out', '_combo.png'))
    print('ok')
