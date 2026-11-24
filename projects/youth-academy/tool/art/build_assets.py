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

import random

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


# 2026-11-24 作り直し：選んでもらった1枚を見本に Gemini で作った 24人×13枚（同じ絵柄・同じマス目）。
# 「ブルーロック・アオアシ・DAYS のようなキャラを参考に」は、個性の強さだけを借りて、どの作品の登場人物にも似せない指示で作った。
# 同じ日に「三百は欲しい」「反転はなし」で 5枚→13枚（6〜13枚目は 一年生・三年生・前線・司令塔と守備・GK と CB・ムードメーカー・海外にルーツ・地方と都会）。
# シートごとに使うマス（行順の番号）。None なら全部。外したもの：女の子に見える顔（4-06・5-01・5-12・6-07・6-18・9-01・12-18）、
# マウスの矢印が写ったマス（1-21）、3枚目の坊主のよく似た顔（3-10・3-11・3-18・3-22）
FACE_SHEETS = [
    ('faces_sheet1.png', None, [i for i in range(24) if i != 21]),
    ('faces_sheet2.png', None, None),
    ('faces_sheet3.png', None, [i for i in range(24) if i not in (10, 11, 18, 22)]),
    ('faces_sheet4.png', None, [i for i in range(24) if i != 6]),
    ('faces_sheet5.png', None, [i for i in range(24) if i not in (1, 12)]),
    ('faces_sheet6.png', None, [i for i in range(24) if i not in (7, 18)]),
    ('faces_sheet7.png', None, None),
    ('faces_sheet8.png', None, None),
    ('faces_sheet9.png', None, [i for i in range(24) if i != 1]),
    ('faces_sheet10.png', None, None),
    ('faces_sheet11.png', None, None),
    ('faces_sheet12.png', None, [i for i in range(24) if i != 18]),
    ('faces_sheet13.png', None, None),
    # 14・15枚目：同じ日に「金髪、赤髪、白髪とかもいいね」「ブルーロックのキャラとかの個性参考に」。別の Google アカウントの Gemini で、
    # 見本の1人と2枚目のシートを渡して同じ絵柄で作った派手な髪色。左右で白と赤に分かれた髪（14-18）は既存の作品の登場人物を思わせるので外し、
    # 14枚目とほぼ同じ顔（15-01・15-02）と、髪に網の模様が出たもの（15-09）も外した
    ('faces_sheet14.png', None, [i for i in range(24) if i != 18]),
    ('faces_sheet15.png', None, [i for i in range(24) if i not in (1, 2, 9)]),
    # 16・17枚目：同じ日に「個性的な見た目も増やして」。そばかす・ほくろ・絆創膏・眉の切り込み・八重歯・瞳の色・バンダナ・一房だけ色の違う前髪など。
    # 外したもの：髪に網の模様（16-05）、とがった耳（16-13）、肩までの長い髪で女の子に見える顔（17-04）
    ('faces_sheet16.png', None, [i for i in range(24) if i not in (5, 13)]),
    ('faces_sheet17.png', None, [i for i in range(24) if i != 4]),
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
            f.save(os.path.join(OUT, 'faces', '%s_%02d.jpg' % (name[:-4], i)), quality=88)
            out.append(uri(f, 'JPEG', quality=80, optimize=True))
    return out


COMPOSITES = 0  # パーツ組み合わせの顔は見た目が良くないので、いまはゲームに入れない（素材と組み立ては残してある）
COMPOSITE_PX = 80


def composites():
    """輪郭・髪・目と眉・鼻と口のパーツを組み合わせた顔（同じ組み合わせは作らない）"""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import parts as PT
    P = PT.extract()
    print('parts', {k: len(v) for k, v in P.items()})
    rnd = random.Random(20261031)
    seen, out = set(), []
    while COMPOSITES and len(out) < COMPOSITES:
        k = (rnd.randrange(len(P['heads'])), rnd.randrange(len(P['hair'])), rnd.randrange(len(P['eyes'])), rnd.randrange(len(P['mouths'])))
        if k in seen:
            continue
        seen.add(k)
        f = PT.compose(P['heads'][k[0]], (P['hair'][k[1]], P['eyes'][k[2]], P['mouths'][k[3]]), COMPOSITE_PX)
        if len(out) < 40:
            f.save(os.path.join(OUT, 'faces', 'combo_%02d.jpg' % len(out)), quality=88)
        out.append(uri(f, 'JPEG', quality=72, optimize=True))
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
    fa, em, ti = faces() + composites(), emblems(), title()
    js = '// 自動生成：tool/art/build_assets.py（art/ の原本から）。手で直さない\n(function () {\n  const YA = (globalThis.YA = globalThis.YA || {});\n  YA.IMG = ' + json.dumps({'faces': fa, 'emblems': em, 'title': ti}, ensure_ascii=False) + ';\n})();\n'
    open(os.path.join(ROOT, 'web', 'src', 'imgdata.js'), 'w', encoding='utf8').write(js)
    print('faces', len(fa), 'emblems', len(em), 'js KB', len(js) // 1024)
