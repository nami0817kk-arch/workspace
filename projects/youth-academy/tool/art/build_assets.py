"""art/ の原本（Gemini で作ったシート）から、ゲームに埋め込む素材を切り出す。

  python tool/art/build_assets.py

出力:
  web/src/imgdata.js  … YA.IMG = { faces:[JPEG の data URI ...], emblems:[PNG の data URI ...], title:'...' }
  art/out/            … 切り出した個別画像（目で確かめる用。コミットしない）
"""
import base64
import io
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, 'art')
OUT = os.path.join(ART, 'out')
os.makedirs(os.path.join(OUT, 'faces'), exist_ok=True)
os.makedirs(os.path.join(OUT, 'emblems'), exist_ok=True)

FACE_PX = 112
EMB_PX = 88


def uri(im, fmt, **kw):
    b = io.BytesIO()
    im.save(b, fmt, **kw)
    return 'data:image/%s;base64,' % ('jpeg' if fmt == 'JPEG' else 'png') + base64.b64encode(b.getvalue()).decode()


def square(im, box):
    """cell の枠 box から、中央・上寄せの正方形を取る"""
    x0, y0, x1, y1 = box
    s = min(x1 - x0, y1 - y0)
    cx = (x0 + x1) // 2
    return im.crop((cx - s // 2, y0, cx - s // 2 + s, y0 + s))


def runs(profile, thr):
    """profile が thr を超える連続区間 [(start,end)]"""
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


def face_cells_auto(im):
    """白い余白で区切られた格子を自動で見つける（シート2）"""
    a = np.asarray(im.convert('RGB')).astype(int)
    notwhite = (a.min(axis=2) < 235)
    cols = runs(notwhite.mean(axis=0), 0.5)
    rows = runs(notwhite.mean(axis=1), 0.5)
    return [(c0, r0, c1, r1) for r0, r1 in rows for c0, c1 in cols if (c1 - c0) > 100 and (r1 - r0) > 100]


# シート1（行の区切りが不揃い）：頭が切れていないマスだけ、目で選んだ枠
SHEET1 = (
    [(8, 5, 230, 228), (242, 5, 465, 228), (476, 5, 698, 228), (710, 5, 932, 228), (943, 5, 1165, 228), (1178, 5, 1400, 228)]
    + [(x0, 238, x1, 440) for x0, x1 in [(8, 230), (242, 465), (476, 698), (710, 932), (943, 1165)]]
    + [(x0, 583, x1, 765) for x0, x1 in [(8, 230), (242, 465), (476, 698), (710, 932), (943, 1165), (1178, 1400)]]
)


# シートごとに使うマス（行順の番号）。None なら全部。
# 3枚目は同じ顔が4色の服で並ぶので上の2行だけ、4枚目は表情の強すぎるもの（泣く・叫ぶ・怒る等）を外す
FACE_SHEETS = [
    ('faces_sheet1.png', SHEET1, None),
    ('faces_sheet2.png', None, None),
    ('faces_sheet3.png', None, list(range(14))),
    ('faces_sheet4.png', None, [0, 5, 8, 11, 12, 13, 14, 15, 16, 19, 20, 21, 22, 25, 27]),
]


def faces():
    out = []
    for name, boxes, keep in FACE_SHEETS:
        im = Image.open(os.path.join(ART, name)).convert('RGB')
        bx = boxes if boxes is not None else face_cells_auto(im)
        if keep is not None:
            bx = [bx[i] for i in keep if i < len(bx)]
        print(name, len(bx), 'cells')
        for i, b in enumerate(bx):
            f = square(im, b).resize((FACE_PX, FACE_PX), Image.LANCZOS)
            f.save(os.path.join(OUT, 'faces', '%s_%02d.jpg' % (name[:12], i)), quality=88)
            out.append(uri(f, 'JPEG', quality=80, optimize=True))
    return out


def emblem_from(cell, bgtol=28):
    """cell（RGB）の外側につながる背景色を透明にして、中身にぴったり切る"""
    a = np.asarray(cell.convert('RGB')).astype(int)
    h, w, _ = a.shape
    # 四隅の色を背景とみなし、そこに近く外とつながっている所を透明にする
    bg = np.median(np.concatenate([a[:4, :4].reshape(-1, 3), a[:4, -4:].reshape(-1, 3), a[-4:, :4].reshape(-1, 3), a[-4:, -4:].reshape(-1, 3)]), axis=0)
    near = (np.abs(a - bg).max(axis=2) < bgtol)
    lab, _ = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgmask = np.isin(lab, list(edge))
    alpha = np.where(bgmask, 0, 255).astype(np.uint8)
    alpha = ndimage.binary_opening(alpha > 0, iterations=1).astype(np.uint8) * 255
    rgba = np.dstack([a.astype(np.uint8), alpha])
    ys, xs = np.where(alpha > 0)
    if len(ys) == 0:
        return None
    im = Image.fromarray(rgba, 'RGBA').crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    s = max(im.size)
    sq = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    sq.paste(im, ((s - im.size[0]) // 2, (s - im.size[1]) // 2))
    return sq.resize((EMB_PX, EMB_PX), Image.LANCZOS)


def emblem_cells(im, rows=3, cols=5):
    """等間隔の格子（シート全体を rows×cols に割る）"""
    w, h = im.size
    # 余白を落とす：白でない範囲の外接枠
    a = np.asarray(im.convert('RGB')).astype(int)
    nw = a.min(axis=2) < 235
    ys, xs = np.where(nw)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cw, ch = (x1 - x0) / cols, (y1 - y0) / rows
    pad = 6
    return [(int(x0 + c * cw) + pad, int(y0 + r * ch) + pad, int(x0 + (c + 1) * cw) - pad, int(y0 + (r + 1) * ch) - pad) for r in range(rows) for c in range(cols)]


def emblem_boxes_white(im, dil=5, min_area=2500):
    """白い背景のシートから、エンブレムごとの外接枠を連結成分で見つける（並びが不揃いでも切れる）"""
    a = np.asarray(im.convert('RGB')).astype(int)
    fg = a.min(axis=2) < 235
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=dil))
    boxes = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        ys, xs = sl
        if (lab[sl] == i).sum() < min_area:
            continue
        pad = dil + 2
        boxes.append((max(0, xs.start - pad), max(0, ys.start - pad), min(a.shape[1], xs.stop + pad), min(a.shape[0], ys.stop + pad)))
    boxes.sort(key=lambda b: (round(((b[1] + b[3]) / 2) / 160), b[0]))
    return boxes


def emblems():
    out = []
    for n in (1, 2, 3, 4):
        im = Image.open(os.path.join(ART, 'emblems_sheet%d.png' % n)).convert('RGB')
        if n == 4:
            cells = emblem_cells(im)
            cells = [(x0 + 10, y0 + 10, x1 - 10, y1 - 10) for x0, y0, x1, y1 in cells]
            tol = 45
        else:
            cells = emblem_boxes_white(im)
            tol = 28
        print('sheet', n, len(cells))
        for i, b in enumerate(cells):
            e = emblem_from(im.crop(b), tol)
            if e is None:
                print('skip', n, i)
                continue
            e.save(os.path.join(OUT, 'emblems', 's%d_%02d.png' % (n, i)))
            out.append(uri(e.quantize(colors=56, method=Image.Quantize.FASTOCTREE), 'PNG', optimize=True))
    return out


def title():
    im = Image.open(os.path.join(ART, 'title_bg_v1.png')).convert('RGB')
    im = im.resize((960, 536), Image.LANCZOS)
    return uri(im, 'JPEG', quality=72, optimize=True)


if __name__ == '__main__':
    fa, em, ti = faces(), emblems(), title()
    js = '// 自動生成：tool/art/build_assets.py（art/ の原本から）。手で直さない\n(function () {\n  const YA = (globalThis.YA = globalThis.YA || {});\n  YA.IMG = ' + json.dumps({'faces': fa, 'emblems': em, 'title': ti}, ensure_ascii=False) + ';\n})();\n'
    open(os.path.join(ROOT, 'web', 'src', 'imgdata.js'), 'w', encoding='utf8').write(js)
    print('faces', len(fa), 'emblems', len(em), 'js KB', len(js) // 1024)
