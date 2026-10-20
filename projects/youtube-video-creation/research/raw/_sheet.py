import sys,glob
from PIL import Image,ImageDraw
d=sys.argv[1]; fs=sorted(f for f in glob.glob(d+'/[0-9][0-9].jpg'))
W=420;ims=[]
for f in fs:
    im=Image.open(f).convert('RGB'); print(f,im.size)
    r=W/im.width; im=im.resize((W,int(im.height*r)))
    ImageDraw.Draw(im).text((5,5),f[-6:],fill=(255,255,0)); ims.append(im)
cols=3;rows=(len(ims)+cols-1)//cols;H=max(i.height for i in ims)
s=Image.new('RGB',(W*cols,H*rows))
for i,im in enumerate(ims): s.paste(im,((i%cols)*W,(i//cols)*H))
s.save(sys.argv[2])
