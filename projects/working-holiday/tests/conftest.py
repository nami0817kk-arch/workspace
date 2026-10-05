import sys
from pathlib import Path

# src/ をインポートパスに通す（kabu-agari-ranking と同じ形）
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
