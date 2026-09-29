# Cenário no estilo Garcez: navy + emblema dourado + ícones em linha teal + cidade + piso iluminado
import random, math
from PIL import Image, ImageFilter, ImageDraw, ImageEnhance, ImageChops

NAVY_T=(3,12,44); NAVY_B=(2,7,32)
GOLD=(212,170,84); GOLD_L=(246,214,140); GOLD_D=(140,100,38)
TEAL=(70,190,230)

def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))
def new(w,h): return Image.new('RGBA',(w,h),(0,0,0,0))

def base(w,h):
    im=Image.new('RGB',(w,h)); px=im.load()
    for y in range(h):
        c=lerp(NAVY_T,NAVY_B,y/(h-1))
        for x in range(w): px[x,y]=c
    return im.convert('RGBA')

def glow(im,cx,cy,rx,ry,color,alpha,blur):
    g=new(*im.size); d=ImageDraw.Draw(g); d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),fill=color+(alpha,))
    return Image.alpha_composite(im,g.filter(ImageFilter.GaussianBlur(blur)))

def skyline(im, horizon, height, seed=1, alpha=170):
    w,h=im.size; rnd=random.Random(seed); g=new(w,h); d=ImageDraw.Draw(g)
    x=-40
    while x<w+40:
        bw=rnd.randint(int(w*0.02),int(w*0.07)); bh=rnd.randint(int(height*0.3),height)
        col=(8,22,66,alpha)
        d.rectangle((x,horizon-bh,x+bw,horizon+height),fill=col)
        # janelas
        for yy in range(horizon-bh+10, horizon, 14):
            for xx in range(x+6, x+bw-6, 12):
                if rnd.random()<0.22: d.rectangle((xx,yy,xx+4,yy+6),fill=(120,170,220,rnd.randint(40,110)))
        x+=bw+rnd.randint(4,18)
    g=g.filter(ImageFilter.GaussianBlur(2.2))
    # névoa na base
    fog=new(w,h); fd=ImageDraw.Draw(fog); fd.rectangle((0,horizon-int(height*0.2),w,horizon+height),fill=(2,7,32,140))
    fog=fog.filter(ImageFilter.GaussianBlur(height*0.25))
    return Image.alpha_composite(Image.alpha_composite(im,g),fog)

def floor_lines(im, horizon, seed=2):
    w,h=im.size; g=new(w,h); d=ImageDraw.Draw(g); vx=w*0.62
    for i in range(-14,15):
        x0=vx+i*w*0.06; x1=vx+i*w*0.30
        d.line([(x0,horizon),(x1,h)],fill=TEAL+(26,),width=2)
    for k in range(1,9):
        t=k/9; y=horizon+(h-horizon)*(t**2.1)
        d.line([(0,y),(w,y)],fill=TEAL+(22,),width=1)
    g=g.filter(ImageFilter.GaussianBlur(1.6))
    # fade no horizonte
    m=Image.new('L',(w,h),0); md=ImageDraw.Draw(m)
    for y in range(horizon,h):
        md.line([(0,y),(w,y)],fill=int(255*min(1,(y-horizon)/(h-horizon)*1.6)))
    g.putalpha(ImageChops.multiply(g.split()[3],m))
    return Image.alpha_composite(im,g)

def emblem(im,cx,cy,size):
    """calendário dourado 3D com check, brilho forte"""
    w,h=im.size
    im=glow(im,cx,cy,size*1.6,size*1.4,GOLD,110,size*0.6)
    im=glow(im,cx,cy,size*0.9,size*0.8,GOLD_L,90,size*0.35)
    g=new(w,h); d=ImageDraw.Draw(g)
    s=size; x0,y0=cx-s*0.5,cy-s*0.45; x1,y1=cx+s*0.5,cy+s*0.5
    # corpo com gradiente vertical
    body=Image.new('RGBA',(int(s),int(s*0.95)),(0,0,0,0)); bd=ImageDraw.Draw(body)
    for y in range(body.height):
        c=lerp(GOLD_L,GOLD_D,y/body.height); bd.line([(0,y),(body.width,y)],fill=c+(255,))
    mask=Image.new('L',body.size,0); ImageDraw.Draw(mask).rounded_rectangle((0,0,body.width-1,body.height-1),radius=int(s*0.12),fill=255)
    body.putalpha(mask)
    g.paste(body,(int(x0),int(y0)),body)
    # cabeçalho mais escuro + argolas
    d.rounded_rectangle((x0,y0,x1,y0+s*0.22),radius=int(s*0.12),fill=GOLD_D+(255,))
    d.rectangle((x0,y0+s*0.12,x1,y0+s*0.22),fill=GOLD_D+(255,))
    for rx in (cx-s*0.25,cx+s*0.25):
        d.rounded_rectangle((rx-s*0.04,y0-s*0.12,rx+s*0.04,y0+s*0.08),radius=int(s*0.04),fill=GOLD_L+(255,))
    # grade
    for i in range(1,4):
        yy=y0+s*0.22+i*(s*0.7/4); d.line([(x0+s*0.1,yy),(x1-s*0.1,yy)],fill=GOLD_D+(160,),width=max(2,int(s*0.012)))
    for i in range(1,4):
        xx=x0+i*(s/4); d.line([(xx,y0+s*0.3),(xx,y1-s*0.08)],fill=GOLD_D+(160,),width=max(2,int(s*0.012)))
    # check
    d.line([(cx-s*0.18,cy+s*0.08),(cx-s*0.04,cy+s*0.22),(cx+s*0.24,cy-s*0.10)],fill=(255,248,225,255),width=max(4,int(s*0.06)),joint='curve')
    # brilho especular
    spec=new(w,h); sd=ImageDraw.Draw(spec); sd.ellipse((x0,y0-s*0.1,x0+s*0.6,y0+s*0.35),fill=(255,255,255,70))
    spec=spec.filter(ImageFilter.GaussianBlur(s*0.12)); spec.putalpha(ImageChops.multiply(spec.split()[3], g.split()[3]))
    g=Image.alpha_composite(g,spec)
    # sombra suave
    sh=new(w,h); ImageDraw.Draw(sh).ellipse((cx-s*0.6,y1-s*0.05,cx+s*0.6,y1+s*0.25),fill=(0,0,0,120)); sh=sh.filter(ImageFilter.GaussianBlur(s*0.12))
    im=Image.alpha_composite(im,sh)
    return Image.alpha_composite(im,g)

def icon(im,kind,cx,cy,s,alpha=150):
    w,h=im.size; g=new(w,h); d=ImageDraw.Draw(g); c=TEAL+(alpha,); lw=max(2,int(s*0.06))
    if kind=='calendar':
        d.rounded_rectangle((cx-s*0.5,cy-s*0.4,cx+s*0.5,cy+s*0.5),radius=int(s*0.1),outline=c,width=lw)
        d.line([(cx-s*0.5,cy-s*0.15),(cx+s*0.5,cy-s*0.15)],fill=c,width=lw)
        for rx in (cx-s*0.25,cx+s*0.25): d.line([(rx,cy-s*0.55),(rx,cy-s*0.3)],fill=c,width=lw)
        for i in range(3):
            for j in range(2): d.rectangle((cx-s*0.32+i*s*0.28,cy+j*s*0.25,cx-s*0.2+i*s*0.28,cy+0.12*s+j*s*0.25),outline=c,width=max(1,lw//2))
    elif kind=='chat':
        d.rounded_rectangle((cx-s*0.5,cy-s*0.4,cx+s*0.5,cy+s*0.3),radius=int(s*0.18),outline=c,width=lw)
        d.polygon([(cx-s*0.2,cy+s*0.3),(cx-s*0.3,cy+s*0.55),(cx+s*0.02,cy+s*0.3)],outline=c,fill=(0,0,0,0))
        for i in range(3): d.ellipse((cx-s*0.28+i*s*0.25,cy-s*0.1,cx-s*0.18+i*s*0.25,cy),fill=c)
    elif kind=='chart':
        d.line([(cx-s*0.5,cy+s*0.5),(cx+s*0.55,cy+s*0.5)],fill=c,width=lw)
        for i,hh in enumerate((0.3,0.55,0.4,0.8)):
            x=cx-s*0.42+i*s*0.25; d.rectangle((x,cy+s*0.5-s*hh,x+s*0.15,cy+s*0.5),outline=c,width=lw)
        d.line([(cx-s*0.35,cy+s*0.05),(cx-s*0.1,cy-s*0.15),(cx+s*0.15,cy-s*0.05),(cx+s*0.45,cy-s*0.42)],fill=c,width=lw)
    elif kind=='target':
        for r in (0.5,0.32,0.14): d.ellipse((cx-s*r,cy-s*r,cx+s*r,cy+s*r),outline=c,width=lw)
    elif kind=='doc':
        d.rounded_rectangle((cx-s*0.38,cy-s*0.5,cx+s*0.38,cy+s*0.5),radius=int(s*0.08),outline=c,width=lw)
        for i in range(4): d.line([(cx-s*0.22,cy-s*0.25+i*s*0.18),(cx+s*0.22,cy-s*0.25+i*s*0.18)],fill=c,width=max(1,lw//2))
    gl=g.filter(ImageFilter.GaussianBlur(s*0.08)); gl.putalpha(gl.split()[3].point(lambda v:int(v*0.9)))
    return Image.alpha_composite(Image.alpha_composite(im,gl),g)

def vignette(im,strength=130):
    w,h=im.size; v=Image.new('L',(w,h),0); ImageDraw.Draw(v).ellipse((-int(w*0.15),-int(h*0.4),int(w*1.15),int(h*1.4)),fill=255)
    v=v.filter(ImageFilter.GaussianBlur(min(w,h)*0.2)); dark=Image.new('RGBA',(w,h),(0,0,0,255))
    dark.putalpha(ImageChops.multiply(ImageChops.invert(v),Image.new('L',(w,h),strength))); return Image.alpha_composite(im,dark)

def grain(im):
    w,h=im.size; n=Image.effect_noise((w,h),14).convert('L'); layer=Image.merge('RGBA',(n,n,n,Image.new('L',(w,h),14))); return Image.alpha_composite(im,layer)

def left_dark(im,frac=0.55,alpha=90):
    w,h=im.size; g=new(w,h); d=ImageDraw.Draw(g)
    for x in range(int(w*frac)): d.line([(x,0),(x,h)],fill=(0,0,0,int(alpha*(1-x/(w*frac))**1.4)))
    return Image.alpha_composite(im,g)

def subject(crop_bottom=0.80, fade_from=0.78):
    cut=Image.open('joao-cut-v3.png').convert('RGBA'); cut=cut.crop(cut.getbbox()); cut=cut.crop((0,0,cut.width,int(cut.height*crop_bottom)))
    rgb=cut.convert('RGB'); a=cut.split()[3]
    rgb=ImageEnhance.Contrast(rgb).enhance(1.06); r,g,b=rgb.split(); r=r.point(lambda v:min(255,int(v*1.02))); b=b.point(lambda v:int(v*0.97)); rgb=Image.merge('RGB',(r,g,b))
    fade=Image.new('L',a.size,255); d=ImageDraw.Draw(fade); hh=a.height; y0=int(hh*fade_from)
    for y in range(y0,hh): t=(y-y0)/max(1,(hh-1-y0)); d.line([(0,y),(a.width,y)],fill=int(255*(1-t)**1.5))
    return Image.merge('RGBA',(*rgb.split(),ImageChops.multiply(a,fade)))

def place(bg,person,target_h,cx_frac,top_frac):
    s=target_h/person.height; p=person.resize((int(person.width*s),int(person.height*s)),Image.LANCZOS)
    rgb=p.convert('RGB').filter(ImageFilter.UnsharpMask(radius=1.6,percent=110,threshold=2)); p=Image.merge('RGBA',(*rgb.split(),p.split()[3]))
    x=int(bg.width*cx_frac-p.width/2); y=int(bg.height*top_frac)
    a=p.split()[3]; rim=new(*bg.size); tint=Image.new('RGBA',p.size,GOLD_L+(0,)); tint.putalpha(a); rim.paste(tint,(x+int(p.width*0.02),y),tint)
    rim=rim.filter(ImageFilter.GaussianBlur(target_h*0.03)); rim.putalpha(rim.split()[3].point(lambda v:int(v*0.5)))
    out=Image.alpha_composite(bg,rim); layer=new(*bg.size); layer.paste(p,(x,y),p); return Image.alpha_composite(out,layer)

def scene(w,h,ex,ey,es,icons,horizon_frac=0.62,person=None,pt=None):
    im=base(w,h)
    im=glow(im,int(w*ex),int(h*ey),int(h*0.9),int(h*0.7),(30,60,140),70,h*0.3)
    im=skyline(im,int(h*horizon_frac),int(h*0.35),seed=int(w+h))
    im=floor_lines(im,int(h*horizon_frac))
    im=emblem(im,int(w*ex),int(h*ey),int(h*es))
    for k,(fx,fy,fs,al) in icons: im=icon(im,k,int(w*fx),int(h*fy),int(h*fs),al)
    if person is not None: im=place(im,person,*pt)
    im=vignette(im); im=grain(im)
    return im

def save(im,p): im.convert('RGB').save(p,quality=86,optimize=True,progressive=True)

A='/home/user/xpn-lp/advogados/assets/'
subj=subject()
# HERO DESKTOP 2560x970: emblema atrás do João (direita), ícones ao redor, lado esquerdo escuro para o texto
W,H=2560,970
im=scene(W,H,0.80,0.52,0.62,
    [('calendar',(0.76,0.26,0.10,150)),('chat',(0.74,0.74,0.09,130)),('chart',(0.95,0.30,0.10,140)),('target',(0.80,0.13,0.06,110)),('doc',(0.94,0.72,0.08,120))],
    person=subj,pt=(int(H*1.14),0.86,0.06))
im=left_dark(im,0.6,110); save(im,A+'hero.jpg')

# HERO MOBILE 800x1660: emblema atrás do João no topo
W,H=800,1660
im=scene(W,H,0.5,0.19,0.27,
    [('calendar',(0.14,0.08,0.05,140)),('chat',(0.86,0.10,0.05,130)),('chart',(0.12,0.30,0.05,130)),('doc',(0.88,0.30,0.045,120))],
    horizon_frac=0.40,person=subject(fade_from=0.66),pt=(int(H*0.44),0.5,0.0))
save(im,A+'mobile-hero.jpg')

# QUEM-SOU 1920x800: cidade + emblema discreto atrás do João
W,H=1920,800
im=scene(W,H,0.78,0.55,0.55,
    [('calendar',(0.66,0.20,0.10,120)),('chart',(0.96,0.28,0.09,120)),('chat',(0.68,0.74,0.08,110))],
    horizon_frac=0.6,person=subj,pt=(int(H*1.06),0.77,0.10))
im=left_dark(im,0.6,110); save(im,A+'quem-sou.jpg')

# QUEM-SOU MOBILE 800x720
W,H=800,720
im=scene(W,H,0.5,0.5,0.6,
    [('calendar',(0.12,0.12,0.09,120)),('chart',(0.88,0.14,0.09,120))],
    horizon_frac=0.62,person=subject(fade_from=0.7),pt=(int(H*1.0),0.5,0.08))
save(im,A+'mobile-quem-sou.jpg')
print('cena ok')
