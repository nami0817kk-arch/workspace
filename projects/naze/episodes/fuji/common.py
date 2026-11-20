"""富士山のセットの共通の設定(地形の範囲・地点・色・カメラ)。出典は research.md。
地点の位置: 国土地理院 地名検索(宝永山・西湖・精進湖・青木ヶ原・河口湖・本栖湖・山中湖・小御岳神社)。
山頂(剣ヶ峯)・宝永火口・長尾山は地図からの読み。断面の端は山頂から各方向へ 12km(南東は 10km)を計算で置いた点。"""
import math
from pathlib import Path

from naze import overlay as O

HERE = Path(__file__).resolve().parent
ASSETS = HERE / "assets"
TOP = (138.7274, 35.3606)


def toward(az, km, base=TOP):
    lon = base[0] + km * math.sin(math.radians(az)) / (111.32 * math.cos(math.radians(base[1])))
    lat = base[1] + km * math.cos(math.radians(az)) / 110.57
    return (round(lon, 5), round(lat, 5))


POINTS = dict(
    top=TOP,
    hoei=(138.7430, 35.3410),
    hoeizan=(138.7522, 35.3437),
    komitake=(138.7338, 35.3950),
    aokigahara=(138.6326, 35.4714),
    nagao=(138.6470, 35.4390),
    saiko=(138.6863, 35.4990),
    shoji=(138.6082, 35.4906),
    kawaguchi=(138.7482, 35.5150),
    motosu=(138.5858, 35.4633),
    yamanaka=(138.8754, 35.4164),
    n12=toward(0, 12), s12=toward(180, 12), e12=toward(90, 12), w12=toward(270, 12), se10=toward(135, 10),
    n3=toward(0, 3), w3=toward(270, 3), e3=toward(90, 3), s3=toward(180, 3),
)

BASE = dict(
    kind="terrain",
    bbox=(138.50, 35.20, 138.96, 35.535),
    dem_z=13,
    exag=1.3,
    tex_opts=dict(valley=0.0, photo=True, photo_sat=1.25, photo_gain=1.08),
    points=POINTS,
    header="なぜ富士山は【きれい】なのか",
)

# 断面(山頂を通る切り方)
PROF_WE = dict(a="w12", b="e12", at=0.05, names=["西", "東"])
PROF_SN = dict(a="s12", b="n12", at=0.05, names=["南", "北"])
PROF_SE = dict(a="top", b="se10", at=0.05, names=["山頂", "南東"])

STEPS = dict(kind="steps", title="富士山の中に重なる火山（内閣府の報告書）", at=0.05, grow=3.0,
             items=[("先小御岳", "数十万年前"), ("小御岳", "約10万年前まで"), ("古富士", "約10万年前〜"), ("新富士", "約1万1000年前〜")])


def cam(look, dist, height, yaw, tz=0.0):
    return dict(look=look, dist=dist, height=height, yaw=yaw, tz=tz)
