import sys

from .cli import main

if __name__ == "__main__":          # 並列合成(multiprocessing の spawn)で、子プロセスが CLI をもう一度動かさないように
    sys.exit(main())
