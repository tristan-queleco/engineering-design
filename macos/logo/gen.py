import math
C=(490,500); s=270; cx=s*math.cos(math.pi/6); cy=s/2
def P(dx,dy): return (C[0]+dx,C[1]+dy)
def pts(L): return " ".join(f"{x:.1f},{y:.1f}" for x,y in L)
top=[P(0,0),P(-cx,-cy),P(0,-s),P(cx,-cy)]
left=[P(0,0),P(-cx,-cy),P(-cx,cy),P(0,s)]
right=[P(0,0),P(cx,-cy),P(cx,cy),P(0,s)]
hc=P(0,-cy); r=72; rx=r*1.2247; ry=r*0.7071
a=P(0,s); b=P(cx,cy); n=(0.5,0.866); off=78
A=(a[0]+n[0]*off,a[1]+n[1]*off); B=(b[0]+n[0]*off,b[1]+n[1]*off)
ext=lambda p,q:(p[0]+n[0]*(off+18),p[1]+n[1]*(off+18))
d=(B[0]-A[0],B[1]-A[1]); L=math.hypot(*d); u=(d[0]/L,d[1]/L); pn=(-u[1],u[0])
def head(tip,dirx):
    k=46;w=20
    base=(tip[0]+dirx[0]*k,tip[1]+dirx[1]*k)
    return pts([tip,(base[0]+pn[0]*w,base[1]+pn[1]*w),(base[0]-pn[0]*w,base[1]-pn[1]*w)])
def layers():
    fond=f'''<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2f6bf0"/><stop offset="1" stop-color="#0c2c86"/></linearGradient>
<clipPath id="sq"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath>
<filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity="0.30"/></filter></defs>
<rect x="100" y="100" width="824" height="824" rx="185" fill="url(#g)" filter="url(#sh)"/>
<g clip-path="url(#sq)" stroke="#ffffff" stroke-opacity="0.09" stroke-width="3">'''+"".join(f'<path d="M{100+i*68.7:.1f} 100V924M100 {100+i*68.7:.1f}H924"/>' for i in range(1,12))+'</g>'
    piece=f'''<polygon points="{pts(left)}" fill="#d7e3ff"/><polygon points="{pts(right)}" fill="#9db7f2"/><polygon points="{pts(top)}" fill="#ffffff"/>
<ellipse cx="{hc[0]}" cy="{hc[1]}" rx="{rx:.1f}" ry="{ry:.1f}" fill="#123a9e"/>
<path d="M{hc[0]-rx:.1f},{hc[1]} A{rx:.1f},{ry:.1f} 0 0 1 {hc[0]+rx:.1f},{hc[1]} L{hc[0]+rx*0.8:.1f},{hc[1]+ry*0.55:.1f} A{rx*0.8:.1f},{ry*0.8:.1f} 0 0 0 {hc[0]-rx*0.8:.1f},{hc[1]+ry*0.55:.1f} Z" fill="#0a2470" opacity="0.65"/>
<polygon points="{pts(top+[top[0]])}" fill="none" stroke="#ffffff" stroke-width="6" stroke-linejoin="round"/>'''
    ea=ext(a,0); eb=ext(b,0)
    cote=f'''<g stroke="#ff8a1f" stroke-width="12" stroke-linecap="round" fill="none"><path d="M{a[0]+n[0]*16:.1f},{a[1]+n[1]*16:.1f}L{ea[0]:.1f},{ea[1]:.1f}"/><path d="M{b[0]+n[0]*16:.1f},{b[1]+n[1]*16:.1f}L{eb[0]:.1f},{eb[1]:.1f}"/>
<path d="M{A[0]+u[0]*40:.1f},{A[1]+u[1]*40:.1f}L{B[0]-u[0]*40:.1f},{B[1]-u[1]*40:.1f}"/></g>
<polygon points="{head(A,u)}" fill="#ff8a1f"/><polygon points="{head(B,(-u[0],-u[1]))}" fill="#ff8a1f"/>'''
    return fond,piece,cote
f,p,c=layers()
w=lambda name,body:open(name,'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{body}</svg>')
w('logo.svg',f+p+c); w('couche-1-fond.svg',f); w('couche-2-piece.svg',p); w('couche-3-cote.svg',c)
print(A,B)
