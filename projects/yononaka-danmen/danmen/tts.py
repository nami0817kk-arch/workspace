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
    if "intonation" in t:     base["intonationScale"] = t["intonation"]
    if "tempo_dynamics" in t: base["tempoDynamicsScale"] = t["tempo_dynamics"]
    if "speed" in t:          base["speedScale"] = t["speed"]
    return person["style_id"], base


def join_wavs(files: list[Path], dst: Path, gap_sec: float = 0.25) -> None:
    with wave.open(str(files[0]), "rb") as w0:
        params = w0.getparams()
    gap = b"\x00" * int(params.framerate * params.sampwidth * params.nchannels * gap_sec)
    with wave.open(str(dst), "wb") as out:
        out.setparams(params)
        for f in files:
            with wave.open(str(f), "rb") as w:
                out.writeframes(w.readframes(w.getnframes()))
            out.writeframes(gap)


def main() -> int:
    ap = argparse.ArgumentParser(description="台本を読み上げて音声にする")
    ap.add_argument("script", help="台本（1行ずつ「話者: 本文」）")
    ap.add_argument("-o", "--out", default="out/voice.wav", help="書き出す先")
    ap.add_argument("--config", default="config.yaml")
    ap.add_argument("--keep", action="store_true", help="行ごとの音声も残す")
    args = ap.parse_args()

    cfg = load_config(Path(args.config))
    lines = parse_script(Path(args.script).read_text(encoding="utf-8"))
    out = Path(args.out); out.parent.mkdir(parents=True, exist_ok=True)
    work = out.parent / "lines"; work.mkdir(exist_ok=True)

    made: list[Path] = []
    for i, (who, tone, text) in enumerate(lines):
        style_id, params = params_for(cfg, who, tone)
        p = work / f"{i:03d}_{who}_{tone}.wav"
        p.write_bytes(synth(cfg["engine_url"], text, style_id, **params))
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
