import sys
from pathlib import Path

# src レイアウトなので、インストールなしでもテストできるようにパスを通す
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
