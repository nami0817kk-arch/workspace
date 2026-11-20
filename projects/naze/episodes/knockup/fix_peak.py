"""本編 knockup.mp4 のピークを -1 dBFS 以下に抑える。python episodes/knockup/fix_peak.py(projects/naze で)
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

out = ROOT / "out" / "knockup"
final = out / "knockup.mp4"
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
for i in range(1, 6):
    q = ROOT / "out" / f"knockup_ch{i}" / "qc.json"
    if not q.exists() or not json.loads(q.read_text(encoding="utf-8")).get("passed"):
        fails.append(f"章が点検に通っていない: ch{i}")
_, warns, stats = sound(final)
st = final.stat()
(out / "qc.json").write_text(json.dumps(dict(passed=not fails, at=datetime.now().isoformat(timespec="seconds"), video=final.name, size=st.st_size,
                                             mtime=st.st_mtime, fails=fails, warns=warns, stats=stats), ensure_ascii=False, indent=1), encoding="utf-8")
print("本編の点検", "通過" if not fails else fails, stats)
