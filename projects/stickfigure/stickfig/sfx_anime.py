"""戦闘アニメ風の効果音(2026-10-24「音とかはドラゴンボールのアニメに寄せて」)。計算で作る(外部の音源・既存作品の音は使わない)。

実在の作品の効果音・曲は使えない(著作権。YouTube の著作権の自動判定にも掛かる)。手触りだけを寄せる:
  - 打撃は「風切り → 高い破裂音 → 中域の衝撃 → 低い胴鳴り」を重ねて、短く鋭く
  - 瞬間移動は高い「シュン」(速い上昇の掃引 + 短い金属の鳴り)
  - 気の溜めは、うなり(ノコギリ波の和音が少しずつ上がる)+ 電気のはじける音 + 風
  - 光線は、明るいうなりの持続(少しずつずらした和音のうねり)+ 轟音 + 終わりの爆発
  - 爆発・激突は、長い低い轟き + 空気の割れる音
音量は 0〜1 の配列で返す(sfx.SR、モノラル)。混ぜ方は sfx._add と同じ。
"""
from __future__ import annotations

import numpy as np

from .sfx import SR, _env, _filt, _noise, _sweep


def _t(n: int) -> np.ndarray:
    return np.arange(n) / SR


def _norm(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    """大きさをそろえ、頭 1 ミリ秒・終わり 15 ミリ秒を滑らかにする(急に切れるとプチッと鳴る)。"""
    x = np.array(x, dtype=np.float64)
    a, b = min(len(x), int(SR * 0.001)), min(len(x), int(SR * 0.015))
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return x * (peak / m) if m > 1e-9 else x


def swish(rng, dur: float = 0.12, lo: float = 900.0, hi: float = 7000.0) -> np.ndarray:
    """速い風切り(拳・蹴りの振り)。後ろに寄った山で、当たりの直前に最大。"""
    n = int(SR * dur)
    ramp = (np.arange(n) / n) ** 2.2
    return _filt(_noise(n, rng), lo, hi) * ramp * np.exp(-((np.arange(n) / n - 0.92) ** 2) / 0.02)


def punch(rng, heavy: float = 1.0) -> np.ndarray:
    """打撃。高い破裂(パシッ)+ 中域の衝撃(バシッ)+ 低い胴鳴り(ドッ)。heavy で低音と長さが増える。"""
    n = int(SR * (0.22 + 0.18 * heavy))
    crack = _filt(_noise(n, rng), 2500, 11000) * _env(n, 0.0002, 0.012)
    smack = _filt(_noise(n, rng), 500, 3000) * _env(n, 0.0005, 0.035 + 0.02 * heavy)
    body = _sweep(n, 180 + 60 * heavy, 45) * _env(n, 0.001, 0.06 + 0.08 * heavy)
    return _norm(0.9 * crack + 0.8 * smack + (0.7 + 0.5 * heavy) * body)


def hit(rng, heavy: float = 1.0) -> np.ndarray:
    """振りから当たりまで(風切り 0.12 秒 → 打撃)。返す配列の 0.12 秒目が当たりの瞬間。"""
    sw = swish(rng, 0.12)
    p = punch(rng, heavy)
    out = np.zeros(len(sw) + len(p))
    out[:len(sw)] += 0.55 * sw
    out[len(sw):] += p
    return _norm(out)


def guard(rng) -> np.ndarray:
    """受け止め。鈍い衝撃と、空気の押される音(当たりより丸い)。"""
    n = int(SR * 0.25)
    thud = _sweep(n, 140, 60) * _env(n, 0.001, 0.05)
    puff = _filt(_noise(n, rng), 300, 1800) * _env(n, 0.002, 0.06)
    return _norm(0.9 * thud + 0.6 * puff)


def flurry(rng, n_hits: int = 10, gap: float = 0.055) -> np.ndarray:
    """連打(ドドドド)。軽い打撃を細かく並べる。"""
    out = np.zeros(int(SR * (gap * n_hits + 0.3)))
    for i in range(n_hits):
        p = punch(rng, 0.25) * (0.6 + 0.4 * rng.random())
        k = int(SR * i * gap)
        out[k:k + len(p)] += p[:len(out) - k]
    return _norm(out)


def zip_(rng) -> np.ndarray:
    """瞬間移動の「シュン」。高い掃引の上昇 + 風 + 短い金属の鳴り。"""
    n = int(SR * 0.22)
    t = _t(n)
    tone = _sweep(n, 1400, 7200) * np.exp(-t / 0.05) * np.minimum(1, t / 0.004)
    air = _filt(_noise(n, rng), 3000, 12000) * np.sin(np.pi * np.minimum(1, t / 0.12)) ** 2 * np.exp(-t / 0.08)
    ting = np.sin(2 * np.pi * 5200 * t) * _env(n, 0.0003, 0.03)
    return _norm(0.7 * tone + 0.6 * air + 0.25 * ting)


def charge(rng, dur: float = 2.5) -> np.ndarray:
    """気を溜める。うなり(ノコギリ波の和音がゆっくり上がる、揺れ付き)+ 電気のはじける音 + 増える風。最後に向けて大きくなる。"""
    n = int(SR * dur)
    t = _t(n)
    u = t / dur
    base = 70 * (2.2 ** u)
    hum = np.zeros(n)
    for mult, a in ((1.0, 0.6), (1.5, 0.35), (2.0, 0.3), (3.01, 0.15)):
        ph = 2 * np.pi * np.cumsum(base * mult) / SR
        hum += a * (2 * ((ph / (2 * np.pi)) % 1.0) - 1)
    hum = _filt(hum, 40, 2500) * (1 + 0.25 * np.sin(2 * np.pi * (6 + 10 * u) * t))
    wind = _filt(_noise(n, rng), 400, 6000) * (0.2 + 0.8 * u)
    crack = np.zeros(n)
    for _ in range(int(25 + 60 * dur)):                     # 電気のはじける音(後ろほど多い)
        i = int(n * np.sqrt(rng.random()))
        k = int(SR * 0.006)
        m = min(k, n - i)
        crack[i:i + m] += rng.standard_normal(m) * np.exp(-np.arange(m) / (SR * 0.0015))
    env = np.minimum(1, t / 0.3) * (0.35 + 0.65 * u ** 1.3)
    return _norm((hum + 0.5 * wind + 0.45 * _filt(crack, 2000, 12000)) * env)


def aura(rng, dur: float = 2.0) -> np.ndarray:
    """覚醒のオーラが噴き上がる。低い轟き + 燃えるような揺れるノイズ + 上がっていく明るいうなり。"""
    n = int(SR * dur)
    t = _t(n)
    roar = _filt(_noise(n, rng), 60, 1400) * (1 + 0.4 * np.sin(2 * np.pi * 9 * t + rng.random() * 6))
    rise = _sweep(n, 110, 420) * 0.5 + _sweep(n, 165, 630) * 0.3
    sub = np.sin(2 * np.pi * 45 * t) * 0.8
    env = np.minimum(1, t / 0.15) * np.where(t > dur - 0.4, (dur - t) / 0.4, 1.0)
    return _norm((roar + rise + sub) * env)


def beam(rng, dur: float = 1.6) -> np.ndarray:
    """光線の発射。最初に空気の割れる音、明るいうなりの持続(少しずつずらした和音のうねり)と轟音、最後は細って消える。"""
    n = int(SR * dur)
    t = _t(n)
    buzz = np.zeros(n)
    rise = np.minimum(1.0, t / 0.25)                         # 撃った瞬間に音程が少し上がって張り付く
    for f, a in ((220, 0.5), (223.5, 0.5), (330, 0.35), (442, 0.3), (660, 0.15)):
        ph = 2 * np.pi * np.cumsum(f * (0.8 + 0.2 * rise)) / SR
        buzz += a * (2 * ((ph / (2 * np.pi)) % 1.0) - 1)
    buzz = _filt(buzz, 80, 5000) * (1 + 0.2 * np.sin(2 * np.pi * 14 * t))
    roar = _filt(_noise(n, rng), 100, 8000)
    burst = _filt(_noise(n, rng), 1500, 12000) * _env(n, 0.0005, 0.08)
    sub = _sweep(n, 90, 40) * _env(n, 0.002, 0.5)
    env = np.minimum(1, t / 0.05) * np.where(t > dur - 0.35, np.maximum(0, (dur - t) / 0.35), 1.0)
    return _norm((1.0 * buzz + 0.22 * roar + 0.8 * sub) * env + 0.8 * burst)


def ki_shot(rng) -> np.ndarray:
    """気弾を撃つ「ピシュン」。下がる掃引 + 短い破裂。"""
    n = int(SR * 0.3)
    t = _t(n)
    tone = _sweep(n, 3200, 500) * np.exp(-t / 0.09)
    pop = _filt(_noise(n, rng), 1000, 9000) * _env(n, 0.0005, 0.02)
    return _norm(0.8 * tone + 0.6 * pop)


def explosion(rng, dur: float = 2.2) -> np.ndarray:
    """大爆発。空気の割れる破裂 + 長い低い轟き + 崩れる破片。"""
    n = int(SR * dur)
    t = _t(n)
    crack = _filt(_noise(n, rng), 1500, 12000) * _env(n, 0.0003, 0.05)
    rumble = _filt(_noise(n, rng), 25, 400) * _env(n, 0.005, 0.8)
    sub = _sweep(n, 80, 22) * _env(n, 0.003, 0.7)
    deb = np.zeros(n)
    for _ in range(30):
        i = int(rng.uniform(0.1, 0.85) * n)
        k = int(SR * 0.01)
        m = min(k, n - i)
        deb[i:i + m] += rng.standard_normal(m) * np.exp(-np.arange(m) / (SR * 0.002)) * (1 - i / n)
    return _norm(0.8 * crack + 1.0 * rumble + 0.9 * sub + 0.3 * _filt(deb, 800, 6000))


def clash(rng) -> np.ndarray:
    """拳と拳の激突。重い打撃 + 空気の割れる衝撃波(ドォン)+ 余韻の轟き。"""
    p = punch(rng, 1.6)
    e = explosion(rng, 1.4)
    out = np.zeros(max(len(p), len(e)))
    out[:len(p)] += p
    out[:len(e)] += 0.7 * e
    return _norm(out)


def dash(rng, dur: float = 0.45) -> np.ndarray:
    """高速の移動・飛行(ビュンッ)。山なりの風 + 少し上下する音程。"""
    n = int(SR * dur)
    t = _t(n)
    ramp = np.sin(np.pi * t / dur) ** 1.5
    tone = _sweep(n, 500, 1300) * 0.25
    return _norm((_filt(_noise(n, rng), 500, 7000) + tone) * ramp)


def land_heavy(rng) -> np.ndarray:
    """重い着地(ズンッ)。低い胴鳴り + 土の擦れ。"""
    n = int(SR * 0.6)
    body = _sweep(n, 110, 35) * _env(n, 0.002, 0.18)
    dirt = _filt(_noise(n, rng), 100, 2500) * _env(n, 0.003, 0.15)
    return _norm(1.0 * body + 0.6 * dirt)


def sting(rng, dur: float = 1.2) -> np.ndarray:
    """場面の山の合図(ジャーン)。金管っぽいノコギリ波の和音(短三和音の上に 9 度)を、明るく開いて減衰させる。"""
    n = int(SR * dur)
    t = _t(n)
    out = np.zeros(n)
    for m in (45, 52, 57, 60, 64, 71):                      # A2 E3 A3 C4 E4 B4
        f = 440.0 * 2 ** ((m - 69) / 12)
        for det in (-0.15, 0.15):
            ph = 2 * np.pi * f * (1 + det / 100) * t
            out += (2 * ((ph / (2 * np.pi)) % 1.0) - 1) * 0.18
    bright = _filt(out, 80, 6000)
    return _norm(bright * _env(n, 0.01, 0.6))


SOUNDS = dict(hit=lambda r: hit(r, 1.0), heavy_hit=lambda r: hit(r, 1.8), guard=guard, flurry=flurry, teleport=zip_, charge=charge, aura=aura,
              beam=beam, ki_shot=ki_shot, explosion=explosion, clash=clash, dash=dash, land=land_heavy, sting=sting)
