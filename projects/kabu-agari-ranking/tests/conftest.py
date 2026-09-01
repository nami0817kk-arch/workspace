import sys
from pathlib import Path

# src/ をインポートパスに通す（本体が sys.path をいじる前提で書かれているため）
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
