"""10-07 に足した5つ：サムネ3案・検索候補の語・冒頭15秒の点検・絵の割り当ての下書き・ショートの最初の2秒の点検。

CI には日本語フォントも素材も検索の通信も無いので、内蔵のフォント・その場で作った絵・作り物の検索候補で確かめる。
"""
import pytest
from PIL import Image, ImageChops

from chiso import assign, check, cli, keywords, script, thumb


# --- 1. サムネイル3案 -----------------------------------------------------------

THUMB = {"image": "p.jpg", "crop": [0, 0, 1600, 900], "focus": [150, 60, 1000, 760],
         "hook": "「天下統一の革命児」", "stamp": "実は保守的？", "name": "織田信長", "lead": "本当に", "main": "革命児？"}


def _assets(tmp_path, size=(1600, 2000)):
    im = Image.new("RGB", size, (120, 90, 60))
    im.paste((230, 200, 170), (600, 300, 1000, 700))           # 顔のつもりの明るい所
    im.save(tmp_path / "p.jpg")
    return tmp_path


def _sc(t):
    return script.parse({"title": "織田信長は何者か", "thumbnail": t,
                         "sections": [{"title": "一", "lines": [{"語り": "a"}]}]})


def test_variant_a_is_the_script_as_is():
    spec = thumb.variant_spec(THUMB, "a")
    assert {k: spec[k] for k in THUMB} == THUMB and spec["layout"] == "a"


def test_variant_b_zooms_and_keeps_only_name_and_main():
    spec = thumb.variant_spec(THUMB, "b", (1600, 2000))
    assert "hook" not in spec and "stamp" not in spec and "lead" not in spec
    assert spec["name"] == "織田信長" and spec["main"] == "革命児？"
    x0, y0, x1, y1 = spec["crop"]
    assert (x1 - x0) < 1600 and abs((x1 - x0) / (y1 - y0) - 16 / 9) < 0.01      # 寄せて、16:9 のまま
    assert 0 <= x0 and 0 <= y0 and x1 <= 1600 and y1 <= 2000                      # 絵の外に出ない


def test_variant_b_crop_from_script_wins():
    t = dict(THUMB, variants={"b": {"crop": [10, 20, 330, 200]}})
    assert thumb.variant_spec(t, "b", (1600, 2000))["crop"] == [10, 20, 330, 200]


def test_face_crop_stays_inside_small_pictures():
    x0, y0, x1, y1 = thumb.face_crop([0, 0, 640, 360], [0, 0, 1280, 720], (640, 360))
    assert (x0, y0) >= (0, 0) and x1 <= 640 and y1 <= 360


def test_variant_c_top_word_and_override():
    assert thumb.variant_spec(THUMB, "c")["top"] == "実は保守的？"                 # 短い判子はそのまま
    assert "stamp" not in thumb.variant_spec(THUMB, "c")
    assert thumb.top_word({"stamp": "約168cm！"}) == "約168cm"
    assert thumb.top_word({"hook": "「四十七士より長い……1万2000人が動いた大事件」"}) == "1万2000人"   # 長い見出しは数字だけ
    assert thumb.top_word({"hook": "「天下人の弟」"}) == "天下人の弟"
    assert thumb.top_word({"main": "弟"}) == "弟"
    t = dict(THUMB, variants={"c": {"top": "49年", "main": "天下人"}})
    spec = thumb.variant_spec(t, "c")
    assert spec["top"] == "49年" and spec["main"] == "天下人"


def test_unknown_variant_is_error():
    with pytest.raises(ValueError):
        thumb.variant_spec(THUMB, "d")


def test_make_variants_draws_three_different_pictures(tmp_path):
    assets = _assets(tmp_path)
    sc = _sc(THUMB)
    imgs = thumb.make_variants(sc, {"fonts": {}}, assets)
    assert list(imgs) == ["a", "b", "c"] and all(im.size == (1280, 720) for im in imgs.values())
    assert ImageChops.difference(imgs["a"], thumb.make(sc, {"fonts": {}}, assets)).getbbox() is None   # a は今の形
    assert ImageChops.difference(imgs["a"], imgs["b"]).getbbox() is not None
    assert ImageChops.difference(imgs["a"], imgs["c"]).getbbox() is not None
    # c の下は赤い帯（色の配分が違う）
    r, g, b = imgs["c"].getpixel((1000, 600))[:3]
    assert r > 150 and g < 80 and b < 80
    pv = thumb.variants_preview(imgs)
    assert pv.width > 1100 and pv.height > 3 * 360


def test_cli_thumb_variants(tmp_path, monkeypatch):
    (tmp_path / "assets").mkdir()
    assets = _assets(tmp_path / "assets")
    sp = tmp_path / "x.yaml"
    sp.write_text("title: 織田信長\nthumbnail: {image: p.jpg, crop: [0, 0, 1600, 900], name: 織田信長, main: 革命児？}\n"
                  "sections: [{title: 一, lines: [{語り: a}]}]\n", encoding="utf-8")
    monkeypatch.setattr(cli, "load_config", lambda: {"fonts": {"gothic": None}, "assets_dir": "."})
    monkeypatch.setenv("CHISO_ASSETS", str(assets))
    out = tmp_path / "out"
    assert cli.main(["thumb", str(sp), "--variants", "--out", str(out)]) == 0
    names = sorted(p.name for p in out.iterdir())
    assert names == ["x_thumbnail_a.png", "x_thumbnail_b.png", "x_thumbnail_c.png", "x_thumbnail_variants_preview.png"]


# --- 3・5. 冒頭15秒とショートの最初の2秒 ----------------------------------------------

def _ep(lines, shorts=None, people=None, title="織田信長は何者か"):
    data = {"title": title, "sections": [{"title": "一", "lines": lines}]}
    if shorts:
        data["shorts"] = shorts
    if people:
        data["people"] = people
    return script.parse(data)


def test_opening_needs_a_concrete_fact():
    vague = [{"語り": "今日は、ある人の話をします。"}, {"聞き": "どんな人？"}, {"語り": "とても有名な人です。"},
             {"聞き": "気になる！"}, {"語り": "1582年、本能寺で亡くなりました。"}]          # 事実は5行目
    assert check.opening_rules(_ep(vague, title="x")) != []
    good = [{"語り": "1582年6月2日の朝、京都の本能寺が燃えました。"}] + vague[1:]
    assert check.opening_rules(_ep(good, title="x")) == []
    named = [{"語り": "織田信長。この名前を知らない人はいません。"}] + vague[1:]
    assert check.opening_rules(_ep(named)) == []
    kansuji = [{"語り": "家来は、四十七人。"}] + vague[1:]
    assert check.opening_rules(_ep(kansuji, title="x")) == []


def test_opening_window_is_about_100_chars():
    long_first = [{"語り": "あ" * 101}, {"語り": "1582年の話です。"}]                    # 2行目は15秒より後
    assert check.opening_rules(_ep(long_first, title="x")) != []


def test_short_first_line():
    lines = [{"語り": "そして、信長は京へ向かいます。", "short": "s1"},
             {"語り": "誰も知らない話です。", "short": "s2"},
             {"語り": "信長は、1560年に今川義元を破ります。", "short": "s3"},
             {"語り": "ここからが本題です。", "short": "s4"}, {"語り": "1万人が動きました。", "short": "s4"}]
    sc = _ep(lines, shorts={k: {"title": k} for k in ("s1", "s2", "s3", "s4")},
             people={"織田信長": {"born": "1534-06-23"}})
    warns = check.short_opening_rules(sc)
    assert any("s1" in w and "そして" in w for w in warns)
    assert any("s2" in w and "名前も数字も" in w for w in warns)
    assert not any("s3" in w for w in warns)
    assert any("s4" in w for w in warns)                         # 2行目に数字があっても、1行目で見る


def test_name_words_split_four_kanji_names():
    sc = _ep([{"語り": "a"}], people={"織田信長": {"born": "1534-06-23", "match": ["上総介"]}})
    names = check.name_words(sc)
    assert {"織田信長", "上総介", "織田", "信長"} <= set(names)


def test_episode_reports_opening_and_shorts():
    base = {"title": "t", "next": {"title": "次", "teaser": "t"},
            "thumbnail": {k: "x" for k in ("image", "crop", "name", "main")}, "shorts": {"s1": {"title": "x"}},
            "sections": [{"title": "まとめ：何者か", "lines": [
                {"語り": "今日の話です。", "short": "s1"}, {"語り": "今日の地層は、ここまでです。"},
                {"二人": "また一緒に、掘りましょう！"}]}]}
    errors, warns = check.episode(script.parse(base))
    assert any("冒頭15秒" in w for w in warns) and any("ショート" in w and "s1" in w for w in warns)
    assert not any("冒頭" in e or "ショート" in e for e in errors)          # 止めはしない


# --- 2. 検索候補の語 -----------------------------------------------------------------

RAW = {
    "織田信長": ["織田信長", "織田信長 本能寺の変", "織田信長 fgo", "織田信長 大河ドラマ"],
    "織田信長 ": ["織田信長 本能寺の変", "織田信長 解説", "織田信長 渡哲也"],
    "織田信長 あ": ["織田信長 明智光秀", "織田信長 安土城", "織田信長の野望", "織田信長 ai", "織田信長の妻"],
}


def test_mark_game_drama_generic():
    assert keywords.mark("fgo") == "game" and keywords.mark("無双") == "game"
    assert keywords.mark("の野望") == "game" and keywords.mark("信長の野望") == "game"
    assert keywords.mark("大河ドラマ") == "drama" and keywords.mark("渡哲也") == "drama"
    assert keywords.mark("解説") == "generic"
    assert keywords.mark("ai") == "game" and keywords.mark("samurai") == ""        # 短い英字は語として一致したときだけ
    assert keywords.mark("本能寺の変") == ""


def test_count_weights_top_suggestions():
    words, _ = keywords.count("織田信長", RAW)
    assert words.most_common(1)[0][0] == "本能寺の変"           # 2回出た
    assert "妻" in words and "の妻" not in words                 # 「秀長の妻」型は「妻」に
    assert "の野望" in words                                       # ゲームの語は印を付けて残す


def test_suggest_excludes_marked_words():
    words, _ = keywords.count("織田信長", RAW)
    sug = keywords.suggest("織田信長", words)
    assert len(sug["titles"]) == 3 and all(t.startswith("織田信長") for t in sug["titles"])
    joined = " ".join(sug["titles"] + sug["tags"] + sug["description_words"])
    for bad in ("fgo", "大河", "渡哲也", "解説", "野望", " ai"):
        assert bad not in joined
    assert sug["tags"][0] == "織田信長" and len(sug["tags"]) <= 15 and "織田信長 本能寺の変" in sug["tags"]


def test_collect_queries_and_waits(monkeypatch):
    asked = []
    raw = keywords.collect("豊臣秀長", wait=0, fetcher=lambda q: asked.append(q) or [q + "x"])
    assert asked[:2] == ["豊臣秀長", "豊臣秀長 "] and asked[2] == "豊臣秀長 あ" and len(asked) == 12
    assert len(keywords.queries("豊臣秀長", full=True)) == 48
    assert raw["豊臣秀長 あ"] == ["豊臣秀長 あx"]


def test_fetch_uses_curl_and_survives_failures(monkeypatch):
    import subprocess
    calls = []

    class R:
        returncode, stdout = 0, '["織田信長",["織田信長 本能寺の変","織田信長 家紋"]]'.encode("utf-8")
    monkeypatch.setattr(subprocess, "run", lambda cmd, **kw: calls.append(cmd) or R())
    assert keywords.fetch("織田信長") == ["織田信長 本能寺の変", "織田信長 家紋"]
    assert calls[0][0] == "curl" and "ds=yt" in calls[0][-1] and "%E7%B9%94" in calls[0][-1]

    class Bad:
        returncode, stdout = 0, b"<html>"
    monkeypatch.setattr(subprocess, "run", lambda cmd, **kw: Bad())
    assert keywords.fetch("織田信長") == []


def test_report_and_description_line():
    text, data = keywords.report("織田信長", RAW)
    assert "ゲーム・娯楽" in text and "大河・ドラマ" in text and "## 題名の候補" in text
    sc = _ep([{"語り": "1582年、本能寺の変が起きます。"}, {"語り": "安土城は燃えました。"}])
    covered = keywords.covered_words([w for w, _ in data["words"]], sc)
    assert covered == ["本能寺の変", "安土城"] or set(covered) == {"本能寺の変", "安土城"}   # 台本に出てくる語だけ
    assert keywords.description_line(covered).startswith("この動画で扱うこと：")
    assert keywords.description_line([]) == ""


# --- 4. 絵の割り当ての下書き -----------------------------------------------------------

ASSETS_MD = """# 素材一覧

| ファイル名 | 何か | 年 | 作者 | 大きさ | ライセンス | 台本で合う場面 | Commons |
|---|---|---|---|---|---|---|---|
| p_alps.jpg | アルプス越えのナポレオン。白馬 | 1801-03 | ダヴィッド | 1920x2294 | PD | 1800年のアルプス越え | https://x |
| p_coronation.jpg | ナポレオンの戴冠式。ノートルダム | 1805-1807 | ダヴィッド | 1920x1207 | PD | 1804年の戴冠・ジョゼフィーヌが皇后に | https://y |
| p_sphinx.jpg | スフィンクスの前のボナパルト | 1867-68 | ジェローム | 1920x1138 | PD | エジプト遠征 | https://z |

## 注意
- 表の外の行は読まない
"""


def test_parse_assets_reads_table_and_scene_years():
    assets = assign.parse_assets(ASSETS_MD)
    assert [a.file for a in assets] == ["p_alps.jpg", "p_coronation.jpg", "p_sphinx.jpg"]
    assert assets[0].years == {1800}                       # 描いた年（1801-03）ではなく、出来事の年
    assert {"アルプス", "ナポレオン"} <= assets[0].tokens
    assert "戴冠" in assets[1].tokens and "エジプト" in assets[2].tokens
    assert assign.years("1805-1807年と1796-97") == {1805, 1806, 1807, 1796, 1797}


def test_draft_switches_on_match_and_suggests_detail():
    lines = ([{"語り": "1798年、ナポレオンはエジプト遠征に出ます。"}]
             + [{"語り": "砂漠を進む兵士たちの話が、長く続きます。" * 2} for _ in range(15)]     # 合う絵が無いまま長い
             + [{"語り": "1804年、ノートルダムで戴冠式が開かれます。"}])
    sc = script.parse({"title": "ナポレオン", "sections": [{"title": "エジプト", "lines": lines}]})
    picks = assign.draft(sc, assign.parse_assets(ASSETS_MD))
    assert picks[0].line.index == 0 and picks[0].file == "p_sphinx.jpg"
    assert any(p.detail for p in picks)                                       # 40秒を超えた所は detail の候補
    last = picks[-1]
    assert last.line.index == len(lines) - 1 and last.file == "p_coronation.jpg" and "戴冠式" in last.reason
    text = assign.report(sc, assign.parse_assets(ASSETS_MD), picks)
    assert "| 行 | 時刻 |" in text and "p_alps.jpg" in text.split("## 使わなかった絵")[1]


def test_cli_assign_writes_markdown(tmp_path, monkeypatch):
    sp = tmp_path / "x.yaml"
    sp.write_text("title: ナポレオン\nsections: [{title: 一, lines: [{語り: 1804年、戴冠式。}]}]\n", encoding="utf-8")
    md = tmp_path / "x_assets.md"
    md.write_text(ASSETS_MD, encoding="utf-8")
    monkeypatch.setattr(cli, "out_dir", lambda: tmp_path)
    assert cli.main(["assign", str(sp), "--assets", str(md)]) == 0
    assert "p_coronation.jpg" in (tmp_path / "x_assign.md").read_text(encoding="utf-8")
