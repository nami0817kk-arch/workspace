# -*- coding: utf-8 -*-
"""今季の監督の顔写真を集める（2026-09-22 指示「今季の監督が誰かも加えよう」）。

`research/pl_data/managers.json`（key → {"name_ja", "page"}）を読み、
tools/plfaces.py と同じ取り方（記事の代表画像、Commons の自由なライセンスだけ）で
assets/photos/pl/<key>_manager_<hash>.jpg に置き、faces.json に role "manager" で控える。

    python tools/plmanagers.py

**顔は必ず目で確かめる**（plfaces と同じ。同姓の別人を拾った前科がある）。
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import plfaces  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import clubleague  # noqa: E402

# リーグは CLUB_LEAGUE で切り替える（2026-09-26）
DATA = clubleague.data_dir()
OUT = ROOT / "assets" / "photos" / "pl"


def main() -> int:
    managers = json.loads((DATA / "managers.json").read_text(encoding="utf-8"))
    index_path = DATA / "faces.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else {}
    ledger = OUT / "credits.json"
    rows = json.loads(ledger.read_text(encoding="utf-8")) if ledger.exists() else []
    found = {r["file"]: r for r in rows}
    for key, info in managers.items():
        name_ja, page = info["name_ja"], info["page"]
        entry = index.setdefault(key, {})
        # 監督が代わったら古い監督の控えは役目を終える
        for who, v in list(entry.items()):
            if isinstance(v, dict) and v.get("role") == "manager" and who != name_ja:
                del entry[who]
        if name_ja in entry and entry[name_ja].get("file"):
            print(f"  {key:12s} 控えあり {name_ja}")
            continue
        got = plfaces.find(name_ja, "https://en.wikipedia.org/wiki/" + page.replace(" ", "_"))
        if not got:
            print(f"  ！ {key} 監督 {name_ja}: 自由に使える顔写真が見つかりません", file=sys.stderr)
            entry[name_ja] = {"role": "manager", "file": "", "page": page}
            continue
        slug = f"{key}_manager_{hashlib.md5(name_ja.encode('utf-8')).hexdigest()[:8]}.jpg"
        plfaces.save(got, OUT / slug)
        entry[name_ja] = {"role": "manager", "file": f"assets/photos/pl/{slug}", "page": got["page"]}
        found[slug] = dict(got, file=slug, source="wikimedia", person=name_ja,
                           subject_check="未確認（目で確かめること）")
        print(f"  {key:12s} 監督 {name_ja:16s} {got['license']}")
    ledger.write_text(json.dumps(list(found.values()), ensure_ascii=False, indent=1), encoding="utf-8")
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
