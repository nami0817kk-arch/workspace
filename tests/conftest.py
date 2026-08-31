import sys
from pathlib import Path

# リポジトリ直下を import パスに通す（main.py が `from src...` で読む構成のため）
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
