

def test_悲報と速報で曲が変わる():
    """【悲報】に緊迫した曲を当てていた。**温度が違う。**

    登録外・退団・敗戦の回に急かす曲が流れると、内容と合わない（2026-09-05）。
    """
    from src.audio_gen import track_for

    assert track_for("【悲報】遠藤航がCL登録外") != track_for("【速報】移籍が決定")


def test_朗報は明るい曲になる():
    from src.audio_gen import track_for

    assert "victory" in track_for("【朗報】上田綺世がデビュー弾")


def test_札が無ければ既定の曲():
    from src.audio_gen import track_for

    assert "bgm_loop" in track_for("遠藤航がCL登録外 なぜ選ばれなかったのか")


def test_frontmatterの指定が優先される():
    from src.audio_gen import track_for

    assert track_for("【悲報】…", "assets/audio/bgm_calm.wav") == "assets/audio/bgm_calm.wav"
