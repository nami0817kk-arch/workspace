"""物語完結型ショート（chiso/storyshort.py）。声・絵の生成は使わない部分だけ。"""
from pathlib import Path

import pytest
from PIL import Image

from chiso import storyshort as S

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "story" / "oichi_s9.yaml"


def _lines():
    return S.lines_of(S.load(SCRIPT))


def _blocks(lines=None):
    return [b for l in (lines or _lines()) for p in l.parts for b in p.blocks]


def test_oichi_script_passes_checks():
    assert S.problems(S.load(SCRIPT)) == []


def test_fourteen_cuts_with_mixed_picture_kinds():
    """第7版：絵は12〜14カット、表情のあるAI人物絵・AI情景絵・実在の絵（出典つき）が混ざる。"""
    doc = S.load(SCRIPT)
    shots = [p.shot for l in _lines() for p in l.parts]
    cuts = list(dict.fromkeys(shots))
    assert 12 <= len(cuts) <= 14 and all(a != b for a, b in zip(shots, shots[1:]))     # 同じ絵が続かない（続くときは別の shot＝別の部分）
    kinds = {doc["shots"][k].get("kind", "ai") for k in cuts}
    assert kinds == {"ai", "real", "composite"}
    assert [k for k in cuts if k.startswith("P")] == ["P1", "P1b", "P6", "P2", "P4", "P5c"]            # 表情のあるAI人物絵（P5・P5b・P3・P3b は使わない）
    from pathlib import Path
    art = Path(__file__).resolve().parent.parent / "out" / "story"
    for k in cuts:
        s = doc["shots"][k]
        if s.get("kind", "ai") == "ai" and str(s.get("file", "")).startswith("oichi3/") and art.exists():   # 絵は手元だけ（CI には無い）
            assert (art / s["file"]).exists() or s.get("placeholder"), k   # 届いた絵（なければ仮の絵）
        if s.get("kind") in ("real", "composite"):
            assert s.get("credit"), k                                                    # 実在の絵は出典つき


def test_screen_text_equals_narration():
    """① 画面に足される文字を全部つなげると、語り（句読点・《》・｜を除く）と一致する。"""
    doc = S.load(SCRIPT)
    said = "".join(S.screen_plain(row["語り"]) for row in doc["lines"])
    shown = "".join(S.screen_plain(u.text) for l in _lines() for u in l.units)
    assert shown == said
    assert "、" not in shown and "。" not in shown


def test_rows_are_10_chars_and_blocks_two_rows():
    """② 1行は10字以内・1ブロックは2行以内。"""
    for b in _blocks():
        assert 1 <= len(b.rows) <= 2
        for r in b.rows:
            assert 1 <= sum(len(S.screen_plain(u.text)) for u in r) <= S.ROW_MAX


def test_blocks_do_not_cross_sentence_ends():
    for l in _lines():
        for p in l.parts:
            sentences = [s for s in p.text.split("。") if s]
            assert len(p.blocks) >= len(sentences)


def test_blocks_follow_clauses_and_keep_yellow():
    """読点・句点で切った句が1ブロック。句をまたがない。《》の黄色は残る。"""
    blocks = S.blocks_of("二度目の落城で、《逃げなかった》姫がいた。茶々は大坂城に、初は和議に、江は徳川の側に。")
    texts = ["".join(S.screen_plain(u.text) for u in b.units) for b in blocks]
    assert texts == ["二度目の落城で", "逃げなかった姫がいた", "茶々は大坂城に初は和議に", "江は徳川の側に"]    # 6字未満の句だけ同じ文の隣とつなぐ
    assert any("《逃げなかった》" in u.text for u in blocks[1].units)
    long = S.blocks_of("勝家は城を出るようにお市に強くすすめましたが、お市は断りました。")
    assert all(sum(len(S.screen_plain(u.text)) for u in r) <= S.ROW_MAX for b in long for r in b.rows)
    assert "".join(S.screen_plain(u.text) for b in long for u in b.units) == "勝家は城を出るようにお市に強くすすめましたがお市は断りました"


def test_every_block_stays_inside_one_clause_and_wraps_at_bunsetsu_boundaries():
    doc = S.load(SCRIPT)
    allowed = []
    for row in doc["lines"]:
        for part in str(row["語り"]).split("｜"):
            for sentence in S.strip_marks(part).split("。"):
                cl = [c for c in sentence.split("、") if c]
                allowed += cl
                allowed += [a + b for a, b in zip(cl, cl[1:])]                    # 6字未満の句（「お市は」「と」）は同じ文の隣とつなぐ
                allowed += [a + b + c for a, b, c in zip(cl, cl[1:], cl[2:])]
    for b in _blocks():
        text = "".join(S.screen_plain(u.text) for u in b.units)
        assert any(text in c for c in allowed), text                     # 句の中に収まる（またがない）
    two = [b for b in _blocks() if len(b.rows) == 2]
    assert two and all(len(r) >= 1 for b in two for r in b.rows)
    wraps = {tuple("".join(S.screen_plain(u.text) for u in r) for r in b.rows) for b in two}
    assert ("城を出るよう", "勧めたと伝わる") in wraps                           # 句の中を文節の境で折り返す（語の途中・句をまたがない）


def test_one_shot_blocks_not_accumulating():
    """ブロックは一度に出す：描画する画像はブロックごとに1枚（文字は足さない）。"""
    fonts = {"gothic": "C:/Windows/Fonts/YuGothB.ttc"}
    if not Path(fonts["gothic"]).exists():
        return
    font_of = S.make_font_of(fonts)
    for b in _blocks()[:6]:
        layers, _pos = S.block_layers(b, font_of, 1200)
        assert len(layers) == 1


def test_unit_start_times_monotonic_inside_voice():
    """③ 文節の開始時刻が単調増加で、声の区間に収まる（声の長さは仮の値）。"""
    lines = _lines()
    secs = [6.0 + i * 0.5 for i in range(len(lines))]
    voice, blocks, spans, total = S.plan(lines, secs)
    for l in lines:
        starts = [u.start for u in l.units]
        assert starts == sorted(starts) and len(set(starts)) == len(starts)
        a, b = voice[l.index]
        assert all(a - 1e-9 <= s <= b + 1e-9 for s in (starts[1:] if l.index == 0 else starts))   # 最初の文節だけ 0 秒から出す
    starts = [u.start for b in blocks for u in b.units]
    assert starts == sorted(starts)
    assert blocks[0].start == 0 and abs(blocks[-1].end - total) < 1e-9
    assert all(b.start == a.end for a, b in zip(blocks, blocks[1:]))       # 間が空いても前のブロックが残る
    assert all(b.start == a.end for a, b in zip(spans, spans[1:]))
    # C は D のあとにもう一度出る（「勝家とともに生涯を閉じました」）
    assert [s.shot for s in spans] == ["P1", "Ck", "S3", "P1b", "P6", "B", "P2", "S2", "S4", "P4", "G", "E", "P5c"]


def test_chunk_onsets_from_mora_counts():
    starts = [0.1 * i for i in range(10)]
    onsets, mismatch = S.chunk_onsets(starts, [3, 3, 4])
    assert onsets == [0.0, pytest.approx(0.3), pytest.approx(0.6)] and not mismatch
    onsets, mismatch = S.chunk_onsets(starts, [2, 2, 2])              # 合わないときは比例
    assert mismatch and onsets[0] == 0.0 and onsets == sorted(onsets)


def test_mora_timeline_scales_to_voice_length():
    q = {"speedScale": 2.0, "prePhonemeLength": 0.1, "postPhonemeLength": 0.1,
         "accent_phrases": [{"moras": [{"text": "コ", "consonant_length": 0.1, "vowel_length": 0.1},
                                        {"text": "ン", "consonant_length": None, "vowel_length": 0.2}],
                             "pause_mora": {"text": "、", "vowel_length": 0.4}},
                            {"moras": [{"text": "ニ", "consonant_length": 0.1, "vowel_length": 0.1}]}]}
    tl = S.mora_timeline(q, 1.0)
    assert [x for _a, _b, x in tl] == ["コ", "ン", "ニ"]
    assert tl == sorted(tl) and tl[-1][1] < 1.0


def test_card_times_follow_the_narration():
    """図解の出入りは語りの中の字から求める（語りと同じ時刻）。"""
    doc = S.load(SCRIPT)
    lines = _lines()
    _v, blocks, _s, total = S.plan(lines, [6.0] * len(lines))
    units = [u for b in blocks for u in b.units]
    ver = next(c for c in doc["cards"] if c["type"] == "versus")
    t0, t1, _ = S.card_times(units, ver, total)
    assert 0 < t0 < t1 and t1 - t0 < 12
    cols = {"type": "columns", "from": "母を失った", "until": "城とともに",
            "items": [{"at": "母を失った", "head": "母", "text": "亡くなった"}, {"at": "敵と味方に", "head": "三人", "text": "分かれる"}]}
    c0, c1, ats = S.card_times(units, cols, total)
    assert ats == sorted(ats) and c0 == ats[0] < c1
    with pytest.raises(ValueError):
        S.card_times(units, {"type": "year", "from": "存在しない言葉"}, total)


def test_peak_markup_and_one_point_one_five_scale():
    plain, mask = S.phrase_plain("だが、お市は《!断った》。《敵》に")
    assert plain == "だが、お市は断った。敵に" and mask[plain.index("断")] == 2 and mask[plain.index("敵")] == 1
    assert S.mark_up(plain, mask) == "だが、お市は《!断った》。《敵》に"
    assert S.screen_plain("お市は《!断った》。") == "お市は断った"
    assert S.PEAK_SCALE == 1.15


def test_pause_before_turns_and_dips():
    lines = _lines()
    secs = [3.0] * len(lines)
    voice, _b, _s, total = S.plan(lines, secs)
    for i, l in enumerate(lines[1:], 1):
        if l.pause is not None:
            assert voice[i][0] - voice[i - 1][1] == pytest.approx(l.pause)          # 転換の前の間
    turn = next(l for l in lines if l.dip)
    assert turn.pause == 0.3                                                     # 転換の直前の1か所だけ0.3秒
    assert all(l.pause is None or 0.12 <= l.pause <= 0.15 for l in lines if l is not turn)    # ほかは0.12〜0.15秒
    assert S.GAP <= 0.15 and S.GAP_HEAVY <= 0.15
    dips = S.dips_of(lines, voice)
    assert dips and all(abs((b - a) - lines[i].pause) < 1e-9 for (a, b), i in zip(dips, [l.index for l in lines if l.dip and l.pause]))
    assert total == pytest.approx(voice[-1][1] + S.END_HOLD + S.end_extra(voice[-1][1]))     # 59秒以内なら登録のお願いの分だけ延ばす
    assert abs((S.END_HOLD - S.CTA_SECONDS) - 0.4) < 1e-9 and S.END_HOLD == 1.2     # 声のあと1.2秒だけ出し、最初の0.4秒は余白（BGM だけ）のあとに「本編は概要欄から」
    assert S.boom_times(lines, voice) == [] and not any(l.riser for l in lines)  # 効果音（低い響き・ライザー）は台本から外した
    assert voice[0][0] == 0.0                                                    # 声は0秒から


def test_subscribe_request_on_screen_at_the_end_without_voice():
    """10-21 決定「ショート末尾に登録のお願い。声なし・画面のみ」を物語型にも（11-01）。文言は旧型と同じ。"""
    from chiso import shorts
    assert S.SUB_TEXT == shorts.CTA_SCREEN == "高評価・チャンネル登録もお願いします"
    lines = _lines()
    assert not any("登録" in l.text for l in lines)                                   # 声（語り）には足さない
    # 尺：余裕があれば締めを SUB_EXTRA 延ばし（表示は計2.0秒）、59秒を超える分は延ばさない
    assert S.end_extra(40.0) == pytest.approx(S.SUB_EXTRA) and S.CTA_SECONDS + S.SUB_EXTRA == pytest.approx(2.0)
    assert 40.0 + S.END_HOLD + S.end_extra(40.0) <= S.MAX_SECONDS
    assert S.end_extra(57.5) == pytest.approx(S.MAX_SECONDS - 57.5 - S.END_HOLD)
    assert S.end_extra(58.5) == 0.0
    voice, _b, _s, total = S.plan(lines, [3.0] * len(lines))
    assert total <= S.MAX_SECONDS
    assert total - S.cta_start(voice[-1][1]) == pytest.approx(S.CTA_SECONDS + S.end_extra(voice[-1][1]), abs=1e-3)
    assert S.cta_start(voice[-1][1]) - voice[-1][1] == pytest.approx(0.4)             # 声のあと0.4秒の余白のあとに出す


def test_subscribe_request_drawn_above_the_cta_pill():
    font = "C:/Windows/Fonts/YuGothB.ttc"                 # config.yaml の fonts.gothic と同じ
    if not Path(font).exists():
        pytest.skip("字体が無い")
    font_of = S.make_font_of({"gothic": font})
    for style, y, sub_y in (("B", None, None), ("C", 1700, 1530)):
        img = Image.new("RGBA", (S.W, S.H), (0, 0, 0, 0))
        S.draw_cta(img, font_of, y, sub_y)
        a = img.split()[3]
        cy = int(S.H * 0.80) if y is None else y
        sy = cy - 92 if sub_y is None else sub_y
        assert a.crop((0, sy, S.W, sy + 72)).getbbox() is not None                    # 登録のお願いの帯
        assert a.crop((0, cy, S.W, cy + 110)).getbbox() is not None                   # 「本編は概要欄から」の札
        assert sy + 72 < cy                                                           # 重ならない
        box = a.getbbox()
        assert box[0] > 60 and box[2] < S.W - 60                                      # 画面の端に寄らない


def test_last_block_is_the_question_and_stays_long():
    lines = _lines()
    voice, blocks, _s, total = S.plan(lines, [3.0] * len(lines))
    last = blocks[-1]
    assert "".join(S.screen_plain(u.text) for u in last.units) == "逃げずにいられますか"
    assert last.end - last.start >= 1.2
    assert any("あなたなら" in "".join(S.screen_plain(u.text) for u in b.units) for b in blocks)


def test_peak_zoom_is_stronger_on_the_peak_shots():
    doc = S.load(SCRIPT)
    lines = _lines()
    _v, _b, spans, _t = S.plan(lines, [3.0] * len(lines))
    eff = {s.shot: (s.zoom or doc["shots"][s.shot].get("zoom", S.ZOOM)) for s in spans}
    assert eff["P1"] == 0.14 and eff["P6"] == 0.14 and eff["S2"] > S.ZOOM                  # 断る・送り出すの絵は8%より強く寄る
    assert eff["Ck"] == S.ZOOM


def test_cards_and_header_render_without_overlap_with_text():
    fonts = {"gothic": "C:/Windows/Fonts/YuGothB.ttc"}
    if not Path(fonts["gothic"]).exists():
        return
    font_of = S.make_font_of(fonts)
    lay = Image.new("RGBA", (S.W, S.H), (0, 0, 0, 0))
    S.draw_header(lay, {"tag": "お市の方", "title": "《逃げなかった》姫と三人の娘"}, font_of)
    assert lay.getbbox()[3] <= S.HEADER_H                                     # 見出し帯は上部だけ
    for kind, fn in (("year", lambda im: S.card_year(im, {"big": "1615年", "sub": "大坂夏の陣"}, 1.0, 0.0, font_of)),
                     ("versus", lambda im: S.card_versus(im, {"left": {"tag": "出発した兵", "big": "約1,500人", "dots": 60},
                                                              "right": {"tag": "帰れた兵", "big": "約80人", "dots": 8}}, 1.0, 0.0, font_of))):
        im = Image.new("RGBA", (S.W, S.H), (0, 0, 0, 0))
        fn(im)
        x0, y0, x1, y1 = im.getbbox()
        assert y1 < S.H * 0.5 + 400 and y0 > S.HEADER_H, kind                   # 語りの文字（下寄り）と重ならない
    cols = Image.new("RGBA", (S.W, S.H), (0, 0, 0, 0))
    S.card_columns(cols, {"items": [{"head": "茶々", "text": "豊臣秀吉の妻"}, {"head": "初", "text": "京極高次の妻"}]},
                   [0.0, 5.0], 1.0, font_of)
    assert cols.getbbox() is not None
    right = cols.crop((S.W // 2, 0, S.W, S.H)).getbbox()                      # 2列目はまだ出ていない（5秒に出る）
    assert right is None or right[0] > 0


def test_motion_is_smooth_and_small():
    zs = [S.motion("in", u / 100)[0] for u in range(101)]
    assert zs[0] == 1.0 and abs(zs[-1] - (1 + S.ZOOM)) < 1e-9
    assert all(b >= a for a, b in zip(zs, zs[1:]))
    assert isinstance(S.cover_window(1000, 2000, (0.5, 0.5), 1.0)[0], float)       # 小数のまま持つ


def test_cover_window_is_9_16_and_inside_source():
    for sw, sh in ((1000, 3000), (3000, 1000), (1024, 1024)):
        x0, y0, x1, y1 = S.cover_window(sw, sh, (0.9, 0.1), 1.08, 0.2, -0.2)
        assert abs((x1 - x0) / (y1 - y0) - S.W / S.H) < 1e-6
        assert x0 >= -1e-6 and y0 >= -1e-6 and x1 <= sw + 1e-6 and y1 <= sh + 1e-6


def test_crop_vertical_is_9_16_and_trims_white_bars():
    im = Image.new("RGB", (1024, 1024), (255, 255, 255))
    im.paste(Image.new("RGB", (1024, 940), (40, 30, 20)), (0, 42))
    out = S.crop_vertical(im)
    assert out.size == (S.W, S.H)
    assert out.getpixel((540, 10)) != (255, 255, 255)


def test_text_size_fits_10_chars_in_80_percent():
    fonts = {"gothic": "C:/Windows/Fonts/YuGothB.ttc"}
    if not Path(fonts["gothic"]).exists():
        return
    f = S.make_font_of(fonts)(S.TEXT_SIZE)
    assert f.getlength("あ" * S.ROW_MAX) <= S.W * 0.82


def test_story_audio_bgm_is_deterministic_quiet_and_fades():
    import numpy as np
    from chiso import storyaudio as A
    b = A.synth_bgm(8.0, seed=7)
    assert np.array_equal(b, A.synth_bgm(8.0, seed=7))                # 同じ音（外部の音源なし・乱数の種で決まる）
    assert len(b) == int(8.0 * A.SR) and float(np.abs(b).max()) <= 0.5 + 1e-6
    assert abs(b[: A.SR // 10]).max() < 0.05 and abs(b[-A.SR // 10:]).max() < 0.05      # 最初はフェードイン・最後はフェードアウト
    boom = A.synth_boom()
    assert float(np.abs(boom).max()) <= 0.9 + 1e-6 and len(boom) > A.SR
    spec = np.abs(np.fft.rfft(boom))[: 400]
    assert np.argmax(spec) * (A.SR / len(boom)) < 120                   # 低い響き（120Hz 未満）


def test_story_audio_mix_keeps_voice_louder(tmp_path):
    import shutil
    import numpy as np
    from chiso import storyaudio as A
    ff = shutil.which("ffmpeg")
    if not ff:
        try:
            import imageio_ffmpeg
            ff = imageio_ffmpeg.get_ffmpeg_exe()
        except Exception:
            pytest.skip("ffmpeg がありません")
    t = np.arange(int(4.0 * A.SR)) / A.SR
    voice = (0.3 * np.sin(2 * np.pi * 220 * t) * (np.sin(2 * np.pi * 3 * t) > 0)).astype("float32")
    A.write_wav(tmp_path / "v.wav", voice, A.SR)
    info = A.mix_voice_bgm(tmp_path / "v.wav", tmp_path / "m.wav", 4.0, [1.0], ff, diff_lu=11.0)
    assert info["voice_lufs"] - info["bgm_lufs_after"] == pytest.approx(11.0, abs=0.2)    # BGM は声より約11 LU 小さい（第8版）
    assert info["rolloff95_hz"] < 4000 and info["head_peak"] < 0.05                       # 帯域は低め、頭出しの強い音が無い
    assert info["peak"] <= 0.9701


def test_hook_says_who_and_what_and_loop_returns_to_it():
    """冒頭の1文は「誰が・何を」を入れる。最初のブロックは1行9字以内・大きい。最後の問いは冒頭の「逃げなかった」に呼応する。"""
    lines = _lines()
    _v, blocks, spans, total = S.plan(lines, [3.0] * len(lines))
    first = blocks[0]
    assert first.big and sum(len(S.screen_plain(u.text)) for u in first.rows[0]) <= 9 and first.start == 0.0
    said = "".join(S.screen_plain(u.text) for b in blocks for u in b.units)
    assert said.startswith("信長の妹お市の方は二度目の落城で逃げなかった")                      # 誰が（信長の妹・お市の方）・何を（二度目の落城で逃げなかった）
    assert S.LOOP_FADE >= 0.3 and S.LEAD == 0.0
    assert "逃げずに" in said.split("あなたなら")[-1]


def test_header_and_now_bar_always_visible_and_in_sync_with_narration():
    """常に画面に出る情報：見出し帯（0秒から）・「いま」の札・年表バー。切り替えは語りがその年・場所を言う所。"""
    doc = S.load(SCRIPT)
    assert doc["hook_clear"] == 0 and doc["header"]["tag"].startswith("お市の方（織田信長の妹）")
    lines = _lines()
    _v, blocks, _s, total = S.plan(lines, [3.0] * len(lines))
    units = [u for b in blocks for u in b.units]
    ts = []
    for it in doc["now"]:
        t0, _t1, _a = S.card_times(units, {"from": it["at"], "items": []}, total)
        ts.append(t0)
    assert ts == sorted(ts) and ts[0] == 0.0
    assert [it["point"] for it in doc["now"]] == [1, 0, 1, 2]                     # 北ノ庄→小谷（十年前）→北ノ庄→大坂
    assert [x["label"] for x in doc["timeline"]] == ["1573 小谷", "1583 北ノ庄", "1615 大坂"]


def test_first_block_scale_and_ease():
    from pathlib import Path
    fonts = {"gothic": "C:/Windows/Fonts/YuGothB.ttc"}
    if not Path(fonts["gothic"]).exists():
        return
    font_of = S.make_font_of(fonts)
    lines = _lines()
    S.plan(lines, [3.0] * len(lines))
    blocks = _blocks(lines)
    big, _ = S.block_layers(blocks[0], font_of, 1200)
    small_block = next(b for b in blocks[2:] if len(b.rows) == 1 and "《" not in "".join(u.text for u in b.units))
    sm, _ = S.block_layers(small_block, font_of, 1200)
    assert big[0].height > sm[0].height * 1.05                                       # 最初のブロックだけ少し大きい
    z_fast = S.motion("in", 0.5, 0.14, "fast")[0]
    assert z_fast > S.motion("in", 0.5, 0.14)[0]                                      # 最初の数秒で寄りが速い


def test_trim_leading_silence(tmp_path):
    import numpy as np
    from chiso import storyaudio as A
    x = np.concatenate([np.zeros(int(0.3 * A.SR)), 0.5 * np.sin(np.arange(A.SR) * 0.1)]).astype("float32")
    A.write_wav(tmp_path / "a.wav", x, A.SR)
    cut, new_len = S.trim_leading_silence(tmp_path / "a.wav", tmp_path / "b.wav")
    assert 0.25 < cut < 0.3 and abs(new_len - (1.3 - cut)) < 0.01
    y, _ = A.read_wav(tmp_path / "b.wav")
    assert abs(y[: int(0.02 * A.SR)]).max() < 0.2 and abs(y[: int(0.06 * A.SR)]).max() > 0.1


def test_tempo_voice_speed_and_amount():
    """第8版のテンポ：語りは300〜345字、声の基準は1.35〜1.42、しみじみ・重いも実効1.28以上、強調・疑問は1.38前後、上限1.5。"""
    doc = S.load(SCRIPT)
    lines = _lines()
    total = sum(len(l.text) for l in lines)
    assert 360 <= total <= 460                                                       # 第9版：初めて見る人に分かるよう説明を足した（380字前後。60秒に収める）
    assert 1.35 <= doc["voice"]["speed"] <= 1.42 and doc["voice"]["max_speed"] == 1.5
    from chiso.voice import TONES
    k = doc["voice"]["tone_strength"]
    ts = doc["tone_speed"]
    for row, l in zip(doc["lines"], lines):
        sp = (row.get("voice") or {}).get("speed", ts.get(l.tone, doc["voice"]["speed"]))
        eff = min(doc["voice"]["max_speed"], sp * (1.0 + (TONES[l.tone].get("speed", 1.0) - 1.0) * k))
        assert 1.28 <= eff <= 1.4, (l.index, eff)                                    # 約1.3倍。1.4倍を超えない（聞き取り優先）


def test_no_sound_effects_and_bgm_quieter():
    doc = S.load(SCRIPT)
    assert doc.get("sfx", False) is False and doc["bgm_diff_lu"] == 11
    assert not any(row.get("boom") or row.get("riser") for row in doc["lines"])


def test_short_blocks_are_merged_with_neighbours():
    """1.0秒未満のブロックは、同じ絵の隣のブロックと結ぶ（声の時刻から）。"""
    lines = _lines()
    voice, blocks, spans, total = S.plan(lines, [2.2] * len(lines), min_block=0.0)
    n0 = len(blocks)
    fast = [[u.start for u in l.units] for l in lines]
    _v, blocks2, _s, _t = S.plan(_lines(), [1.2] * len(lines))                        # 声が速い（短い行）：短いブロックが出る
    assert len(blocks2) <= n0
    for b in blocks2:
        dur = b.end - b.start
        assert dur >= 0.9 or len(b.units) >= 1                                       # 結べないものを除き、短すぎるブロックを残さない
    assert all(len(b.rows) <= 2 and all(sum(len(S.screen_plain(u.text)) for u in r) <= S.ROW_MAX for r in b.rows) for b in blocks2)
    assert "".join(S.screen_plain(u.text) for b in blocks2 for u in b.units) == "".join(S.screen_plain(u.text) for b in blocks for u in b.units)


def test_short_clauses_are_merged_and_names_not_split():
    blocks = S.blocks_of("1583年4月、北ノ庄城。お市は、城を出るよう勧められたと伝わる。")
    rows = [[S.screen_plain("".join(u.text for u in r)) for r in b.rows] for b in blocks]
    assert rows[0] == ["1583年4月", "北ノ庄城"]                                      # 名前の途中で折り返さない
    assert all(sum(len(s) for s in r) >= 6 for r in rows)                           # 「お市は」だけのブロックを作らない


def test_cinematic_bgm_strings_riser_and_hush(tmp_path):
    """第7版の音：弦の持続音を足した BGM、転換前に上がる音、頂点の一拍の無音（BGM だけ消える）。"""
    import shutil
    import numpy as np
    from chiso import storyaudio as A
    b = A.synth_bgm(6.0, seed=7)
    s = A._string(110.0, 2.0, A.SR, 0.3)
    assert float(np.abs(s).max()) > 0.1 and abs(s[: A.SR // 50]).max() < 0.05          # 弦はゆっくり立ち上がる
    r = A.synth_riser()
    f_early = np.argmax(np.abs(np.fft.rfft(r[: A.SR // 5]))) * (A.SR / (A.SR // 5))
    f_late = np.argmax(np.abs(np.fft.rfft(r[-A.SR // 4: -A.SR // 50]))) * (A.SR / (len(r[-A.SR // 4: -A.SR // 50])))
    assert f_late > f_early * 2                                                         # 音程が上がっていく
    assert abs(r[-5:]).max() < 0.1                                                       # 最後は急に止まる（直後に低い響き）
    ff = shutil.which("ffmpeg")
    if not ff:
        try:
            import imageio_ffmpeg
            ff = imageio_ffmpeg.get_ffmpeg_exe()
        except Exception:
            return
    t = np.arange(int(4.0 * A.SR)) / A.SR
    voice = np.zeros_like(t, dtype="float32")                                           # 声が無い（BGM だけが聞こえる）形で、無音区間を測る
    voice[: int(0.5 * A.SR)] = 0.2 * np.sin(2 * np.pi * 200 * t[: int(0.5 * A.SR)])
    A.write_wav(tmp_path / "v.wav", voice, A.SR)
    A.mix_voice_bgm(tmp_path / "v.wav", tmp_path / "m.wav", 4.0, [], ff, hushes=[(2.0, 2.4)])
    m, _ = A.read_wav(tmp_path / "m.wav")
    assert abs(m[int(2.1 * A.SR): int(2.35 * A.SR)]).max() < 0.002                       # 一拍の無音
    assert abs(m[int(1.2 * A.SR): int(1.8 * A.SR)]).max() > 0.01                          # その前後は BGM が鳴っている


def test_map_card_draws_places_inside_the_box():
    from pathlib import Path
    from PIL import Image
    fonts = {"gothic": "C:/Windows/Fonts/YuGothB.ttc"}
    assets = (Path(__file__).resolve().parent.parent / "../../../output/rekishi-chiso/assets").resolve()
    if not Path(fonts["gothic"]).exists() or not (assets / "maps" / "land_50m.geojson").exists():
        return
    font_of = S.make_font_of(fonts)
    img = Image.new("RGBA", (S.W, S.H), (0, 0, 0, 0))
    spec = {"bounds": [134.7, 137.7, 34.6, 36.7], "places": [["北ノ庄", 136.22, 36.06], ["小谷", 136.28, 35.46]], "hot": "北ノ庄"}
    S.card_map(img, spec, 1.0, 0.0, font_of, assets)
    x0, y0, x1, y1 = img.getbbox()
    assert y0 > S.HEADER_H and y1 < S.H * 0.5 and x0 > 0 and x1 < S.W                  # 見出し帯・語りの文字（下寄り）と重ならない


def test_bgm_gentle_natural_sound():
    """第8版の BGM：ビブラートは弱く、立ち上がりはなだらか、和音は単純（高い弦・うなりの重ねを外した）。"""
    import numpy as np
    from chiso import storyaudio as A
    assert A.VIBRATO_DEPTH <= 0.002 and A.FADE_IN >= 2.5
    b = A.synth_bgm(12.0)
    assert abs(b[: A.SR // 2]).max() < 0.03                                              # 最初の0.5秒は聞こえないほど小さい
    st = A.bgm_stats(b)
    assert st["rolloff95_hz"] < 3000 and st["vibrato_cents"] < 4                          # 低い帯域・約±3セント
    s = A._string(220.0, 3.0, A.SR, 0.3)
    spec = np.abs(np.fft.rfft(s))
    f = np.fft.rfftfreq(len(s), 1 / A.SR)
    assert abs(f[np.argmax(spec)] - 220.0) < 3                                            # 基音がはっきりしている（濁りが無い）


def test_header_styles_fit_width_and_stay_out_of_the_middle():
    """第10版の上の常時表示3案：題は幅の8割まで（超えたら2行）、上の表示は画面の上の方だけ（C のバーは下の帯だけ）。"""
    fonts = {"gothic": "C:/Windows/Fonts/YuGothB.ttc"}
    if not Path(fonts["gothic"]).exists():
        return
    font_of = S.make_font_of(fonts)
    header = {"tag": "お市の方（織田信長の妹）", "title": "《二度目の落城》で、逃げなかった"}
    labels = ["1573 小谷", "1583 北ノ庄", "1615 大坂"]
    for style, bottom in (("A", 470), ("B", 410), ("C", 340)):
        ov = S.Overlay(style, header, font_of, labels)
        f = font_of({"A": 76, "B": 104, "C": 100}[style])
        rows = S._title_rows(header["title"], f)
        assert len(rows) == 2 and all(f.getlength(S.screen_plain(r)) <= S.W * 0.8 for r in rows)
        layers = [ov.header_layer(), ov.now_layer("1573年　小谷城（十年前）"), ov.bar_layer(0)]
        for lay in layers:
            box = lay.getbbox()
            assert box[2] <= S.W
            if style == "C" and lay is layers[2]:
                assert box[1] >= 1560 and box[3] <= 1700                      # C のバーは出典の上
            else:
                assert box[3] <= bottom, (style, box)


def test_story_short_post_description():
    doc = S.load(SCRIPT.parent / "oichi_s11.yaml")
    from chiso.cli import assets_dir, load_config
    config = load_config()
    text = S.post_description(doc, config, "lQrMu8QRQCs")
    assert "本編はこちら → https://youtu.be/lQrMu8QRQCs" in text and "Gemini" in text
    assert "VOICEVOX:剣崎雌雄" in text and "運営：つるはし社" in text and "#お市の方" in text
    assert len(text) <= 5000
    if (assets_dir(config) / "paintings" / "credits.json").exists():               # 絵の出典の控えは手元だけ（CI には無い）
        assert "https://commons.wikimedia.org/wiki/File:Oeyo.jpg" in text
