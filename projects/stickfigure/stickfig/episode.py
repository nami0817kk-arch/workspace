"""エピソード: 複数の場面(戦い)と、場面カード(タイトル・「一か月後」など)を、1本の動画にまとめる。

episode.yaml:
    name: ep1
    mood_cards: sad              # カードの BGM(none で無音)
    items:
    - card: {text: "第1話 敗北", sub: "最強の剣士ミドリ", dur: 2.2}
    - scene: scenes/fight_default.yaml          # 台本ファイル
    - scene: {name: s2, fight: {...}}           # その場に書いた台本(fight: の指定でもよい)
    - card: {text: "一か月後", dur: 1.6, style: time}

各場面は build_scene でそれぞれ点検・書き出しし、同じ設定の mp4(H.264 + AAC 44.1kHz ステレオ)に揃えて、ffmpeg で連結する。
"""
from __future__ import annotations

import subprocess
import wave
from pathlib import Path
from typing import Optional

import numpy as np
import yaml
from PIL import Image, ImageDraw

from . import anime, camera, fight, plan as planmod, sfx

W, H = camera.W, camera.H
LOUDNORM = "loudnorm=I=-16:TP=-2:LRA=12"       # 音量をそろえ、ピークの頭打ち(YouTube は約 -14 LUFS に合わせる。ピークが 0 を越えると再エンコードで歪む)


def load_shot(path) -> dict:
    """手付けのカット(tools/shots/*.py)の場面: build() か build_scene() の返す場面(タプルなら先頭)。"""
    import importlib.util
    sp = importlib.util.spec_from_file_location("_shot_" + Path(path).stem, path)
    mod = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(mod)
    got = (getattr(mod, "build", None) or mod.build_scene)()
    return got[0] if isinstance(got, tuple) else got


def apply_vertical(scene: dict) -> dict:
    """縦(9:16)で書き出す設定。手付けの場面(vertical_zoom がある)は、細い枠(横の 1/3)に 2 人が収まるようカメラを引き、
    切り出しをカメラの中心に固定し、人物が画面の下寄りに来るようカメラの目線を上げる(上が空き、下の床だけが広がるのを避ける)。"""
    scene["output"] = {"aspect": "vertical"}
    vz = scene.get("vertical_zoom")
    if vz:
        scene["cam_zoom"] = float(scene.get("cam_zoom", 1.0)) * float(vz)
        scene["output"]["crop"] = "camera"
        for sh in scene.get("shots", []):
            sh["target_z"] = float(sh.get("target_z", 1.0)) + float(scene.get("vertical_lift", 1.4))
    return scene


def load_episode(path) -> dict:
    ep = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    if "story" in ep:                         # 物語の型(story.py)から組む。ほかのキーで上書き
        from . import story
        base = story.build_story(ep["story"])
        base.update({k: v for k, v in ep.items() if k != "story"})
        ep = base
    return ep


def _card_frame(text: str, sub: str, style: str, color, alpha: float, size=(W, H)) -> Image.Image:
    W, H = size
    k = 0.6 if W < H else 1.0                 # 縦画面は文字を小さめに
    bg = Image.new("RGB", (W, H), tuple(color))
    img = bg.copy()
    d = ImageDraw.Draw(img)
    if style == "time":          # 場面の転換: 右下に小さく
        f = anime._font(int(64 * k))
        tw = d.textlength(text, font=f)
        d.text((W - tw - 60, H - 140), text, font=f, fill=(235, 235, 235))
    else:
        f = anime._font(int(110 * k))
        tw = d.textlength(text, font=f)
        d.text(((W - tw) / 2, H * 0.36), text, font=f, fill=(255, 255, 255), stroke_width=6, stroke_fill=(10, 10, 16))
        if sub:
            f2 = anime._font(int(46 * k))
            tw2 = d.textlength(sub, font=f2)
            d.text(((W - tw2) / 2, H * 0.36 + 150 * k), sub, font=f2, fill=(220, 220, 230))
    return Image.blend(bg, img, max(0.0, min(1.0, alpha)))


def _write_wav(path: Path, snd: np.ndarray) -> None:
    pcm = (np.stack([snd, snd], axis=1) * 32767 * 0.8).clip(-32767, 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sfx.SR)
        w.writeframes(pcm.tobytes())


def card_segment(c: dict, out: Path, ff: str, mood: Optional[str], fps: int = 30, size=(W, H)) -> Path:
    out.mkdir(parents=True, exist_ok=True)
    dur = float(c.get("dur", 2.0))
    n = int(dur * fps)
    color = c.get("color", (10, 10, 18))
    for p in out.glob("*.png"):
        p.unlink()
    for i in range(n):
        t = i / fps
        a = min(1.0, t / 0.3, (dur - t) / 0.3)
        _card_frame(c["text"], c.get("sub", ""), c.get("style", "title"), color, a, size).save(out / f"{i + 1:04d}.png")
    silent = out / "card_silent.mp4"
    subprocess.run([ff, "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(out / "%04d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", str(silent)], check=True)
    snd = sfx.bgm(dur, mood, 5) * 0.5 if mood and mood != "none" else np.zeros(int(sfx.SR * dur))
    fade = int(sfx.SR * 0.3)
    snd[:fade] *= np.linspace(0, 1, fade)
    snd[-fade:] *= np.linspace(1, 0, fade)
    wav = out / "card.wav"
    _write_wav(wav, snd)
    mp4 = out / "card.mp4"
    subprocess.run([ff, "-y", "-loglevel", "error", "-i", str(silent), "-i", str(wav), "-c:v", "copy", "-c:a", "aac",
                    "-b:a", "192k", "-ar", "44100", "-ac", "2", "-shortest", str(mp4)], check=True)
    return mp4


def _passing_variant(sc: dict, tries: int = 6) -> dict:
    """fight 指定の場面が点検に落ちるとき、seed を +1 ずつずらして通るものを返す(無ければ元のまま)。
    random の技・連打の clip の組み合わせが seed で変わるので、たいてい数回で通る。"""
    from . import qa
    if "fight" not in sc or not isinstance(sc.get("fight"), dict):
        return sc
    base_seed = int(sc["fight"].get("seed", 0) or 0)
    for k in range(tries):
        cand = dict(sc, fight=dict(sc["fight"], seed=base_seed + k)) if (k or "seed" in sc["fight"]) else sc
        try:
            scene = fight.expand(dict(cand), verify=False)
            pl = planmod.build_plan(scene)
        except Exception:                                  # clips が無い等。点検できない環境ではそのまま
            return sc
        if qa.run_gate(pl, scene.get("qa"))["passed"]:
            if k:
                print(f"  場面 {sc.get('name', '')}: seed {base_seed} は点検に落ちるので {base_seed + k} にした")
            return cand
    return sc


def build_episode(ep: dict, out: Path, reuse_figs: bool = False, force: bool = False, vertical: bool = False, preview: bool = False) -> Optional[Path]:
    from . import cli
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    from . import review
    r = review.review_episode(ep)                       # 書き出す前の自動点検(字幕の読みやすさ・話の筋)。直すところがあれば止める
    for n in r["notes"]:
        print("  " + n)
    if not r["ok"] and not force:
        print("自動点検で直すところがあるので、書き出さずに止める(--force で続ける)")
        return None
    ff = cli.find_ffmpeg()
    segs = []
    for i, it in enumerate(ep["items"]):
        seg_dir = out / f"seg{i + 1:02d}"
        if "card" in it:
            card = dict(it["card"])
            if "color" not in card:                                   # カードの色: 次の場面の舞台の色を暗くしたもの(2D の舞台とつながる)
                nxt = next((x["scene"] for x in ep["items"][i + 1:] if "scene" in x), None)
                if nxt is not None:
                    try:
                        from . import look
                        scn = fight.expand(dict(nxt)) if not isinstance(nxt, str) else planmod.load_scene(nxt)
                        sky = look.FLAT_THEMES.get(scn.get("stage", {}).get("theme", "cave"), look.FLAT_THEMES["cave"])["sky"]
                        card["color"] = tuple(int(c * 0.35) for c in sky)
                    except Exception:
                        pass
            segs.append(card_segment(card, seg_dir, ff, ep.get("mood_cards", "sad"), size=((720, 1280) if vertical else (W, H))))
            continue
        scene = load_shot(it["shot"]) if "shot" in it else None   # 手付けのカット(tools/shots/*.py)
        sc = it.get("scene")
        if scene is not None:
            pass
        elif isinstance(sc, str):
            scene = planmod.load_scene(sc)
        else:
            sc = _passing_variant(sc)                 # fight の場面は、点検に落ちる seed なら少しずらして通るものにする(量産で 1 場面のために話ごと止まらない)
            scene = fight.expand(dict(sc), verify=True)
            if "skit" in scene:                       # 物語の小話(skit:)もその場に書ける
                from . import skit
                scene = skit.expand(scene)
            planmod.validate_scene(scene)
        if vertical:
            apply_vertical(scene)
        if preview:                                   # 下書き: Blender を使わない線画(数秒/場面)。台本・字幕・カメラ・音のタイミングを先に見る
            from . import preview as prev
            segs.append(prev.preview_scene(scene, seg_dir / f"{scene.get('name', 'scene')}_prev.mp4", ff))
            continue
        mp4 = cli.build_scene(scene, seg_dir, reuse_figs, force, quiet=True)
        if mp4 is None:
            print(f"場面 {i + 1} が点検で止まった")
            return None
        segs.append(mp4)
    lst = out / "concat.txt"
    lst.write_text("".join(f"file '{Path(s).resolve().as_posix()}'\n" for s in segs), encoding="utf-8")
    final = out / f"{ep.get('name', 'episode')}{'_preview' if preview else ''}.mp4"
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-crf", "18", "-af", LOUDNORM, "-c:a", "aac", "-b:a", "192k", "-ar", "44100", "-ac", "2", str(final)], check=True)
    print(f"\n【エピソード】{final}({len(segs)} 区間)")
    return final
