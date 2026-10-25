"""理の書(旧 棒人間ストーリー)へ動画を API で上げる。

鍵はリポジトリの外(環境変数 NAZE_YT_TOKEN、無ければ dev/output/yononaka-danmen/secrets/token.json)。
上げる前に、鍵のチャンネルが合っているかを確かめ、違えば止める。子ども向けではない・カテゴリは教育(27)。

使い方: python -m naze.upload 動画.mp4 --title "…" --desc-file 説明.txt [--publish-at 2026-10-26T09:00:00+09:00]
--publish-at を付けると非公開で上げて、その時刻に公開する予約になる。投稿の前に必ず動画をユーザーに見せる。
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

CHANNEL_ID = "UC3l_jGgDvr1JilhUUaERT3w"          # 理の書(@kotowari、2026-10-26 に棒人間ストーリーから変更)
DEFAULT_TOKEN = Path.home() / "dev" / "output" / "yononaka-danmen" / "secrets" / "token.json"


def service():
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
    tok = Path(os.environ.get("NAZE_YT_TOKEN", DEFAULT_TOKEN))
    c = Credentials.from_authorized_user_file(str(tok))
    if not c.valid:
        c.refresh(Request())
        tok.write_text(c.to_json(), encoding="utf-8")
    return build("youtube", "v3", credentials=c)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--title", required=True)
    ap.add_argument("--desc-file", required=True)
    ap.add_argument("--publish-at", default="")
    ap.add_argument("--tags", default="なぜ,解説,雑学")
    a = ap.parse_args()
    from googleapiclient.http import MediaFileUpload
    yt = service()
    me = yt.channels().list(part="snippet", mine=True).execute().get("items", [])
    if not me or me[0]["id"] != CHANNEL_ID:
        sys.exit(f"鍵のチャンネルが違うので止める: {[(i['id'], i['snippet']['title']) for i in me]}")
    status = dict(privacyStatus="public", selfDeclaredMadeForKids=False, embeddable=True)
    if a.publish_at:
        status.update(privacyStatus="private", publishAt=a.publish_at)
    body = dict(snippet=dict(title=a.title, description=Path(a.desc_file).read_text(encoding="utf-8"), tags=[t for t in a.tags.split(",") if t],
                             categoryId="27", defaultLanguage="ja", defaultAudioLanguage="ja"),
                status=status)
    req = yt.videos().insert(part="snippet,status", body=body, media_body=MediaFileUpload(a.video, chunksize=8 * 1024 * 1024, resumable=True))
    res = None
    while res is None:
        st, res = req.next_chunk()
        if st:
            print(f"  {int(st.progress() * 100)}%")
    print(f"投稿しました: https://youtu.be/{res['id']}" + (f"(公開予約 {a.publish_at})" if a.publish_at else "(公開)"))


if __name__ == "__main__":
    main()
