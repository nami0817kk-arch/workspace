"""試作（Artifact の HTML の中身）を、アプリに同梱する assets/game/index.html へ写す。

使い方:
    python tool/sync_game.py <試作の HTML>

試作は claude.ai の Artifact で、文書の頭（doctype・meta）が無い形。ここで頭を足し、
localStorage に書いた値をアプリにも渡す仕掛け（ShokanStore）を入れる。
"""
import pathlib
import sys

KEYS = ["shokan-yamafuda-v2", "shokan-mute"]  # lib/main.dart の storeKeys と同じ

HEAD = """<!doctype html><html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}[hidden]{display:none!important}body{margin:0;-webkit-touch-callout:none}</style>
<script>
// アプリの保存窓口: 決まった名前の値を localStorage に書いたら、アプリ（ShokanStore）にも渡す
(function(){var K=%s;try{var o=Storage.prototype.setItem,r=Storage.prototype.removeItem;
function send(k,v){try{if(K.indexOf(k)>=0&&window.ShokanStore)window.ShokanStore.postMessage(JSON.stringify({k:k,v:v}))}catch(e){}}
Storage.prototype.setItem=function(k,v){o.call(this,k,v);if(this===window.localStorage)send(k,String(v))};
Storage.prototype.removeItem=function(k){r.call(this,k);if(this===window.localStorage)send(k,null)};}catch(e){}})();
</script>
</head><body>
""" % ("[" + ",".join('"%s"' % k for k in KEYS) + "]")


def main() -> None:
    src = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
    for k in KEYS:
        assert f"'{k}'" in src or k.replace("shokan-", "") in src, f"試作が {k} を使っていない"
    dst = pathlib.Path(__file__).resolve().parent.parent / "assets" / "game" / "index.html"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(HEAD + src + "\n</body></html>\n", encoding="utf-8")
    print("wrote", dst)


if __name__ == "__main__":
    main()
