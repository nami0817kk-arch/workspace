"""python -m naze <手順> <題材のフォルダ>

手順(地形の回): kana(読みを出す)/ voice(声と時間割)/ prep(標高・色・カメラ)/ stills 1,60,120(確認用のコマ)/ render(全コマ)/ compose(mp4)/ all
手順(計算の回): kana / voice / compose / all   … 画面は題材の ep.py の frame() が描く
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

from .config import OUT


def load(folder: Path) -> dict:
    sp = importlib.util.spec_from_file_location("ep_" + folder.name, folder / "ep.py")
    mod = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(mod)
    ep = dict(mod.EP)
    ep["_mod"] = mod
    return ep


def main(argv=None) -> int:
    argv = argv or sys.argv[1:]
    step, folder = argv[0], Path(argv[1])
    ep = load(folder)
    out = OUT / folder.name
    out.mkdir(parents=True, exist_ok=True)
    kind = ep.get("kind", "terrain")
    if kind == "terrain":
        from . import terrain_ep as K
        if step == "kana":
            K.kana(ep)
        elif step == "voice":
            K.voice(ep, out)
        elif step == "prep":
            K.prep(ep, out)
        elif step == "stills":
            for p in K.stills(ep, out, argv[2]):
                print(p)
        elif step == "render":
            K.render(out)
        elif step == "compose":
            print(K.final(ep, out, folder.name))
        elif step == "all":
            K.voice(ep, out)
            K.prep(ep, out)
            K.render(out)
            print(K.final(ep, out, folder.name))
    else:
        from . import sim_ep as S
        if step == "kana":
            S.kana(ep)
        elif step == "voice":
            S.voice(ep, out)
        elif step in ("compose", "all"):
            if step == "all":
                S.voice(ep, out)
            print(S.final(ep, out, folder.name))
        elif step == "stills":
            for p in S.stills(ep, out, argv[2]):
                print(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
