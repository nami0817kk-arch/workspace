# -*- coding: utf-8 -*-
"""集めたものを「なぜが立つか」で選り分ける。判定は Gemini（無料枠）に任せる。

鍵は gemini-api プロジェクトの .env から読む。画像生成には無料枠が無いが、
文章のほうは無料で通る（2026-10-06 に確認）。
"""
from __future__ import annotations

import json
import pathlib
import re
import time
import urllib.error
import urllib.request

ENV = pathlib.Path(r"C:/Users/なみ/dev/workspace/projects/gemini-api/.env")
MODELS = ["gemini-3.5-flash", "gemini-3.6-flash", "gemini-3.7-flash",
          "gemini-3.1-flash-lite", "gemini-flash-latest"]

PROMPT = """あなたは YouTube チャンネル「世の中の断面図」の題材を選ぶ人です。
このチャンネルは、ニュースや世の中の疑問を1つ選び、制度・歴史・数字の断面を見せます。

【採る条件】次のどれかに強く当てはまるものだけ採ります。
1. 結果は報じられているが、**理由が説明されていない**
2. 多くの人が**誤解している**（言葉の意味、数字の読み方）
3. **日本だけ、あるいは1国だけが異質**

【採らないもの】
- 政治的な是非（どちらが正しいか）を論じることになるもの
- 医療・健康の助言になるもの
- 事件・事故・死亡・芸能の私生活
- 投資の推奨になるもの
- 30分の動画にするには中身が薄いもの
- 公的な統計や法令に当たれないもの（出典が取れないもの）

【出力】採るものだけを JSON の配列で返してください。説明文は書かないでください。
各要素は次の形です。
{"n": 元の番号, "title": "疑問形のタイトル案", "why": "なぜ成立するか30字以内",
 "cond": 1か2か3, "source": "当たるべき原典（役所名や統計名）", "score": 1〜5}

score は「30分の動画として面白くなるか」。5がいちばん良い。
多くても12件までに絞ってください。

【候補】
"""


def _key() -> str:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.startswith("GEMINI_API_KEY"):
            return line.split("=", 1)[1].strip()
    raise SystemExit("GEMINI_API_KEY が見つかりません")


def ask(prompt: str, tries: int = 3) -> str:
    key = _key()
    body = json.dumps({"contents": [{"parts": [{"text": prompt}]}],
                       "generationConfig": {"temperature": 0.3, "maxOutputTokens": 3000}}).encode()
    for _ in range(tries):
        for m in MODELS:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{m}:generateContent?key={key}"
            try:
                req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=180) as res:
                    d = json.load(res)
                return d["candidates"][0]["content"]["parts"][0]["text"]
            except urllib.error.HTTPError:
                continue
        time.sleep(15)
    raise SystemExit("Gemini がどのモデルでも応えませんでした（混んでいるときは少し待つ）")


def judge(items: list) -> list[dict]:
    lines = [f"{i+1}. [{it.source}] {it.text}" for i, it in enumerate(items)]
    text = ask(PROMPT + "\n".join(lines))
    m = re.search(r"\[.*\]", text, re.S)
    if not m:
        raise SystemExit(f"返事を読めませんでした:\n{text[:300]}")
    out = json.loads(m.group(0))
    for row in out:
        n = int(row.get("n", 0)) - 1
        if 0 <= n < len(items):
            row["original"] = items[n].text
            row["source_feed"] = items[n].source
            row["link"] = items[n].link
    return sorted(out, key=lambda r: -int(r.get("score", 0)))
