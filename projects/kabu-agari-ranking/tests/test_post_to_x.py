"""X への投稿文のテスト。

投稿はサイトへの唯一の流入経路なので、文面が壊れる＝誰も来ない。
長さ超過で 403 になっても、投稿処理は警告を出すだけで止まらない
（サイトの公開を巻き込まないため）＝壊れても気づきにくい。ここで固定する。
"""
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


def test_長い銘柄名でも280字に収まる():
    # 全角も1字として数える X の仕様に対し、余裕をもって収まることを見る
    text = post_to_x._build_tweet(_payload())
    assert len(text) <= 280, text


def test_銘柄名は途中で切る():
    assert post_to_x._truncate("あいうえおかきくけこさ") == "あいうえおかきくけこ…"
    assert post_to_x._truncate("みじかい") == "みじかい"


def test_件数が3件未満でも作れる():
    text = post_to_x._build_tweet(_payload(n=1))
    assert "1位" in text and "2位" not in text
