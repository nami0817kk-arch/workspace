"""エピソードを書き出す前の自動点検(数秒): 字幕の読みやすさ・話の筋・リズム・長さ。

    python -m stickfig review scenes/episodes/ep_revenge.yaml

- 字幕: 吹き出しは 22 文字まで(2行まで)、ナレーションは 44 文字まで。読む時間は 1 文字 0.10 秒+0.5 秒(最大2秒。実際の秒で数える)
- 筋: 倒れている(face: ko)人物が、台詞をしゃべっていないか(最後の一言は台詞に last_words: true を付ければ許す)
- リズム: 場面ごとの見積もり(rhythm.plan_metrics)が参考6本の範囲に入っているか(目安)
- 長さ: 全体の秒数(ショートは 60 秒まで)
"""
from __future__ import annotations

from typing import List

from . import fight, plan as planmod, rhythm

LIMIT = dict(say=22, narr=44, shout=14)


def check_captions(caps: List[dict], tau_end: float) -> List[str]:
    """吹き出し・ナレーション・叫びの、長さと読む時間。問題の文を返す(空なら問題なし)。"""
    bad = []
    for c in caps:
        k = c.get("kind", "say")
        n = len(c["text"])
        if n > LIMIT.get(k, 30):
            bad.append(f"「{c['text']}」は長い({n}文字。{k}は {LIMIT.get(k, 30)} 文字まで)")
        need = 0.5 + 0.10 * n
        if c["t1"] - c["t0"] < min(need, 2.0) - 0.2:
            bad.append(f"「{c['text']}」は出ている時間が短い({c['t1'] - c['t0']:.1f}秒。読むのに約 {min(need, 2.0):.1f}秒)")
        if c["t1"] > tau_end + 0.05:
            bad.append(f"「{c['text']}」が場面の終わり({tau_end:.1f}秒)をはみ出す")
    return bad


def check_story(plan: dict) -> List[str]:
    """倒れている人物がしゃべらない。"""
    bad = []
    for c in plan.get("scene", {}).get("captions") or []:
        if c.get("kind", "say") != "say" or c.get("last_words"):       # last_words: 倒れた人物の最後の一言は、筋として許す
            continue
        f = next((i for i, fr in enumerate(plan["frames"]) if fr["tau"] >= c["t0"] + 0.2), None)
        if f is not None and plan["frames"][f]["actors"][c["who"]].get("face") == "ko":
            bad.append(f"{c['who']} は倒れているのに「{c['text']}」としゃべる({c['t0']:.1f}秒)")
    return bad


def _real_time_captions(plan: dict) -> List[dict]:
    """字幕の時刻を、設計時間(tau)から、動画の実際の秒(スロー・早送り・テンポを反映)に直す。"""
    fps, n = plan["fps"], plan["n"]

    def real(t: float) -> float:
        for i, fr in enumerate(plan["frames"]):
            if fr["tau"] >= t:
                return i / fps
        return n / fps
    return [dict(c, t0=real(c["t0"]), t1=real(c["t1"])) for c in plan.get("scene", {}).get("captions") or []]


def review_episode(ep: dict) -> dict:
    notes, total = [], 0.0
    for i, it in enumerate(ep["items"]):
        if "card" in it:
            total += float(it["card"].get("dur", 2.0))
            if len(it["card"]["text"]) > 12:
                notes.append(f"区間{i + 1} カード「{it['card']['text']}」は長い(12文字まで)")
            continue
        if "shot" in it:                                 # 手付けのカット(点検は animecheck。ここでは長さとリズムの目安だけ)
            from .episode import load_shot
            sc = load_shot(it["shot"])
        elif isinstance(it["scene"], str):                 # 台本ファイルの指定(fight: / skit: はその中で展開される)
            sc = planmod.load_scene(it["scene"])
        else:
            sc = fight.expand(dict(it["scene"]))
            if "skit" in sc:
                from . import skit
                sc = skit.expand(sc)
        planmod.validate_scene(sc)
        pl = planmod.build_plan(sc)
        total += pl["n"] / pl["fps"]
        real = _real_time_captions(pl)
        for m in check_captions(real, pl["n"] / pl["fps"]) + check_story(pl):
            notes.append(f"区間{i + 1} {sc.get('name')}: {m}")
        met = rhythm.plan_metrics(pl)
        for k in ("cuts_per_min", "dup_frame_ratio", "flash_groups_per_min"):
            lo, hi, label = rhythm.REFERENCE[k]
            if not lo <= met[k] <= hi:
                notes.append(f"(目安)区間{i + 1} {sc.get('name')}: {label} {met[k]}(参考 {lo}〜{hi})")
    hard = [n for n in notes if not n.startswith("(目安)")]
    return dict(seconds=round(total, 1), notes=notes, ok=not hard)


def report(ep: dict) -> str:
    r = review_episode(ep)
    out = [f"# エピソードの自動点検", "", f"- 長さ: {r['seconds']} 秒" + ("(ショートは 60 秒まで)" if r["seconds"] > 60 else "(ショートに収まる)"),
           f"- 判定: {'問題なし' if r['ok'] else '直すところあり'}", ""]
    out += [f"- {n}" for n in r["notes"]] or ["- 指摘なし"]
    return chr(10).join(out)
