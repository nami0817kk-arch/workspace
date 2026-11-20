import sys
from PIL import Image
src,name=sys.argv[1],sys.argv[2]
im=Image.open(src).convert('RGB')
w,h=im.size
m=int(w*float(sys.argv[3])) if len(sys.argv)>3 else int(w*0.02); mh=int(h*float(sys.argv[4])) if len(sys.argv)>4 else int(h*0.03)
im=im.crop((m,mh,w-m,h-mh)).resize((1376,768),Image.LANCZOS)
d='out/story/kiyomori-fukuhara-if/main/'
im.save(d+name+'.jpg',quality=93)
import shutil
print('saved',name)
