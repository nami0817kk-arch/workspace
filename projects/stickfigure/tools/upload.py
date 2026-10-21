"""棒人間ストーリーへ動画を API で上げる(2026-10-21。旧「日本のなぜ」のときに作った鍵がそのまま使える)。

鍵はリポジトリの外(環境変数 STICKFIG_YT_TOKEN、無ければ dev/output/yononaka-danmen/secrets/token.json)。
上げる前に、鍵のチャンネルが棒人間ストーリーかを確かめ、違えば止める。子ども向けではない・カテゴリは映画とアニメ。

使い方: python tools/upload.py 動画.mp4 --title "…" --desc-file 説明.txt [--privacy public|unlisted|private] [--tags 棒人間,アニメ]
ショートは縦(9:16)で 3 分以内なら YouTube が自動でショートにする。題名か説明に #shorts を入れておく。
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

CHANNEL_ID = "UC3l_jGgDvr1JilhUUaERT3w"          # 棒人間ストーリー(@bouningen_story)
DEFAULT_TOKEN = Path.home() / "dev" / "output" / "yononaka-danmen" / "secrets" / "token.json"


def service():
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
    tok = Path(os.environ.get("STICKFIG_YT_TOKEN", DEFAULT_TOKEN))
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
    ap.add_argument("--privacy", default="public", choices=["public", "unlisted", "private"])
    ap.add_argument("--tags", default="棒人間,棒人間アニメ,アニメ")
    a = ap.parse_args()
    from googleapiclient.http import MediaFileUpload
    yt = service()
    me = yt.channels().list(part="snippet", mine=True).execute().get("items", [])
    if not me or me[0]["id"] != CHANNEL_ID:
        sys.exit(f"鍵のチャンネルが棒人間ストーリーではないので止める: {[(i['id'], i['snippet']['title']) for i in me]}")
    body = dict(snippet=dict(title=a.title, description=Path(a.desc_file).read_text(encoding="utf-8"), tags=[t for t in a.tags.split(",") if t],
                             categoryId="1", defaultLanguage="ja", defaultAudioLanguage="ja"),
                status=dict(privacyStatus=a.privacy, selfDeclaredMadeForKids=False, embeddable=True))
    req = yt.videos().insert(part="snippet,status", body=body, media_body=MediaFileUpload(a.video, chunksize=8 * 1024 * 1024, resumable=True))
    res = None
    while res is None:
        st, res = req.next_chunk()
        if st:
            print(f"  {int(st.progress() * 100)}%")
    print(f"投稿しました: https://youtu.be/{res['id']}({a.privacy})")


if __name__ == "__main__":
    main()
