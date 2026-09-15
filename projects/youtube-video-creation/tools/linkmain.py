"""公開済みショートの概要欄に、本編へのリンクを入れ直す（2026-09-15）。

**なぜ要るか。**9/1〜9/15 の実測で、ショートは 72,281 再生あるのに、
**ショート経由で本編に来たのは1回**だった（`insightTrafficSourceType` の
`SHORTS_CONTENT_LINKS`）。概要欄にリンクが無く、辿る道がそもそも無かった。
収益化に要る 4,000 時間は**本編の視聴時間しか数えない**ので、
いちばん人がいる場所から本編へ橋を架ける。

これから出すぶんは `src.upload.prepare()` が自動で入れる。
ここは**すでに上げてしまったぶん**を直す道具。

    python tools/linkmain.py --dry-run          # 何が変わるかだけ見る
    python tools/linkmain.py --limit 10         # 10本だけ直す

**1本 50 ユニット**（videos.update）。全部やると本数×50 なので `--limit` で刻む。
本編をまだ投稿していないショートは、黙って飛ばす。
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, ".")

from src import posted as posted_mod  # noqa: E402
from src import quota  # noqa: E402
from src import upload as upload_mod  # noqa: E402


def targets(root: Path) -> list[tuple[str, str, Path]]:
    """(ショートの動画ID, 本編の動画ID, 出力先) を、新しい順に。"""
    rows = []
    for row in reversed(posted_mod._load(posted_mod.LEDGER)):
        name = str(row.get("build") or "")
        vid = str(row.get("video_id") or "")
        if not name.endswith("_short") or not vid or row.get("deleted"):
            continue
        out = root / name
        if not (out / "description.txt").exists():
            continue
        main = posted_mod.find(name[: -len("_short")])
        if main and main.get("video_id"):
            rows.append((vid, main["video_id"], out))
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="output")
    ap.add_argument("--limit", type=int, default=0, help="直す本数（0は全部）")
    ap.add_argument("--skip", type=int, default=0)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    rows = targets(Path(args.root))
    chosen = rows[args.skip:]
    if args.limit:
        chosen = chosen[:args.limit]
    print(f"本編とひもづくショート {len(rows)}本　うち {len(chosen)}本を直します")
    print(f"これから {len(chosen) * 50:,} ユニット使います（1本50）")

    if args.dry_run:
        for short_id, main_id, out in chosen[:12]:
            body = upload_mod.prepare(out).description
            has = upload_mod.MAIN_LINK_HEADING in body
            print(f"  {short_id} → 本編 {main_id}　{out.name}　{'（既に入っている）' if not has else ''}")
        print("\n--dry-run なので送っていません")
        return 0

    api = quota.counted(upload_mod.get_service())
    done, failed = [], []
    for short_id, _main_id, out in chosen:
        try:
            draft = upload_mod.prepare(out)
            # **もう無い動画がある**（2026-09-15）。二重投稿を消したぶんと、
            # 消えたまま上げ直していないぶん。items が空のまま [0] を取って
            # `list index out of range` で落ちていたので、理由を出して飛ばす
            items = api.videos().list(part="snippet", id=short_id).execute()["items"]
            if not items:
                failed.append((short_id, f"YouTube に無い（消されている）　{out.name}"))
                continue
            now = items[0]["snippet"]
            if upload_mod.MAIN_LINK_HEADING in now.get("description", ""):
                continue                      # もう入っている。枠を使わない
            now["description"] = draft.description
            api.videos().update(part="snippet", body={"id": short_id, "snippet": now}).execute()
            done.append(short_id)
        except Exception as err:              # noqa: BLE001
            failed.append((short_id, str(err)[:140]))
            if "quotaExceeded" in str(err):
                print("■ 枠を使い切りました。ここで止めます", flush=True)
                break

    # **直せなかったことを、いちばん最後の行に残す**（upload と同じ理由）
    sys.stdout.flush()
    for vid, why in failed:
        print(f"  × {vid}: {why}")
    print(f"\n■ 直した {len(done)}本 / 直せなかった {len(failed)}本", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
