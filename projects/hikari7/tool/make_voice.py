"""台詞の音声を作る（2026-10-03 ユーザー選択「セリフは事前に録って同梱」）。

手元で起動している VOICEVOX ENGINE（http://127.0.0.1:50021）で、game.html の中の
「名前などが差し込まれない台詞」（「」の中が固定の文）を、声ごとに MP3 にして app/assets/audio/voice/ に置く。
名前が入る台詞は事前に録れないので読まない。

    python tool/make_voice.py            # 足りない分だけ作る（作り直さない）
    python tool/make_voice.py --list     # 読む台詞の一覧と数だけ出す
    python tool/make_voice.py --limit 10 # 試しに10本

声はすべて「VOICEVOX:話者名」の表記で商用利用できる（2026-10-03 に各規約を確認。CLAUDE.md の表）。
高さ・速さは合成のときに決め、再生では変えない（雨晴はうの規約が再加工を避けるよう読めるため、全員そろえる）。
"""
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, 'app', 'assets', 'audio', 'voice')
ENGINE = 'http://127.0.0.1:50021'

# 声：(キー, 話者ID, 話者名, 男女, 高さ, 速さ)
VOICES = [
    ('f1', 8, '春日部つむぎ', 'f', 0.0, 1.08),
    ('f2', 14, '冥鳴ひまり', 'f', 0.02, 1.05),
    ('f3', 10, '雨晴はう', 'f', 0.0, 1.06),
    ('f4', 16, '九州そら', 'f', 0.03, 1.08),
    ('m1', 12, '白上虎太郎', 'm', 0.0, 1.06),
    ('m2', 11, '玄野武宏', 'm', 0.0, 1.05),
    ('m3', 21, '剣崎雌雄', 'm', 0.0, 1.04),
    ('m4', 100, '黒沢冴白', 'm', 0.0, 1.05),
]

# 「」で囲まれていても台詞ではないもの（画面の文言・見出し）
NOT_LINE = re.compile(r'^(▶|★|☆|✓)|動画をじっくり見る|いまデビューしたら|このメンバーで|おまかせ|大きく映す|この子は誰')


def key_of(text):
    """台詞からファイル名を作る。ゲーム側（game.html の voiceKey）と同じ FNV-1a（UTF-16 の単位で回す）。"""
    h = 2166136261
    b = text.encode('utf-16-le')
    for i in range(0, len(b), 2):
        h ^= b[i] | (b[i + 1] << 8)
        h = (h * 16777619) & 0xFFFFFFFF
    return '%08x' % h


def lines():
    s = io.open(os.path.join(ROOT, 'prototype', 'game.html'), encoding='utf-8').read()
    js = s[s.index('/*ENGINE-START*/'):]
    bad = set("'\"+\n{}<>\\")
    seen, out = set(), []
    for m in re.finditer('「([^」]{2,90})」', js):
        t = m.group(1)
        if any(ch in bad for ch in t) or t in seen or len(t) < 4 or NOT_LINE.search(t):
            continue
        if not re.search('[。！？…、]|です|ます|た$|い$|る$|ね$|よ$|な$|か$|て$|ん$|う$', t):
            continue
        seen.add(t)
        out.append(t)
    # 「」を付けずに持っている台詞（応募のひと言・面談）。表示のときに「」が付く
    for t in plain_lines():
        if t not in seen and not any(ch in bad for ch in t):
            seen.add(t)
            out.append(t)
    return out


def plain_lines():
    """エンジンを node で読み、LINES・GEN_LINES・HINT_LINES・INTV_LINES の中身を取り出す。"""
    js = ("const fs=require('fs'),vm=require('vm');const s=fs.readFileSync(process.argv[1],'utf8');"
          "vm.runInThisContext('var FACE_IMG={m:[],f:[]};var FACE_GRP={m:[],f:[]};'+s.split('/*ENGINE-START*/')[1].split('/*ENGINE-END*/')[0]);"
          "const L=[].concat(...Object.values(LINES),GEN_LINES,HINT_LINES,...Object.values(INTV_LINES));console.log(JSON.stringify(L));")
    out = subprocess.run(['node', '-e', js, os.path.join(ROOT, 'prototype', 'game.html')], capture_output=True, text=True, encoding='utf-8', check=True).stdout
    return [t for t in json.loads(out) if isinstance(t, str) and len(t) >= 4]


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def synth(text, v):
    _, sid, _, _, pitch, speed = v
    q = urllib.request.urlopen(urllib.request.Request(f'{ENGINE}/audio_query?speaker={sid}&text={urllib.parse.quote(text)}', method='POST')).read()
    aq = json.loads(q)
    aq.update(speedScale=speed, pitchScale=pitch, intonationScale=1.15, volumeScale=1.0, prePhonemeLength=0.05, postPhonemeLength=0.08, outputSamplingRate=24000)
    req = urllib.request.Request(f'{ENGINE}/synthesis?speaker={sid}', data=json.dumps(aq).encode(), headers={'Content-Type': 'application/json'})
    return urllib.request.urlopen(req).read()


def main():
    L = lines()
    if '--list' in sys.argv:
        for t in L:
            print(t)
        print(len(L), '本')
        return
    lim = int(sys.argv[sys.argv.index('--limit') + 1]) if '--limit' in sys.argv else None
    if lim:
        L = L[:lim]
    ff = ffmpeg()
    index = {}
    made = 0
    for v in VOICES:
        d = os.path.join(OUT, v[0])
        os.makedirs(d, exist_ok=True)
        for t in L:
            k = key_of(t)
            index[k] = t
            mp3 = os.path.join(d, k + '.mp3')
            if os.path.exists(mp3):
                continue
            wav = synth(t, v)
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
                f.write(wav)
                tmp = f.name
            try:
                subprocess.run([ff, '-y', '-loglevel', 'error', '-i', tmp, '-ac', '1', '-ar', '24000', '-codec:a', 'libmp3lame', '-b:a', '32k', mp3], check=True)
            finally:
                os.unlink(tmp)
            made += 1
        print(v[0], v[2], '完了')
    meta = {'voices': [{'k': v[0], 'name': v[2], 'g': v[3]} for v in VOICES], 'lines': sorted(index)}
    with io.open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False)
    total = sum(os.path.getsize(os.path.join(dp, fn)) for dp, _, fs in os.walk(OUT) for fn in fs)
    print('新しく作った', made, '本・合計', total // 1024, 'KB')


if __name__ == '__main__':
    main()
