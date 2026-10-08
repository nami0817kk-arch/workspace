from types import SimpleNamespace as NS

from chiso import shortpost

CONFIG = {"cast": {"語り": {"name": "剣崎雌雄"}, "聞き": {"name": "春日部つむぎ"}},
          "roles": {"マリー": {"name": "波音リツ"}}, "character_credits": ["立ち絵：x"]}


def _sc():
    lines = [NS(speaker="語り", shorts=("s1",)), NS(speaker="マリー", shorts=("s1",)), NS(speaker="聞き", shorts=("s2",))]
    return NS(shorts={"s1": {"title": "題／二行", "yt_title": "検索される題", "lead": "一言目", "tags": ["首飾り事件", "首飾り事件", "a b"]},
                      "s2": {"title": "画面の題／二行"}},
              tags=["マリーアントワネット", "マリー・アントワネット", "世界史"], question="本当に悪女だったのか",
              short_lines=lambda sid: [l for l in lines if sid in l.shorts])


def test_title_tags_description():
    sc = _sc()
    assert shortpost.title(sc, "s1") == "検索される題"
    assert shortpost.title(sc, "s2") == "画面の題 二行"                       # yt_title が無ければ画面の題
    assert shortpost.tags(sc, "s1") == ["首飾り事件", "a b", "マリーアントワネット", "マリー・アントワネット", "世界史"]
    d = shortpost.description(sc, CONFIG, "s1", "ABC")
    assert d.startswith("一言目") and "https://youtu.be/ABC" in d and "本当に悪女だったのか" in d
    assert "VOICEVOX:波音リツ" in d                                         # マリーの声を使ったショートだけ
    assert d.splitlines()[-1] == "#首飾り事件 #マリーアントワネット #世界史"
    assert "波音リツ" not in shortpost.description(sc, CONFIG, "s2", None)


def test_tags_fit_youtube_limit():
    sc = _sc()
    sc.shorts["s1"]["tags"] = ["あ" * 100] * 10
    assert sum(len(t) + 1 for t in shortpost.tags(sc, "s1")) <= shortpost.TAGS_CHARS + 1


def test_schedule_hourly():
    assert shortpost.schedule("2026-10-05 11:00", 60, 3) == ["2026-10-05 11:00", "2026-10-05 12:00", "2026-10-05 13:00"]


def test_description_opens_with_tease_and_main_link():
    sc = _sc()
    sc.shorts["s1"]["tease"] = "じゃあ、／誰が描いた？"
    d = shortpost.description(sc, CONFIG, "s1", "ABC").splitlines()
    assert d[0] == "じゃあ、誰が描いた？" and d[1] == "答えは本編で→ https://youtu.be/ABC"
    assert sum("https://youtu.be/ABC" in x for x in d) == 1             # 本編のリンクは1回だけ
    d2 = shortpost.description(sc, CONFIG, "s1", None).splitlines()
    assert d2[0] == "じゃあ、誰が描いた？" and "答えは本編で" in d2[1] and "youtu.be" not in "".join(d2)
