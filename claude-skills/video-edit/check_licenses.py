"""素材のライセンスを、公開・収益化する動画に使えるかで判定する。

    python check_licenses.py <credits.json か素材フォルダ>

imagegen fetch が書く credits.json を読み、動画に使えないライセンスを弾く。
書き出し前のゲートとして使う。判定の根拠は SKILL.md の「画像を使う前の権利チェック」。

終了コード: 0 = 全部OK / 1 = 使えないものがある / 2 = 要確認が混ざる
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# 判定は license 文字列の正規化後に前方一致・部分一致で行う。
# 迷ったら通さない（不明は REVIEW に倒す）。
BLOCK = [
    ("ND", "改変禁止。ズーム・クロップ・字幕重ねが改変に当たるため動画では使えない"),
    ("NC", "非営利限定。収益化と両立しない"),
    ("GFDL", "ライセンス全文の提示を求める設計で、動画には載せきれない"),
    ("ALL RIGHTS RESERVED", "許諾が要る"),
    ("COPYRIGHTED", "許諾が要る"),
]
WARN = [
    ("SA", "継承条件つき。Ken Burns 等の加工で Adapted Material となり、動画側も同じ条件で出す必要が生じる"),
]
OK_EXACT = ("CC0", "PUBLIC DOMAIN", "PD", "PDM", "NO KNOWN COPYRIGHT")


def classify(license_name: str) -> tuple[str, str]:
    """(判定, 理由) を返す。判定は OK / WARN / BLOCK / REVIEW。"""
    raw = (license_name or "").strip()
    if not raw:
        return "REVIEW", "ライセンス不明。出典ページで確認するまで使わない"
    name = re.sub(r"[^A-Z0-9 ]+", " ", raw.upper())
    tokens = name.split()

    for key, why in BLOCK:
        if key in tokens:
            return "BLOCK", why
    if "GFDL" in name:
        return "BLOCK", dict(BLOCK)["GFDL"]

    if any(name.startswith(k) or k in name for k in OK_EXACT):
        return "OK", "条件なし"

    for key, why in WARN:
        if key in tokens:
            return "WARN", why

    if "BY" in tokens:
        return "OK", "表示（作品名・作者・ライセンス・リンク）を概要欄に書けば可"

    return "REVIEW", f"判定できないライセンス表記: {raw}"


def load(target: Path) -> list[dict]:
    if target.is_dir():
        target = target / "credits.json"
    if not target.exists():
        sys.exit(f"credits.json が見つかりません: {target}")
    data = json.loads(target.read_text(encoding="utf-8"))
    return data if isinstance(data, list) else data.get("items", [])


def main() -> int:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    items = load(Path(sys.argv[1]))
    counts = {"OK": 0, "WARN": 0, "BLOCK": 0, "REVIEW": 0}
    mark = {"OK": "  OK   ", "WARN": " 要注意 ", "BLOCK": " 使用不可", "REVIEW": " 要確認 "}

    for item in items:
        verdict, why = classify(item.get("license", ""))
        counts[verdict] += 1
        name = item.get("file") or item.get("title") or "(名称不明)"
        print(f"{mark[verdict]} [{item.get('license', '不明')}] {name}")
        if verdict != "OK":
            print(f"          → {why}")
            if item.get("page_url"):
                print(f"          出典: {item['page_url']}")

    print()
    print(f"合計 {len(items)} 件: OK {counts['OK']} / 要注意 {counts['WARN']} "
          f"/ 使用不可 {counts['BLOCK']} / 要確認 {counts['REVIEW']}")

    if counts["BLOCK"]:
        print("使用不可の素材がある。差し替えてから書き出すこと。")
        return 1
    if counts["WARN"] or counts["REVIEW"]:
        print("そのまま出さず、上の項目を判断してから書き出すこと。")
        return 2
    print("このまま書き出してよい（概要欄の表示は別途必要）。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
