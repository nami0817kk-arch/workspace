"""meanings.js を作る。words.js の各ことばに、漢字の書き方と英語の意味を付ける（日本語を学ぶ人向け）。

    python -m venv .venv && .venv/Scripts/pip install wordfreq 'fugashi[unidic-lite]'
    curl -o tool/work/JMdict_e.gz http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz
    .venv/Scripts/python tool/mkmeanings.py

ひらがなだけでは同じ読みの言葉（はし＝橋・箸・端）を見分けられない。そこで words.js を作ったときと同じ頻度表
（wordfreq）を UniDic にかけ、その読みでいちばんよく使われる書き方（漢字）を選んでから、
JMdict（EDRDG、CC BY-SA 4.0）でその書き方と読みが両方合う見出しを引く。書き方が合う見出しが無ければ、
読みが合う見出しのうち よく使う印（news1・ichi1 など）の多いものを選ぶ。
意味は最初の語義の最初の訳から、画面に収まる長さ（MAXLEN 字）まで。
"""
import gzip, json, re, subprocess, sys
import xml.etree.ElementTree as ET
from pathlib import Path
import fugashi
from wordfreq import top_n_list

ROOT = Path(__file__).resolve().parent.parent
JM = ROOT / 'tool/work/JMdict_e.gz'
MAXLEN = 28
# 手で選んだことば（words_manual.js）は頻度表から来ていないので、頻度で選ぶと別の言葉になることがある
# （とり→取り、しか→歯科、りす→fracture）。ねらった書き方をここで決める
PREFER = {
    'とり': '鳥', 'なす': '茄子', 'しか': '鹿', 'たこ': '蛸', 'いか': '烏賊', 'かき': '柿', 'のり': '海苔',
    'いと': '糸', 'かい': '貝', 'かね': '金', 'きし': '岸', 'きり': '霧', 'さら': '皿', 'しろ': '白',
    'すみ': '隅', 'たい': '鯛', 'たま': '玉', 'とし': '年', 'もち': '餅', 'もの': '物', 'りす': '栗鼠',
    'たか': '鷹', 'かえる': '蛙', 'おにく': 'お肉', 'うちわ': '団扇', 'かいろ': '懐炉', 'ほうき': '箒',
    'やかん': '薬缶', 'やすい': '安い', 'うまい': '美味い', 'ひよこ': '雛', 'こけし': 'こけし', 'まり': '鞠',
    'たいよう': '太陽', 'おつきみ': '月見', 'すいかわり': 'スイカ割り', 'まと': '的',
}
# 辞書の見出しに無い言い方（お＋見出し）。[書き方, 英語]
EXTRA = {'おつきみ': ['お月見', 'moon viewing']}


def hira(k):
    return ''.join(chr(ord(c) - 0x60) if 'ァ' <= c <= 'ヶ' else c for c in k)


def surfaces(words):
    """読み → その読みでいちばんよく使う書き方（頻度表の順で最初に出たもの）"""
    want, out = set(words), {}
    t = fugashi.Tagger()
    for w in top_n_list('ja', 80000):
        ms = t(w)
        if len(ms) != 1:
            continue
        f = ms[0].feature
        if not f.kana or f.kana == '*':
            continue
        r = hira(f.kana)
        if r in want and r not in out:
            # 動詞・形容詞は言い切りの形だけ（たべ→食べ ではなく たべる→食べる）
            out[r] = w
    return out


PRI = re.compile(r'news1|ichi1|spec1|spec2|gai1|news2|ichi2|nf\d\d')


def load_jmdict():
    """読み（ひらがな）→ 見出しの一覧"""
    by_reading = {}
    with gzip.open(JM, 'rb') as fh:
        # DTD の実体（&n; など）は ElementTree が知らないので、名前のまま残す
        text = fh.read().decode('utf-8')
    text = re.sub(r'<!DOCTYPE.*?\]>', '', text, flags=re.S)
    text = re.sub(r'&([\w-]+);', r'\1', text)
    root = ET.fromstring(text)
    for e in root.iter('entry'):
        kebs = [(k.findtext('keb'), [p.text for p in k.findall('ke_pri')]) for k in e.findall('k_ele')]
        rebs = []
        for r in e.findall('r_ele'):
            reb = r.findtext('reb')
            rebs.append((hira(reb), [p.text for p in r.findall('re_pri')],
                         [x.text for x in r.findall('re_restr')], r.find('re_nokanji') is not None, reb))
        senses = []
        for s in e.findall('sense'):
            senses.append({'g': [g.text for g in s.findall('gloss') if g.text],
                           'misc': [m.text for m in s.findall('misc')],
                           'stagk': [x.text for x in s.findall('stagk')],
                           'stagr': [hira(x.text) for x in s.findall('stagr')]})
        ent = {'k': kebs, 'r': rebs, 's': senses}
        for reb, *_ in rebs:
            by_reading.setdefault(reb, []).append(ent)
    return by_reading


def pick(word, surf, cands):
    """いちばん合う見出しと、その中の書き方（漢字。漢字が無ければカタカナ）"""
    best, bscore, bkeb = None, -1, ''
    for ent in cands:
        # 同じ見出しに イカ（漢字なし）と いか（漢字あり）のように読みが2つあることがあるので、全部見る
        for rinfo in [r for r in ent['r'] if r[0] == word]:
            _, rpri, restr, nokanji, orig = rinfo
            kebs = [k for k in ent['k'] if not nokanji and (not restr or k[0] in restr)]
            score, keb = 0, ''
            if surf and any(k[0] == surf for k in kebs):
                score += 100
                keb = surf
            elif surf and surf == orig and orig != word:   # カタカナで書く言葉（メロン）
                score += 100
            elif surf == word:   # 頻度表でもひらがなで書かれる言葉（かな書きの印 uk が付いた見出しを好む）
                if any('uk' in s['misc'] for s in ent['s']):
                    score += 40
            score += len([p for p in rpri if PRI.match(p)]) * 5
            if not keb and kebs:
                keb = sorted(kebs, key=lambda k: -len([p for p in k[1] if PRI.match(p)]))[0][0]
            if not keb and orig != word:   # 漢字が無くカタカナで書く言葉は、カタカナを見せる
                keb = orig
            if score > bscore:
                best, bscore, bkeb = ent, score, keb
    return best, bkeb


def gloss(ent, word, keb):
    for s in ent['s']:
        if s['stagk'] and keb not in s['stagk']:
            continue
        if s['stagr'] and word not in s['stagr']:
            continue
        if not s['g']:
            continue
        out = ''
        for g in s['g']:
            while re.search(r'\([^()]*\)', g):   # 「(something)」のような補足は外す（入れ子も）
                g = re.sub(r'\s*\([^()]*\)\s*', ' ', g)
            g = re.sub(r'\s+', ' ', g).strip(' ;')
            if not g:
                continue
            nxt = g if not out else out + '; ' + g
            if len(nxt) > MAXLEN and out:
                break
            out = nxt
            if len(out) >= MAXLEN // 2:
                break
        if len(out) > MAXLEN:
            out = out[:MAXLEN - 1].rstrip() + '…'
        return out
    return ''


def main():
    words = json.loads(subprocess.check_output(['node', '-e',
        "const W=require('%s');console.log(JSON.stringify(W.short.concat(W.middle,W.long)))" % (ROOT / 'prototype/words.js').as_posix()]))
    surf = surfaces(words)
    jm = load_jmdict()
    out, missing = {}, []
    for w in words:
        if w in EXTRA:
            out[w] = EXTRA[w]
            continue
        cands = jm.get(w)
        if not cands:
            missing.append(w)
            continue
        ent, keb = pick(w, PREFER.get(w) or surf.get(w), cands)
        g = gloss(ent, w, keb)
        if not g:
            missing.append(w)
            continue
        out[w] = [keb if keb != w else '', g]
    lines = ',\n'.join("  '%s': [%s, %s]" % (w, json.dumps(v[0], ensure_ascii=False), json.dumps(v[1], ensure_ascii=False))
                       for w, v in out.items())
    head = ('// ことばの漢字の書き方と英語の意味（日本語を学ぶ人向けの表示）。tool/mkmeanings.py が作る（手で直さない）。\n'
            '// 出どころ: JMdict（Electronic Dictionary Research and Development Group、CC BY-SA 4.0）。\n'
            '// 同じ読みの言葉は、頻度表（wordfreq）でその読みにいちばん多い書き方で選んだ。[漢字（無ければ空）, 英語]\n')
    js = head + 'var TenbinMeanings = {\n' + lines + '\n};\nif (typeof module !== \'undefined\') module.exports = TenbinMeanings;\n'
    (ROOT / 'prototype/meanings.js').write_text(js, encoding='utf-8')
    print(len(words), 'words,', len(out), 'with meaning,', len(missing), 'missing')
    print('missing:', ' '.join(missing[:80]))


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
