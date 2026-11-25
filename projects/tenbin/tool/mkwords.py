"""words.js を作る。手で選んだことば（prototype/words_manual.js）＋ 頻度表からよく使う言葉。

    python -m venv .venv && .venv/bin/pip install wordfreq 'fugashi[unidic-lite]'
    .venv/bin/python tool/mkwords.py

頻度表 wordfreq の日本語上位6万語を UniDic（fugashi + unidic-lite）で品詞と読みにかけ、
ゲームにある74字（清音・濁点・半濁点・小さい っゃゅょ）で読める名詞（普通名詞）・形容詞と動詞（言い切りの形）・副詞を、よく使う順に集める。
カタカナ語（ひらがなにすると読みにくい）、感動詞、文法のための語、子どもに向かない語、
漢字1字の音読みだけの2字（かん・せん…）は除く。上位 TOP 語を手で選んだことばに足す。
"""
import json, re, subprocess
from pathlib import Path
import fugashi
from wordfreq import top_n_list

ROOT = Path(__file__).resolve().parent.parent
TOP = 3500   # 2026-11-25 濁点・小さい字を足したとき。濁点・小さい字を含む候補はこの順位まで（ことばは約4,000語に）
OK = set('あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん'
         'がぎぐげござじずぜぞだづでどばびぶべぼぱぴぷぺぽ'     # 2026-11-25「案2」で濁点・半濁点（ぢ のことばは候補に無かった）
         'っゃゅょ')                                          # 「小さいもいれる」
# ぁぃぅぇぉゎ は入れない: ひらがなのことばにはほとんど出てこない（カタカナ語の字）。上位の候補で各1語だった
SMALL = set('ぁぃぅぇぉっゃゅょゎ')
SEION = set('あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん')
OLD_TOP = 2000  # 清音だけのことばは、これまでどおり上位2000語を残す（濁点のことばに押し出されて もうふ・こねこ が消えた）
# ゃゅょ の前に来てよい字（い段）。それ以外のつながりは読みの誤りなので入れない
I_ROW = set('きしちにひみりぎじぢびぴ')
KATA = re.compile('[ァ-ヶー]')
# 文法のための語・間投げの語・言葉として不自然な切れ端
STOP = set('''こと そう よう ため より ああ ねえ なあ まあ ええ おい うん はい つつ もん とこ わけ もの とき ところ はず ほう
あの この その どの こう いや おお ねん えん せい すう けい かい けん りつ むろ しき めん さく へん わり いち まん
つけ おき かえ いり おち うまれ つかい つくり おしえ ためし かけ いく くる みる ゆう なし あり いか まき はつ とく
すけ まりい みにきい ひとひと さは てか たた ちい との かか つと ちと ふつ はや つて よれ もれ けた そく しい れつ へい
へき えい えし とほ わる はん さし ろん おん なん かく かつ たい すい こく きん にん ちく しん たん ふん ひん りん こん
そん あつ しか ろう ちり やし ます
てれ おこ もろ ふよ ほさ しさ こみ そし すか はめ けり ひけ いお まし きも たれ しし きよ よけ おつ せめ よせ ぬき
のせ やせ にせ まけ つれ
ほめ へらし みたし かまい ひきおこし
ばこ はずし とりもどし とりだし'''.split())
# 子どもも遊ぶので入れない言葉（性・犯罪・薬物・死に関わる語など）
BAD = set('''えろ くそ しぬ しね ころす うんこ ちんこ まんこ ちん ちんちん きちく やつ あいつ こいつ そいつ やろう くず めす おす
ちつ ひわい せいよく せいえき いんらん うわき ふりん まやく あんさつ ころし さつい さつりく ちかん ゆうかい へんたい
しけい いけにえ しにん にんしん しり らち
したい まいそう けつ こかん ほうか はんにん はんこう かんきん ふはい とらわれ
ばか さぎ しご しぼう じさつ どれい はだか ししゃ ぜんら そうぎ にょう ほりょ ちんぽ はんざい さつじん さつがい ぼうりょく
きょにゅう ばくだん しゅうげき しょけい やくぶつ ばくげき ぼうこう ひっさつ ごうもん げんばく じごく ぶき ちゅうどく
げい おっぱい どうてい しょじょ ぎゃくたい ひとじち したぎ ばいしゅん'''.split())  # 2行目: 2026-11-25 英語の意味を見て外した（死体・犯罪・股間など）。3行目から: 同日、濁点・小さい字のことばを足したときに意味を見て外した


def hira(k):
    return ''.join(chr(ord(c) - 0x60) if 'ァ' <= c <= 'ヶ' else c for c in k)


def collect():
    t = fugashi.Tagger()
    seen, out = set(), []
    for w in top_n_list('ja', 60000):
        ms = t(w)
        if len(ms) != 1:
            continue
        m, f = ms[0], ms[0].feature
        if KATA.search(w) or f.pos1 not in ('名詞', '形容詞', '動詞', '副詞'):
            continue
        if f.pos1 == '名詞' and f.pos2 != '普通名詞':
            continue
        if f.pos1 in ('形容詞', '動詞') and m.surface != f.lemma:
            continue
        if not f.kana or f.kana == '*':
            continue
        r = hira(f.kana)
        if not (2 <= len(r) <= 6) or any(c not in OK for c in r) or r[0] in 'んを' or 'を' in r:
            continue
        if r[0] in SMALL or r[-1] == 'っ' or any(c in 'ゃゅょ' and r[i - 1] not in I_ROW for i, c in enumerate(r) if i):
            continue
        if r in seen or r in STOP or r in BAD:
            continue
        seen.add(r)
        out.append(r)
    return out


def main():
    manual = json.loads(subprocess.check_output(['node', '-e',
        "const W=require('%s');console.log(JSON.stringify(W.short.concat(W.middle,W.long)))" % (ROOT / 'prototype/words_manual.js').as_posix()]))
    words, seen = [], set()
    cand = collect()
    seion = [r for r in cand if all(c in SEION for c in r)][:OLD_TOP]
    for r in manual + seion + cand[:TOP]:
        if r in seen or r in BAD:
            continue
        if len(r) == 2 and r[1] == 'ん' and r not in manual:
            continue
        seen.add(r)
        words.append(r)
    tiers = {'short': [w for w in words if len(w) == 2], 'middle': [w for w in words if len(w) == 3],
             'long': [w for w in words if 4 <= len(w) <= 6]}

    def fmt(a):
        return ',\n'.join('    ' + ', '.join("'%s'" % w for w in a[i:i + 16]) for i in range(0, len(a), 16))
    head = ('// 字をくっつけて作る「ことば」。tool/mkwords.py が作る（手で直すなら words_manual.js の方を直して作り直す）。\n'
            '// ゲームにあるひらがな74字（清音・濁点・半濁点・っゃゅょ）で読める、よく使う言葉。手で選んだ言葉（words_manual.js）＋ 頻度表（wordfreq）の上位から\n'
            '// 名詞・形容詞・動詞（言い切り）・副詞を集め、カタカナ語・文法のための語・子どもに向かない語・漢字1字の音読み（かん・せん…）を除いた。\n'
            '// 字の袋もここから作る（ことばに使う字が多めに来る）。node test/words.test.js で字・字数・重複を確かめる\n'
            '// 出どころ: wordfreq（Robyn Speer）の頻度データ（CC BY-SA 4.0）で選び、UniDic（BSD）で品詞と読みを見た。この一覧も CC BY-SA 4.0 で扱う（アプリの「クレジット」に表示）\n')
    js = head + 'var TenbinWords = {\n' + ',\n'.join('  %s: [\n%s]' % (k, fmt(v)) for k, v in tiers.items()) + \
        '\n};\nif (typeof module !== \'undefined\') module.exports = TenbinWords;\n'
    (ROOT / 'prototype/words.js').write_text(js, encoding='utf-8')
    print(len(words), {k: len(v) for k, v in tiers.items()})


if __name__ == '__main__':
    main()
