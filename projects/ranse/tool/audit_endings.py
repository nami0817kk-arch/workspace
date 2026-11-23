"""手書きの最期（lib/engine/endings_*.dart）の条件に出てくる旗・場面・人の役割・死因の文・歩んだ道の文・死に方が、
ゲーム側（それ以外の lib/engine/*.dart）に本当にあるかを突き合わせる。ないものは、何度遊んでも出会えない最期になる。

使い方: python tool/audit_endings.py
（主君の名前を照らす補助の関数を、人の役割と取り違えて出すことがある。出たら中身を見て判断する）
"""
import glob
import io
import os
import re

base = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib', 'engine')
srcs = {
    os.path.basename(fn): io.open(fn, encoding='utf-8').read()
    for fn in glob.glob(os.path.join(base, '*.dart'))
}
engine = ''.join(v for k, v in srcs.items() if not k.startswith('endings_'))
flags_set = set(re.findall(r"setFlag\('([^']+)'\)", engine)) | set(
    re.findall(r"'(history_[a-z]+)'", engine)
)
scene_ids = set(re.findall(r"SceneDef\(\s*'([^']+)'", engine))
roles = set(re.findall(r"meet\(\s*'([^']+)'", engine))


def lits(pat):
    return [m.group(1) for m in re.finditer(pat, engine, re.S)]


def pieces(ts):
    out = []
    for t in ts:
        out += [p for p in re.split(r"\$\{[^}]*\}|\$[a-zA-Z_]+", t) if p]
    return out


die_p = pieces(lits(r"die\(\s*'((?:[^'\\]|\\.)*)'"))
mark_p = pieces(lits(r"mark\(\s*'((?:[^'\\]|\\.)*)'"))
kinds_ok = {'tenju', 'byo', 'senshi', 'seppuku', 'ansatsu', 'sai', 'ue', 'yukue', 'era', 'victory'}

checks = {
    'flag': lambda v: (v[6:] in scene_ids) if v.startswith('scene:') else v in flags_set,
    'role': lambda v: v in roles,
    'dead': lambda v: any(v in p for p in die_p),
    'path': lambda v: any(v in p for p in mark_p),
}

report = []
for fn, s in sorted(srcs.items()):
    if not fn.startswith('endings_') or fn == 'endings_catalog.dart':
        continue
    # 補助の関数が何を見ているか（_xxx(Game g, String s) => ...）
    helper_kind = {}
    for m in re.finditer(r"bool (_[a-zA-Z]+)\(Game g, String [a-z]+\)\s*(?:=>|\{)([^;]*);", s):
        body = m.group(2)
        if 'hasFlag' in body:
            helper_kind[m.group(1)] = 'flag'
        elif 'containsKey' in body or 'people[' in body:
            helper_kind[m.group(1)] = 'role'
        elif 'dead' in body:
            helper_kind[m.group(1)] = 'dead'
        elif 'path' in body:
            helper_kind[m.group(1)] = 'path'
    for i, line in enumerate(s.split('\n'), 1):
        found = []
        found += [('flag', f) for f in re.findall(r"hasFlag\('([^']+)'\)", line)]
        found += [('role', r[0] or r[1]) for r in re.findall(r"people\['([^']+)'\]|containsKey\('([^']+)'\)", line)]
        for h, k in helper_kind.items():
            found += [(k, a) for a in re.findall(re.escape(h) + r"\(g, '([^']+)'\)", line)]
        found += [('dead', d) for d in re.findall(r"dead[^;]*?contains\('([^']+)'\)", line)]
        found += [('path', p) for p in re.findall(r"path[^;]*?contains\('([^']+)'\)", line)]
        for k in re.findall(r"kinds:\s*\{([^}]*)\}", line):
            for x in re.findall(r"'([a-z]+)'", k):
                if x not in kinds_ok:
                    report.append(f'{fn} {i}: 死に方なし {x}')
        for k, v in found:
            if not checks[k](v):
                report.append(f'{fn} {i}: {k}なし {v}')

print('\n'.join(report))
print(f'{len(report)} 件')
