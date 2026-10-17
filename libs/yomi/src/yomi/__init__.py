"""yomi：合成音声の読み違いを、音を出す前に見つける（チャンネルに依存しない部分）。

入力は「文（読み替え辞書で置き換えたもの）と、エンジンが返したカナ」の組と、読み替え辞書（dict）。
① diff_line：fugashi（UniDic）との食い違い／② ambiguous_hits・rule_of：読みが割れる語と文脈で決まる型／
③ collisions：読み替え辞書の巻き込み／⑤ Case・check：見つけた誤読のテスト。まとめて回すのは review。
"""
from .cases import Case, check, check_kana
from .collide import Collision, collision_lines, collisions
from .diff import Diff, diff_line, same_reading, segments, token_kana
from .kana import VoicevoxKana, engine_up, kata, norm, voicevox_kana
from .lexicon import Lexicon, default
from .morph import Tok, available, tokens
from .replace import apply_readings, apply_tracked, load_readings, replacements
from .review import Report, review
from .rules import Hit, ambiguous_hits, rule_of

__all__ = [
    "Case", "check", "check_kana", "Collision", "collision_lines", "collisions", "Diff", "diff_line", "same_reading",
    "segments", "token_kana", "VoicevoxKana", "engine_up", "kata", "norm", "voicevox_kana", "Lexicon", "default",
    "Tok", "available", "tokens", "apply_readings", "apply_tracked", "load_readings", "replacements", "Report",
    "review", "Hit", "ambiguous_hits", "rule_of",
]
