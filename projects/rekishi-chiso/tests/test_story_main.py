"""物語型の本編（台本の一番上に story: true。10-24 ユーザー決定）の決まり。

- check：締めの決まり文句（剣崎「今日の地層は」→二人「また一緒に」）と次回予告（next:）を必須にしない。最後の行は剣崎。
  想像の台詞は1本8か所まで、「〇〇想像」の声と imagined: true をそろえる。旧型の台本は今までどおり。
- script：imagined: true の行の札はメモ欄に積まない。
- render：imagined: true の行は字幕の上に小さく「想像」の札。
- describe：description_head を一番上に、description_note を目次の前に。
"""
from pathlib import Path

from PIL import Image, ImageFont

from chiso import check, cli, render, script

THUMB = {k: "x" for k in ("image", "crop", "hook", "stamp", "name", "main")}


def _story(last=None, imagined=1, story=True, mark=True, who="お市想像"):
    lines = [{"語り": "1583年4月、最期の夜を迎える城に、ひとりの女がいました。"}]
    for _ in range(imagined):
        lines.append({"人物": "「この子たちだけは」", "who": who, **({"imagined": True} if mark else {})})
    data = {"title": "お市の方｜なぜ", "thumbnail": THUMB, **({"story": True} if story else {}),
            "sections": [{"title": "導入", "lines": lines},
                         {"title": "まとめ：その後", "lines": last or [{"語り": "お市は、その城で生涯を閉じました。"},
                                                                     {"語り": "チャンネル登録も、よろしくお願いします。"}]}]}
    return script.parse(data)


def test_story_does_not_need_closing_or_next():
    errors, warns = check.episode(_story())
    assert errors == []
    assert not any("二人" in w for w in warns)


def test_story_last_line_is_the_narrator():
    sc = _story(last=[{"語り": "余韻の一文。"}, {"二人": "また一緒に、掘りましょう！"}])
    errors, warns = check.cast_rules(sc)
    assert any("剣崎" in e for e in errors)
    assert any("二人" in w for w in warns)


def test_old_type_still_needs_closing_and_next():
    errors, _ = check.episode(_story(story=False))
    assert any("次回" in e for e in errors)
    assert any("また一緒に" in e for e in errors)
    assert any("今日の地層は" in e for e in errors)


def test_imagined_lines_are_counted_and_marked():
    _, warns = check.cast_rules(_story(imagined=9))
    assert any("9か所" in w for w in warns)
    _, warns = check.cast_rules(_story(imagined=8))
    assert not any("か所（1本" in w for w in warns)
    errors, _ = check.cast_rules(_story(mark=False))                  # 想像の声なのに印が無い
    assert any("imagined" in e for e in errors)
    errors, _ = check.cast_rules(_story(who="お市"))                  # 印があるのに記録の声
    assert any("想像" in e for e in errors)


def test_imagined_card_is_not_added_to_memo():
    sc = script.parse({"title": "t", "sections": [{"title": "一", "lines": [
        {"語り": "a", "card": {"head": "1583年", "body": "北ノ庄"}},
        {"人物": "「b」", "who": "お市想像", "imagined": True, "card": {"head": "想像", "body": "x"}},
        {"語り": "c"}]}]})
    assert sc.lines[1].imagined and not sc.lines[0].imagined
    assert [c.head for c in sc.lines[2].memo] == ["1583年"]


class _Painter(render.Painter):
    def font(self, kind, size, bold=False):
        return ImageFont.load_default(size)


def test_imagined_tag_above_the_subtitle(tmp_path):
    for name in ("k.png", "t.png"):
        Image.new("RGBA", (300, 900), (90, 110, 160, 255)).save(tmp_path / name)
    config = {"cast": {"語り": {"name": "剣崎雌雄", "image": "k.png", "side": "left"},
                       "聞き": {"name": "春日部つむぎ", "image": "t.png", "side": "right"}},
              "roles": {"お市想像": {"label": "お市の方（想像）", "name": "冥鳴ひまり"}}, "subtitles": True}
    sc = _story()
    p = _Painter(config, sc, tmp_path, (1920, 1080))
    p.layered = True
    line = sc.lines[1]
    st = render.state_of(line)
    assert st.imagined
    base = p.base(render.state_of(sc.lines[0]))
    plain = p.with_cast(base, line.speaker, 0, "この子たちだけは")
    tagged = p.with_cast(base, line.speaker, 0, "この子たちだけは", imagined=True)
    y0 = 1080 - 34 - (34 + 60 * render.SUB_ROWS)
    box = (440 + 20, y0 - 18, 440 + 120, y0 + 14)                     # 字幕の枠の左上（名札は真ん中）
    assert plain.crop(box).tobytes() != tagged.crop(box).tobytes()
    assert tagged.getpixel((440 + 30, y0 - 8))[:3] == render.IMAGINED_COLOR


def test_describe_puts_head_first_and_note_before_credits(monkeypatch, tmp_path):
    monkeypatch.setenv("CHISO_ASSETS", str(tmp_path))
    data = {"title": "t", "story": True, "description_head": "1583年4月、北ノ庄城。\nこの動画でわかること",
            "description_note": "再現の場面の台詞の一部は、記録をもとにした想像です。",
            "sections": [{"title": "一", "lines": [{"語り": "a"}]}]}
    sc = script.parse(data)
    config = {"cast": {"語り": {"name": "剣崎雌雄"}}, "operator": "つるはし社"}
    text = cli.description(sc, config, cues=None)
    rows = text.splitlines()
    assert rows[0] == "1583年4月、北ノ庄城。"
    assert rows.index("再現の場面の台詞の一部は、記録をもとにした想像です。") < rows.index("■ 音声")
    old = cli.description(script.parse({k: v for k, v in data.items() if not k.startswith("description")}), config, None)
    assert old.splitlines()[0] == "■ 音声"                            # 書いていない台本は今までどおり
