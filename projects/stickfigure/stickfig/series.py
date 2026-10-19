"""シリーズ: 何本ものエピソードを、物語の型・名前・色・seed を変えて、まとめて作る(チャンネルの量産)。

    python -m stickfig series --n 5 --out out/series --seed 100 [--vertical] [--build]

--build なしは、各エピソードの指定(yaml)だけを out/series/specs/ に書く(数秒)。--build で、順に書き出してサムネ・投稿の下書きまで作る(1本 約3〜8分)。
"""
from __future__ import annotations

from pathlib import Path
from typing import List

import yaml

from . import story

# (主人公の名前, 色, 相手の名前, 色)
CAST = [("ミドリ", story.GREEN, "アカ", story.RED), ("アオイ", story.BLUE, "ムラサキ", story.PURPLE),
        ("ダイダイ", [0.95, 0.55, 0.1], "ハイ", story.GRAY), ("キイロ", [0.9, 0.8, 0.1], "クロ", [0.12, 0.12, 0.16])]
ARC_ORDER = ["revenge", "duel", "protect", "mentor", "tournament"]
TITLES = dict(revenge="雪辱戦", tournament="勝ち上がり", duel="一騎打ち", protect="守る者", mentor="師の教え")


def plan_series(n: int, seed: int = 100) -> List[dict]:
    out = []
    for i in range(n):
        arc = ARC_ORDER[i % len(ARC_ORDER)]
        hero, hc, rival, rc = CAST[(i // len(ARC_ORDER) + i) % len(CAST)]
        sd = seed + i
        out.append(dict(name=f"ep{i + 1:02d}_{arc}", title=TITLES[arc],
                        story=dict(arc=arc, hero=hero, rival=rival, hero_color=list(hc), rival_color=list(rc), seed=sd, name=f"ep{i + 1:02d}_{arc}")))
    return out


def write_specs(n: int, out: Path, seed: int = 100) -> List[Path]:
    specs = out / "specs"
    specs.mkdir(parents=True, exist_ok=True)
    paths = []
    for s in plan_series(n, seed):
        p = specs / f"{s['name']}.yaml"
        p.write_text(yaml.safe_dump(dict(story=s["story"], title=s["title"]), allow_unicode=True, sort_keys=False), encoding="utf-8")
        paths.append(p)
    return paths


def build_series(n: int, out: Path, seed: int = 100, vertical: bool = False, reuse: bool = False, compile_all: bool = False) -> List[Path]:
    from . import episode, kit
    out = Path(out)
    done = []
    for p in write_specs(n, out, seed):
        spec = yaml.safe_load(p.read_text(encoding="utf-8"))
        ep = episode.load_episode(p)
        d = out / p.stem
        mp4 = episode.build_episode(ep, d, reuse, False, vertical)
        if mp4 is None:
            continue
        st = spec["story"]
        kit.make_kit(d, spec["title"], st["hero"], st["rival"], st["arc"])
        done.append(mp4)
    if compile_all and done:
        compile_series(done, out, vertical)
    return done


def compile_series(mp4s: List[Path], out: Path, vertical: bool = False, title: str = "棒人間バトル") -> Path:
    """何本かのエピソードを、冒頭の題名カードつきで 1 本につなぐ(長尺用。各エピソードは同じ設定の mp4 なので再エンコードして連結)。"""
    import subprocess
    from . import cli, episode
    out = Path(out)
    ff = cli.find_ffmpeg()
    size = (720, 1280) if vertical else (1280, 720)
    card = episode.card_segment(dict(text=title, sub=f"全{len(mp4s)}話", dur=2.4), out / "_card_all", ff, "calm", size=size)
    lst = out / "concat_all.txt"
    lines = [f"file '{Path(x).resolve().as_posix()}'" for x in [card] + list(mp4s)]
    lst.write_text(chr(10).join(lines) + chr(10), encoding="utf-8")
    final = out / ("all_vertical.mp4" if vertical else "all.mp4")
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
                    "-af", episode.LOUDNORM, "-c:a", "aac", "-b:a", "192k", "-ar", "44100", "-ac", "2", str(final)], check=True)
    print(f"【まとめ】{final}({len(mp4s)} 話)")
    return final
