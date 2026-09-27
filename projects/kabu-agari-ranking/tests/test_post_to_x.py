"""X への投稿文のテスト。

投稿はサイトへの唯一の流入経路なので、文面が壊れる＝誰も来ない。
長さ超過で 403 になっても、投稿処理は警告を出すだけで止まらない
（サイトの公開を巻き込まないため）＝壊れても気づきにくい。ここで固定する。
"""
import json
import post_to_x


def _payload(rec_date="2026-09-18", n=30):
    return {
        "rec_date": rec_date,
        "gainers": [
            {
                "rank": i + 1,
                "code": f"{7200 + i}",
                "name": "ながい名前のかぶしきがいしゃ" * 3,
                "close": 1000.0,
                "change_pct": 20.0 - i,
                "metric_value": 1000,
            }
            for i in range(n)
        ],
    }


def test_投稿文に日付と順位とURLが入る():
    text = post_to_x._build_tweet(_payload())
    assert "2026-09-18" in text
    assert "1位" in text and "3位" in text
    assert "4位" not in text  # 上位3件だけ
    # トップではなくその日のページ（翌日には別の内容になってしまうため）
    assert "archive/gainers/2026-09-18" in text


def test_ストップ高を投稿文に出す():
    p = _payload(n=3)
    # 113円 → 163円（値幅50円）はストップ高
    p["gainers"][0].update(close=163.0, change_pct=44.25)
    text = post_to_x._build_tweet(p)
    assert "（S高）" in text
    assert "ストップ高は1銘柄" in text


def test_ストップ高が無ければその行を出さない():
    text = post_to_x._build_tweet(_payload())
    assert "ストップ高" not in text


def test_長い銘柄名でもXの数え方で上限に収まる():
    # X は日本語を2文字、URL を23文字として数える。素の len() で見ていると
    # 上限を超えたまま気づけず、投稿が 403 で弾かれる（警告が出るだけ）。
    text = post_to_x._build_tweet(_payload())
    assert post_to_x.weighted_length(text) <= 280, post_to_x.weighted_length(text)


def test_Xの数え方():
    assert post_to_x.weighted_length("abc") == 3          # ラテンは1文字
    assert post_to_x.weighted_length("あいう") == 6        # 日本語は2文字
    # URL は長さによらず23文字
    short = post_to_x.weighted_length("https://a.jp/x")
    long = post_to_x.weighted_length("https://example.com/archive/gainers/2026-09-18")
    assert short == long == 23


def test_上限を超えたら後ろから削る():
    payload = _payload()
    payload["gainers"] = [
        {**row, "name": "ながいなまえのかぶしきがいしゃ" * 2} for row in payload["gainers"]
    ]
    # 無理やり長くする（本来は _truncate が効くが、削る側の動きを見る）
    payload["rec_date"] = "2026-09-18"
    text = post_to_x._build_tweet(payload)
    assert post_to_x.weighted_length(text) <= 280
    # ドメイン名ではなく公開設定を見る。移転のたびにテストが落ちるのを避ける。
    assert post_to_x.SITE_URL in text, "URL は最後まで残す"


def test_銘柄名は途中で切る():
    assert post_to_x._truncate("あいうえおかきくけこさ") == "あいうえおかきくけこ…"
    assert post_to_x._truncate("みじかい") == "みじかい"


def test_件数が3件未満でも作れる():
    text = post_to_x._build_tweet(_payload(n=1))
    assert "1位" in text and "2位" not in text


def test_本当に上限を超える日は後ろから削る(monkeypatch):
    """上限を定数に置いてあるのに、どこでも見ていなかった（2026-09-28 に気づいた）。
    _truncate が効くので普段は超えないが、超えた日は 403 で弾かれていた。"""
    monkeypatch.setattr(post_to_x, "_NAME_MAX_LEN", 40)
    monkeypatch.setattr(post_to_x, "_TOP_N", 10)
    payload = _payload()
    payload["gainers"] = [
        {"rank": i, "code": f"{1000 + i}", "name": "あ" * 40,
         "close": 163.0, "change_pct": 44.25, "metric_value": 1}
        for i in range(1, 11)
    ]
    text = post_to_x._build_tweet(payload)
    assert post_to_x.weighted_length(text) <= post_to_x._TWEET_LIMIT
    # 日付と行き先は最後まで残す
    assert payload["rec_date"] in text
    assert post_to_x.SITE_URL in text
    # 順位の高いものほど残る
    assert "1位 " in text


def test_削るのはハッシュタグが先(monkeypatch):
    """本文の銘柄より、ハッシュタグのほうが無くても意味が通る。"""
    monkeypatch.setattr(post_to_x, "_TOP_N", 5)
    # ハッシュタグ（17文字ぶん）を外せばちょうど収まる長さ
    payload = _payload()
    payload["gainers"] = [
        {"rank": i, "code": f"{1000 + i}", "name": "あ" * 8,
         "close": 163.0, "change_pct": 44.25, "metric_value": 1}
        for i in range(1, 6)
    ]
    text = post_to_x._build_tweet(payload)
    assert post_to_x.weighted_length(text) <= post_to_x._TWEET_LIMIT
    assert "#日本株" not in text
    assert "5位 " in text, "ハッシュタグを削れば足りるのに銘柄まで削っている"


# --- 投稿しない分岐 -----------------------------------------------------------

def _no_network(monkeypatch):
    """ここを通ったら実際に投稿しようとしている。"""
    def boom(*a, **k):
        raise AssertionError("投稿してはいけない場面で送信しようとした")
    monkeypatch.setattr(post_to_x, "OAuth1Session", boom)


def test_キーが無ければ投稿しない(monkeypatch, capsys):
    _no_network(monkeypatch)
    for key in ("X_API_KEY", "X_API_SECRET", "X_ACCESS_TOKEN", "X_ACCESS_TOKEN_SECRET"):
        monkeypatch.delenv(key, raising=False)
    post_to_x.post_today()
    assert "未設定" in capsys.readouterr().out


def _with_keys(monkeypatch):
    for key in ("X_API_KEY", "X_API_SECRET", "X_ACCESS_TOKEN", "X_ACCESS_TOKEN_SECRET"):
        monkeypatch.setenv(key, "dummy")


def test_最新データが無ければ投稿しない(monkeypatch, tmp_path, capsys):
    _no_network(monkeypatch)
    _with_keys(monkeypatch)
    monkeypatch.setattr(post_to_x, "_LATEST_PATH", tmp_path / "latest.json")
    post_to_x.post_today()
    assert "latest.json が無い" in capsys.readouterr().out


def test_同じ日を二度投稿しない(monkeypatch, tmp_path, capsys):
    """記録の置き場が手元しか無いので、ここが唯一の歯止め。"""
    _no_network(monkeypatch)
    _with_keys(monkeypatch)
    latest = tmp_path / "latest.json"
    latest.write_text(json.dumps(_payload(), ensure_ascii=False), encoding="utf-8")
    last = tmp_path / "last_tweet.txt"
    last.write_text(_payload()["rec_date"], encoding="utf-8")
    monkeypatch.setattr(post_to_x, "_LATEST_PATH", latest)
    monkeypatch.setattr(post_to_x, "_LAST_POST_PATH", last)
    post_to_x.post_today()
    assert "投稿済み" in capsys.readouterr().out


def test_値上がりが空なら投稿しない(monkeypatch, tmp_path, capsys):
    _no_network(monkeypatch)
    _with_keys(monkeypatch)
    payload = {**_payload(), "gainers": []}
    latest = tmp_path / "latest.json"
    latest.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(post_to_x, "_LATEST_PATH", latest)
    monkeypatch.setattr(post_to_x, "_LAST_POST_PATH", tmp_path / "none.txt")
    post_to_x.post_today()
    assert "値上がりデータが無い" in capsys.readouterr().out
