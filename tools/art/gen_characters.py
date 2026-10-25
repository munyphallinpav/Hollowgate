"""Humanoid paper-doll generator: 5 player classes + NPCs, 3 views each."""
import math
from PIL import Image
from pix import Canvas, Sheet, hx, ramp, shade, mix, CLEAR

FW, FH = 32, 32

CLASSES = {
    'warrior': dict(skin='#e8b796', hair='#733e39', hair_style='short', top='#8b9bb4', trim='#a22633',
                    pants='#5a4a42', boots='#4a2f2a', belt='#3e2731', hat='helmet', hat_col='#c0cbdc',
                    plume='#e43b44', back='shield', sleeve='#8b9bb4', glove='#5a6988'),
    'ranger': dict(skin='#e8b796', hair='#b86f50', hair_style='short', top='#3e8948', trim='#b86f50',
                   pants='#5a4632', boots='#4a3326', belt='#733e39', hat='hood', hat_col='#2f6b3b',
                   back='quiver', sleeve='#8a5a3a', glove='#733e39', cape='#2f6b3b'),
    'assassin': dict(skin='#d6a07e', hair='#262b44', hair_style='short', top='#3a3550', trim='#be2633',
                     pants='#2b2840', boots='#1d1a2c', belt='#be2633', hat='cowl', hat_col='#2b2840',
                     mask='#2b2840', back=None, sleeve='#3a3550', glove='#1d1a2c', scarf='#be2633'),
    'mage': dict(skin='#f0c9a8', hair='#c0cbdc', hair_style='long', top='#2d4f9e', trim='#feae34',
                 pants='#2d4f9e', boots='#3a2a55', belt='#feae34', hat='wizard', hat_col='#3b3fa0',
                 back=None, sleeve='#2d4f9e', glove='#f0c9a8', robe=True),
    'priest': dict(skin='#f0c9a8', hair='#feae34', hair_style='long', top='#ece8e1', trim='#e6b422',
                   pants='#ece8e1', boots='#8a6b4a', belt='#3f7dd6', hat='hood_w', hat_col='#f4f1ea',
                   back=None, sleeve='#ece8e1', glove='#f0c9a8', robe=True),
}

NPCS = {
    'guard': dict(skin='#d6a07e', hair='#3e2731', hair_style='short', top='#5a6988', trim='#feae34',
                  pants='#3a4466', boots='#262b44', belt='#733e39', hat='helmet', hat_col='#8b9bb4',
                  plume='#124e89', back='shield', sleeve='#5a6988', glove='#3a4466'),
    'merchant': dict(skin='#e8b796', hair='#3e2731', hair_style='short', top='#b86f50', trim='#ead4aa',
                     pants='#5a4a42', boots='#3e2731', belt='#ead4aa', hat='cap', hat_col='#a22633',
                     back=None, sleeve='#b86f50', glove='#e8b796', apron='#ead4aa'),
    'smith': dict(skin='#c28569', hair='#181425', hair_style='bald', top='#5a4a42', trim='#3e2731',
                  pants='#3e2731', boots='#262b44', belt='#262b44', hat=None, hat_col=None, beard='#3e2731',
                  back=None, sleeve='#c28569', glove='#262b44', apron='#733e39'),
    'alchemist': dict(skin='#e8b796', hair='#68386c', hair_style='long', top='#68386c', trim='#63c74d',
                      pants='#3e2731', boots='#3e2731', belt='#63c74d', hat='wizard', hat_col='#4b2a50',
                      back=None, sleeve='#68386c', glove='#e8b796', robe=True),
    'sage': dict(skin='#f0c9a8', hair='#ffffff', hair_style='long', top='#124e89', trim='#2ce8f5',
                 pants='#124e89', boots='#262b44', belt='#2ce8f5', hat='wizard', hat_col='#193c3e', beard='#ffffff',
                 back=None, sleeve='#124e89', glove='#f0c9a8', robe=True),
    'cook': dict(skin='#e8b796', hair='#b86f50', hair_style='short', top='#ffffff', trim='#e43b44',
                 pants='#3a4466', boots='#3e2731', belt='#e43b44', hat='chef', hat_col='#ffffff',
                 back=None, sleeve='#ffffff', glove='#e8b796', apron='#f4f1ea'),
    'guildmaster': dict(skin='#c28569', hair='#8b9bb4', hair_style='short', top='#733e39', trim='#feae34',
                        pants='#3e2731', boots='#262b44', belt='#feae34', hat=None, hat_col=None, beard='#8b9bb4',
                        back=None, sleeve='#733e39', glove='#3e2731', cape='#a22633'),
    'collector': dict(skin='#e8b796', hair='#262b44', hair_style='long', top='#b55088', trim='#fee761',
                      pants='#3e2731', boots='#3e2731', belt='#fee761', hat='hood', hat_col='#68386c',
                      back=None, sleeve='#b55088', glove='#e8b796', robe=True),
    'architect': dict(skin='#d6a07e', hair='#5a4a42', hair_style='short', top='#c0cbdc', trim='#124e89',
                      pants='#3a4466', boots='#3e2731', belt='#124e89', hat='cap', hat_col='#feae34',
                      back=None, sleeve='#c0cbdc', glove='#d6a07e'),
    'villager': dict(skin='#e8b796', hair='#733e39', hair_style='long', top='#63c74d', trim='#ead4aa',
                     pants='#5a4a42', boots='#3e2731', belt='#ead4aa', hat=None, hat_col=None,
                     back=None, sleeve='#63c74d', glove='#e8b796'),
}


def R(c, n=4):
    return ramp(c, n)


class Pose:
    def __init__(self, bob=0, legs=(0, 0), arms=(0, 0), lean=0, arms_up=False, attack=None, hurt=False,
                 dash=False, kneel=0):
        self.bob, self.legs, self.arms, self.lean = bob, legs, arms, lean
        self.arms_up, self.attack, self.hurt, self.dash, self.kneel = arms_up, attack, hurt, dash, kneel


# ---------------------------------------------------------------- parts
def draw_legs_front(c, s, p, back=False):
    pr = R(s['pants'])
    br = R(s['boots'])
    top = 23 + p.bob
    for i, x0 in enumerate((12, 17)):
        lift = p.legs[i]
        bottom = 29 - lift
        for y in range(top, bottom + 1):
            for x in range(x0, x0 + 3):
                if y >= bottom - 1:
                    col = br[2] if x == x0 else br[1]
                    if y == bottom and x == x0 + 2:
                        col = br[0]
                else:
                    col = pr[2] if x == x0 else (pr[1] if x == x0 + 2 else pr[2])
                c.put(x, y, col)


def draw_torso_front(c, s, p, back=False):
    tr = R(s['top'])
    trim = R(s['trim'])
    y0 = 16 + p.bob
    robe = s.get('robe')
    h = 7
    for y in range(y0, y0 + h):
        for x in range(12, 20):
            col = tr[2]
            if x == 12:
                col = tr[3]
            if x == 19:
                col = tr[1]
            c.put(x, y, col)
    if robe:
        # robe skirt flares over the legs
        for y in range(y0 + h, 28):
            w = 4 + (y - (y0 + h)) // 3
            for x in range(16 - w, 16 + w):
                col = tr[2] if x > 16 - w else tr[3]
                if x == 16 + w - 1:
                    col = tr[1]
                c.put(x, y, col)
        if not back:
            c.vline(15, y0 + 1, 27, trim[2])
            c.vline(16, y0 + 1, 27, trim[1])
        yb = 27
        w = 4 + (yb - (y0 + h)) // 3
        c.hline(16 - w, 16 + w - 1, yb, trim[1])
    else:
        if not back:
            # collar / trim
            c.hline(14, 17, y0, trim[2])
            if s.get('apron'):
                ar = R(s['apron'])
                c.rect(13, y0 + 2, 6, h - 1, ar[2])
                c.vline(13, y0 + 2, y0 + h, ar[3])
            else:
                c.vline(15, y0 + 1, y0 + h - 2, trim[2])
    # belt
    br = R(s['belt'])
    c.hline(12, 19, y0 + 5, br[1])
    if not back:
        c.put(15, y0 + 5, br[3])
        c.put(16, y0 + 5, br[2])
    if s.get('cape') and back:
        cr = R(s['cape'])
        c.rect(11, y0, 10, 10, cr[1])
        c.vline(11, y0, y0 + 9, cr[2])
        c.hline(11, 20, y0 + 10, cr[0])


def draw_arms_front(c, s, p, back=False):
    sr = R(s['sleeve'])
    gr = R(s['glove'])
    skin = R(s['skin'])
    y0 = 16 + p.bob
    for i, x0 in enumerate((10, 20)):
        off = p.arms[i]
        if p.arms_up:
            # raised arms (casting)
            for y in range(y0 - 5, y0 + 2):
                c.put(x0, y, sr[2] if i == 0 else sr[1])
                c.put(x0 + 1, y, sr[1])
            c.rect(x0, y0 - 7, 2, 2, gr[2])
            continue
        for y in range(y0 + off, y0 + 5 + off):
            c.put(x0, y, sr[3] if i == 0 else sr[2])
            c.put(x0 + 1, y, sr[2] if i == 0 else sr[1])
        c.put(x0, y0 + 5 + off, gr[2])
        c.put(x0 + 1, y0 + 5 + off, gr[1])


def draw_head_front(c, s, p, back=False):
    sk = R(s['skin'])
    hr = R(s['hair'])
    y0 = 6 + p.bob
    # head block 10x10 with rounded corners
    for y in range(y0, y0 + 10):
        for x in range(11, 21):
            if (y in (y0, y0 + 9)) and x in (11, 20):
                continue
            col = sk[2]
            if x == 11:
                col = sk[3]
            if x == 20 or y == y0 + 9:
                col = sk[1]
            c.put(x, y, col)
    if not back:
        # eyes
        ey = y0 + 5
        if s.get('mask'):
            ey = y0 + 4
        c.put(13, ey, hx('262b44'))
        c.put(13, ey + 1, hx('262b44'))
        c.put(18, ey, hx('262b44'))
        c.put(18, ey + 1, hx('262b44'))
        c.put(12, ey + 2, mix(sk[2], hx('f6757a'), 0.4))
        c.put(19, ey + 2, mix(sk[2], hx('f6757a'), 0.4))
        if s.get('beard'):
            br = R(s['beard'])
            c.rect(12, y0 + 7, 8, 3, br[2])
            c.rect(13, y0 + 10, 6, 1, br[1])
            c.put(15, y0 + 7, sk[1])
            c.put(16, y0 + 7, sk[1])
    # hair
    style = s['hair_style']
    if style != 'bald':
        for x in range(11, 21):
            c.put(x, y0, hr[2] if x < 17 else hr[1])
            c.put(x, y0 + 1, hr[2] if x < 16 else hr[1])
        if not back:
            for x in (11, 12, 19, 20):
                c.put(x, y0 + 2, hr[1])
            c.put(11, y0 + 3, hr[1])
            c.put(20, y0 + 3, hr[0])
            c.put(14, y0 + 2, hr[2])
            c.put(15, y0 + 2, hr[2])
            c.put(17, y0 + 2, hr[3])
        else:
            for y in range(y0, y0 + 9):
                for x in range(11, 21):
                    c.put(x, y, hr[2] if x < 16 else hr[1])
            c.hline(12, 19, y0 + 2, hr[3])
        if style == 'long':
            for y in range(y0 + 3, y0 + 13):
                c.put(10, y, hr[1])
                c.put(21, y, hr[0])
                if back:
                    for x in range(11, 21):
                        c.put(x, y, hr[2] if x < 16 else hr[1])
            if not back:
                c.put(11, y0 + 4, hr[2])
                c.put(20, y0 + 4, hr[1])
    else:
        c.put(13, y0 + 1, sk[3])


def draw_hat_front(c, s, p, back=False):
    hat = s.get('hat')
    if not hat:
        return
    y0 = 6 + p.bob
    hr = R(s['hat_col'])
    if hat == 'helmet':
        for y in range(y0 - 1, y0 + 5):
            for x in range(10, 22):
                if y == y0 - 1 and x in (10, 11, 20, 21):
                    continue
                col = hr[2] if x < 15 else hr[1]
                if y == y0:
                    col = hr[3] if x < 17 else hr[2]
                c.put(x, y, col)
        # cheek guards
        for y in range(y0 + 5, y0 + 9):
            c.put(10, y, hr[1])
            c.put(11, y, hr[2])
            c.put(20, y, hr[1])
            c.put(21, y, hr[0])
        if back:
            for y in range(y0 + 5, y0 + 9):
                for x in range(10, 22):
                    c.put(x, y, hr[1] if x > 15 else hr[2])
        else:
            c.hline(12, 19, y0 + 4, hr[0])  # visor shadow
        pl = R(s.get('plume', '#e43b44'))
        for i in range(4):
            c.put(15, y0 - 2 - i, pl[2])
            c.put(16, y0 - 2 - i, pl[1])
        c.put(17, y0 - 5, pl[1])
        c.put(14, y0 - 4, pl[3])
    elif hat in ('hood', 'hood_w', 'cowl'):
        for y in range(y0 - 1, y0 + 11):
            for x in range(10, 22):
                inner = 12 <= x <= 19 and y >= y0 + 3
                if inner and not back:
                    continue
                if y == y0 - 1 and x in (10, 11, 20, 21):
                    continue
                col = hr[2] if x < 16 else hr[1]
                if y == y0 - 1 or (y == y0 and x < 15):
                    col = hr[3]
                c.put(x, y, col)
        if not back:
            c.hline(12, 19, y0 + 3, hr[0])
            if hat == 'hood_w':
                tr = R(s['trim'])
                c.hline(12, 19, y0 + 2, tr[2])
                c.put(15, y0 + 1, tr[3])
                c.put(16, y0 + 1, tr[2])
        if hat == 'cowl' and not back and s.get('mask'):
            mr = R(s['mask'])
            c.rect(12, y0 + 7, 8, 3, mr[1])
            c.hline(12, 19, y0 + 7, mr[2])
            if s.get('scarf'):
                sr = R(s['scarf'])
                c.hline(11, 20, y0 + 10, sr[2])
                c.put(19, y0 + 11, sr[1])
                c.put(20, y0 + 12, sr[1])
    elif hat == 'wizard':
        # brim
        for x in range(8, 24):
            c.put(x, y0 + 2, hr[1] if x > 15 else hr[2])
            if 9 <= x <= 22:
                c.put(x, y0 + 1, hr[2])
        # cone
        for i, y in enumerate(range(y0 + 1, y0 - 9, -1)):
            w = max(1, 5 - i // 2)
            sx = 16 + (1 if i > 6 else 0) + (1 if i > 8 else 0)
            for x in range(sx - w, sx + w):
                c.put(x, y, hr[2] if x < sx else hr[1])
            c.put(sx - w, y, hr[3])
        tr = R(s['trim'])
        c.hline(11, 20, y0 + 1, tr[2])
        if not back:
            c.put(15, y0 - 3, tr[3])
    elif hat == 'cap':
        for y in range(y0 - 1, y0 + 3):
            for x in range(11, 21):
                c.put(x, y, hr[2] if x < 16 else hr[1])
        c.hline(11, 22 if not back else 20, y0 + 2, hr[0])
    elif hat == 'chef':
        for y in range(y0 - 6, y0 + 2):
            for x in range(11, 21):
                c.put(x, y, hr[3] if x < 15 else hr[2])
        c.hline(11, 20, y0 + 1, hr[1])


def draw_back_item(c, s, p, view):
    item = s.get('back')
    y0 = 16 + p.bob
    if item == 'shield':
        sr = R('#8b9bb4')
        er = R(s['trim'])
        if view == 'back':
            for y in range(y0 - 1, y0 + 8):
                w = 4 if y < y0 + 5 else 4 - (y - (y0 + 4))
                for x in range(16 - w, 16 + w):
                    c.put(x, y, er[2] if abs(x - 15.5) < w - 1 else sr[1])
            c.vline(15, y0, y0 + 6, hx('feae34'))
            c.hline(13, 18, y0 + 2, hx('feae34'))
        elif view == 'front':
            # shield held on left arm
            for y in range(y0 + 1, y0 + 9):
                w = 3 if y < y0 + 6 else 3 - (y - (y0 + 5))
                for x in range(10 - w + 1, 10 + w):
                    c.put(x, y, er[2] if x > 8 else sr[2])
            c.vline(9, y0 + 2, y0 + 7, hx('feae34'))
    elif item == 'quiver':
        qr = R('#733e39')
        if view == 'back':
            for y in range(y0 - 3, y0 + 7):
                c.put(17, y + (1 if y > y0 + 2 else 0), qr[2])
                c.put(18, y + (1 if y > y0 + 2 else 0), qr[1])
            for i in range(3):
                c.put(16 + i, y0 - 4, hx('ead4aa'))
                c.put(16 + i, y0 - 5, hx('e43b44'))


# ---- side view (facing right)
def draw_side(c, s, p):
    sk = R(s['skin'])
    hr = R(s['hair'])
    tr = R(s['top'])
    pr = R(s['pants'])
    br = R(s['boots'])
    sr = R(s['sleeve'])
    gr = R(s['glove'])
    b = p.bob
    lean = p.lean
    robe = s.get('robe')
    # far arm (behind)
    if not p.arms_up:
        ax = 15 - p.arms[1] + lean
        c.thick_line(15 + lean, 17 + b, ax, 21 + b, shade(sr[1], -0.2), 2)
    # back item
    if s.get('back') == 'quiver':
        qr = R('#733e39')
        c.thick_line(12 + lean, 14 + b, 11 + lean, 22 + b, qr[2], 2)
        c.put(12 + lean, 13 + b, hx('e43b44'))
        c.put(13 + lean, 12 + b, hx('e43b44'))
    if s.get('cape'):
        cr = R(s['cape'])
        sway = 1 if p.legs[0] > 0 else 0
        c.poly([(13 + lean, 16 + b), (16 + lean, 16 + b), (13 - sway, 27), (10 - sway, 27)], cr[1])
    # legs (far leg first, darker)
    hipx, hipy = 15 + lean // 2, 23 + b
    for i, off in enumerate((-p.legs[0], p.legs[0])):
        dark = i == 0
        pc = shade(pr[2], -0.25) if dark else pr[2]
        bc = shade(br[2], -0.25) if dark else br[2]
        fx = hipx + off
        c.thick_line(hipx, hipy, fx, 27, pc, 3)
        c.rect(fx - 1, 27, 3, 2, bc)
        c.put(fx + 2, 28, bc)
    # torso
    y0 = 16 + b
    for y in range(y0, y0 + 7):
        for x in range(13, 19):
            col = tr[2]
            if x == 13:
                col = tr[1]
            if x == 18:
                col = tr[3]
            c.put(x + lean, y, col)
    if robe:
        for y in range(y0 + 7, 28):
            w = 3 + (y - (y0 + 7)) // 3
            for x in range(16 - w, 16 + w):
                c.put(x + lean // 2, y, tr[2] if x > 16 - w + 1 else tr[1])
        trim = R(s['trim'])
        c.hline(16 - 6 + lean // 2, 16 + 5 + lean // 2, 27, trim[1])
    if s.get('apron'):
        ar = R(s['apron'])
        c.rect(17 + lean, y0 + 2, 2, 7, ar[2])
    belt = R(s['belt'])
    c.hline(13 + lean, 18 + lean, y0 + 5, belt[1])
    c.put(18 + lean, y0 + 5, belt[3])
    if s.get('back') == 'shield':
        er = R(s['trim'])
        for y in range(y0, y0 + 8):
            c.put(12 + lean, y, er[1])
            c.put(11 + lean, y, R('#8b9bb4')[1])
    # head
    hy = 6 + b
    hx0 = 11 + lean
    for y in range(hy, hy + 10):
        for x in range(hx0, hx0 + 10):
            if y in (hy, hy + 9) and x in (hx0, hx0 + 9):
                continue
            col = sk[2]
            if x >= hx0 + 8:
                col = sk[3]
            if y == hy + 9:
                col = sk[1]
            c.put(x, y, col)
    # nose
    c.put(hx0 + 10, hy + 6, sk[2])
    # eye
    ey = hy + 5 if not s.get('mask') else hy + 4
    c.put(hx0 + 7, ey, hx('262b44'))
    c.put(hx0 + 7, ey + 1, hx('262b44'))
    c.put(hx0 + 8, ey + 2, mix(sk[2], hx('f6757a'), 0.4))
    if s.get('beard'):
        brd = R(s['beard'])
        c.rect(hx0 + 5, hy + 7, 5, 3, brd[2])
        c.rect(hx0 + 6, hy + 10, 3, 1, brd[1])
    # hair (back of head)
    if s['hair_style'] != 'bald':
        for y in range(hy, hy + 7):
            for x in range(hx0, hx0 + 6 - (1 if y > hy + 3 else 0)):
                c.put(x, y, hr[2] if y < hy + 2 else hr[1])
        c.hline(hx0 + 1, hx0 + 9, hy, hr[2])
        c.hline(hx0 + 2, hx0 + 8, hy + 1, hr[2])
        c.put(hx0 + 8, hy + 2, hr[1])
        c.put(hx0 + 3, hy + 1, hr[3])
        if s['hair_style'] == 'long':
            c.rect(hx0 - 1, hy + 3, 3, 9, hr[1])
            c.rect(hx0, hy + 3, 2, 8, hr[2])
    # hat
    hat = s.get('hat')
    if hat:
        hc = R(s['hat_col'])
        if hat == 'helmet':
            c.rect(hx0 - 1, hy - 1, 11, 6, hc[2])
            c.hline(hx0, hx0 + 8, hy - 1, hc[3])
            c.rect(hx0 - 1, hy + 5, 5, 4, hc[1])
            c.hline(hx0 + 4, hx0 + 9, hy + 4, hc[0])
            pl = R(s.get('plume', '#e43b44'))
            for i in range(5):
                c.put(hx0 + 4 - i, hy - 2 - (i // 2), pl[2])
                c.put(hx0 + 4 - i, hy - 1 - (i // 2), pl[1])
        elif hat in ('hood', 'hood_w', 'cowl'):
            c.rect(hx0 - 1, hy - 1, 11, 4, hc[2])
            c.rect(hx0 - 1, hy + 3, 6, 9, hc[1])
            c.hline(hx0, hx0 + 8, hy - 1, hc[3])
            c.vline(hx0 + 9, hy, hy + 3, hc[1])
            if hat == 'hood_w':
                tr2 = R(s['trim'])
                c.hline(hx0 + 4, hx0 + 9, hy + 2, tr2[2])
            if s.get('mask'):
                mr = R(s['mask'])
                c.rect(hx0 + 5, hy + 7, 5, 3, mr[1])
            if s.get('scarf'):
                scr = R(s['scarf'])
                c.hline(hx0 + 2, hx0 + 8, hy + 10, scr[2])
                c.put(hx0, hy + 11, scr[1])
                c.put(hx0 - 1, hy + 12, scr[1])
                c.put(hx0 - 2, hy + 12, scr[0])
        elif hat == 'wizard':
            c.hline(hx0 - 3, hx0 + 12, hy + 2, hc[1])
            c.hline(hx0 - 2, hx0 + 11, hy + 1, hc[2])
            for i in range(10):
                w = max(1, 5 - i // 2)
                cxh = hx0 + 5 - (i // 3)
                c.hline(cxh - w, cxh + w - 1, hy - i, hc[2] if i % 3 else hc[3])
            tr2 = R(s['trim'])
            c.hline(hx0, hx0 + 9, hy + 1, tr2[2])
        elif hat == 'cap':
            c.rect(hx0, hy - 1, 10, 3, hc[2])
            c.hline(hx0 + 6, hx0 + 12, hy + 2, hc[0])
        elif hat == 'chef':
            c.rect(hx0 + 1, hy - 6, 9, 7, hc[3])
            c.hline(hx0 + 1, hx0 + 9, hy + 1, hc[1])
    # near arm
    if p.arms_up:
        c.thick_line(16 + lean, 17 + b, 20 + lean, 11 + b, sr[2], 2)
        c.rect(20 + lean, 9 + b, 2, 2, gr[2])
    elif p.attack is not None:
        ext = [1, 4, 5, 2][p.attack % 4]
        c.thick_line(16 + lean, 17 + b, 16 + ext + lean, 20 + b - (1 if ext > 3 else 0), sr[3], 2)
        c.rect(16 + ext + lean, 19 + b - (1 if ext > 3 else 0), 2, 2, gr[2])
    else:
        ax = 16 + p.arms[0] + lean
        c.thick_line(16 + lean, 17 + b, ax, 21 + b, sr[3], 2)
        c.rect(ax, 21 + b, 2, 1, gr[2])


def draw_view(spec, view, pose):
    c = Canvas(FW, FH)
    if view == 'side':
        draw_side(c, spec, pose)
    else:
        back = view == 'up'
        if back:
            draw_legs_front(c, spec, pose, True)
            draw_arms_front(c, spec, pose, True)
            draw_torso_front(c, spec, pose, True)
            draw_head_front(c, spec, pose, True)
            draw_hat_front(c, spec, pose, True)
            draw_back_item(c, spec, pose, 'back')
        else:
            draw_back_item(c, spec, pose, 'behind')
            draw_legs_front(c, spec, pose)
            draw_torso_front(c, spec, pose)
            draw_arms_front(c, spec, pose)
            draw_head_front(c, spec, pose)
            draw_hat_front(c, spec, pose)
            draw_back_item(c, spec, pose, 'front')
    c.outline()
    return c


def rotate_frame(c, angle, dy=0, alpha=255):
    img = c.img.rotate(angle, resample=Image.NEAREST, center=(16, 29), translate=(0, dy))
    if alpha < 255:
        a = img.split()[3].point(lambda v: v * alpha // 255)
        img.putalpha(a)
    out = Canvas(FW, FH)
    out.img = img
    out.px = img.load()
    return out


def build_humanoid(spec):
    sheet = Sheet('h', FW, FH)
    for view in ('down', 'up', 'side'):
        side = view == 'side'
        # idle 4
        sheet.add('idle_' + view, [draw_view(spec, view, Pose(bob=b)) for b in (0, 0, 1, 1)], 5)
        # walk 6
        walk = []
        if side:
            legs = [2, 1, -1, -2, -1, 1]
            for i, l in enumerate(legs):
                walk.append(draw_view(spec, view, Pose(bob=1 if i in (1, 4) else 0, legs=(l, l), arms=(-l, l))))
        else:
            pat = [(1, 0), (1, 0), (0, 0), (0, 1), (0, 1), (0, 0)]
            for i, (a, b2) in enumerate(pat):
                walk.append(draw_view(spec, view, Pose(bob=1 if i in (2, 5) else 0, legs=(a, b2),
                                                       arms=(1 if a else -1 if b2 else 0, 1 if b2 else -1 if a else 0))))
        sheet.add('walk_' + view, walk, 10)
        # attack 4
        if side:
            att = [draw_view(spec, view, Pose(lean=l, attack=i, legs=(1, 1))) for i, l in enumerate((-1, 1, 2, 0))]
        else:
            att = [draw_view(spec, view, Pose(bob=b, arms=a)) for b, a in ((0, (0, -2)), (1, (0, 1)), (1, (0, 2)), (0, (0, 0)))]
        sheet.add('attack_' + view, att, 12, False)
        # cast 4
        cast = [draw_view(spec, view, Pose(bob=b, arms_up=u)) for b, u in ((0, False), (1, True), (0, True), (1, True))]
        sheet.add('cast_' + view, cast, 8, False)
        # dash 3
        if side:
            dash = [draw_view(spec, view, Pose(lean=2, legs=(2, 2), arms=(-2, 2))) for _ in range(3)]
        else:
            dash = [draw_view(spec, view, Pose(bob=1, legs=(1, 1))) for _ in range(3)]
        sheet.add('dash_' + view, dash, 12, False)
        # hurt 2
        hurt = [draw_view(spec, view, Pose(lean=-2 if side else 0, bob=1, legs=(0, 0))) for _ in range(2)]
        sheet.add('hurt_' + view, hurt, 8, False)
        # death 6
        base = draw_view(spec, view, Pose(bob=1))
        d = [base, rotate_frame(base, 0, 2), rotate_frame(base, -30, 1), rotate_frame(base, -60, 1),
             rotate_frame(base, -90, 0), rotate_frame(base, -90, 0, 160)]
        if view == 'side':
            d = [base, rotate_frame(base, 0, 2), rotate_frame(base, 30, 1), rotate_frame(base, 60, 1),
                 rotate_frame(base, 90, 0), rotate_frame(base, 90, 0, 160)]
        sheet.add('death_' + view, d, 8, False)
    return sheet


def build_all(out_dir, manifest):
    import os
    os.makedirs(out_dir, exist_ok=True)
    for name, spec in list(CLASSES.items()) + list(NPCS.items()):
        sh = build_humanoid(spec)
        path = os.path.join(out_dir, name + '.png')
        meta = sh.save(path)
        meta['path'] = 'res://assets/sprites/characters/' + name + '.png'
        meta['dirs'] = True
        manifest['char_' + name] = meta
