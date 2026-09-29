"""公開済みの動画の概要欄を、いまの決まりに少しずつ合わせる（2026-09-30 ユーザー
「過去文も直していきたい。毎日少しづつ対応できる？」）。

    python tools/fix_old_descriptions.py --dry-run          # 何を直すかだけ見る（読むだけ・1本1ユニット未満）
    python tools/fix_old_descriptions.py --limit 40         # 40本まで直す（1本50ユニット）

直すこと（**記事から動画を作ったと読める言い方を消す**。2026-09-30「記事から動画作ってると思われたくないの」）:
- 「■ 出典」の記事アドレスの一覧（9/17 より前の本）を節ごと消す
- 「※発言は下の記事から引いています。」を消す
- 「※各社の報道をもとにしています。クラブが発表した…を画面上で分けています。」を、札の説明だけに
- 「※反応は実在する投稿・記事から引いています。出典は下にあります。」を「※反応は実在する投稿から引いています。」に
- 「画像: サイト名」の1行を消す（2026-09-29「出さなければならないものを除いて出さなくて良い」）

**残すもの**: 末尾の「※ 画像: …」（CC BY / BY-SA の表示は利用の条件）、音声の表記、目次、連絡先、ハッシュタグ。
**丸ごと差し替えない**（公開中と手元で尺が違い、目次の時刻がずれる）。いまの概要欄を取ってきて、行を消すだけ。

- 済んだ本は research/desc_fix_done.json に控え、次の日は続きから（新しい本から順に）
- API の枠は、投稿のぶんを残すため **残りが RESERVE を切ったら止める**
"""
from __future__ import annotations

import argparse
import io
import json
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, ".")

DONE = Path("research/desc_fix_done.json")
RESERVE = 3000          # 投稿（1本100）のために残す枠
BATCH = 50              # videos.list は50本まで1回（1ユニット）

NEWS_OLD = ("※各社の報道をもとにしています。クラブが発表した「確定」、\n"
            "報道機関が伝える「報道」、SNS段階の「未確認」、\n"
            "経緯の説明である「背景」を画面上で分けています。")
NEWS_NEW = ("※画面の札で、クラブが発表した「確定」、\n"
            "報道機関が伝える「報道」、SNS段階の「未確認」、\n"
            "経緯の説明である「背景」を分けています。")


def fix(text: str) -> str:
    """概要欄の文字列を直す。直すところが無ければ同じ文字列を返す。"""
    out = text.replace("\r\n", "\n")
    out = out.replace(NEWS_OLD, NEWS_NEW)
    out = out.replace("※反応は実在する投稿・記事から引いています。出典は下にあります。",
                      "※反応は実在する投稿から引いています。")
    lines = out.split("\n")
    kept: list[str] = []
    skipping = False
    for line in lines:
        if line.strip() == "■ 出典":
            skipping = True
            continue
        if skipping:
            if line.strip() == "":
                skipping = False
                # 節のあとの空行は1つだけ残す（前の節との間の空行が既にある）
            continue
        if line.strip() == "※発言は下の記事から引いています。":
            continue
        if line.startswith("画像: "):
            continue
        kept.append(line)
    out = "\n".join(kept)
    # 行を消したあとに残る3つ以上の改行を2つにそろえる
    out = re.sub(r"\n{3,}", "\n\n", out)
    # 「■ クレジット」の中身が空になったら見出しごと消す
    out = re.sub(r"■ クレジット\n(?=\n|■|#|$)", "", out)
    out = re.sub(r"\n{3,}", "\n\n", out)
    return out


def _load_done() -> dict:
    try:
        return json.loads(DONE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def main() -> int:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=40, help="この回に書き換える本数の上限")
    ap.add_argument("--dry-run", action="store_true", help="書き換えずに、直す内容だけ出す")
    args = ap.parse_args()

    from src import posted, quota
    from src.upload import get_service

    done = _load_done()
    rows = [r for r in posted._load(posted.LEDGER) if r.get("video_id")]
    # 新しい本から（見られているのは新しい本）
    todo = [r for r in reversed(rows) if r["video_id"] not in done]
    print(f"■ 概要欄の直し　残り {len(todo)}本 / 公開済み {len(rows)}本　枠の残り {quota.left()}")
    if not todo:
        print("全部済んでいます")
        return 0

    # **許可が切れていたら、同意画面を開かずに終える**（2026-09-29 の午後に失効して、投稿の処理が
    # ブラウザの同意画面を待ったまま止まった）。毎日の自動実行では、誰も押せない画面を開いても止まるだけ
    from src.upload import SCOPES, TOKEN_PATH
    try:
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)
        if not creds.valid:
            creds.refresh(Request())
            TOKEN_PATH.write_text(creds.to_json(), encoding="utf-8")
    except Exception as err:  # noqa: BLE001
        print(f"× YouTube の許可が切れています（{str(err)[:80]}）。今日は何もしません。"
              "`python -m src.cli quota` などを手で1回打って、ブラウザで許可し直してください")
        return 2

    service = get_service()
    changed = checked = 0
    now = datetime.now().isoformat(timespec="seconds")
    for start in range(0, len(todo), BATCH):
        if changed >= args.limit:
            break
        chunk = todo[start:start + BATCH]
        got = service.videos().list(part="snippet", id=",".join(r["video_id"] for r in chunk)).execute()
        by_id = {item["id"]: item for item in got.get("items") or []}
        for row in chunk:
            if changed >= args.limit:
                break
            vid = row["video_id"]
            item = by_id.get(vid)
            if item is None:
                # 消された動画など。次から見ない
                done[vid] = {"at": now, "result": "見つからない"}
                continue
            checked += 1
            snippet = item["snippet"]
            before = snippet.get("description", "")
            after = fix(before)
            if after == before:
                done[vid] = {"at": now, "result": "直すところ無し"}
                continue
            if args.dry_run:
                print(f"  直す: {row.get('build')}　{vid}　{len(before)}字 → {len(after)}字")
                changed += 1
                continue
            if quota.left() < RESERVE + 60:
                print(f"  枠の残りが {quota.left()} なので止めます（投稿のぶん {RESERVE} を残す）")
                DONE.write_text(json.dumps(done, ensure_ascii=False, indent=1), encoding="utf-8")
                return 0
            snippet["description"] = after[:5000]
            # 題名・タグ・カテゴリは取ってきたまま返す（snippet は部分更新できない）
            service.videos().update(part="snippet", body={"id": vid, "snippet": snippet}).execute()
            done[vid] = {"at": now, "result": "直した"}
            changed += 1
            print(f"  直した: {row.get('build')}　{vid}")
    if not args.dry_run:
        DONE.write_text(json.dumps(done, ensure_ascii=False, indent=1), encoding="utf-8")
    left_after = len([r for r in rows if r["video_id"] not in done])
    print(f"■ {'直す予定' if args.dry_run else '直した'} {changed}本 / 見た {checked}本　残り {left_after}本　枠の残り {quota.left()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
