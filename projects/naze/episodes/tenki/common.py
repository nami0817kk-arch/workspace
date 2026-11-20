"""天気の子 × 東京の低い土地 の共通の設定。出典は research.md。地点は国土地理院 地名検索(駅・役所・公園)。"""
from pathlib import Path

from naze import overlay as O

HERE = Path(__file__).resolve().parent
ASSETS = HERE / "assets"

POINTS = dict(
    tabata=(139.7617, 35.7371), tokyo=(139.7662, 35.6813), odaiba=(139.7710, 35.6310), koto=(139.8171, 35.6732),
    kameido=(139.8267, 35.6990), shinjuku=(139.6995, 35.6896), yoyogi=(139.7012, 35.6836), hibiya=(139.7562, 35.6739),
    kokyo=(139.7520, 35.6846), minamisuna=(139.8303, 35.6686), edogawa=(139.8681, 35.7067), adachi=(139.8047, 35.7750),
    katsushika=(139.8472, 35.7433), sumida=(139.8015, 35.7107), nishikasai=(139.8593, 35.6668),
    center=(139.74, 35.68), east=(139.83, 35.70), west=(139.68, 35.69),
    tabata_w=(139.7450, 35.7371), tabata_e=(139.7950, 35.7371),
)

BASE = dict(
    kind="terrain",
    bbox=(139.56, 35.52, 139.92, 35.82),
    dem_z=13,
    exag=20.0,
    tex_opts=dict(valley=0.0, photo=True, photo_sat=1.2, photo_gain=1.08),
    points=POINTS,
    header="東京は【沈む】のか",
)

PROF_TABATA = dict(a="tabata_w", b="tabata_e", at=0.05, names=["西（台地）", "東（低地）"])
PROF_KOKYO = dict(a="kokyo", b="tokyo", at=0.05, names=["皇居", "東京駅"])


def cam(look, dist, height, yaw, tz=0.0):
    return dict(look=look, dist=dist, height=height, yaw=yaw, tz=tz)


def L(point, text, color=O.WHITE, at=0.2, below=False):
    return dict(point=point, text=text, color=color, at=at, below=below)
