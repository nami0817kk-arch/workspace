"""再生リストを作って、本編を入れる（2026-09-15）。

**なぜ作るか。**詰まっているのは本編の視聴時間で、9/14 の実測で 9.9時間しかない
（収益化には4,000時間）。本編の再生は中央値7回で、そもそも配られていない。
ホームと関連動画は登録者がいないと動かないが、**再生リストの中の自動再生は
登録者が要らない**。1本見た人が2本目に流れる見込みがある、いまのところ唯一の道。

**ショートは入れない。**再生リストの自動再生に乗らないので、入れても枠を使うだけ。

**1本入れるごとに50ユニット**かかる。114本ぜんぶで 5,750 なので、
`--limit` で刻む。あとから足せるので、作り直しは要らない。

    # まず見る（何も送らない）
    python tools/playlist.py --title 海外サッカーニュース --limit 38 --dry-run
    # 作る
    python tools/playlist.py --title 海外サッカーニュース --limit 38
    # 既にある再生リストへ足す
    python tools/playlist.py --id PL... --limit 38 --skip 38

順番は**再生数の多い順**。目的は「自動再生で2本目に流れるか」を確かめることで、
そのためには**1本目に人が来る本**が要る。中央値7回の本ばかり集めても入口が無い。
"""
from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path

sys.path.insert(0, ".")

from src import quota  # noqa: E402
from src.upload import get_service  # noqa: E402

LEDGER = Path("research/playlists.json")
SNAPSHOT = Path("research/metrics/20260914/raw_videos.json")


def mains(snapshot: Path) -> list[dict]:
    """公開中の本編を、再生数の多い順に。"""
    book = json.load(io.open(snapshot, encoding="utf-8"))
    rows = [v for v in book["videos"] if v["privacy"] == "public" and not v["short"]]
    rows.sort(key=lambda v: -v["views"])
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--title", default="", help="新しく作るときの題名")
    ap.add_argument("--id", default="", help="既にある再生リストへ足すとき")
    ap.add_argument("--limit", type=int, default=38, help="入れる本数")
    ap.add_argument("--skip", type=int, default=0, help="先頭から飛ばす本数")
    ap.add_argument("--snapshot", default=str(SNAPSHOT))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not args.title and not args.id:
        print("--title か --id のどちらかを渡してください", file=sys.stderr)
        return 1

    rows = mains(Path(args.snapshot))
    chosen = rows[args.skip:args.skip + args.limit]
    cost = (0 if args.id else 50) + len(chosen) * 50
    print(f"公開中の本編 {len(rows)}本　うち {args.skip + 1}〜{args.skip + len(chosen)}本目を入れます")
    print(f"これから {cost:,} ユニット使います（1本50 ＋ 作成50）")
    for i, v in enumerate(chosen, 1):
        print(f"  {i:>3}. {v['views']:>5}回  {v['title'][:44]}")
    if args.dry_run:
        print("\n--dry-run なので送っていません")
        return 0

    api = quota.counted(get_service())
    playlist_id = args.id
    if not playlist_id:
        made = api.playlists().insert(
            part="snippet,status",
            body={
                "snippet": {
                    "title": args.title,
                    "description": (
                        "海外サッカーのニュースを1本1テーマでまとめています。\n"
                        "新しいものから順に追加していきます。"
                    ),
                },
                "status": {"privacyStatus": "public"},
            },
        ).execute()
        playlist_id = made["id"]
        print(f"\n作りました: https://www.youtube.com/playlist?list={playlist_id}")

    done, failed = [], []
    for v in chosen:
        try:
            api.playlistItems().insert(
                part="snippet",
                body={"snippet": {
                    "playlistId": playlist_id,
                    "resourceId": {"kind": "youtube#video", "videoId": v["id"]},
                }},
            ).execute()
            done.append(v["id"])
        except Exception as err:                     # noqa: BLE001
            failed.append((v["id"], str(err)[:120]))
            if "quotaExceeded" in str(err):
                print("■ 枠を使い切りました。ここで止めます", flush=True)
                break

    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    book = json.loads(LEDGER.read_text(encoding="utf-8")) if LEDGER.exists() else {}
    entry = book.setdefault(playlist_id, {"title": args.title, "videos": []})
    entry["videos"] += [v for v in done if v not in entry["videos"]]
    LEDGER.write_text(json.dumps(book, ensure_ascii=False, indent=1), encoding="utf-8")

    # **入れられなかったことを、いちばん最後の行に残す**（upload と同じ理由）
    sys.stdout.flush()
    for vid, why in failed:
        print(f"  × {vid}: {why}")
    print(f"\n■ 入れた {len(done)}本 / 入らなかった {len(failed)}本"
          f"　https://www.youtube.com/playlist?list={playlist_id}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
