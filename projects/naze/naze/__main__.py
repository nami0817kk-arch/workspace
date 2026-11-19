"""python -m naze <手順> <題材のフォルダ>

手順(地形の回): kana(読みを出す)/ voice(声と時間割)/ prep(標高・色・カメラ)/ stills 1,60,120(確認用のコマ)/ render(全コマ)/ compose(mp4)/ all
手順(計算の回): kana / voice / compose / all   … 画面は題材の ep.py の frame() が描く
台本の点検: lint … 台本を書いたらすぐ、見せる前(答えを引っ張る・冒頭の入り方・代弁・比べ。2026-11-19 の決まり)
点検(両方): qc … compose のあと。通らなければ投稿できない(naze/qc.py)
映像の点検(世界の地図の回): vqc … 描く前でも使える(naze/vqc.py)。qc の中でも走る
compose は 20 秒以上の動画をコマで分けて同時に描く(数は NAZE_JOBS、無ければ空きメモリから。NAZE_JOBS=1 で今まで通り)
"""
from __future__ import annotations

import importlib.util
import os
import re
import sys
from pathlib import Path


def load(folder: Path) -> dict:
    sp = importlib.util.spec_from_file_location("ep_" + folder.name, folder / "ep.py")
    mod = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(mod)
    ep = dict(mod.EP)
    ep["_mod"] = mod
    ep["_folder"] = folder                                 # qc が本編の何章目か(答えをどこまで引っ張るか)を見るのに使う
    # 結びに「チャンネル登録と高評価」のお願いを足す(本編は最後の章だけ。long が NAZE_CTA=0 で止める)
    if ep.get("cta", True) and os.environ.get("NAZE_CTA", "1") != "0":
        from .overlay import CTA_TEXT
        ep["lines"] = list(ep["lines"]) + [dict(id="cta", text=CTA_TEXT, style="cta", pause=0.2,
                                                 say="チャンネルとうろくと、こうひょうか、よろしくおねがいします。")]
    return ep


def lint(folder: Path) -> int:
    """台本を書いたらすぐ、見せる前に走らせる。答えを冒頭で言っていないか・冒頭の入り方・代弁・比べ(naze/qc.py の rules)。"""
    folders = [folder] if (folder / "ep.py").exists() else sorted(p.parent for p in folder.glob("*/ep.py"))
    if not folders:
        raise SystemExit(f"{folder} に ep.py が無い")
    os.environ["NAZE_CTA"] = "0"                           # 結びのお願いの行は台本の点検に入れない
    from . import qc
    bad = 0
    for f in folders:
        ep = load(f)
        F, Wn = qc.rules(ep)
        print(f"== {f.name}({qc.position(ep)}) {'通過' if not F else '✖'}")
        for x in F:
            print("  ✖", x)
        for x in Wn:
            print("  △", x)
        bad += bool(F)
    print(f"決まり {qc.RULES}: {len(folders) - bad}/{len(folders)} 本が通過")
    return 1 if bad else 0


def main(argv=None) -> int:
    argv = argv or sys.argv[1:]
    step, folder = argv[0], Path(argv[1])
    if step == "lint":                                    # 台本だけを今の決まりで見る(声の前。題材のフォルダなら章とショートを全部)
        return lint(folder)
    if step == "long":
        from . import long
        return long.main(folder, argv[2:])
    # 縦か横かは、字幕などの位置を決める config を読む前に決める
    if re.search(r"aspect\s*=\s*[\"']landscape", (folder / "ep.py").read_text(encoding="utf-8")):
        os.environ["NAZE_ASPECT"] = "landscape"
    from .config import OUT
    ep = load(folder)
    # 本編の章(episodes/<題材>/<章>)は、題材の名前を頭に付けて出力先がぶつからないようにする
    out = OUT / (folder.name if folder.parent.name == "episodes" else f"{folder.parent.name}_{folder.name}")
    out.mkdir(parents=True, exist_ok=True)
    kind = ep.get("kind", "terrain")
    if step == "vqc":
        from . import vqc
        return 0 if vqc.run(ep, out, ep["_mod"].MAP) else 1
    if step == "qc":
        from . import qc
        from . import terrain_ep, sim_ep
        return 0 if qc.run(ep, out, terrain_ep if kind == "terrain" else sim_ep, out.name) else 1
    if step == "pre":                                     # 書き出しの前の点検(声のあと。重なり・はみ出し・台本と行ごとのコマ)
        from . import qc
        from . import terrain_ep, sim_ep
        return 0 if qc.pre(ep, out, terrain_ep if kind == "terrain" else sim_ep, out.name) else 1
    if step == "seg":                                     # 分けて描くときの 1 切れ(compose._parallel が呼ぶ): seg <題材> <a> <b> <出力>
        from . import compose
        from . import terrain_ep, sim_ep
        fr, _ = (terrain_ep if kind == "terrain" else sim_ep).frame_fn(ep, out)
        compose.render_video(fr, int(argv[2]), int(argv[3]), Path(argv[4]))
        return 0
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
            print(K.final(ep, out, out.name))
        elif step == "all":
            K.voice(ep, out)
            K.prep(ep, out)
            K.render(out)
            print(K.final(ep, out, out.name))
    else:
        from . import sim_ep as S
        if step == "kana":
            S.kana(ep)
        elif step == "voice":
            S.voice(ep, out)
        elif step in ("compose", "all"):
            if step == "all":
                S.voice(ep, out)
            print(S.final(ep, out, out.name))
        elif step == "stills":
            for p in S.stills(ep, out, argv[2]):
                print(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
