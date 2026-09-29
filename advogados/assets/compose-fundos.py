import random, math
from PIL import Image, ImageFilter, ImageDraw, ImageEnhance, ImageChops

GOLD=(201,163,90); GOLD2=(232,196,120); NAVY_T=(4,14,48); NAVY_B=(2,8,38)

def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))

def base(w,h):
    # gradiente vertical + leve escurecimento à esquerda (legibilidade do texto)
    im=Image.new('RGB',(w,h)); px=im.load()
    for y in range(h):
        c=lerp(NAVY_T,NAVY_B,y/(h-1))
        for x in range(w): px[x,y]=c
    im=im.convert('RGBA')
    left=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(left)
    for x in range(int(w*0.55)):
        a=int(70*(1-x/(w*0.55))**1.5); d.line([(x,0),(x,h)],fill=(0,0,0,a))
    return Image.alpha_composite(im,left)

def soft_ellipse(im, cx, cy, rx, ry, color, alpha, blur):
    g=Image.new('RGBA', im.size,(0,0,0,0)); d=ImageDraw.Draw(g)
    d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry), fill=color+(alpha,))
    g=g.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(im,g)

def beam(im, x0,y0,x1,y1, width, alpha, blur):
    g=Image.new('RGBA', im.size,(0,0,0,0)); d=ImageDraw.Draw(g)
    d.line([(x0,y0),(x1,y1)], fill=GOLD2+(alpha,), width=width)
    g=g.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(im,g)

def bokeh(im, seed, region, n, rmin, rmax):
    rnd=random.Random(seed); x0,y0,x1,y1=region
    g=Image.new('RGBA', im.size,(0,0,0,0))
    for i in range(n):
        r=rnd.randint(rmin,rmax); x=rnd.randint(x0,x1); y=rnd.randint(y0,y1)
        a=rnd.randint(22,70); bl=rnd.uniform(r*0.15, r*0.6)
        layer=Image.new('RGBA', im.size,(0,0,0,0)); d=ImageDraw.Draw(layer)
        col=GOLD2 if rnd.random()<0.7 else (255,240,210)
        d.ellipse((x-r,y-r,x+r,y+r), fill=col+(a,))
        # anel mais claro na borda (bokeh de lente)
        d.ellipse((x-r,y-r,x+r,y+r), outline=col+(min(255,a+40),), width=max(1,r//12))
        layer=layer.filter(ImageFilter.GaussianBlur(bl))
        g=Image.alpha_composite(g,layer)
    return Image.alpha_composite(im,g)

def vignette(im, strength=120):
    w,h=im.size; v=Image.new('L',(w,h),0); d=ImageDraw.Draw(v)
    d.ellipse((-int(w*0.15),-int(h*0.35),int(w*1.15),int(h*1.35)), fill=255)
    v=v.filter(ImageFilter.GaussianBlur(min(w,h)*0.18))
    dark=Image.new('RGBA',(w,h),(0,0,0,strength)); mask=ImageChops.invert(v)
    dark.putalpha(ImageChops.multiply(mask, Image.new('L',(w,h),strength)))
    return Image.alpha_composite(im,dark)

def grain(im, amount=4, seed=7):
    rnd=random.Random(seed); w,h=im.size
    n=Image.effect_noise((w,h), amount*4).convert('L')
    n=ImageChops.add(n, Image.new('L',(w,h),128-int(n.getextrema()[1]/2)))  # centra ~128
    layer=Image.merge('RGBA',(n,n,n,Image.new('L',(w,h),18)))
    return Image.alpha_composite(im,layer)

def subject(crop_bottom=0.80, fade_from=0.78):
    cut=Image.open('joao-cut-v3.png').convert('RGBA'); cut=cut.crop(cut.getbbox())
    cut=cut.crop((0,0,cut.width,int(cut.height*crop_bottom)))
    rgb=cut.convert('RGB'); a=cut.split()[3]
    rgb=ImageEnhance.Contrast(rgb).enhance(1.06); rgb=ImageEnhance.Color(rgb).enhance(1.02)
    # tom levemente quente
    r,g,b=rgb.split(); r=r.point(lambda v:min(255,int(v*1.02))); b=b.point(lambda v:int(v*0.97)); rgb=Image.merge('RGB',(r,g,b))
    fade=Image.new('L',a.size,255); d=ImageDraw.Draw(fade); h=a.height; y0=int(h*fade_from)
    for y in range(y0,h):
        t=(y-y0)/max(1,(h-1-y0)); d.line([(0,y),(a.width,y)], fill=int(255*(1-t)**1.5))
    return Image.merge('RGBA',(*rgb.split(),ImageChops.multiply(a,fade)))

def place(bg, person, target_h, cx_frac, top_frac, rim=True):
    s=target_h/person.height
    p=person.resize((int(person.width*s), int(person.height*s)), Image.LANCZOS)
    # nitidez após o resize
    rgb=p.convert('RGB').filter(ImageFilter.UnsharpMask(radius=1.6, percent=110, threshold=2))
    p=Image.merge('RGBA',(*rgb.split(),p.split()[3]))
    x=int(bg.width*cx_frac-p.width/2); y=int(bg.height*top_frac)
    out=bg
    if rim:
        # contorno de luz quente atrás da silhueta
        a=p.split()[3]
        glow=Image.new('RGBA',bg.size,(0,0,0,0)); tint=Image.new('RGBA',p.size,GOLD2+(0,)); tint.putalpha(a)
        glow.paste(tint,(x+int(p.width*0.02),y),tint)
        glow=glow.filter(ImageFilter.GaussianBlur(target_h*0.035))
        glow=Image.merge('RGBA',(*glow.convert('RGB').split(), glow.split()[3].point(lambda v:int(v*0.55))))
        out=Image.alpha_composite(out,glow)
    layer=Image.new('RGBA',bg.size,(0,0,0,0)); layer.paste(p,(x,y),p)
    return Image.alpha_composite(out,layer)

def backdrop(w,h,kx,ky, bokeh_region, seed=3, beams=True):
    im=base(w,h)
    im=soft_ellipse(im,int(w*kx),int(h*ky),int(h*0.75),int(h*0.62),GOLD,78,h*0.25)      # luz principal
    im=soft_ellipse(im,int(w*kx),int(h*(ky-0.15)),int(h*0.32),int(h*0.28),GOLD2,42,h*0.12) # núcleo
    im=soft_ellipse(im,int(w*0.18),int(h*1.05),int(h*0.8),int(h*0.5),(24,48,120),60,h*0.3)  # contraluz azul
    if beams:
        im=beam(im,int(w*0.62),-int(h*0.2),int(w*0.95),int(h*1.1),int(h*0.12),26,h*0.08)
        im=beam(im,int(w*0.72),-int(h*0.2),int(w*1.02),int(h*1.0),int(h*0.06),34,h*0.05)
    im=bokeh(im,seed,bokeh_region,16,int(h*0.012),int(h*0.07))
    im=vignette(im,110)
    im=grain(im)
    return im

def save(im,path,q=86):
    im.convert('RGB').save(path,quality=q,optimize=True,progressive=True)

A='/home/user/xpn-lp/advogados/assets/'
subj=subject()

# HERO DESKTOP 2560x970
W,H=2560,970
bg=backdrop(W,H,0.86,0.55,(int(W*0.55),int(H*0.02),int(W*0.99),int(H*0.75)),seed=3)
save(place(bg,subj,int(H*1.14),0.875,0.06),A+'hero.jpg')

# HERO MOBILE 800x1660
W,H=800,1660
bg=backdrop(W,H,0.5,0.20,(int(W*0.05),int(H*0.02),int(W*0.95),int(H*0.40)),seed=5,beams=False)
bg=soft_ellipse(bg,int(W*0.5),int(H*0.22),int(W*0.5),int(W*0.5),GOLD,34,W*0.25)
save(place(subject(fade_from=0.64),subj if False else bg,0,0,0) if False else place(bg,subject(fade_from=0.66),int(H*0.44),0.5,0.0),A+'mobile-hero.jpg')

# QUEM-SOU 1920x800
W,H=1920,800
bg=backdrop(W,H,0.78,0.6,(int(W*0.5),int(H*0.02),int(W*0.99),int(H*0.7)),seed=9)
save(place(bg,subj,int(H*1.06),0.77,0.10),A+'quem-sou.jpg')

# QUEM-SOU MOBILE 800x720
W,H=800,720
bg=backdrop(W,H,0.5,0.5,(int(W*0.05),int(H*0.02),int(W*0.95),int(H*0.6)),seed=11,beams=False)
save(place(bg,subject(fade_from=0.7),int(H*1.0),0.5,0.08),A+'mobile-quem-sou.jpg')
print('composites ok')
