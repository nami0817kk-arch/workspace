# -*- coding: utf-8 -*-
"""台本の「流れ」を Gemini に読ませて、穴を言わせる（2026-09-22 に毎回の手順へ）。

機械の点検は全部が形式のこと（音量・無音・画面の停止・割合）で、
「話がつながっているか」「聞いた人が置いていかれないか」を見るものは無い。
9/13 にこの手順を作ったのに 9/22 まで使っておらず、その日に
「上田のショートが何を言いたいか分からない」「鈴木のショートが選ばれたことがない」
「シメオネの数字の確認は不要」と3本で同じ型の指摘を受けた。

使い方:
    python tools/flow.py scripts/20260922_ueda.md [scripts/...]

結果は output/flow/<台本名>.md に残す。**`approve` はこの控えが無いと通さない。**
判断させるのではなく、できたものの欠点を言わせる。鵜呑みにしない。
"""
from __future__ import annotations

import base64
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV = Path("C:/Users/なみ/dev/workspace/platform/ai-lab/.env")
OUT = ROOT / "output" / "flow"

PROMPT = """あなたはテレビのニュース番組の構成作家です。次の台本は、合成音声で読み上げる
1〜3分のサッカー動画です。読み上げる文と、画面に出るテロップ・カードが書かれています。
「## 」で始まる行が節（チャプター）、「@main: true」の節はショート動画として単体でも出します。

先に、変えてはいけない決まりです。この決まりを壊す提案はしないでください。
- 発言（キャスター・解説以外の話者の行）は原文のまま。言い換えない・作らない
- ネット民の反応は実在の投稿。作らない・足さない・削れとは言わない
- 「まとめ」の節は置かない。反応で終わる
- 媒体名は出さない。事実は出典があるものだけ
- 問いかけの1行を画面に出す案は出さない

見てほしいのは中身の流れだけです。次の5つに、**該当する行をそのまま引用して**答えてください。
該当が無い項目は「無し」と書いてください。ほめ言葉は要りません。

1. 流れが飛んでいる箇所。前の行を聞いただけでは、次の行が何の話か分からないところ
2. 立てたのに回収されない疑問。タイトルや冒頭が約束したのに、本文が答えていないこと
3. 順番を入れ替えたほうが分かりやすい箇所
4. 抜いても意味が変わらない行（同じことの言い直し、数字の確認だけの行）
5. 一度聞いただけでは分からない言い回し（合成音声で読まれることを前提に）

最後に、**ショート（@main の節）だけを取り出して1本にしたとき**、
初めて見る人が「何が起きて、何が論点か」を分かるかどうかを、分かる／分からないで答え、
分からないなら足りない1文を書いてください。

--- 台本 ---
"""


def _key() -> str:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.startswith("GEMINI_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("GEMINI_API_KEY が空です")


# 混雑（503）が続くときは、別のモデルへ順に逃がす（2026-09-22、3.6-flash が1時間落ち続けた）
# 429 は無料枠の使い切り（課金はしていない）。その日はそのモデルを飛ばす
MODELS = ("gemini-3.6-flash", "gemini-3.5-flash", "gemini-flash-latest", "gemini-3.8-flash", "gemini-3.7-flash")


def _call(model: str, body: bytes):
    url = (f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
           f"?key={_key()}")
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as res:
        return json.load(res)


def ask(text: str, model: str | None = None) -> str:
    import time

    first = model or os.environ.get("GEMINI_MODEL", MODELS[0])
    order = [first] + [m for m in MODELS if m != first]
    body = json.dumps({"contents": [{"parts": [{"text": text}]}]}).encode("utf-8")
    data = None
    last: Exception | None = None
    for name in order:
        for attempt in range(2):
            try:
                data = _call(name, body)
                break
            except urllib.error.HTTPError as err:
                last = err
                if err.code not in (429, 503):
                    raise
                if err.code == 429:
                    break          # 枠切れは待っても戻らない。次のモデルへ
                time.sleep(20)
        if data is not None:
            if name != first:
                print(f"  （{first} が混雑のため {name} で読みました）")
            break
    if data is None:
        raise last  # type: ignore[misc]
    return "\n".join(part.get("text", "")
                     for cand in data.get("candidates", [])
                     for part in cand.get("content", {}).get("parts", []))


def run(script: Path) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    answer = ask(PROMPT + script.read_text(encoding="utf-8"))
    out = OUT / (script.stem + ".md")
    out.write_text(f"# 流れの点検: {script.name}\n\n{answer}\n", encoding="utf-8")
    return out


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    if argv == ["--prompt"]:
        # Gemini の無料枠が切れた日は、同じ問いを別の読み手（Claude の下請け）に渡す。
        # 控えは同じ output/flow/<台本>.md に、1行目を
        # 「# 流れの点検: <台本>（読み手: Claude。Gemini は無料枠切れ）」として書く
        print(PROMPT)
        return 0
    for arg in argv:
        script = Path(arg)
        if not script.exists():
            print(f"台本がありません: {script}", file=sys.stderr)
            return 1
        try:
            out = run(script)
        except Exception as err:
            detail = getattr(err, "read", lambda: b"")()
            print(f"■ {script.name}: 呼べませんでした: {err} "
                  f"{detail[:300].decode('utf-8', 'replace')}", file=sys.stderr)
            return 1
        print(f"■ {script.name} → {out.relative_to(ROOT)}")
        print(out.read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
