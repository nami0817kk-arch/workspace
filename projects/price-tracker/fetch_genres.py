"""商品が属する末端ジャンルの名前と階層を引いて data/genres.json に控える。

楽天の商品検索APIは `genreId` を返すが、名前は返さない。うちは大ジャンル8つの
名前しか持っておらず、価格.com のような「カテゴリの下のサブカテゴリ」を
出せなかった。ジャンル検索API（IchibaGenre/Search）は指定したジャンルの
`genre`（名前・階層の深さ）と `ancestors`（祖先すべて）を返すので、
一度引いて控えておけば以後は通信なしで使える。

ジャンルは滅多に変わらない。既に控えてあるIDは引き直さない（--all で全部引く）。
1秒1回の制限を守るので、1,000件で約17分かかる。
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from src import rakuten, store  # noqa: E402

OUT = ROOT / "data" / "genres.json"


def load_env() -> None:
    """`.env` を環境変数に入れる。

    日々の取得は run-daily.ps1 が .env を読んでから fetch.py を呼ぶが、
    これは手で回すので自分で読む（鍵は出力しない）。
    """
    path = ROOT / ".env"
    if not path.exists():
        return
    import os
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def wanted(items: dict) -> list[str]:
    """商品が実際に属しているジャンルID。多い順に引く（途中で止めても効く）。"""
    count = {}
    for meta in items.values():
        gid = str(meta.get("genre_id") or "").strip()
        if gid:
            count[gid] = count.get(gid, 0) + 1
    return [gid for gid, _ in sorted(count.items(), key=lambda kv: -kv[1])]


def lookup(genre_id: str, throttle) -> dict | None:
    app_id, access_key, _ = rakuten.credentials()
    payload = rakuten._get(rakuten.GENRE_URL, {
        "applicationId": app_id, "accessKey": access_key,
        "genreId": genre_id, "format": "json", "formatVersion": 2,
    }, throttle)
    node = payload.get("genre") or {}
    name = str(node.get("nameJa") or node.get("genreName") or "").strip()
    if not name:
        return None
    ancestors = []
    for a in payload.get("ancestors") or []:
        aid = str(a.get("genreId") or "").strip()
        aname = str(a.get("nameJa") or a.get("genreName") or "").strip()
        if aid and aname:
            ancestors.append({"id": aid, "name": aname,
                              "level": int(a.get("level") or 0)})
    return {"name": name, "level": int(node.get("level") or 0),
            "ancestors": ancestors}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--all", action="store_true", help="控えてあるものも引き直す")
    ap.add_argument("--limit", type=int, default=0, help="引く件数の上限")
    args = ap.parse_args(argv)

    load_env()
    items = store.load_json(ROOT / "data" / "items.json", {})
    known = store.load_json(OUT, {})
    ids = wanted(items)
    todo = ids if args.all else [g for g in ids if g not in known]
    if args.limit:
        todo = todo[:args.limit]
    print(f"ジャンル {len(ids):,}種類 / 控えあり {len(known):,} / 引く {len(todo):,}")

    throttle = rakuten.Throttle()
    got = 0
    for i, gid in enumerate(todo, 1):
        try:
            info = lookup(gid, throttle)
        except Exception as err:          # 1件の失敗で全部を捨てない
            print(f"  {gid}: {type(err).__name__} {str(err)[:200]}")
            continue
        if info:
            known[gid] = info
            got += 1
        if i % 50 == 0:
            store.save_json(OUT, known)
            print(f"  {i:,}/{len(todo):,} 件")
    store.save_json(OUT, known)
    print(f"控えた: {got:,}件 / 合計 {len(known):,}件 → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
