"""Monster sprite generator (side view facing right, flipped in-engine)."""
import math
import os
from PIL import Image
from pix import Canvas, Sheet, hx, ramp, shade, mix, CLEAR

EYE = hx('181425')
WHITE = hx('ffffff')


def R(c, n=4):
    return ramp(c, n)


# ------------------------------------------------------------ generic helpers
def leg(c, x0, y0, x1, y1, col, w=2):
    c.thick_line(x0, y0, x1, y1, col, w)


def finish(c):
    c.outline()
    return c


def death_frames(base):
    out = []
    for i, (sq, a) in enumerate(((1.0, 255), (0.8, 220), (0.55, 150), (0.3, 70))):
        img = base.img.copy()
        w, h = img.size
        nh = max(1, int(h * sq))
        img2 = img.resize((w + int((1 - sq) * 6), nh), Image.NEAREST)
        out_img = Image.new('RGBA', (w, h), CLEAR)
        out_img.alpha_composite(img2.crop((0, 0, min(w, img2.width), nh)), (0, h - nh))
        if a < 255:
            al = out_img.split()[3].point(lambda v: v * a // 255)
            out_img.putalpha(al)
        cv = Canvas(w, h)
        cv.img = out_img
        cv.px = out_img.load()
        out.append(cv)
    return out


def shifted(c, dx, dy):
    out = Canvas(c.w, c.h)
    out.img.alpha_composite(c.img, (0, 0))
    out.img = Image.new('RGBA', (c.w, c.h), CLEAR)
    out.img.alpha_composite(c.img, (dx, dy)) if dx >= 0 and dy >= 0 else out.img.paste(c.img, (dx, dy), c.img)
    out.px = out.img.load()
    return out


# ------------------------------------------------------------ slime
def slime(anim, i, n):
    W, H = 20, 18
    c = Canvas(W, H)
    rr = [hx('6f7a86'), hx('9aa6b2'), hx('c7d0d8'), hx('eef3f7')]
    sq = 0.0
    lift = 0
    if anim == 'idle':
        sq = [0.0, 0.08, 0.15, 0.08][i]
    elif anim == 'move':
        sq = [0.2, -0.15, -0.2, -0.1, 0.05, 0.25][i]
        lift = [0, 2, 4, 3, 1, 0][i]
    elif anim == 'attack':
        sq = [0.3, 0.35, -0.3, 0.0][i]
        lift = [0, 0, 2, 0][i]
    rx = 7 * (1 + sq * 0.6)
    ry = 6 * (1 - sq)
    cx, cy = 10, 16 - ry - lift
    c.ellipse(cx, cy, rx, ry, None, rr, light=(-0.5, -0.8))
    # flat-ish bottom
    c.hline(int(cx - rx + 2), int(cx + rx - 2), int(cy + ry), rr[1])
    # face
    ex = cx + 2
    ey = int(cy - ry * 0.1)
    c.put(ex, ey, EYE)
    c.put(ex, ey + 1, EYE)
    c.put(ex + 3, ey, EYE)
    c.put(ex + 3, ey + 1, EYE)
    if anim == 'attack' and i in (1, 2):
        c.hline(ex, ex + 3, ey + 3, EYE)
    c.put(cx - rx * 0.5, cy - ry * 0.5, WHITE)
    c.put(cx - rx * 0.5 + 1, cy - ry * 0.5, WHITE)
    c.put(cx - rx * 0.5, cy - ry * 0.5 + 1, rr[3])
    return finish(c)


# ------------------------------------------------------------ quadrupeds
def quad(anim, i, n, p):
    W, H = p['size']
    c = Canvas(W, H)
    body = R(p['body'])
    belly = R(p.get('belly', p['body']))
    ground = H - 2
    phase = (i / max(1, n)) * math.tau
    bob = 0
    lunge = 0
    rear = 0
    jaw = 0
    if anim == 'idle':
        bob = 1 if i in (2, 3) else 0
        sw = [0, 0, 0, 0]
    elif anim == 'move':
        bob = 1 if i % 3 == 1 else 0
        a = math.sin(phase) * p.get('stride', 3)
        sw = [a, -a, -a, a]
    elif anim == 'attack':
        lunge = [-1, 2, 4, 1][i]
        jaw = [0, 1, 2, 1][i]
        rear = [0, 2, 4, 1][i] if p.get('rears') else 0
        sw = [0, 2, 3, 0]
    else:
        sw = [0, 0, 0, 0]
    bl, bh = p['blen'], p['bh']
    leglen = p['leg']
    cx = W // 2 - 2 + lunge
    cy = ground - leglen - bh // 2 + bob - rear // 2
    # tail
    tx = cx - bl // 2
    tail = p.get('tail', 'brush')
    if tail == 'brush':
        c.thick_line(tx, cy - 1, tx - 5, cy - 4 + (1 if i % 2 else 0), body[1], 3)
        c.thick_line(tx - 4, cy - 4, tx - 7, cy - 2, body[2], 2)
    elif tail == 'long':
        c.thick_line(tx, cy - 1, tx - 6, cy - 3, body[1], 2)
        c.thick_line(tx - 6, cy - 3, tx - 9, cy - 6 + (i % 2), body[1], 2)
        c.put(tx - 9, cy - 7 + (i % 2), hx('181425'))
    elif tail == 'stub':
        c.disc(tx, cy - 2, 2, body[2])
    elif tail == 'puff':
        c.disc(tx, cy - 1, 2.2, hx('f4f1ea'))
    # far legs (darker)
    fx, bx = cx + bl // 2 - 3, cx - bl // 2 + 3
    lw = p.get('legw', 2)
    dark = shade(body[1], -0.3)
    leg(c, fx - 1, cy + 1, fx - 1 + sw[1], ground - (rear if rear else 0), dark, lw)
    leg(c, bx - 1, cy + 1, bx - 1 + sw[3], ground, dark, lw)
    # body
    c.ellipse(cx, cy, bl / 2, bh / 2, None, body, light=(-0.3, -0.9))
    # belly
    for x in range(int(cx - bl / 2 + 3), int(cx + bl / 2 - 2)):
        c.put(x, int(cy + bh / 2 - 1), belly[2])
    # stripes
    if p.get('stripes'):
        for k in range(4):
            sx = int(cx - bl / 2 + 4 + k * (bl - 6) / 4)
            for dy in range(-bh // 2 + 1, 1):
                c.put(sx + (dy % 2), cy + dy, hx('262b44'))
    if p.get('spots'):
        for k in range(3):
            c.put(int(cx - bl / 4 + k * 4), int(cy - 1 - (k % 2)), hx('f4f1ea'))
    # near legs
    leg(c, fx + 1, cy + 1, fx + 1 + sw[0], ground - (rear if rear else 0), body[2], lw)
    leg(c, bx + 1, cy + 1, bx + 1 + sw[2], ground, body[2], lw)
    # paws
    for lx in (fx + 1 + sw[0], bx + 1 + sw[2]):
        c.put(lx, ground, body[0])
        c.put(lx + 1, ground, body[0])
    # head
    hr = p['head']
    hx0 = cx + bl / 2 - 1
    hy0 = cy - bh / 2 - hr * 0.3 - rear
    c.ellipse(hx0, hy0, hr, hr * 0.9, None, body, light=(-0.3, -0.9))
    # snout
    sl = p.get('snout', 4)
    sy = hy0 + hr * 0.3
    c.rect(hx0 + hr - 2, sy - 1, sl, 3, body[2])
    c.put(hx0 + hr - 2 + sl, sy - 1, hx('181425'))  # nose
    if jaw:
        c.rect(hx0 + hr - 2, sy + 2, sl - 1, jaw, hx('a22633'))
        c.rect(hx0 + hr - 1, sy + 2 + jaw, sl - 2, 1, body[1])
        c.put(hx0 + hr, sy + 2, WHITE)
    # ears
    et = p.get('ears', 'point')
    if et == 'point':
        c.poly([(hx0 - 2, hy0 - hr + 2), (hx0 + 1, hy0 - hr - 3), (hx0 + 2, hy0 - hr + 2)], body[1])
    elif et == 'round':
        c.disc(hx0 - 1, hy0 - hr + 1, 2, body[1])
    elif et == 'long':
        c.thick_line(hx0 - 1, hy0 - hr + 1, hx0 - 3, hy0 - hr - 6, body[2], 2)
        c.thick_line(hx0 + 1, hy0 - hr + 1, hx0, hy0 - hr - 6, body[3], 2)
    if p.get('antlers'):
        a = hx('c28569')
        c.line(hx0, hy0 - hr, hx0 - 2, hy0 - hr - 6, a)
        c.line(hx0 - 2, hy0 - hr - 4, hx0 - 5, hy0 - hr - 6, a)
        c.line(hx0 + 1, hy0 - hr, hx0 + 3, hy0 - hr - 7, a)
        c.line(hx0 + 3, hy0 - hr - 4, hx0 + 6, hy0 - hr - 6, a)
    # eye
    ec = hx(p.get('eye', '181425'))
    c.put(hx0 + hr * 0.4, hy0 - hr * 0.2, ec)
    if p.get('eye_glow'):
        c.put(hx0 + hr * 0.4 + 1, hy0 - hr * 0.2, ec)
    if p.get('mane'):
        mr = R(p['mane'])
        c.ellipse(hx0 - hr * 0.6, hy0 + 1, hr * 0.7, hr * 1.1, None, mr)
    return finish(c)


WOLF = dict(size=(32, 24), body='#8b9bb4', belly='#c0cbdc', blen=17, bh=8, leg=6, head=4.2, snout=4, tail='brush',
            ears='point', stride=3, eye='feae34')
TIGER = dict(size=(38, 26), body='#f77622', belly='#ead4aa', blen=21, bh=9, leg=6, head=5, snout=3, tail='long',
             ears='round', stripes=True, stride=4, eye='63c74d')
BEAR = dict(size=(38, 32), body='#733e39', belly='#b86f50', blen=21, bh=12, leg=6, head=5.5, snout=3, tail='stub',
            ears='round', stride=2, rears=True, legw=3)
RABBIT = dict(size=(16, 14), body='#c0cbdc', belly='#ffffff', blen=7, bh=5, leg=2, head=2.8, snout=1, tail='puff',
              ears='long', stride=1)
DEER = dict(size=(30, 32), body='#b86f50', belly='#ead4aa', blen=14, bh=7, leg=10, head=3.5, snout=3, tail='stub',
            ears='point', antlers=True, spots=True, stride=3)


# ------------------------------------------------------------ bipeds
def biped(anim, i, n, p):
    W, H = p['size']
    c = Canvas(W, H)
    skin = R(p['skin'])
    cloth = R(p.get('cloth', p['skin']))
    ground = H - 2
    s = p['scale']
    bob = 0
    sw = 0
    lean = 0
    armA = 0.0  # weapon arm angle (radians, 0 = down-forward)
    phase = (i / max(1, n)) * math.tau
    if anim == 'idle':
        bob = 1 if i in (1, 2) else 0
        armA = 0.3
    elif anim == 'move':
        bob = 1 if i % 3 == 1 else 0
        sw = math.sin(phase) * 2.5 * s
        armA = 0.3 + math.sin(phase) * 0.4
    elif anim == 'attack':
        armA = [-2.4, -2.0, 0.9, 0.6][i]
        lean = [-1, -1, 2, 1][i]
        bob = [0, 0, 1, 0][i]
    if p.get('shamble'):
        armA = 1.4 + (0.15 * math.sin(phase) if anim != 'attack' else [-0.5, 0, 1.6, 1.4][i])
    legl = int(p['leg'] * s)
    hipy = ground - legl + bob
    cx = W // 2 + lean
    bw = p['bw'] * s
    bh = int(p['bh'] * s)
    # tail
    if p.get('tail'):
        tc = skin[1]
        c.thick_line(cx - 2, hipy - 1, cx - 7 * s, ground - 1, tc, max(2, int(2 * s)))
        c.thick_line(cx - 7 * s, ground - 1, cx - 10 * s, ground - 2, tc, 2)
    # wings behind
    if p.get('wings'):
        wr = R(p['wings'])
        flap = [-0.6, 0.0, 0.6, 0.0][i % 4]
        wings(c, cx - 1, hipy - bh + 2, 9 * s, 9 * s, wr, flap)
    # cape behind
    if p.get('cape'):
        cr = R(p['cape'])
        flap = 1 if i % 2 else 0
        c.poly([(cx - bw / 2, hipy - bh), (cx + 1, hipy - bh), (cx - 3 - flap, ground), (cx - bw - 3 - flap, ground - 1)], cr[1])
        c.poly([(cx - bw / 2 + 1, hipy - bh + 1), (cx, hipy - bh + 1), (cx - 3, ground - 2), (cx - 5, ground - 2)], hx('a22633'))
    # far arm
    sh = (cx + 1, hipy - bh + 2)
    alen = p['arm'] * s
    if not p.get('no_far_arm'):
        fa = armA * 0.3 + 0.2 if anim != 'attack' else 0.3
        if p.get('shamble'):
            fa = armA
        c.thick_line(sh[0] - 1, sh[1], sh[0] - 1 + math.sin(fa) * alen, sh[1] + math.cos(fa) * alen,
                     shade(skin[1] if p.get('bare_arms', True) else cloth[1], -0.2), max(2, int(2 * s)))
    # legs
    lw = max(2, int(p.get('legw', 2) * s))
    if p.get('robe_legs'):
        rc = R(p['cloth'])
        c.poly([(cx - bw / 2, hipy - 2), (cx + bw / 2, hipy - 2), (cx + bw / 2 + 2, ground), (cx - bw / 2 - 2, ground)], rc[1])
        c.hline(cx - bw / 2 - 2, cx + bw / 2 + 1, ground, rc[0])
    elif p.get('float'):
        rc = R(p.get('cloth', p['skin']))
        for k in range(3):
            c.thick_line(cx - 2 + k * 2, hipy - 1, cx - 3 + k * 2 + (math.sin(phase + k) * 1.5), ground - 2 - k, rc[1 + k % 2], 2)
    else:
        lc = R(p.get('pants', p['skin']))
        c.thick_line(cx - 1, hipy, cx - 1 - sw, ground, shade(lc[1], -0.2), lw)
        c.thick_line(cx + 1, hipy, cx + 1 + sw, ground, lc[2], lw)
        fc = R(p.get('feet', p.get('pants', p['skin'])))
        c.rect(cx - 2 - sw, ground, lw + 1, 1, fc[0])
        c.rect(cx + sw, ground, lw + 1, 1, fc[1])
    # torso
    ty = hipy - bh
    for y in range(int(ty), int(hipy + 1)):
        for x in range(int(cx - bw / 2), int(cx + bw / 2 + 1)):
            col = cloth[2]
            if x <= cx - bw / 2 + 0.5:
                col = cloth[1]
            if x >= cx + bw / 2 - 0.5:
                col = cloth[3]
            c.put(x, y, col)
    if p.get('ribs'):
        for k in range(3):
            c.hline(cx - bw / 2 + 1, cx + bw / 2 - 1, ty + 2 + k * 2, skin[0])
        c.vline(cx, ty, hipy, skin[3])
    if p.get('belt'):
        c.hline(cx - bw / 2, cx + bw / 2, hipy - 1, hx(p['belt']))
    if p.get('belly'):
        br = R(p['belly'])
        for y in range(int(ty + 2), int(hipy)):
            c.hline(cx + 1, cx + bw / 2 - 1, y, br[2])
    if p.get('collar'):
        cr = R(p['collar'])
        c.poly([(cx - bw / 2 - 1, ty - 2), (cx - bw / 2 + 2, ty + 2), (cx - bw / 2, ty + 3)], cr[1])
    # head
    hr = p['head'] * s
    hcx = cx + p.get('head_dx', 1) * s
    hcy = ty - hr + 1 + p.get('head_dy', 0)
    c.ellipse(hcx, hcy, hr, hr, None, skin, light=(-0.4, -0.8))
    if p.get('snout'):
        c.rect(hcx + hr - 1, hcy, p['snout'], 3, skin[2])
        c.put(hcx + hr - 1 + p['snout'], hcy, hx('181425'))
        if anim == 'attack' and i == 2:
            c.rect(hcx + hr - 1, hcy + 3, p['snout'] - 1, 1, hx('a22633'))
    if p.get('ears'):
        c.poly([(hcx - 1, hcy - 1), (hcx - hr - 4, hcy - 3), (hcx - 1, hcy + 2)], skin[2])
        c.put(hcx - hr - 2, hcy - 2, skin[3])
    if p.get('horns'):
        hc = hx(p['horns'])
        c.line(hcx - 1, hcy - hr, hcx - 3, hcy - hr - 3, hc)
        c.line(hcx + 2, hcy - hr, hcx + 3, hcy - hr - 3, hc)
    if p.get('hair'):
        hrr = R(p['hair'])
        c.ellipse(hcx - hr * 0.35, hcy - hr * 0.45, hr * 0.85, hr * 0.7, None, hrr)
        if p.get('long_hair'):
            c.rect(hcx - hr, hcy - 1, max(2, int(hr * 0.8)), int(hr * 2.2), hrr[1])
    if p.get('leafhair'):
        lr = R(p['leafhair'])
        for k in range(7):
            ang = math.pi + k * 0.45
            lx = hcx - 1 + math.cos(ang) * hr * 1.05
            ly = hcy - 1 + math.sin(ang) * hr * 1.05
            c.disc(lx, ly, 1.6 * s, lr[1 + k % 3])
        c.rect(hcx - hr - 1, hcy, 2, int(hr * 2.4), lr[1])
    if p.get('helm'):
        hm = R(p['helm'])
        c.ellipse(hcx, hcy - hr * 0.35, hr + 0.5, hr * 0.7, None, hm)
    # eye
    ec = hx(p.get('eye', '181425'))
    ex = hcx + hr * 0.45
    ey = hcy - hr * 0.1
    c.put(ex, ey, ec)
    if p.get('eye_glow'):
        c.put(ex, ey + 1, ec)
    if p.get('skull'):
        c.put(ex - 1, ey, hx('181425'))
        c.put(ex, ey, hx('181425'))
        c.put(ex, ey + 1, hx('e43b44') if p.get('eye_glow') else hx('181425'))
        c.hline(hcx, hcx + hr, hcy + hr * 0.6, skin[0])
    if p.get('brow'):
        c.hline(hcx - 1, hcx + hr, hcy - hr * 0.35, skin[0])
    if p.get('tusks'):
        c.put(hcx + hr * 0.6, hcy + hr * 0.5, WHITE)
        c.put(hcx + hr * 0.6, hcy + hr * 0.5 - 1, WHITE)
    if p.get('fangs') and anim == 'attack':
        c.put(hcx + hr * 0.6, hcy + hr * 0.5, WHITE)
    # near arm + weapon
    ax = sh[0] + 1 + math.sin(armA) * alen
    ay = sh[1] + math.cos(armA) * alen
    armc = skin[2] if p.get('bare_arms', True) else cloth[2]
    c.thick_line(sh[0] + 1, sh[1], ax, ay, armc, max(2, int(2 * s)))
    wpn = p.get('weapon')
    if wpn:
        ang = armA
        dx, dy = math.sin(ang), math.cos(ang)
        if wpn in ('dagger', 'sword', 'spear', 'club', 'staff', 'trident', 'scythe'):
            L = {'dagger': 4, 'sword': 8, 'spear': 13, 'club': 10, 'staff': 13, 'trident': 13, 'scythe': 12}[wpn] * s
            # weapon continues from hand in arm direction (perpendicular for swing look)
            wx, wy = ax + dx * L, ay + dy * L
            if wpn in ('spear', 'trident', 'staff'):
                wx, wy = ax + 4 * s + L * 0.7, ay - L * 0.5 if anim != 'attack' else ay + dy * L
                if anim == 'attack' and i >= 2:
                    wx, wy = ax + L, ay - 1
            col = {'dagger': hx('c0cbdc'), 'sword': hx('c0cbdc'), 'spear': hx('b86f50'), 'club': hx('733e39'),
                   'staff': hx('733e39'), 'trident': hx('feae34'), 'scythe': hx('5a6988')}[wpn]
            th = 3 if wpn == 'club' else 1
            if wpn == 'club':
                th = max(2, int(2 * s))
            c.thick_line(ax, ay, wx, wy, col, th if wpn != 'club' else th)
            if wpn == 'club':
                c.disc(wx, wy, 2.5 * s, hx('733e39'))
                c.put(wx - 1, wy - 1, hx('b86f50'))
            if wpn in ('spear',):
                c.put(wx, wy, hx('e4e8ef'))
                c.put(wx + 1, wy, hx('e4e8ef'))
            if wpn == 'trident':
                c.line(wx - 2, wy - 2, wx + 2, wy + 2, col)
            if wpn == 'staff':
                c.disc(wx, wy, 1.8 * s, hx(p.get('orb', '63c74d')))
    c.disc(ax, ay, max(1.0, 1.2 * s), skin[1] if not p.get('glove') else hx(p['glove']))
    return finish(c)


GOBLIN = dict(size=(24, 24), scale=1.0, skin='#63c74d', cloth='#733e39', pants='#5a4a42', feet='#3e2731', leg=5, bw=6,
              bh=6, head=4.2, arm=5, ears=True, weapon='dagger', eye='fee761', bare_arms=True, head_dx=1)
OGRE = dict(size=(44, 46), scale=1.9, skin='#9aa35a', brow=True, cloth='#5a4a42', pants='#3e2731', feet='#262b44', leg=6, bw=8,
            bh=7, head=4.2, arm=6, tusks=True, weapon='club', belly='#e8b796', eye='181425', legw=2.2)
SKELETON = dict(size=(24, 30), scale=1.1, skin='#e4e8ef', cloth='#c0cbdc', pants='#c0cbdc', leg=7, bw=5, bh=7, head=4,
                arm=6, ribs=True, skull=True, weapon='sword', eye='e43b44', eye_glow=True, legw=1.5)
ZOMBIE = dict(size=(24, 30), scale=1.1, skin='#8fb08a', cloth='#5a6988', pants='#3e2731', feet='#262b44', leg=7, bw=6,
              bh=7, head=4.2, arm=6, shamble=True, eye='e43b44', hair='#3e2731', bare_arms=True)
LIZARD = dict(size=(30, 32), scale=1.15, skin='#3e8948', cloth='#3e8948', pants='#265c42', feet='#193c3e', leg=7,
              bw=6, bh=8, head=3.8, arm=6, tail=True, snout=3, weapon='spear', belly='#ead4aa', eye='fee761')
VAMPIRE = dict(size=(26, 34), scale=1.15, skin='#e4e8ef', cloth='#262b44', pants='#181425', feet='#181425', leg=8,
               bw=6, bh=8, head=3.8, arm=6, cape='#181425', collar='#a22633', hair='#181425', eye='e43b44',
               eye_glow=True, fangs=True, bare_arms=False)
DRYAD = dict(size=(26, 34), scale=1.15, skin='#9ad08a', cloth='#3e8948', leg=8, bw=5, bh=8, head=3.6, arm=6,
             leafhair='#63c74d', float=True, eye='265c42', weapon='staff', orb='fee761', bare_arms=True)
ANGEL = dict(size=(28, 32), scale=1.0, skin='#f0c9a8', cloth='#f4f1ea', leg=8, bw=6, bh=8, head=3.6, arm=6,
             hair='#fee761', float=True, eye='124e89', weapon='staff', orb='ffffff', wings='#f4f1ea')
GUARDIAN = dict(size=(28, 34), scale=1.2, skin='#8b9bb4', cloth='#5a6988', pants='#3a4466', feet='#262b44', leg=7,
                bw=6, bh=8, head=3.8, arm=6, helm='#c0cbdc', weapon='spear', eye='2ce8f5', eye_glow=True)


# ------------------------------------------------------------ special shapes
def treant(anim, i, n):
    W, H = 44, 50
    c = Canvas(W, H)
    bark = R('#733e39')
    leaf = R('#3e8948', 5)
    ground = H - 2
    phase = i / max(1, n) * math.tau
    bob = 1 if (anim == 'idle' and i in (1, 2)) else 0
    sway = int(math.sin(phase) * 2) if anim == 'move' else 0
    att = [-6, -5, 6, 3][i] if anim == 'attack' else 0
    cx = 22
    # root legs
    for k, d in enumerate((-5, 0, 5)):
        off = sway * (1 if k % 2 else -1)
        c.thick_line(cx + d, ground - 12, cx + d * 1.6 + off, ground, bark[1 + (k % 2)], 3)
    # trunk
    for y in range(ground - 30 + bob, ground - 8):
        w = 6 + (1 if y > ground - 16 else 0)
        for x in range(cx - w, cx + w):
            col = bark[2] if x < cx + 2 else bark[1]
            if (x + y * 3) % 7 == 0:
                col = bark[0]
            c.put(x, y, col)
    # face
    fy = ground - 22 + bob
    c.rect(cx + 1, fy, 2, 2, hx('181425'))
    c.rect(cx + 5, fy, 2, 2, hx('181425'))
    c.put(cx + 2, fy, hx('fee761'))
    c.put(cx + 6, fy, hx('fee761'))
    c.hline(cx + 1, cx + 6, fy + 5, hx('181425'))
    # arms (branches)
    ay = ground - 24 + bob
    c.thick_line(cx - 5, ay, cx - 13, ay + 6 - att // 2, bark[1], 3)
    c.thick_line(cx + 5, ay, cx + 14, ay - 2 + att, bark[2], 3)
    c.line(cx + 14, ay - 2 + att, cx + 18, ay - 5 + att, bark[2])
    c.line(cx + 14, ay - 2 + att, cx + 18, ay + 1 + att, bark[2])
    c.disc(cx + 16, ay - 4 + att, 2.5, leaf[2])
    # crown
    cy = ground - 36 + bob
    for k in range(9):
        ang = k / 9 * math.tau
        c.disc(cx + math.cos(ang) * 9 + sway, cy + math.sin(ang) * 6, 6, leaf[1 + k % 3])
    c.ellipse(cx + sway, cy - 1, 11, 8, None, leaf[1:], light=(-0.4, -0.9))
    for k in range(6):
        c.put(cx - 6 + k * 3 + sway, cy - 4 + (k % 2) * 3, leaf[4])
    return finish(c)


def mermaid(anim, i, n):
    W, H = 30, 30
    c = Canvas(W, H)
    skin = R('#f0c9a8')
    tail = R('#2ce8f5')
    hair = R('#e43b44')
    ground = H - 2
    phase = i / max(1, n) * math.tau
    wave = math.sin(phase) * 2
    bob = 1 if (anim == 'idle' and i in (1, 2)) else 0
    cx = 13
    # tail curling on ground
    pts = []
    for k in range(12):
        t = k / 11
        x = cx - 2 - t * 9
        y = ground - 4 + math.sin(t * 3 + phase) * 1.5 + t * 2
        pts.append((x, y))
    for k, (x, y) in enumerate(pts):
        c.disc(x, y, 3.2 - k * 0.18, tail[1 + (k % 2)])
    fx, fy = pts[-1]
    c.poly([(fx, fy), (fx - 5, fy - 4 + wave), (fx - 3, fy), (fx - 5, fy + 4 - wave)], tail[2])
    # scales sparkle
    for k in range(0, 10, 3):
        c.put(pts[k][0], pts[k][1] - 1, tail[3])
    # torso
    ty = ground - 16 + bob
    c.thick_line(cx, ground - 5, cx + 1, ty + 4, skin[2], 4)
    c.rect(cx - 1, ty + 3, 5, 2, hx('feae34'))  # shell top
    # head & hair
    c.ellipse(cx + 2, ty - 1, 3.6, 3.6, None, skin)
    c.rect(cx - 3, ty - 4, 5, 11, hair[1])
    c.ellipse(cx + 1, ty - 3, 3.8, 2.6, None, hair)
    c.put(cx + 4, ty - 1, hx('124e89'))
    # arm with trident
    att = anim == 'attack'
    a = [-1.6, -1.2, 1.2, 0.8][i] if att else 0.6
    hxp, hyp = cx + 2 + math.sin(a) * 6, ty + 5 - math.cos(a) * 4
    c.thick_line(cx + 2, ty + 4, hxp, hyp, skin[2], 2)
    tx, ty2 = hxp + 6, hyp - 6 if not att else hyp + (2 if i >= 2 else -6)
    c.line(hxp - 2, hyp + 2, tx, ty2, hx('feae34'))
    c.line(tx - 1, ty2 - 2, tx + 2, ty2 + 1, hx('feae34'))
    c.put(tx - 1, ty2 - 3, hx('feae34'))
    c.put(tx + 3, ty2 + 1, hx('feae34'))
    return finish(c)


def wings(c, x, y, span, h, col_ramp, flap, left=False):
    """Draw a membrane/feather wing. flap in [-1,1] (-1 up, 1 down)."""
    tipx = x - span
    tipy = y - h * (1 - flap)
    midy = y - h * 0.4 * (1 - flap)
    c.poly([(x, y), (tipx * 0.5 + x * 0.5, midy - 2), (tipx, tipy), (tipx + span * 0.3, y + 3 + flap * 2),
            (x - 2, y + 4)], col_ramp[1])
    c.line(x, y, tipx, tipy, col_ramp[2])
    c.line(x, y, tipx + span * 0.3, y + 2 + flap * 2, col_ramp[0])


def wyvern(anim, i, n):
    W, H = 50, 42
    c = Canvas(W, H)
    body = R('#5a8a3a')
    belly = R('#ead4aa')
    memb = R('#8a5a3a')
    flap = [-1, -0.3, 0.6, 0.2][i % 4]
    if anim == 'attack':
        flap = [-1, -1, 1, 0.5][i]
    cy = 20 + int(flap * 2)
    cx = 26 + ([0, -2, 5, 2][i] if anim == 'attack' else 0)
    # far wing
    wings(c, cx - 1, cy - 2, 18, 16, [shade(x, -0.25) for x in memb], flap)
    # tail
    c.thick_line(cx - 6, cy + 2, cx - 16, cy + 6, body[1], 3)
    c.thick_line(cx - 16, cy + 6, cx - 22, cy + 3, body[1], 2)
    c.poly([(cx - 22, cy + 1), (cx - 26, cy + 3), (cx - 22, cy + 5)], hx('c0cbdc'))
    # body
    c.ellipse(cx, cy + 2, 8, 5, None, body)
    c.hline(cx - 5, cx + 5, cy + 6, belly[2])
    # legs (talons)
    c.thick_line(cx - 2, cy + 6, cx - 3, cy + 12, body[1], 2)
    c.thick_line(cx + 3, cy + 6, cx + 3, cy + 12, body[2], 2)
    c.put(cx + 4, cy + 12, hx('e4e8ef'))
    # neck + head
    c.thick_line(cx + 6, cy, cx + 12, cy - 6, body[2], 3)
    c.ellipse(cx + 14, cy - 7, 4, 3, None, body)
    c.rect(cx + 16, cy - 7, 4, 2, body[2])
    c.put(cx + 15, cy - 9, hx('e43b44'))
    c.line(cx + 11, cy - 9, cx + 8, cy - 12, hx('c0cbdc'))
    if anim == 'attack' and i == 2:
        c.rect(cx + 16, cy - 5, 3, 1, hx('a22633'))
    # near wing
    wings(c, cx + 1, cy - 1, 20, 18, memb, flap)
    return finish(c)


def dragon(anim, i, n):
    W, H = 84, 66
    c = Canvas(W, H)
    body = R('#be2633')
    belly = R('#feae34')
    memb = R('#733e39')
    ground = H - 3
    phase = i / max(1, n) * math.tau
    flap = math.sin(phase) * 0.6 if anim != 'attack' else [-0.8, -0.8, 0.8, 0.4][i]
    bob = 1 if (anim == 'idle' and i in (1, 2)) else 0
    sw = math.sin(phase) * 3 if anim == 'move' else 0
    lunge = [0, -2, 5, 2][i] if anim == 'attack' else 0
    cx, cy = 40 + lunge, ground - 20 + bob
    # far wing
    wings(c, cx - 2, cy - 8, 32, 24, [shade(x, -0.3) for x in memb], flap)
    # tail
    tail = [(cx - 14, cy + 2), (cx - 24, cy + 8), (cx - 32, cy + 12), (cx - 38, cy + 10 + math.sin(phase) * 2)]
    for k in range(len(tail) - 1):
        c.thick_line(*tail[k], *tail[k + 1], body[1], 6 - k * 1.5)
    c.poly([(tail[-1][0], tail[-1][1] - 3), (tail[-1][0] - 6, tail[-1][1]), (tail[-1][0], tail[-1][1] + 3)], body[0])
    # far legs
    c.thick_line(cx + 8, cy + 6, cx + 9 - sw, ground, shade(body[1], -0.3), 5)
    c.thick_line(cx - 10, cy + 6, cx - 9 + sw, ground, shade(body[1], -0.3), 5)
    # body
    c.ellipse(cx, cy, 16, 10, None, body, light=(-0.3, -0.9))
    for x in range(cx - 10, cx + 12):
        c.put(x, cy + 8, belly[2])
        c.put(x, cy + 9, belly[1])
    # spikes on back
    for k in range(6):
        sx = cx - 12 + k * 5
        c.poly([(sx, cy - 8 + abs(k - 3) // 2), (sx + 2, cy - 13 + abs(k - 3) // 2), (sx + 4, cy - 8 + abs(k - 3) // 2)], belly[1])
    # near legs
    c.thick_line(cx + 10, cy + 6, cx + 11 + sw, ground, body[2], 5)
    c.thick_line(cx - 8, cy + 6, cx - 7 - sw, ground, body[2], 5)
    for lx in (cx + 11 + sw, cx - 7 - sw):
        c.hline(lx - 1, lx + 3, ground, hx('e4e8ef'))
    # neck
    nk = [(cx + 12, cy - 4), (cx + 18, cy - 12), (cx + 22, cy - 18)]
    for k in range(2):
        c.thick_line(*nk[k], *nk[k + 1], body[2], 7 - k)
    hx0, hy0 = cx + 26, cy - 21
    c.ellipse(hx0, hy0, 6, 5, None, body)
    c.rect(hx0 + 3, hy0 - 1, 7, 4, body[2])
    c.put(hx0 + 9, hy0 - 1, hx('181425'))
    # horns
    c.thick_line(hx0 - 3, hy0 - 4, hx0 - 9, hy0 - 10, hx('ead4aa'), 2)
    c.thick_line(hx0, hy0 - 4, hx0 - 4, hy0 - 11, hx('c0b59a'), 2)
    # eye
    c.put(hx0 + 2, hy0 - 2, hx('fee761'))
    c.put(hx0 + 3, hy0 - 2, hx('fee761'))
    if anim == 'attack' and i >= 2:
        c.rect(hx0 + 4, hy0 + 3, 6, 2, hx('a22633'))
        c.put(hx0 + 10, hy0 + 2, hx('feae34'))
        c.put(hx0 + 11, hy0 + 3, hx('fee761'))
    # near wing
    wings(c, cx + 2, cy - 7, 34, 26, memb, flap)
    return finish(c)


def phoenix(anim, i, n):
    W, H = 56, 46
    c = Canvas(W, H)
    body = R('#f77622')
    glow = R('#fee761')
    deep = R('#be2633')
    flap = [-1, -0.3, 0.7, 0.2][i % 4]
    if anim == 'attack':
        flap = [-1, -1, 1, 0.6][i]
    cx, cy = 28 + ([0, -2, 4, 1][i] if anim == 'attack' else 0), 20 + int(flap * 2)
    # flame tail streamers
    for k in range(4):
        ln = 14 + k * 3
        wob = math.sin(i * 1.3 + k) * 2
        c.thick_line(cx - 6, cy + 3, cx - 6 - ln, cy + 6 + k * 2 + wob, [deep[2], body[2], glow[2], body[3]][k], 2)
        c.disc(cx - 6 - ln, cy + 6 + k * 2 + wob, 1.5, glow[3])
    wings(c, cx - 1, cy - 2, 20, 16, [shade(x, -0.2) for x in deep], flap)
    c.ellipse(cx, cy + 1, 7, 5, None, body)
    c.ellipse(cx + 1, cy + 2, 4, 3, None, glow)
    # head + crest
    c.ellipse(cx + 8, cy - 5, 3.5, 3.2, None, body)
    c.poly([(cx + 11, cy - 5), (cx + 15, cy - 4), (cx + 11, cy - 3)], hx('feae34'))
    c.put(cx + 9, cy - 6, hx('181425'))
    for k in range(3):
        c.line(cx + 6 - k, cy - 8, cx + 3 - k * 2, cy - 13 + k, glow[2 + (k % 2)])
    # legs
    c.line(cx - 1, cy + 6, cx - 1, cy + 10, hx('feae34'))
    c.line(cx + 2, cy + 6, cx + 3, cy + 10, hx('feae34'))
    wings(c, cx + 1, cy - 1, 22, 18, body, flap)
    # wing fire tips
    return finish(c)


def hawk(anim, i, n):
    W, H = 20, 16
    c = Canvas(W, H)
    body = R('#8a5a3a')
    flap = [-1, -0.3, 0.7, 0.2][i % 4]
    cx, cy = 10, 8 + int(flap)
    wings(c, cx, cy - 1, 8, 7, [shade(x, -0.25) for x in body], flap)
    c.ellipse(cx, cy + 1, 4, 2.5, None, body)
    c.disc(cx + 4, cy - 1, 2, hx('ead4aa'))
    c.put(cx + 6, cy - 1, hx('feae34'))
    c.put(cx + 4, cy - 2, hx('181425'))
    c.thick_line(cx - 4, cy + 1, cx - 7, cy + 2, body[1], 2)
    wings(c, cx + 1, cy, 9, 8, body, flap)
    return finish(c)


def bat(anim, i, n):
    W, H = 16, 12
    c = Canvas(W, H)
    body = R('#3a3550')
    flap = [-1, 0, 1, 0][i % 4]
    cx, cy = 8, 6 + int(flap)
    for side in (-1, 1):
        tip = (cx + side * 7, cy - 3 * (1 - flap))
        c.poly([(cx, cy - 1), tip, (cx + side * 5, cy + 2), (cx + side * 2, cy + 1)], body[1])
    c.disc(cx, cy, 2.2, body[2])
    c.put(cx - 1, cy - 1, hx('e43b44'))
    c.put(cx + 1, cy - 1, hx('e43b44'))
    c.put(cx - 1, cy - 3, body[2])
    c.put(cx + 1, cy - 3, body[2])
    return finish(c)


def mimic(anim, i, n):
    W, H = 22, 20
    c = Canvas(W, H)
    wood = R('#b86f50')
    metal = R('#feae34')
    ground = H - 2
    open_ = 0
    hop = 0
    if anim == 'idle':
        open_ = [0, 1, 0, 0][i]
    elif anim == 'move':
        open_ = [1, 3, 2, 1][i % 4]
        hop = [0, 2, 3, 1][i % 4]
    elif anim == 'attack':
        open_ = [2, 6, 7, 3][i]
    by = ground - hop
    # base box
    c.rect(3, by - 7, 16, 8, wood[1])
    c.hline(3, 18, by - 7, wood[2])
    c.rect(3, by - 4, 16, 1, metal[1])
    # tongue / teeth when open
    if open_:
        c.rect(4, by - 8 - open_, 14, open_ + 1, hx('3e2731'))
        for k in range(5):
            c.put(5 + k * 3, by - 8, WHITE)
            c.put(6 + k * 3, by - 8 - open_, WHITE)
        c.thick_line(10, by - 8, 14 + open_, by - 7 - open_ // 2, hx('e43b44'), 2)
        c.put(8, by - 9 - open_ + 2, hx('fee761'))
    # lid
    ly = by - 8 - open_
    c.rect(3, ly - 4, 16, 4, wood[2])
    c.hline(3, 18, ly - 4, wood[3])
    c.rect(10, ly - 2, 2, 3, metal[2])
    c.vline(3, ly - 4, by, metal[1])
    c.vline(18, ly - 4, by, metal[1])
    return finish(c)


# ------------------------------------------------------------ registry
def B(params):
    return lambda a, i, n: biped(a, i, n, params)


def Q(params):
    return lambda a, i, n: quad(a, i, n, params)


MONSTERS = {
    # name: (draw_fn, (w,h), anims dict {anim: frames}, flyer)
    'slime': (slime, (20, 18), {'idle': 4, 'move': 6, 'attack': 4}, False),
    'wolf': (Q(WOLF), WOLF['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'tiger': (Q(TIGER), TIGER['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'bear': (Q(BEAR), BEAR['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'goblin': (B(GOBLIN), GOBLIN['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'ogre': (B(OGRE), OGRE['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'skeleton': (B(SKELETON), SKELETON['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'zombie': (B(ZOMBIE), ZOMBIE['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'treant': (treant, (44, 50), {'idle': 4, 'move': 6, 'attack': 4}, False),
    'dryad': (B(DRYAD), DRYAD['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'lizard': (B(LIZARD), LIZARD['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'mermaid': (mermaid, (30, 30), {'idle': 4, 'move': 6, 'attack': 4}, False),
    'vampire': (B(VAMPIRE), VAMPIRE['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'wyvern': (wyvern, (50, 42), {'idle': 4, 'move': 4, 'attack': 4}, True),
    'dragon': (dragon, (84, 66), {'idle': 4, 'move': 6, 'attack': 4}, False),
    'phoenix': (phoenix, (56, 46), {'idle': 4, 'move': 4, 'attack': 4}, True),
    'mimic': (mimic, (22, 20), {'idle': 4, 'move': 4, 'attack': 4}, False),
    'rabbit': (Q(RABBIT), RABBIT['size'], {'idle': 4, 'move': 4, 'attack': 4}, False),
    'deer': (Q(DEER), DEER['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'hawk': (hawk, (20, 16), {'idle': 4, 'move': 4, 'attack': 4}, True),
    'bat': (bat, (16, 12), {'idle': 4, 'move': 4, 'attack': 4}, True),
    'angel': (B(ANGEL), ANGEL['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
    'guardian': (B(GUARDIAN), GUARDIAN['size'], {'idle': 4, 'move': 6, 'attack': 4}, False),
}


def build_monster(name):
    fn, (w, h), anims, flyer = MONSTERS[name]
    sh = Sheet(name, w, h)
    for anim, n in anims.items():
        frames = [fn(anim, i, n) for i in range(n)]
        fps = 7 if anim == 'idle' else (10 if anim == 'move' else 11)
        sh.add(anim, frames, fps, anim != 'attack')
    hurt = fn('idle', 0, 4)
    sh.add('hurt', [hurt, hurt], 8, False)
    sh.add('death', death_frames(hurt), 8, False)
    return sh


def build_all(out_dir, manifest):
    os.makedirs(out_dir, exist_ok=True)
    for name in MONSTERS:
        sh = build_monster(name)
        meta = sh.save(os.path.join(out_dir, name + '.png'))
        meta['path'] = 'res://assets/sprites/monsters/' + name + '.png'
        meta['dirs'] = False
        meta['flyer'] = MONSTERS[name][3]
        manifest['mon_' + name] = meta
