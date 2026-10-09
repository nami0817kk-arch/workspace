# -*- coding: utf-8 -*-
"""台本の行を読み上げて1本の音声にする。

台本は1行ずつ「話者: 本文」。話者に括弧で強さを付けられる。

    語り: ガソリン1リットル、175円。
    語り(強): 驚くかもしれませんが、半分近くが税金です。
    聞き: えっ、半分もですか。

強さを書かなければ「ふつう」。段階は config.yaml の tones で決める。
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.parse
import urllib.request
import wave
from pathlib import Path

import yaml

LINE = re.compile(r"^\s*(?P<who>[^\s:：(（]+)\s*(?:[（(](?P<tone>[^）)]+)[）)])?\s*[:：]\s*(?P<text>.+?)\s*$")


def load_config(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def parse_yaml_script(data: dict) -> list[tuple[str, str, str]]:
    """YAML の台本（sections → lines）を (話者, 強さ, 本文) に並べ直す。"""
    out: list[tuple[str, str, str]] = []
    for sec in data.get("sections", []):
        for line in sec.get("lines", []):
            if not isinstance(line, dict) or len(line) != 1:
                raise ValueError(f"読めない行です（節 {sec.get('no')}）: {line}")
            key, text = next(iter(line.items()))
            m = re.match(r"^(?P<who>[^\s(（]+)\s*(?:[（(](?P<tone>[^）)]+)[）)])?$", key)
            if not m:
                raise ValueError(f"話者の書き方が読めません: {key}")
            out.append((m["who"], m["tone"] or "ふつう", str(text)))
    return out


def parse_script(text: str) -> list[tuple[str, str, str]]:
    """「話者(強さ): 本文」の行を (話者, 強さ, 本文) にする。"""
    out: list[tuple[str, str, str]] = []
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        m = LINE.match(raw)
        if not m:
            raise ValueError(f"読めない行です: {raw}")
        out.append((m["who"], m["tone"] or "ふつう", m["text"]))
    return out


def synth(url: str, text: str, style_id: int, **params) -> bytes:
    q = urllib.request.Request(
        f"{url}/audio_query?text={urllib.parse.quote(text)}&speaker={style_id}", method="POST")
    with urllib.request.urlopen(q, timeout=120) as res:
        query = json.load(res)
    query.update(params)
    body = json.dumps(query).encode()
    s = urllib.request.Request(f"{url}/synthesis?speaker={style_id}", data=body,
                               headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(s, timeout=300) as res:
        return res.read()


def params_for(cfg: dict, who: str, tone: str) -> tuple[int, dict]:
    person = cfg["cast"][who]
    if person.get("style_id") is None:
        raise SystemExit(f"{who} の声がまだ決まっていません（config.yaml の style_id が空です）")
    base = dict(speedScale=person["speed"], pitchScale=person["pitch"],
                intonationScale=person["intonation"],
                tempoDynamicsScale=person["tempo_dynamics"],
                prePhonemeLength=person["pre"], postPhonemeLength=person["post"])
    t = cfg["tones"].get(tone)
    if t is None:
        raise SystemExit(f"強さ「{tone}」は config.yaml の tones にありません")
    # tone_strength … 強さの効き（1 で tones の値そのまま、0.3 なら差の3割だけ）
    k = float(person.get("tone_strength", 1.0))
    if "intonation" in t:
        base["intonationScale"] = person["intonation"] + (t["intonation"] - 1.0) * k
    if "tempo_dynamics" in t: base["tempoDynamicsScale"] = t["tempo_dynamics"]
    if "speed" in t:          base["speedScale"] = person["speed"] + (t["speed"] - 1.0) * k
    if "max_intonation" in person:
        base["intonationScale"] = min(base["intonationScale"], person["max_intonation"])
    base["outputSamplingRate"] = int(cfg.get("sample_rate", 44100))
    return person["style_id"], base


def engine_for(cfg: dict, who: str) -> str:
    """その人の声を作るエンジンの URL（人ごとの指定が無ければ共通のもの）。"""
    return cfg["cast"][who].get("engine_url") or cfg["engine_url"]


TIMING_URL = "http://127.0.0.1:50021"   # 音ごとの長さは VOICEVOX に聞く（AivisSpeech は 0 を返す）
TIMING_ID = 21


def timing_query(text: str) -> dict:
    """その文の、音ごとの長さ（口パク用）。VOICEVOX の audio_query をそのまま返す。"""
    q = urllib.request.Request(
        f"{TIMING_URL}/audio_query?text={urllib.parse.quote(text)}&speaker={TIMING_ID}", method="POST")
    with urllib.request.urlopen(q, timeout=120) as res:
        return json.load(res)


def join_wavs(files: list[Path], dst: Path, gap_sec=0.25) -> None:
    """声をつなぐ。gap_sec は一律の秒数か、**行ごとの秒数の並び**。

    画面は行ごとに間を変えているのに、声を一律の間でつなぐと、行を重ねるほど
    口と声がずれていく（2026-10-10 に見つけた）。
    """
    gaps = gap_sec if isinstance(gap_sec, (list, tuple)) else [gap_sec] * len(files)
    with wave.open(str(files[0]), "rb") as w0:
        params = w0.getparams()
    unit = params.sampwidth * params.nchannels
    with wave.open(str(dst), "wb") as out:
        out.setparams(params)
        for f, g in zip(files, gaps):
            with wave.open(str(f), "rb") as w:
                out.writeframes(w.readframes(w.getnframes()))
            out.writeframes(b"\x00" * int(params.framerate * g) * unit)


def main() -> int:
    ap = argparse.ArgumentParser(description="台本を読み上げて音声にする")
    ap.add_argument("script", help="台本（1行ずつ「話者: 本文」）")
    ap.add_argument("-o", "--out", default="out/voice.wav", help="書き出す先")
    ap.add_argument("--config", default="config.yaml")
    ap.add_argument("--keep", action="store_true", help="行ごとの音声も残す")
    args = ap.parse_args()

    cfg = load_config(Path(args.config))
    src = Path(args.script)
    if src.suffix in (".yaml", ".yml"):
        data = yaml.safe_load(src.read_text(encoding="utf-8"))
        lines = parse_yaml_script(data)
        print(f"■ {data.get('title', '(題名なし)')}　節 {len(data.get('sections', []))}　行 {len(lines)}")
    else:
        lines = parse_script(src.read_text(encoding="utf-8"))
    out = Path(args.out); out.parent.mkdir(parents=True, exist_ok=True)
    work = out.parent / "lines"; work.mkdir(exist_ok=True)

    made: list[Path] = []
    for i, (who, tone, text) in enumerate(lines):
        style_id, params = params_for(cfg, who, tone)
        p = work / f"{i:03d}_{who}_{tone}.wav"
        p.write_bytes(synth(engine_for(cfg, who), text, style_id, **params))
        made.append(p)
        print(f"  {i+1:>3}/{len(lines)}  {who}({tone})  {text[:28]}")
    join_wavs(made, out)
    if not args.keep:
        for p in made:
            p.unlink()
        work.rmdir()
    print(f"書き出しました: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
