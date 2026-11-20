"""ショートのピークを -1 dBFS 以下に抑える。python episodes/samurai/fix_short_peak.py s5(projects/naze で)
書き出しのあとでピークが -1 dBFS を超えたショートに、本編の fix_peak.py と同じ仕上げ(alimiter 0.8 → AAC)をかけ、qc.json の音の数字を作り直す。"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from naze.config import ffmpeg  # noqa: E402
from naze.qc import sound  # noqa: E402

for e in sys.argv[1:]:
    out = ROOT / "out" / f"samurai_{e}"
    final = out / f"samurai_{e}.mp4"
    src, tmp = out / "_src.mp4", out / "_peak.mp4"
    shutil.copy2(final, src)
    for gain in (0.0, -0.4, -0.7, -1.0, -1.4):
        subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", str(src), "-c:v", "copy", "-af", f"alimiter=limit=0.8:level=false,volume={gain}dB",
                        "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "1", "-movflags", "+faststart", str(tmp)], check=True)
        _, _, stats = sound(tmp)
        print(e, "gain", gain, stats)
        if stats["peak"] is not None and stats["peak"] <= -1.0:
            break
    tmp.replace(final)
    src.unlink()
    q = json.loads((out / "qc.json").read_text(encoding="utf-8"))
    _, warns, stats = sound(final)
    st = final.stat()
    q.update(size=st.st_size, mtime=st.st_mtime)
    q.setdefault("stats", {}).update(stats)
    (out / "qc.json").write_text(json.dumps(q, ensure_ascii=False, indent=1), encoding="utf-8")
    print(e, "完了", stats)
