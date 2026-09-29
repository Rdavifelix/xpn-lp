# Foto original (cenário do evento) à direita + navy entrando da esquerda por gradiente, como na hero do Garcez.
from PIL import Image, ImageFilter, ImageDraw, ImageEnhance, ImageChops
NAVY=(2,9,43)
SRC='/home/user/xpn-lp/formatos/assets/joao.jpg'   # 1170x1170 — trocar pela foto completa quando chegar

def tone(im):
    # leve tratamento: menos saturação, um pouco mais escura, tinta navy suave por cima (mantém o cenário visível)
    im=ImageEnhance.Color(im).enhance(0.85); im=ImageEnhance.Brightness(im).enhance(0.82); im=ImageEnhance.Contrast(im).enhance(1.08)
    tint=Image.new('RGB',im.size,NAVY); return Image.blend(im,tint,0.28)

def hfade(im, x0, x1, strength=1.0):
    """navy opaco até x0, transparente a partir de x1 (fade horizontal)"""
    w,h=im.size; g=Image.new('RGBA',(w,h),NAVY+(0,)); px=g.load()
    for x in range(w):
        t=0 if x>=x1 else 1 if x<=x0 else 1-(x-x0)/(x1-x0)
        a=int(255*strength*(t**1.35))
        for y in range(h): px[x,y]=NAVY+(a,)
    return Image.alpha_composite(im.convert('RGBA'),g)

def vfade(im, y0, y1, strength=1.0):
    w,h=im.size; g=Image.new('RGBA',(w,h),NAVY+(0,)); px=g.load()
    for y in range(h):
        t=0 if y<=y0 else 1 if y>=y1 else (y-y0)/(y1-y0)
        a=int(255*strength*(t**1.4))
        for x in range(w): px[x,y]=NAVY+(a,)
    return Image.alpha_composite(im.convert('RGBA'),g)

src=Image.open(SRC).convert('RGB')
A='/home/user/xpn-lp/advogados/assets/'

# HERO DESKTOP 2560x970: foto ocupa a metade direita (escala pela altura), navy à esquerda com fade
W,H=2560,970
canvas=Image.new('RGB',(W,H),NAVY)
s=H/src.height; ph=Image.open(SRC).convert('RGB'); ph=ph.resize((int(src.width*s),H),Image.LANCZOS); ph=tone(ph)
ph=ph.filter(ImageFilter.UnsharpMask(radius=1.2,percent=80,threshold=2))
x=W-ph.width-int(W*0.02)            # encostada à direita com pequena margem
canvas.paste(ph,(x,0))
out=hfade(canvas, x+int(ph.width*0.12), x+int(ph.width*0.55))   # navy opaco sobre o começo da foto, sem emenda visível
out=vfade(out, int(H*0.80), H, 0.9)                        # base dissolve na seção seguinte
out.convert('RGB').save(A+'hero.jpg',quality=86,optimize=True,progressive=True)

# HERO MOBILE 800x1660: foto no topo (largura total), dissolvendo para navy embaixo
W,H=800,1660
canvas=Image.new('RGB',(W,H),NAVY)
ph=src.resize((W,W),Image.LANCZOS); ph=tone(ph); canvas.paste(ph,(0,0))
out=vfade(canvas, int(W*0.55), int(W*1.02), 1.0)
out.convert('RGB').save(A+'mobile-hero.jpg',quality=84,optimize=True,progressive=True)

# QUEM-SOU 1920x800: mesmo esquema, foto à direita
W,H=1920,800
canvas=Image.new('RGB',(W,H),NAVY)
s=H/src.height; ph=src.resize((int(src.width*s),H),Image.LANCZOS); ph=tone(ph)
x=W-ph.width-int(W*0.02); canvas.paste(ph,(x,0))
out=hfade(canvas, x+int(ph.width*0.12), x+int(ph.width*0.58)); out=vfade(out,int(H*0.82),H,0.9)
out.convert('RGB').save(A+'quem-sou.jpg',quality=86,optimize=True,progressive=True)

# QUEM-SOU MOBILE 800x720
W,H=800,720
ph=src.resize((W,W),Image.LANCZOS); ph=tone(ph); ph=ph.crop((0,0,W,H))
out=vfade(ph, int(H*0.6), H, 1.0)
out.convert('RGB').save(A+'mobile-quem-sou.jpg',quality=84,optimize=True,progressive=True)
print('ok')
