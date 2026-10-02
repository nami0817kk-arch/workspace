"""写真の顔の位置を機械で見る（2026-10-03）。

**なぜ要るか。**冒頭やショートで顔・頭のてっぺんが切れる指摘を何度も受けた
（09-25「子供が主役になってる」、09-29「本編の顔がキレてる」）。表・反応の白い箱・
テロップの帯が顔にかかる指摘もある（10-03 久保の結婚のショートで、最後に反応の箱が顎にかかった）。
それまでは人が `_w.jpg`（16:9）・`_v.jpg`（9:16）を手で切り、`tools/frames.py` の4コマを目で見ていた。

ここでは OpenCV の Haar cascade（正面＋横顔）で顔の枠を取り、

- `find_faces` … 顔の枠（大きい順）
- `head_box` … 顔の枠から、頭のてっぺん〜顎の下までの推定の枠
- `crop_box` / `crop_around` … 頭が切れない位置で、指定の縦横比に切る
- `head_cut` … 頭の推定の枠が画像の端からはみ出していれば True
- `overlay_on_face` … 顔の上に文字の板（白い箱・濃い板）が重なっていそうか

を出す。**OpenCV が入っていない環境（CI）では import で落ちない。**
`available()` が False になり、`find_faces` は空を返す（「検出できない」）。
OpenCV は 4.x を使う（5.0 から Haar cascade の xml が同梱されなくなった）。

**顔の検出は当てにならないことがある**（横顔・帽子・手で顔が隠れた写真は取れない）。
「見つからない」は「顔が無い」ではない。最後は人が絵を見る決まり（frames.py）は変えない。
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from PIL import Image

try:  # OpenCV は任意の依存。無ければ「検出できない」で返す
    import cv2  # type: ignore
    import numpy as np  # type: ignore
except ImportError:  # pragma: no cover - CI では入っていないことがある
    cv2 = None
    np = None

Box = tuple[int, int, int, int]  # (x, y, w, h)

# 大きい写真はこの幅まで縮めてから見る（3000px の写真をそのまま回すと数秒かかる）
DETECT_WIDTH = 960
# 顔の最小の大きさ（画像の短い辺に対する割合）。小さすぎると服の模様や文字を顔と取る
MIN_FACE = 0.06
# 頭の推定：顔の枠（眉〜口）から、上に髪のぶん・下に顎のぶん・左右に耳のぶんを足す
HEAD_UP = 0.5
HEAD_DOWN = 0.2
HEAD_SIDE = 0.12
# 切るとき、頭のてっぺんの上に残す余白（切り出しの高さに対する割合）
TOP_MARGIN = 0.04


def available() -> bool:
    """顔の検出が使えるか（OpenCV が入っているか）。"""
    return cv2 is not None


_CASCADES: dict[str, Any] = {}


def _cascade(name: str):
    if name not in _CASCADES:
        path = Path(cv2.data.haarcascades) / name
        if not path.exists():
            raise RuntimeError(f"顔の検出器がありません: {path}（OpenCV 4.x が要る。5.0 には同梱されない）")
        # **OpenCV はパスに日本語があると開けない**（C:/Users/なみ/...）。中身を読んでメモリから渡す
        storage = cv2.FileStorage(path.read_text(encoding="utf-8"),
                                  cv2.FILE_STORAGE_READ | cv2.FILE_STORAGE_MEMORY)
        clf = cv2.CascadeClassifier()
        if not clf.read(storage.getFirstTopLevelNode()) or clf.empty():
            raise RuntimeError(f"顔の検出器が読めません: {path}")
        _CASCADES[name] = clf
    return _CASCADES[name]


def _to_rgb(src) -> "np.ndarray":
    """パス・PIL・numpy（RGB）のどれでも、RGB の numpy 配列にする。"""
    if isinstance(src, (str, Path)):
        with Image.open(src) as opened:
            return np.asarray(opened.convert("RGB"))
    if isinstance(src, Image.Image):
        return np.asarray(src.convert("RGB"))
    arr = np.asarray(src)
    if arr.ndim == 2:
        return np.stack([arr] * 3, axis=-1)
    return arr[..., :3]


def _iou(a: Box, b: Box) -> float:
    ax2, ay2, bx2, by2 = a[0] + a[2], a[1] + a[3], b[0] + b[2], b[1] + b[3]
    iw = max(0, min(ax2, bx2) - max(a[0], b[0]))
    ih = max(0, min(ay2, by2) - max(a[1], b[1]))
    inter = iw * ih
    if not inter:
        return 0.0
    small = min(a[2] * a[3], b[2] * b[3])
    # 片方がもう片方にほぼ入っているときも同じ顔とみなす（正面と横顔で枠の大きさが違う）
    return max(inter / (a[2] * a[3] + b[2] * b[3] - inter), inter / small if small else 0.0)


def _merge(boxes: list[tuple[Box, int]]) -> list[Box]:
    """重なった枠を1つにまとめる。票（検出器の数）の多いもの、次に大きいものを残す。"""
    boxes = sorted(boxes, key=lambda b: (-b[1], -b[0][2] * b[0][3]))
    kept: list[Box] = []
    for box, _ in boxes:
        if all(_iou(box, k) < 0.4 for k in kept):
            kept.append(box)
    return kept


def find_faces(src, min_face: float = MIN_FACE, neighbors: int = 6) -> list[Box]:
    """顔の枠 (x, y, w, h) を大きい順に返す。OpenCV が無ければ空。

    正面（alt2）と横顔（左右）の Haar cascade を使う。`frontalface_default` は
    文字や服の模様を顔と取りやすいので使わない（久保のショートの反応の箱で拾った）。
    """
    if not available():
        return []
    rgb = _to_rgb(src)
    h, w = rgb.shape[:2]
    scale = min(1.0, DETECT_WIDTH / max(w, h))
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    if scale < 1.0:
        gray = cv2.resize(gray, (round(w * scale), round(h * scale)), interpolation=cv2.INTER_AREA)
    gray = cv2.equalizeHist(gray)
    gh, gw = gray.shape[:2]
    side = max(20, int(min(gh, gw) * min_face))
    found: list[tuple[Box, int]] = []

    def run(name: str, image, flip: bool = False) -> None:
        hits = _cascade(name).detectMultiScale(image, scaleFactor=1.1, minNeighbors=neighbors,
                                               minSize=(side, side))
        for (x, y, bw, bh) in hits:
            if flip:
                x = gw - x - bw
            found.append(((int(x), int(y), int(bw), int(bh)), 2 if "frontal" in name else 1))

    run("haarcascade_frontalface_alt2.xml", gray)
    run("haarcascade_profileface.xml", gray)
    run("haarcascade_profileface.xml", cv2.flip(gray, 1), flip=True)
    boxes = _merge(found)
    out = [(round(x / scale), round(y / scale), round(bw / scale), round(bh / scale))
           for (x, y, bw, bh) in boxes]
    out = [b for b in out if not _on_plate(rgb, b) and _skin_ok(rgb, b)]
    return sorted(out, key=lambda b: -b[2] * b[3])


def main_face(src, **kw) -> Box | None:
    """いちばん大きい顔。見つからなければ None。"""
    faces = find_faces(src, **kw)
    return faces[0] if faces else None


def head_box(face: Box) -> Box:
    """顔の枠から、頭のてっぺん〜顎の下までの推定の枠（画像の外にはみ出してよい）。

    Haar の枠は眉の上〜口の下くらいなので、上に髪のぶん（高さ×0.5）、
    下に顎のぶん（×0.2）、左右に耳のぶん（×0.12）を足す。
    """
    x, y, w, h = face
    return (round(x - w * HEAD_SIDE), round(y - h * HEAD_UP),
            round(w * (1 + 2 * HEAD_SIDE)), round(h * (1 + HEAD_UP + HEAD_DOWN)))


def _size(image) -> tuple[int, int]:
    if isinstance(image, Image.Image):
        return image.size
    if isinstance(image, (str, Path)):
        with Image.open(image) as opened:
            return opened.size
    if isinstance(image, tuple):
        return image  # (w, h)
    arr = np.asarray(image)
    return arr.shape[1], arr.shape[0]


def crop_box(size: tuple[int, int], aspect: float, box: Box | None, *,
             top: float | None = None, center: float | None = None,
             third: float = 1 / 3, margin: float = TOP_MARGIN,
             zoom: float = 1.0) -> tuple[int, int, int, int]:
    """切り出す範囲 (left, top, right, bottom) を返す。

    - `aspect` は幅÷高さ（16:9 なら 16/9、9:16 なら 9/16）
    - 切り出しは、その縦横比で取れるいちばん大きい範囲（`zoom` > 1 で狭める）
    - 左右は顔の真ん中を切り出しの真ん中へ。上下は顔の真ん中を上から `third` の位置へ
      置き、そのうえで**頭のてっぺんの上に `margin` の余白が残るまで下げる**
    - `top`（切り出しの上端、画像の高さに対する割合）・`center`（顔の左右の位置、
      画像の幅に対する割合）を渡すと、顔の位置より優先する（手で直すとき）
    - 顔が無い（box=None）ときは、左右は真ん中、上下は上から 8%（widecrop と同じ既定）
    - 頭が入りきらないとき（顔のアップ）は、顔の枠（顎まで）を入れて、上の髪をあきらめる。
      顔の枠そのものが入らないときは `fits` が False（縦長の写真を 16:9 に切るのは解にならない）
    """
    w, h = size
    if w / h > aspect:
        ch = h
        cw = round(h * aspect)
    else:
        cw = w
        ch = round(w / aspect)
    if zoom > 1.0:
        cw, ch = round(cw / zoom), round(ch / zoom)

    if center is not None:
        cx = w * center
    elif box is not None:
        cx = box[0] + box[2] / 2
    else:
        cx = w / 2
    left = round(cx - cw / 2)
    left = max(0, min(w - cw, left))

    if top is not None:
        y0 = round(h * top)
    elif box is not None:
        face_mid = box[1] + box[3] / 2
        y0 = face_mid - ch * third
        hb = head_box(box)
        # 頭のてっぺんより上に余白を残す（上を落とすと「顔がキレてる」）
        y0 = min(y0, hb[1] - ch * margin)
        # 上に残る余白が margin に届かないなら、上は切らない（立った髪は推定より高い。04_kubo で6px切れた）
        if y0 < ch * margin:
            y0 = 0
        # ただし顔の枠（顎まで）は必ず入れる。首（HEAD_DOWN のぶん）よりは髪を優先する
        y0 = max(y0, box[1] + box[3] - ch)
        y0 = round(y0)
    else:
        y0 = round(h * 0.08)
    y0 = max(0, min(h - ch, y0))
    return (left, y0, left + cw, y0 + ch)


def fits(crop: tuple[int, int, int, int], box: Box) -> bool:
    """切り出しに顔の枠がまるごと入っているか。"""
    l, t, r, b = crop
    return box[0] >= l and box[1] >= t and box[0] + box[2] <= r and box[1] + box[3] <= b


def crop_around(image, aspect: float, box: Box | None = None, **kw) -> Image.Image:
    """頭が切れない位置で、指定の縦横比に切った PIL 画像を返す。

    `box` を渡さなければ、その画像のいちばん大きい顔を使う。
    """
    pil = image if isinstance(image, Image.Image) else Image.open(image).convert("RGB")
    if box is None:
        box = main_face(pil)
    return pil.crop(crop_box(pil.size, aspect, box, **kw))


def head_cut(image, faces: list[Box] | None = None, edges: tuple[str, ...] = ("top", "left", "right"),
             slack: float = 0.0) -> bool:
    """いちばん大きい顔の、頭の推定の枠が画像の端からはみ出していれば True。

    `slack` は許すはみ出し（顔の高さに対する割合）。顔が見つからなければ False
    （切れているかどうか分からない。見つからないことは別に知らせる）。
    """
    if faces is None:
        faces = find_faces(image)
    if not faces:
        return False
    return bool(cut_edges(_size(image), faces[0], edges, slack))


def cut_edges(size: tuple[int, int], face: Box, edges: tuple[str, ...] = ("top", "left", "right"),
              slack: float = 0.0) -> list[str]:
    """頭の推定の枠がはみ出している端の名前（top / left / right / bottom）。"""
    w, h = size
    x, y, bw, bh = head_box(face)
    pad = face[3] * slack
    out = []
    if "top" in edges and y < -pad:
        out.append("top")
    if "left" in edges and x < -pad:
        out.append("left")
    if "right" in edges and x + bw > w + pad:
        out.append("right")
    if "bottom" in edges and y + bh > h + pad:
        out.append("bottom")
    return out


# ---- 顔の上の文字の板 -------------------------------------------------------

# 反応の白い箱：明るく（どのチャンネルも 215 以上）、色が薄く、ほぼ平らな画素
WHITE_MIN = 215
WHITE_SAT = 30
# 濃い板（表・テロップの帯）：暗く、色が薄い画素
DARK_MAX = 55
DARK_SAT = 45
# 平らさ：周りの画素との差（3x3 のラプラシアンの絶対値）がこれ以下
FLAT_MAX = 12
# 顔の枠の中で、行の大半（ROW_FILL 以上）がそういう画素で埋まった行が
# WHITE_ROWS（白）／DARK_ROWS（濃い板）以上あれば「板がかかっている」とする。
# 濃いほうを高くしてあるのは、黒髪・前髪も「暗く色が薄い」から（福原さんの前髪で 2 割近く出た）
ROW_FILL = 0.6
WHITE_ROWS = 0.12
DARK_ROWS = 0.5
# 板の縁：顔の幅の EDGE_FILL 以上にわたって、上下で明るさが EDGE_STEP 以上同じ向きに変わる行。
# 顔・髪の輪郭は曲がっているので、まっすぐ横一本の縁にはならない。テロップの帯・表の縁はなる
EDGE_STEP = 25
EDGE_FILL = 0.8
# 縁の向こう側（板の側）の数行が、平らで（ラプラシアンの中央値がこれ以下）暗いか白ければ板とみなす
EDGE_SIDE_ROWS = 6
EDGE_SIDE_FLAT = 3
EDGE_SIDE_DARK = 80
# 検出した顔の真ん中のこの割合以上が板の画素なら、文字を顔と取ったものとして落とす
TEXT_PLATE = 0.45
# 検出した顔の真ん中の肌色（YCrCb）の割合がこれ未満なら落とす。実物で本物の顔は 0.67〜1.0、
# 反応の箱のすきまのぼやけた背景を顔と取ったもの（10-02 久保の本編の最後）は 0.29 だった
SKIN_MIN = 0.4


def _plate_rows(patch) -> dict:
    """枠の中の行ごとに、文字の板がかかっているかを見る（`overlay_on_face` の中身）。

    返すのは {"white": 白い行の割合, "dark": 濃い行の割合, "edge": 縁の種類/None,
    "rows": 行ごとの「板がかかっている」の真偽（numpy の bool 配列）}。
    """
    patch = np.ascontiguousarray(patch)
    hsv = cv2.cvtColor(patch, cv2.COLOR_RGB2HSV)
    val, sat = hsv[..., 2].astype(int), hsv[..., 1].astype(int)
    gray = cv2.cvtColor(patch, cv2.COLOR_RGB2GRAY)
    lap = np.abs(cv2.Laplacian(gray, cv2.CV_16S, ksize=1))
    white = (val >= WHITE_MIN) & (sat <= WHITE_SAT) & (lap <= FLAT_MAX)
    dark = (val <= DARK_MAX) & (sat <= DARK_SAT)
    white_row = white.mean(axis=1) >= ROW_FILL
    dark_row = dark.mean(axis=1) >= ROW_FILL
    rows = white_row.copy()
    if dark_row.mean() >= DARK_ROWS:
        rows |= dark_row
    edge = None
    g = gray.astype(int)
    n = g.shape[0]
    if n >= 2 * EDGE_SIDE_ROWS + 4:
        diff = np.zeros_like(g)
        diff[2:-2] = g[4:] - g[:-4]
        for r in range(3, n - 3):
            if max(float((diff[r] <= -EDGE_STEP).mean()), float((diff[r] >= EDGE_STEP).mean())) < EDGE_FILL:
                continue
            for below, side in ((True, slice(r + 3, r + 3 + EDGE_SIDE_ROWS)),
                                (False, slice(max(0, r - 3 - EDGE_SIDE_ROWS), r - 3))):
                if val[side].size == 0 or float(np.median(lap[side])) > EDGE_SIDE_FLAT:
                    continue
                v = float(np.median(val[side]))
                kind = "dark" if v <= EDGE_SIDE_DARK else "white" if v >= WHITE_MIN else None
                if kind is None:
                    continue
                edge = edge or kind
                # 縁の向こう側が板。下が板なら縁から下、上が板なら縁から上
                if below:
                    rows[r:] = True
                else:
                    rows[:r + 1] = True
                break
    return {"white": float(white_row.mean()), "dark": float(dark_row.mean()), "edge": edge, "rows": rows}


def overlay_on_face(image, face: Box) -> dict:
    """顔の枠（顎の下まで少し広げた範囲）の上に、文字の板が重なっていそうかを見る。

    簡易の判定で、次のどれかなら「かかっている」（hit）:
    - 行のほぼ全部が、明るく平らで色の薄い画素（反応の白い箱）の行が WHITE_ROWS 以上
    - 行のほぼ全部が、暗く色の薄い画素（表・テロップの濃い板）の行が DARK_ROWS 以上
    - 顔の幅いっぱいに、まっすぐ横一本の縁があり、その向こうが平らで暗いか白い（板の縁）
    返すのは {"white", "dark", "edge", "hit": "white"/"dark"/None, "cover": 顔の枠の中で板がかかった行の割合}。
    `cover` が小さい（0.05 未満）なら、板は顎のすぐ下（首）に接しているだけ。
    """
    none = {"white": 0.0, "dark": 0.0, "edge": None, "hit": None, "cover": 0.0}
    if not available():
        return none
    rgb = _to_rgb(image)
    H, W = rgb.shape[:2]
    x, y, w, h = face
    # 顎の下まで見る（10-03 は箱が顎にかかった）。左右は顔の枠のまま
    y2 = min(H, round(y + h * (1 + HEAD_DOWN)))
    x1, y1, x2 = max(0, x), max(0, y), min(W, x + w)
    if x2 - x1 < 4 or y2 - y1 < 4:
        return none
    got = _plate_rows(rgb[y1:y2, x1:x2])
    hit = None
    if got["white"] >= WHITE_ROWS:
        hit = "white"
    elif got["dark"] >= DARK_ROWS:
        hit = "dark"
    elif got["edge"]:
        hit = got["edge"]
    face_rows = got["rows"][: max(1, min(H, y + h) - y1)]
    cover = float(face_rows.mean()) if hit else 0.0
    return {"white": round(got["white"], 3), "dark": round(got["dark"], 3), "edge": got["edge"],
            "hit": hit, "cover": round(cover, 3)}


def _skin_ok(rgb, box: Box) -> bool:
    """検出した「顔」の真ん中に、肌の色がそれなりにあるか。白黒の写真では見ない（True）。"""
    x, y, w, h = box
    patch = np.ascontiguousarray(rgb[max(0, y + h // 5):y + h - h // 5, max(0, x + w // 5):x + w - w // 5])
    if patch.size == 0:
        return True
    if float(np.abs(patch[..., 0].astype(int) - patch[..., 2].astype(int)).mean()) < 4:
        return True   # 白黒
    ycc = cv2.cvtColor(patch, cv2.COLOR_RGB2YCrCb)
    cr, cb = ycc[..., 1].astype(int), ycc[..., 2].astype(int)
    skin = (cr >= 133) & (cr <= 180) & (cb >= 70) & (cb <= 130)
    return float(skin.mean()) >= SKIN_MIN


def _on_plate(rgb, box: Box) -> bool:
    """検出した「顔」の真ん中が、板（白い箱・濃い板）の上か。文字を顔と取ったものを落とす。

    10-03 の本編で、テロップの「おめで」の字を顔と取った。顔の真ん中（目・鼻・口）は
    肌なので、白く平らな画素や暗く平らな画素で半分以上が埋まることは無い。
    """
    x, y, w, h = box
    cx1, cy1 = x + w // 5, y + h // 5
    cx2, cy2 = x + w - w // 5, y + h - h // 5
    patch = np.ascontiguousarray(rgb[max(0, cy1):cy2, max(0, cx1):cx2])
    if patch.size == 0:
        return False
    hsv = cv2.cvtColor(patch, cv2.COLOR_RGB2HSV)
    val, sat = hsv[..., 2].astype(int), hsv[..., 1].astype(int)
    gray = cv2.cvtColor(patch, cv2.COLOR_RGB2GRAY)
    flat = np.abs(cv2.Laplacian(gray, cv2.CV_16S, ksize=1)) <= EDGE_SIDE_FLAT
    plate = ((val >= WHITE_MIN) & (sat <= WHITE_SAT) & flat) | ((val <= DARK_MAX) & (sat <= DARK_SAT) & flat)
    return float(plate.mean()) >= TEXT_PLATE


def _plate_pixels(rgb) -> "np.ndarray":
    """板らしい画素（白く平ら／暗く色が薄く平ら）の真偽。"""
    rgb = np.ascontiguousarray(rgb)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    val, sat = hsv[..., 2].astype(int), hsv[..., 1].astype(int)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    lap = np.abs(cv2.Laplacian(gray, cv2.CV_16S, ksize=1))
    return (((val >= WHITE_MIN) & (sat <= WHITE_SAT) & (lap <= FLAT_MAX))
            | ((val <= DARK_MAX) & (sat <= DARK_SAT) & (lap <= EDGE_SIDE_FLAT)))


def same_picture(a, b, box: Box, need: float = 0.45, visible: float = 0.15) -> bool:
    """2枚のコマで、顔のまわり（頭の推定の枠を広げた範囲）が同じ写真のままか。

    板で隠れた顔は検出できないので、前後のコマで見つけた顔を借りて見る。
    そのとき写真が替わっていれば借りられない。`a`（見たいコマ）で板に隠れていない画素だけを比べ、
    明るさの相関が `need` 以上なら同じ写真とみなす（カードが出ると写真が暗く落ちるので、差ではなく相関で見る）。
    隠れていない画素が `visible` 未満なら比べられない（False）。
    実物で、同じ写真は 0.63〜0.72、違う写真は -0.07〜0.21 だった（10-02・10-03 の3本）。
    """
    if not available():
        return False
    ra, rb = _to_rgb(a), _to_rgb(b)
    if ra.shape != rb.shape:
        return False
    H, W = ra.shape[:2]
    hx, hy, hw, hh = head_box(box)
    x1, y1 = max(0, hx - hw // 3), max(0, hy - hh // 4)
    x2, y2 = min(W, hx + hw + hw // 3), min(H, hy + hh + hh // 4)
    if x2 - x1 < 4 or y2 - y1 < 4:
        return False
    pa = np.ascontiguousarray(ra[y1:y2, x1:x2])
    pb = np.ascontiguousarray(rb[y1:y2, x1:x2])
    open_ = ~_plate_pixels(pa)
    if open_.mean() < visible:
        return False
    ga = cv2.cvtColor(pa, cv2.COLOR_RGB2GRAY).astype(float)[open_]
    gb = cv2.cvtColor(pb, cv2.COLOR_RGB2GRAY).astype(float)[open_]
    if ga.std() < 1e-6 or gb.std() < 1e-6:
        return False
    return bool(float(np.corrcoef(ga, gb)[0, 1]) >= need)
