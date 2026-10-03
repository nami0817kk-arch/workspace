"""立ち絵に黄色い工事用ヘルメットをかぶせる（「地層を掘る」二人の目印）。

絵は自作の図形。立ち絵の規約（つむぎ：加筆・加工可、剣崎雌雄：二次創作に制限なし）の範囲で重ねる。
"""
from PIL import Image, ImageDraw, ImageFilter
import sys
def helmet(w=700, color=(242,190,40)):
    H=int(w*0.62); im=Image.new("RGBA",(w,H),(0,0,0,0)); d=ImageDraw.Draw(im)
    ol=(60,40,20,255); lw=max(4,w//90)
    dark=tuple(int(c*0.78) for c in color)+(255,)
    # つば
    d.ellipse([0,int(H*0.70),w,int(H*0.98)],fill=dark,outline=ol,width=lw)
    # ドーム
    d.pieslice([int(w*0.10),int(H*0.04),int(w*0.90),int(H*1.36)],180,360,fill=color+(255,),outline=ol,width=lw)
    d.line([int(w*0.10)+lw,int(H*0.70)+lw//2,int(w*0.90)-lw,int(H*0.70)+lw//2],fill=dark,width=lw*2)
    # 中央の稜線
    d.rounded_rectangle([int(w*0.45),int(H*0.05),int(w*0.55),int(H*0.70)],radius=w//40,fill=dark,outline=ol,width=lw//2)
    # ハイライト
    hl=Image.new("RGBA",im.size,(0,0,0,0)); hd=ImageDraw.Draw(hl)
    hd.ellipse([int(w*0.22),int(H*0.16),int(w*0.38),int(H*0.40)],fill=(255,255,235,150))
    hl=hl.filter(ImageFilter.GaussianBlur(w/60)); im=Image.alpha_composite(im,hl)
    return im
def put(base_fn, out_fn, cx, cy, w, angle):
    """base_fn の立ち絵（余白を切った状態）の (cx, cy) を中心に、幅 w・angle 度傾けて重ねる。"""
    b=Image.open(base_fn).convert("RGBA")
    b=b.crop(b.getbbox())
    h=helmet(w).rotate(angle,expand=True,resample=Image.BICUBIC)
    b.alpha_composite(h,(int(cx-h.width/2),int(cy-h.height/2)))
    b.save(out_fn)


# 公式の立ち絵（余白を切った状態）でのヘルメットの位置。絵を差し替えたら測り直す。
PLACEMENTS = {
    "tsumugi": (1135, 285, 640, -10),   # 春日部つむぎ公式立ち絵 v2.0
    "kenzaki": (322, 95, 230, -14),     # 剣崎雌雄 公式イラスト（VOICEVOX 掲載の全身図）
}
