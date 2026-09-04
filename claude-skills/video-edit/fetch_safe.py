"""動画に使えるライセンスの素材だけを選んで取得する。

    python fetch_safe.py "キーワード" -n 4 -o 出力先 [--source wikimedia] [--pool 25]

`imagegen fetch` は検索上位から順に落とすため、GFDL や CC BY-SA を掴む。
こちらは **広く検索してから CC0 / PD / CC BY だけに絞って** 落とす。
判定基準は check_licenses.py と同じ（SKILL.md「画像を使う前の権利チェック」）。

ai-lab の venv から実行すること:
    cd C:/Users/なみ/dev/workspace/platform/ai-lab
    PYTHONPATH=src .venv/Scripts/python.exe <このファイル> "soccer ball" -n 3 -o out/
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from check_licenses import classify  # noqa: E402


def use_utf8_streams() -> None:
    """Windows のコンソールでも日本語と欧文の記号を出せるようにする。

    既定は CP932 で、素材のタイトルに `Perú` の `ú` のような文字が入ると
    表示の途中で UnicodeEncodeError を出して落ちる。実測では
    「Argentina 2-0 Perú - Copa América 2024」で落ち、**ライセンス確認の
    工程がそこで止まった**。ヨーロッパの選手・クラブ・スタジアム名は
    é ú ñ ü を含むことが多く、サッカー用途では高い確率で当たる。

    差し替えではなく付け替え（reconfigure）にしてあるので、pytest が
    出力を捕捉しているときも壊さない。
    """
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (ValueError, OSError):   # 付け替えられない環境では諦める
            pass


def main() -> int:
    use_utf8_streams()
    parser = argparse.ArgumentParser(
        description="CC0 / PD / CC BY の素材だけを選んで取得する",
    )
    parser.add_argument("query", help="検索キーワード")
    parser.add_argument("-n", "--num", type=int, default=3, help="落とす件数 (既定: 3)")
    parser.add_argument("-o", "--out", required=True, help="出力先ディレクトリ")
    parser.add_argument("--source", default="wikimedia", help="検索先 (既定: wikimedia)")
    parser.add_argument(
        "--pool", type=int, default=25,
        help="選別前に検索する件数 (既定: 25)。少ないと使えるものが残らない",
    )
    parser.add_argument(
        "--min-width", type=int, default=1920,
        help="この幅を満たす中で最小のものを選ぶ (既定: 1920)。巨大画像で待たされないため",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="落とさず、選別結果だけ見る",
    )
    args = parser.parse_args()

    from imagegen import assets

    try:
        found = assets.search(args.query, source=args.source, limit=args.pool)
    except Exception as exc:  # コネクタ側の障害はそのまま見せる
        print(f"検索に失敗しました: {type(exc).__name__}: {exc}")
        return 1

    if not found:
        print(f"「{args.query}」で素材が見つかりませんでした")
        return 1

    keep, dropped = [], []
    for asset in found:
        verdict, why = classify(asset.license)
        (keep if verdict == "OK" else dropped).append((asset, verdict, why))

    print(f"検索 {len(found)} 件 → 使えるもの {len(keep)} 件")
    if not keep:
        print("使えるライセンスの素材がありませんでした。--pool を増やすか、語を変えてください。")
        for asset, verdict, why in dropped[:5]:
            print(f"  除外 [{asset.license}] {asset.title[:50]}")
        return 1

    # 1080p の動画で寄り引きする前提だと、幅は 1920 あれば足りる。
    # それ以上は落とす時間が延びるだけなので、「足りる中でいちばん小さいもの」を先に。
    # 足りるものが無ければ、大きい順に妥協する。
    need = args.min_width

    def rank(item):
        asset = item[0]
        width, height = asset.width or 0, asset.height or 0
        enough = width >= need
        # enough なら小さい順、足りないなら大きい順
        return (0 if enough else 1, width * height if enough else -(width * height))

    keep.sort(key=rank)
    chosen = [asset for asset, _, _ in keep[: args.num]]

    for asset in chosen:
        print(f"  採用 [{asset.license}] {asset.width}x{asset.height} {asset.title[:45]}")
    if dropped:
        reasons = {}
        for asset, verdict, _ in dropped:
            reasons[asset.license] = reasons.get(asset.license, 0) + 1
        print("  除外: " + ", ".join(f"{lic}×{n}" for lic, n in sorted(reasons.items())))

    if args.dry_run:
        print("(--dry-run のため落としていません)")
        return 0

    saved = assets.download_all(chosen, args.out)
    print()
    for asset, path in saved:
        print(f"保存: {path.name}")
    print(f"クレジットは {Path(args.out) / 'CREDITS.md'} に追記しました。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
