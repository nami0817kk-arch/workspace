"""話す人の名前と声の出どころ。立ち絵の2人（cast）と、人物の言葉を読む声（roles）をまとめて引く。

2026-10-04「マリーアントワネットのセリフとかの声はどうなっている？」：本人の言葉も剣崎が地の文と同じ声で
読んでいて、裁判や最期の言葉が平板だった。台本で「人物」の行にした言葉だけ、roles の声で読む。
"""
from __future__ import annotations


def roles(config: dict) -> dict:
    return config.get("roles") or {}


def entry(config: dict, speaker: str) -> dict:
    """話者の設定（cast か roles）。"""
    if speaker in config["cast"]:
        return config["cast"][speaker]
    return roles(config)[speaker]


def label(config: dict, speaker: str) -> str:
    """字幕に出す名前。cast は声の名前（剣崎雌雄）、人物は人物の名前（マリー・アントワネット）。"""
    if speaker in config["cast"]:
        return config["cast"][speaker]["name"]
    if speaker == "二人":
        return "剣崎・つむぎ"
    r = roles(config).get(speaker, {})
    return r.get("label", speaker)


def credit_names(config: dict, script=None) -> list[str]:
    """クレジットに出す VOICEVOX の声の名前。人物の声は、その台本で使ったものだけ。"""
    names = [c["name"] for c in config["cast"].values()]
    used = script.roles if script is not None else list(roles(config))
    for who in used:
        n = roles(config).get(who, {}).get("name")
        if n and n not in names:
            names.append(n)
    return names


def unknown_roles(config: dict, script) -> list[str]:
    return [who for who in script.roles if who not in roles(config)]
