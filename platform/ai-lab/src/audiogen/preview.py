"""試聴ページの生成。

生成した WAV は、並べて聴き比べられないと良し悪しが判断できない。
出力ディレクトリを走査して、波形つきの一覧を1枚の HTML にまとめる。

音声ファイルは埋め込まず相対パスで参照するだけなので、ページ自体は
音源に比べてごく小さい。ブラウザで開けばその場で再生できる。
"""

from __future__ import annotations

import html
import os
import wave
from dataclasses import dataclass

WAVEFORM_COLUMNS = 300
"""波形を何列に分けて描くか。"""

WAVEFORM_HEIGHT = 96
"""波形の描画高さ。座標を整数に丸めても粗く見えない程度に取ってある。"""


@dataclass(frozen=True)
class Track:
    """試聴ページに並べる1曲ぶんの情報。"""

    path: str
    """ページからの相対パス。"""
    name: str
    seconds: float
    sample_rate: int
    channels: int
    peaks: list[tuple[float, float]]
    """列ごとの (下端, 上端)。-1.0〜1.0。"""

    @property
    def label(self) -> str:
        return "stereo" if self.channels == 2 else "mono"


def read_peaks(path: str, columns: int = WAVEFORM_COLUMNS) -> Track:
    """WAV を読んで、波形の概形と基本情報を取り出す。"""
    with wave.open(path, "rb") as fp:
        channels = fp.getnchannels()
        width = fp.getsampwidth()
        sr = fp.getframerate()
        frames = fp.getnframes()
        raw = fp.readframes(frames)

    if width != 2:
        raise ValueError(f"{path}: only 16-bit WAV files are supported")

    total = len(raw) // 2
    # 左右がある場合は片チャンネルだけ見れば概形は足りる。
    step = channels
    samples = total // step
    block = max(1, samples // max(1, columns))

    peaks: list[tuple[float, float]] = []
    for start in range(0, samples, block):
        low = high = 0.0
        for index in range(start, min(start + block, samples)):
            offset = index * step * 2
            value = int.from_bytes(raw[offset : offset + 2], "little", signed=True) / 32768.0
            low = min(low, value)
            high = max(high, value)
        peaks.append((low, high))

    return Track(
        path=os.path.basename(path),
        name=os.path.splitext(os.path.basename(path))[0],
        seconds=frames / sr if sr else 0.0,
        sample_rate=sr,
        channels=channels,
        peaks=peaks[:columns],
    )


def _waveform_svg(track: Track) -> str:
    """上端をたどって折り返し、下端を戻る1本の塗りつぶしパスとして描く。

    列ごとに線を引くと要素数がそのままファイルサイズになるので、
    1トラック1パスにまとめ、座標も整数に丸めている。
    """
    half = WAVEFORM_HEIGHT / 2
    width = max(1, len(track.peaks))
    tops, bottoms = [], []
    for index, (low, high) in enumerate(track.peaks):
        top = round(half - high * half)
        bottom = round(half - low * half)
        if bottom - top < 1:  # 無音の区間でも中心線が見えるように
            top, bottom = round(half) - 1, round(half) + 1
        tops.append(f"{index},{top}")
        bottoms.append(f"{index},{bottom}")
    path = "M" + " ".join(tops) + " " + " ".join(reversed(bottoms)) + "Z"
    return (
        f'<svg class="wave" viewBox="0 0 {width} {WAVEFORM_HEIGHT}" '
        f'preserveAspectRatio="none" aria-hidden="true"><path d="{path}"/></svg>'
    )


_STYLE = """
:root { color-scheme: light dark; --fg: #1a1a1a; --muted: #6b7280; --bg: #fafaf9;
        --card: #ffffff; --line: #e5e7eb; --wave: #3b6ea5; }
@media (prefers-color-scheme: dark) {
  :root { --fg: #e8e8e6; --muted: #9ca3af; --bg: #16181c; --card: #1f2227;
          --line: #303540; --wave: #6ea8dc; }
}
* { box-sizing: border-box; }
body { margin: 0; padding: 2rem 1.5rem 4rem; background: var(--bg); color: var(--fg);
       font: 15px/1.6 system-ui, -apple-system, "Segoe UI", "Helvetica Neue", sans-serif; }
main { max-width: 60rem; margin: 0 auto; }
h1 { font-size: 1.4rem; margin: 0 0 .25rem; }
p.lead { color: var(--muted); margin: 0 0 2rem; }
h2 { font-size: 1rem; text-transform: uppercase; letter-spacing: .06em;
     color: var(--muted); margin: 2.5rem 0 .75rem; }
.card { background: var(--card); border: 1px solid var(--line); border-radius: 10px;
        padding: .85rem 1rem; margin-bottom: .6rem; }
.head { display: flex; align-items: baseline; gap: .75rem; flex-wrap: wrap; }
.name { font-weight: 600; }
.meta { color: var(--muted); font-size: .85rem; margin-left: auto; }
.wave { width: 100%; height: 48px; display: block; margin: .5rem 0 .4rem; }
.wave path { fill: var(--wave); }
audio { width: 100%; height: 32px; }
footer { color: var(--muted); font-size: .85rem; margin-top: 3rem; }
"""


def _card(track: Track) -> str:
    return (
        '<div class="card">'
        f'<div class="head"><span class="name">{html.escape(track.name)}</span>'
        f'<span class="meta">{track.seconds:.2f}s / {track.sample_rate}Hz / {track.label}</span></div>'
        f"{_waveform_svg(track)}"
        f'<audio controls preload="none" src="{html.escape(track.path)}"></audio>'
        "</div>"
    )


def build_page(tracks: list[Track], title: str = "audiogen preview") -> str:
    """試聴ページの HTML を組み立てる。"""
    groups: dict[str, list[Track]] = {}
    for track in tracks:
        # ファイル名の頭で BGM と効果音をゆるく分けて並べる。
        kind = "BGM" if track.name.startswith("bgm") else "効果音"
        groups.setdefault(kind, []).append(track)

    sections = []
    for kind in ("BGM", "効果音"):
        items = groups.get(kind)
        if not items:
            continue
        cards = "".join(_card(track) for track in items)
        sections.append(f"<h2>{kind} ({len(items)})</h2>{cards}")

    return (
        "<!doctype html>\n"
        '<html lang="ja"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>{html.escape(title)}</title><style>{_STYLE}</style></head><body><main>"
        f"<h1>{html.escape(title)}</h1>"
        f'<p class="lead">{len(tracks)} 個の音声。波形は概形で、再生は元の WAV を参照している。</p>'
        f'{"".join(sections)}'
        "<footer>audiogen で生成 — 同じ設定と seed からいつでも作り直せる。</footer>"
        "</main></body></html>\n"
    )


def collect(directory: str) -> list[Track]:
    """ディレクトリ内の WAV を名前順に読み込む。"""
    names = sorted(name for name in os.listdir(directory) if name.lower().endswith(".wav"))
    return [read_peaks(os.path.join(directory, name)) for name in names]


def write_preview(directory: str, filename: str = "index.html", title: str | None = None) -> str:
    """ディレクトリ内の WAV から試聴ページを書き出し、そのパスを返す。"""
    tracks = collect(directory)
    if not tracks:
        raise ValueError(f"{directory}: no .wav files found")
    path = os.path.join(directory, filename)
    with open(path, "w", encoding="utf-8") as fp:
        fp.write(build_page(tracks, title or f"audiogen preview — {os.path.basename(os.path.abspath(directory))}"))
    return path
