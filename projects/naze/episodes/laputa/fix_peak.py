"""本編 laputa.mp4 のピークを -1 dBFS 以下に抑える。python episodes/laputa/fix_peak.py(projects/naze で)
`naze long` の仕上げ(loudnorm → alimiter 0.84 → AAC)でつないだ全体のピークが +0.6 dBFS まで出る(各章は -1.0〜-1.3)ので、
もう一度 alimiter(0.8)をかけて AAC にし直し、qc.json を作り直す。共有コード(naze/)は触らない。long のあとに毎回回す。"""
import json
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from naze.config import ffmpeg  # noqa: E402
from naze.qc import sound  # noqa: E402

out = ROOT / "out" / "laputa"
final = out / "laputa.mp4"
src = out / "_src.mp4"
tmp = out / "_peak.mp4"
shutil.copy2(final, src)
for gain in (0.0, -0.4, -0.7, -1.0, -1.4):   # alimiter のあと AAC にし直すと山が出るので、-1 dBFS 以下になるまで音量を少しずつ下げる
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", str(src), "-c:v", "copy", "-af", f"alimiter=limit=0.8:level=false,volume={gain}dB",
                    "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "1", "-movflags", "+faststart", str(tmp)], check=True)
    _, _, stats = sound(tmp)
    print("gain", gain, stats)
    if stats["peak"] is not None and stats["peak"] <= -1.0:
        break
tmp.replace(final)
src.unlink()
fails = []
for i in range(1, 12):
    q = ROOT / "out" / f"laputa_ch{i}" / "qc.json"
    if not q.exists() or not json.loads(q.read_text(encoding="utf-8")).get("passed"):
        fails.append(f"章が点検に通っていない: ch{i}")
_, warns, stats = sound(final)
st = final.stat()
(out / "qc.json").write_text(json.dumps(dict(passed=not fails, at=datetime.now().isoformat(timespec="seconds"), video=final.name, size=st.st_size,
                                             mtime=st.st_mtime, fails=fails, warns=warns, stats=stats), ensure_ascii=False, indent=1), encoding="utf-8")
print("本編の点検", "通過" if not fails else fails, stats)


# ---- ショート 5 本(縦)も、ピークが -1 dBFS を超えていたら同じ仕上げをする。qc.json は音の項目だけ更新(size・mtime も) ----
def fix_short(k):
    vdir = ROOT / "out" / f"laputa_{k}"
    v = vdir / f"laputa_{k}.mp4"
    q = vdir / "qc.json"
    if not v.exists() or not q.exists():
        return
    _, _, st0 = sound(v)
    if st0["peak"] is not None and st0["peak"] <= -1.0:
        print(k, "ピーク", st0["peak"], "そのまま")
        return
    s = vdir / "_src.mp4"
    t = vdir / "_peak.mp4"
    shutil.copy2(v, s)
    for gain in (0.0, -0.4, -0.7, -1.0, -1.4, -1.8):
        subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", str(s), "-c:v", "copy", "-af", f"alimiter=limit=0.8:level=false,volume={gain}dB",
                        "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "1", "-movflags", "+faststart", str(t)], check=True)
        _, _, st = sound(t)
        print(k, "gain", gain, st)
        if st["peak"] is not None and st["peak"] <= -1.0:
            break
    t.replace(v)
    s.unlink()
    _, warns_s, st = sound(v)
    r = json.loads(q.read_text(encoding="utf-8"))
    keep = [w for w in r.get("warns", []) if not w.startswith(("音量", "ピーク", "無音"))]
    r["warns"] = keep + warns_s
    r["stats"].update(LUFS=st["LUFS"], peak=st["peak"])
    sst = v.stat()
    r.update(size=sst.st_size, mtime=sst.st_mtime, at=datetime.now().isoformat(timespec="seconds"))
    q.write_text(json.dumps(r, ensure_ascii=False, indent=1), encoding="utf-8")


for k in ("s1", "s2", "s3", "s4", "s5"):
    fix_short(k)
