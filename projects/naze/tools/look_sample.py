"""写実の3D感の見本(2026-11-19 ユーザーが「いいんじゃない」): 実写の映像 → 奥行きを付けた写真 → 立体の地形、を同じ色の調子でつなぐ。
素材は同じフォルダに clip0.mp4・clip1.mp4(Pexels)・photo2.jpg・photo3.jpg を置く。奥行きは assets3d/models/depth_anything_v2_small.onnx。"""
import sys, os, json, math
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import imageio_ffmpeg
sys.path.insert(0, r"C:/Users/なみ/dev/wt-naze/projects/naze")
os.environ["NAZE_ASPECT"] = "landscape"
W, H, FPS = 1920, 1080, 30
HERE = os.path.dirname(os.path.abspath(__file__)); os.chdir(HERE)
FB = ImageFont.truetype("C:/Windows/Fonts/meiryob.ttc", 52); FS = ImageFont.truetype("C:/Windows/Fonts/meiryob.ttc", 30)
rng = np.random.default_rng(0)
VIG = None
def grade(f):
    """色の調子をそろえる: 少し暖かく・影に青緑・コントラスト・周りを暗く・細かい粒。"""
    global VIG
    x = f.astype(np.float32) / 255
    x = np.clip((x - 0.5) * 1.12 + 0.5, 0, 1)
    l = x.mean(2, keepdims=True)
    x = x + (1 - l) * np.array([-0.03, 0.01, 0.035]) + l * np.array([0.035, 0.01, -0.03])   # 影=青緑・明るい所=暖色
    if VIG is None:
        yy, xx = np.mgrid[0:H, 0:W]; r = np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2))
        VIG = (1 - 0.32 * np.clip(r - 0.45, 0, 1) ** 1.6)[..., None]
    x = x * VIG + rng.normal(0, 0.012, (H, W, 1))
    return (np.clip(x, 0, 1) * 255).astype(np.uint8)
def caption(f, text, tag):
    im = Image.fromarray(f); d = ImageDraw.Draw(im)
    tw = d.textlength(text, font=FB); x = (W - tw) / 2; y = H - 150
    for dx, dy in [(-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, 2), (2, -2), (-2, 2)]: d.text((x + dx, y + dy), text, font=FB, fill=(15, 12, 10))
    d.text((x, y), text, font=FB, fill=(255, 250, 240))
    d.text((40, 34), tag, font=FS, fill=(255, 245, 225))
    return np.asarray(im)
def cover(img):
    h, w = img.shape[:2]; s = max(W / w, H / h); img = cv2.resize(img, (round(w * s), round(h * s)), interpolation=cv2.INTER_AREA)
    y = (img.shape[0] - H) // 2; x = (img.shape[1] - W) // 2; return img[y:y + H, x:x + W]
# ---- 1 実写の映像 ----
def clip(path, sec, start=0.0):
    cap = cv2.VideoCapture(path); fps = cap.get(cv2.CAP_PROP_FPS); cap.set(cv2.CAP_PROP_POS_MSEC, start * 1000)
    out = []
    for i in range(int(sec * FPS)):
        cap.set(cv2.CAP_PROP_POS_MSEC, (start + i / FPS) * 1000); ok, f = cap.read()
        if not ok: break
        out.append(cover(cv2.cvtColor(f, cv2.COLOR_BGR2RGB)))
    return out
# ---- 2 奥行きを付けた写真 ----
import onnxruntime as ort
SES = ort.InferenceSession(r"C:/Users/なみ/dev/assets3d/models/depth_anything_v2_small.onnx", providers=["CPUExecutionProvider"])
def depth(img):
    x = cv2.resize(img, (518, 518)).astype(np.float32) / 255
    x = (x - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
    d = SES.run(None, {SES.get_inputs()[0].name: x.transpose(2, 0, 1)[None].astype(np.float32)})[0][0]
    d = cv2.resize(d, (img.shape[1], img.shape[0])); d = (d - d.min()) / (d.max() - d.min() + 1e-6)
    return cv2.GaussianBlur(d, (0, 0), 3)                         # 1=手前
def parallax(path, sec):
    src = cover(np.asarray(Image.open(path).convert("RGB")))
    big = cv2.resize(src, (int(W * 1.15), int(H * 1.15)), interpolation=cv2.INTER_CUBIC)
    d = depth(big); h, w = big.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    out = []; n = int(sec * FPS)
    for i in range(n):
        u = i / (n - 1); e = u * u * (3 - 2 * u)
        zoom = 1.0 + 0.10 * e                                     # 中へ入っていく
        cx, cy = w / 2 + (-40 + 80 * e), h / 2
        px = (xx - W / 2) / zoom + cx; py = (yy - H / 2) / zoom + cy
        dd = cv2.remap(d, px, py, cv2.INTER_LINEAR)
        shift = (dd - 0.5) * (60 * e - 30)                         # 手前ほど横に大きくずれる
        out.append(cv2.remap(big, px - shift, py - (dd - 0.5) * 18 * e, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT))
    return out
# ---- 3 立体の地形 ----
def terrain(sec):
    from naze import worldmap
    m = worldmap.Map(lat0=-24.7, bases=[((10, -30, 22, -18), 6), ((14.2, -25.6, 16.2, -23.8), 9)])
    out = []; n = int(sec * FPS)
    for i in range(0, n, 2):
        u = i / (n - 1); e = u * u * (3 - 2 * u)
        v = m.view(15.0 + 0.3 * e, -24.9 + 0.1 * e, 3.2 - 1.6 * e, 50 + 8 * e)
        f = np.asarray(m.base_img(v))[..., :3]
        out += [f, f]
    return out[:n]
segs = [
    (clip("clip1.mp4", 4.0, 2.0), "ナミブ砂漠の砂丘は、高さ300mを超える", "1 実写の映像"),
    (parallax("photo2.jpg", 5.0), "雨は1年に数十ミリしか降らない", "2 写真に奥行き"),
    (clip("clip0.mp4", 4.0, 3.0), "その真ん中を、人が歩いていく", "1 実写の映像"),
    (terrain(5.0), "海岸から内陸へ、砂の海が広がる", "3 立体の地形"),
    (parallax("photo3.jpg", 5.0), "そこに、なぜ木が立っていられるのか", "2 写真に奥行き"),
]
wr = imageio_ffmpeg.write_frames("sample.mp4", (W, H), fps=FPS, codec="libx264", quality=8, macro_block_size=1)
wr.send(None); sheet = []
prev = None
for frames, text, tag in segs:
    for i, f in enumerate(frames):
        g = caption(grade(f), text, tag)
        if prev is not None and i < 8: g = (g * (i / 8) + prev * (1 - i / 8)).astype(np.uint8)   # 短いディゾルブ
        wr.send(np.ascontiguousarray(g))
        if i == len(frames) // 2: sheet.append(Image.fromarray(g).resize((960, 540)))
    prev = g
wr.close()
s = Image.new("RGB", (1920, 540 * 3), "black")
for k, im in enumerate(sheet): s.paste(im, (960 * (k % 2), 540 * (k // 2)))
s.save("sheet.jpg", quality=85); print("ok")
