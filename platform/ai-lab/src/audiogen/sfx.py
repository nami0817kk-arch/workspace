"""効果音(SFX)のプリセット。

すべて ``preset(sr=..., seed=..., pitch=...) -> list[float]`` の形で、
モノラルの float バッファを返す。``PRESETS`` から名前で引ける。

``pitch`` はすべてのプリセットが受け取る音程の倍率。ノイズ主体の音では
フィルタの帯域が動くので、太さ・細さの調整として効く。
"""

from __future__ import annotations

import random
from typing import Callable

from . import effects as fx
from . import envelope as env
from . import oscillators as osc
from .core import SAMPLE_RATE, add_into, concat, fade, mix, normalize, remove_dc, silence

SfxFunc = Callable[..., list]


def _finish(buf: list[float], sr: int, level: float = 0.85) -> list[float]:
    """直流除去・正規化・極短フェードで仕上げる(クリックノイズ防止)。"""
    return fade(normalize(remove_dc(buf), level), fade_in=0.001, fade_out=0.008, sr=sr)


# --- 収集・獲得 ---------------------------------------------------------------


def coin(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """コイン取得音。短い音のあと高い音を伸ばす、定番の2音。"""
    first = osc.square(988.0 * pitch, 0.055, sr, duty=0.5)
    second = osc.square(1319.0 * pitch, 0.32, sr, duty=0.5)
    first = env.apply(first, env.adsr(0.055, 0.002, 0.01, 0.9, 0.01, sr))
    second = env.apply(second, env.percussive(0.32, tau=0.13, attack=0.002, sr=sr))
    return _finish(concat(first, second), sr)


def pickup(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """アイテム取得音。短い上昇スイープ + キラッとした倍音。"""
    duration = 0.24
    freq = osc.sweep(600.0 * pitch, 1500.0 * pitch, duration * 0.7)
    body = osc.triangle(freq, duration, sr)
    sparkle = osc.sine(lambda t: freq(t) * 3.0, duration, sr, amp=0.3)
    tone = mix(body, sparkle)
    return _finish(env.apply(tone, env.percussive(duration, tau=0.09, attack=0.004, sr=sr)), sr, 0.8)


def powerup(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """パワーアップ音。上昇アルペジオ。"""
    freqs = [261.63, 329.63, 392.0, 523.25, 659.26, 783.99]
    step = 0.06
    out: list[float] = []
    for freq in freqs:
        step_tone = osc.square(freq * pitch, step, sr, duty=0.5)
        step_tone = env.apply(step_tone, env.adsr(step, 0.004, 0.02, 0.8, 0.02, sr))
        out = concat(out, step_tone)
    tail = osc.square(freqs[-1] * 2 * pitch, 0.3, sr, duty=0.25)
    tail = env.apply(tail, env.percussive(0.3, tau=0.11, attack=0.003, sr=sr))
    return _finish(concat(out, tail), sr)


def level_up(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """レベルアップのファンファーレ。和音を駆け上がってから伸ばす。"""
    step = 0.085
    out: list[float] = []
    for index, freq in enumerate((392.0, 523.25, 659.26, 783.99)):
        tone = osc.square(freq * pitch, 0.5, sr, duty=0.25)
        tone = env.apply(tone, env.percussive(0.5, tau=0.22, attack=0.004, sr=sr))
        add_into(out, tone, offset=int(index * step * sr), gain=0.55)
    chord = mix(
        *(
            env.apply(
                osc.square(freq * pitch, 0.7, sr, duty=0.5),
                env.percussive(0.7, tau=0.3, attack=0.006, sr=sr),
            )
            for freq in (523.25, 659.26, 783.99, 1046.5)
        )
    )
    add_into(out, chord, offset=int(4 * step * sr), gain=0.5)
    return _finish(fx.reverb(out, room=0.6, wet=0.22, sr=sr, tail=0.5), sr)


def heal(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """回復音。柔らかい上昇アルペジオに残響。"""
    freqs = [523.25, 659.26, 783.99, 1046.5]
    step = 0.09
    out: list[float] = []
    for i, freq in enumerate(freqs):
        tone = osc.triangle(freq * pitch, 0.4, sr)
        tone = env.apply(tone, env.percussive(0.4, tau=0.16, attack=0.012, sr=sr))
        add_into(out, tone, offset=int(i * step * sr), gain=0.7)
    return _finish(fx.reverb(out, room=0.72, wet=0.35, sr=sr, tail=0.7), sr, 0.8)


# --- 動作・攻撃 ---------------------------------------------------------------


def jump(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """ジャンプ音。上昇するパルス波スイープ。"""
    duration = 0.22
    freq = osc.sweep(220.0 * pitch, 880.0 * pitch, duration * 0.8)
    tone = osc.render("pulse25", freq, duration, sr)
    return _finish(env.apply(tone, env.percussive(duration, tau=0.09, attack=0.003, sr=sr)), sr)


def land(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """着地音。低い衝撃にわずかな砂利感を足す。"""
    rng = random.Random(seed)
    duration = 0.3
    thud = osc.sine(osc.sweep(180.0 * pitch, 45.0 * pitch, 0.1), duration, sr)
    thud = env.apply(thud, env.percussive(duration, tau=0.09, attack=0.002, sr=sr))
    grit = fx.lowpass(osc.noise(duration, sr, rng=rng), 1200.0 * pitch, sr)
    grit = env.apply(grit, env.percussive(duration, tau=0.035, attack=0.001, sr=sr))
    return _finish(mix(thud, grit, gains=(0.9, 0.35)), sr)


def footstep(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """足音。ごく短いローパスノイズ。"""
    rng = random.Random(seed)
    duration = 0.16
    body = fx.lowpass(
        osc.noise(duration, sr, rng=rng), osc.sweep(1400.0 * pitch, 300.0 * pitch, duration), sr
    )
    return _finish(env.apply(body, env.percussive(duration, tau=0.035, attack=0.002, sr=sr)), sr, 0.6)


def dash(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """ダッシュ / 回避。短く鋭い風切り。"""
    rng = random.Random(seed)
    duration = 0.3
    body = osc.noise(duration, sr, rng=rng)
    centre = osc.sweep(2600.0 * pitch, 500.0 * pitch, duration)
    body = fx.bandpass(body, low=lambda t: centre(t) * 0.6, high=lambda t: centre(t) * 1.7, sr=sr)
    return _finish(env.apply(body, env.percussive(duration, tau=0.09, attack=0.008, sr=sr)), sr, 0.8)


def swing(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """武器を振る音。膨らんでから素早く抜ける。"""
    rng = random.Random(seed)
    duration = 0.35
    body = osc.noise(duration, sr, rng=rng)
    centre = osc.sweep(700.0 * pitch, 3400.0 * pitch, duration * 0.6)
    body = fx.bandpass(body, low=lambda t: centre(t) * 0.7, high=lambda t: centre(t) * 1.5, sr=sr)
    shape = env.adsr(duration, duration * 0.5, duration * 0.08, 0.8, duration * 0.35, sr)
    return _finish(env.apply(body, shape), sr, 0.8)


def whoosh(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0, duration: float = 0.6) -> list[float]:
    """風切り音。ノイズをバンドパスで往復させる。"""
    rng = random.Random(seed)
    body = osc.noise(duration, sr, rng=rng)
    centre_up = osc.sweep(300.0 * pitch, 3000.0 * pitch, duration * 0.55)
    body = fx.bandpass(body, low=lambda t: centre_up(t) * 0.5, high=lambda t: centre_up(t) * 1.8, sr=sr)
    shape = env.apply(body, env.adsr(duration, duration * 0.45, duration * 0.1, 0.75, duration * 0.4, sr))
    return _finish(shape, sr, 0.8)


def laser(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """レーザー / ショット音。急降下スイープ。"""
    duration = 0.28
    freq = osc.sweep(1800.0 * pitch, 120.0 * pitch, duration)
    tone = mix(
        osc.saw(freq, duration, sr, amp=0.7),
        osc.square(freq, duration, sr, amp=0.4),
    )
    tone = fx.lowpass(tone, osc.sweep(6000.0 * pitch, 800.0 * pitch, duration), sr)
    return _finish(env.apply(tone, env.percussive(duration, tau=0.1, attack=0.001, sr=sr)), sr)


def charge(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """溜め音。上昇しながら震えが速くなる。"""
    duration = 0.9
    freq = osc.vibrato(osc.sweep(180.0 * pitch, 900.0 * pitch, duration), rate=9.0, depth=0.03)
    tone = osc.render("saw", freq, duration, sr)
    tone = fx.lowpass(tone, osc.sweep(700.0 * pitch, 5000.0 * pitch, duration), sr)
    tone = env.apply(tone, env.ramp(duration, 0.15, 1.0, sr))
    return _finish(fade(tone, fade_out=0.05, sr=sr), sr, 0.8)


# --- 衝撃・破壊 ---------------------------------------------------------------


def hit(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """被弾 / 打撃音。ノイズのアタックに低音の芯を足す。"""
    rng = random.Random(seed)
    duration = 0.26
    crack = fx.highpass(osc.noise(duration, sr, rng=rng), 600.0 * pitch, sr)
    crack = env.apply(crack, env.percussive(duration, tau=0.05, attack=0.001, sr=sr))
    thump = osc.sine(osc.sweep(320.0 * pitch, 60.0 * pitch, 0.12), duration, sr)
    thump = env.apply(thump, env.percussive(duration, tau=0.08, attack=0.001, sr=sr))
    return _finish(mix(crack, thump, gains=(0.6, 0.8)), sr)


def explosion(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0, duration: float = 1.4) -> list[float]:
    """爆発音。ノイズのフィルタスイープ + 低音のドン。"""
    rng = random.Random(seed)
    body = osc.noise(duration, sr, rng=rng)
    body = fx.lowpass(body, osc.sweep(3200.0 * pitch, 90.0 * pitch, duration), sr)
    body = env.apply(body, env.percussive(duration, tau=duration * 0.32, attack=0.004, sr=sr))
    body = fx.distort(body, drive=2.2)

    boom = osc.sine(osc.sweep(150.0 * pitch, 35.0 * pitch, duration * 0.6), duration, sr, amp=0.9)
    boom = env.apply(boom, env.percussive(duration, tau=duration * 0.22, attack=0.002, sr=sr))
    return _finish(mix(body, boom, gains=(0.75, 0.6)), sr, level=0.92)


def shatter(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """破壊音。割れる一撃のあとに破片が散らばる。"""
    rng = random.Random(seed)
    duration = 0.9
    out: list[float] = []
    crack = fx.highpass(osc.noise(0.12, sr, rng=rng), 1800.0 * pitch, sr)
    add_into(out, env.apply(crack, env.percussive(0.12, tau=0.03, attack=0.001, sr=sr)))
    # 破片が落ちる音を、間隔と高さをばらして散らす。
    for _ in range(14):
        start = rng.uniform(0.03, duration - 0.15)
        freq = rng.uniform(1600.0, 5200.0) * pitch
        piece = osc.triangle(freq, 0.09, sr, amp=rng.uniform(0.25, 0.7))
        piece = env.apply(piece, env.percussive(0.09, tau=0.018, attack=0.001, sr=sr))
        add_into(out, piece, offset=int(start * sr), gain=0.5)
    return _finish(out, sr, 0.85)


def thunder(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """雷鳴。鋭い一撃のあと低い唸りが尾を引く。"""
    rng = random.Random(seed)
    duration = 2.1
    crack = fx.highpass(osc.noise(0.25, sr, rng=rng), 2500.0 * pitch, sr)
    crack = env.apply(crack, env.percussive(0.25, tau=0.05, attack=0.002, sr=sr))
    rumble = fx.lowpass(
        osc.noise(duration, sr, rng=rng), osc.sweep(400.0 * pitch, 60.0 * pitch, duration), sr
    )
    rumble = env.apply(rumble, env.percussive(duration, tau=0.85, attack=0.06, sr=sr))
    rumble = fx.distort(rumble, drive=1.8)
    body = mix(crack, rumble, gains=(0.7, 0.9))
    return _finish(fx.reverb(body, room=0.85, wet=0.3, sr=sr, tail=0.5), sr, 0.9)


def engine(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """エンジンの唸り。低い鋸波を細かく震わせる。"""
    rng = random.Random(seed)
    duration = 1.2
    freq = osc.vibrato(110.0 * pitch, rate=28.0, depth=0.09)
    body = osc.render("saw", freq, duration, sr)
    body = fx.distort(fx.lowpass(body, 900.0 * pitch, sr), drive=2.5)
    grit = fx.bandpass(osc.noise(duration, sr, rng=rng), 200.0, 1500.0, sr)
    return _finish(fade(mix(body, grit, gains=(0.9, 0.2)), 0.05, 0.08, sr), sr, 0.85)


# --- UI・演出 -----------------------------------------------------------------


def blip(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """UI のカーソル移動音。ごく短い一発。"""
    duration = 0.05
    tone = osc.square(880.0 * pitch, duration, sr, duty=0.5)
    return _finish(env.apply(tone, env.percussive(duration, tau=0.02, attack=0.001, sr=sr)), sr, 0.7)


def select(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """決定音。二段の上昇ブリップ。"""
    step = 0.055
    low = env.apply(
        osc.square(659.26 * pitch, step, sr, duty=0.5),
        env.adsr(step, 0.003, 0.01, 0.9, 0.015, sr),
    )
    high = env.apply(
        osc.square(987.77 * pitch, 0.16, sr, duty=0.5),
        env.percussive(0.16, tau=0.06, attack=0.002, sr=sr),
    )
    return _finish(concat(low, high), sr, 0.8)


def error(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """エラー / キャンセル音。低い方へ落ちる2音。"""
    step = 0.13
    first = env.apply(
        osc.square(220.0 * pitch, step, sr, duty=0.5), env.adsr(step, 0.004, 0.02, 0.85, 0.03, sr)
    )
    second = env.apply(
        osc.square(155.56 * pitch, 0.3, sr, duty=0.5), env.percussive(0.3, tau=0.12, attack=0.003, sr=sr)
    )
    return _finish(concat(first, second), sr, 0.8)


def menu_open(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """メニューを開く音。短い上昇スイープに空気感を重ねる。"""
    rng = random.Random(seed)
    duration = 0.26
    air = fx.bandpass(
        osc.noise(duration, sr, rng=rng),
        low=osc.sweep(400.0 * pitch, 1800.0 * pitch, duration),
        high=osc.sweep(1600.0 * pitch, 6000.0 * pitch, duration),
        sr=sr,
    )
    air = env.apply(air, env.adsr(duration, 0.1, 0.05, 0.7, 0.1, sr))
    tone = env.apply(
        osc.triangle(osc.sweep(520.0 * pitch, 1040.0 * pitch, duration * 0.8), duration, sr),
        env.percussive(duration, tau=0.1, attack=0.005, sr=sr),
    )
    return _finish(mix(tone, air, gains=(0.8, 0.35)), sr, 0.75)


def menu_close(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """メニューを閉じる音。開く音を逆向きにしたもの。"""
    rng = random.Random(seed)
    duration = 0.24
    air = fx.bandpass(
        osc.noise(duration, sr, rng=rng),
        low=osc.sweep(1800.0 * pitch, 400.0 * pitch, duration),
        high=osc.sweep(6000.0 * pitch, 1600.0 * pitch, duration),
        sr=sr,
    )
    air = env.apply(air, env.percussive(duration, tau=0.08, attack=0.004, sr=sr))
    tone = env.apply(
        osc.triangle(osc.sweep(1040.0 * pitch, 460.0 * pitch, duration * 0.8), duration, sr),
        env.percussive(duration, tau=0.09, attack=0.004, sr=sr),
    )
    return _finish(mix(tone, air, gains=(0.8, 0.35)), sr, 0.75)


def teleport(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """ワープ音。揺らしながら上昇し、ディレイで消える。"""
    duration = 0.5
    base = osc.sweep(200.0 * pitch, 2400.0 * pitch, duration)
    freq = osc.vibrato(base, rate=22.0, depth=0.08)
    tone = osc.render("pulse12", freq, duration, sr)
    tone = env.apply(tone, env.adsr(duration, 0.02, 0.05, 0.8, 0.2, sr))
    return _finish(fx.delay(tone, time=0.09, feedback=0.45, wet=0.4, sr=sr, tail=0.6), sr, 0.8)


def shield(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """防御・バリア。金属質の和音を震わせて張る。"""
    duration = 0.7
    tone = mix(
        *(
            osc.sine(440.0 * ratio * pitch, duration, sr)
            for ratio in (1.0, 1.5, 2.4, 3.3)  # 倍音列から外して金属感を出す
        )
    )
    tone = fx.tremolo(tone, rate=14.0, depth=0.35, sr=sr)
    tone = env.apply(tone, env.adsr(duration, 0.03, 0.15, 0.55, duration * 0.5, sr))
    return _finish(fx.reverb(tone, room=0.7, wet=0.25, sr=sr, tail=0.4), sr, 0.8)


def water_drop(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0) -> list[float]:
    """水滴。急激に上がる短い正弦波。"""
    duration = 0.22
    freq = osc.sweep(500.0 * pitch, 2200.0 * pitch, duration * 0.35)
    tone = osc.sine(freq, duration, sr)
    tone = env.apply(tone, env.percussive(duration, tau=0.05, attack=0.002, sr=sr))
    return _finish(fx.reverb(tone, room=0.6, wet=0.3, sr=sr, tail=0.35), sr, 0.75)


def alarm(sr: int = SAMPLE_RATE, seed: int | None = None, pitch: float = 1.0, repeats: int = 3) -> list[float]:
    """警報音。2音を交互に繰り返す。"""
    step = 0.18
    out: list[float] = []
    for _ in range(max(1, repeats)):
        for freq in (880.0, 587.33):
            tone = osc.square(freq * pitch, step, sr, duty=0.5)
            tone = env.apply(tone, env.adsr(step, 0.006, 0.02, 0.85, 0.05, sr))
            out = concat(out, tone)
        out = concat(out, silence(0.05, sr))
    return _finish(out, sr, 0.8)


PRESETS: dict[str, SfxFunc] = {
    "coin": coin,
    "pickup": pickup,
    "powerup": powerup,
    "level_up": level_up,
    "heal": heal,
    "jump": jump,
    "land": land,
    "footstep": footstep,
    "dash": dash,
    "swing": swing,
    "whoosh": whoosh,
    "laser": laser,
    "charge": charge,
    "hit": hit,
    "explosion": explosion,
    "shatter": shatter,
    "thunder": thunder,
    "engine": engine,
    "blip": blip,
    "select": select,
    "error": error,
    "menu_open": menu_open,
    "menu_close": menu_close,
    "teleport": teleport,
    "shield": shield,
    "water_drop": water_drop,
    "alarm": alarm,
}


MIN_SAMPLE_RATE = 4000
"""これより低いと、可聴域の音がほとんど残らない。"""


def generate(name: str, sr: int = SAMPLE_RATE, seed: int | None = None, **params) -> list[float]:
    """プリセット名から効果音を生成する。"""
    try:
        preset = PRESETS[name]
    except KeyError:
        raise ValueError(f"unknown sfx preset: {name!r} (available: {', '.join(sorted(PRESETS))})") from None
    if sr < MIN_SAMPLE_RATE:
        raise ValueError(f"sample rate must be >= {MIN_SAMPLE_RATE}Hz (指定: {sr})")
    pitch = params.get("pitch", 1.0)
    if pitch <= 0.0:
        # 0 以下だと周波数が 0 か負になり、鳴っているのに音がしない状態になる。
        raise ValueError(f"pitch must be > 0 (指定: {pitch})")
    return preset(sr=sr, seed=seed, **params)


def variations(
    name: str,
    count: int = 4,
    sr: int = SAMPLE_RATE,
    seed: int | None = None,
    spread: float = 0.12,
    **params,
) -> list[list[float]]:
    """同じ効果音の少しずつ違う版をまとめて作る。

    足音や打撃のように何度も鳴る音は、毎回まったく同じだと耳につく。
    音程を ``spread`` の範囲で散らし、ノイズの種も1つずつ変えることで、
    同じ性格のまま重複して聞こえない一組を作る。
    """
    if count < 1:
        raise ValueError(f"count must be >= 1 (指定: {count})")
    if spread < 0.0:
        raise ValueError(f"spread must be >= 0 (指定: {spread})")
    if name not in PRESETS:
        raise ValueError(f"unknown sfx preset: {name!r} (available: {', '.join(sorted(PRESETS))})")

    rng = random.Random(seed)
    base_pitch = params.pop("pitch", 1.0)
    out = []
    for index in range(count):
        # 1つ目は指定どおりの音にしておき、2つ目以降を散らす。
        factor = 1.0 if index == 0 else rng.uniform(1.0 - spread, 1.0 + spread)
        out.append(
            generate(name, sr=sr, seed=rng.randrange(1 << 30), pitch=base_pitch * factor, **params)
        )
    return out


def available() -> list[str]:
    """使えるプリセット名を並べる。"""
    return sorted(PRESETS)
