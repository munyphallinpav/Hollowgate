"""Ground tiles (16x16) + fringe overlays + world objects (trees, rocks, ores, buildings, dungeon props)."""
import math
import os
import random
from PIL import Image
from pix import Canvas, Sheet, hx, ramp, shade, mix, CLEAR, rng

T = 16


def R(c, n=4):
    return ramp(c, n)


def noise_tile(seed, base, spots=(), density=0.18, light_rows=False):
    r = rng(seed)
    c = Canvas(T, T)
    rr = R(base, 5)
    for y in range(T):
        for x in range(T):
            v = r.random()
            col = rr[3]
            if v < density * 0.5:
                col = rr[2]
            elif v < density:
                col = rr[4]
            c.put(x, y, col)
    for (col, count, size) in spots:
        for _ in range(count):
            x, y = r.randrange(T), r.randrange(T)
            for k in range(size):
                c.put((x + k) % T, y, hx(col) if isinstance(col, str) else col)
    return c


def grass_tile(seed, base='#5aa04a'):
    r = rng(seed)
    c = noise_tile(seed, base, density=0.15)
    rr = R(base, 5)
    for _ in range(6):
        x, y = r.randrange(T), r.randrange(1, T)
        c.put(x, y, rr[1])
        c.put(x, y - 1, rr[4])
    return c


def stone_floor(seed, base, crack='#000000', slab=True):
    r = rng(seed)
    c = Canvas(T, T)
    rr = R(base, 5)
    for y in range(T):
        for x in range(T):
            col = rr[3] if r.random() > 0.12 else rr[2]
            c.put(x, y, col)
    if slab:
        # slab seams
        c.hline(0, 15, 0, rr[1])
        c.vline(0, 0, 15, rr[1])
        off = 8 if (seed % 2) else 0
        c.vline(off, 0, 7, rr[1])
        c.hline(0, 15, 8, rr[1])
        c.vline((off + 8) % 16, 8, 15, rr[1])
        for x in range(1, 16):
            c.put(x, 1, rr[4])
            c.put(x, 9, rr[4])
    for _ in range(2):
        x, y = r.randrange(T), r.randrange(T)
        c.put(x, y, rr[0])
    return c


def water_tile(seed, base='#2f7fd0', deep=False):
    r = rng(seed)
    c = Canvas(T, T)
    rr = R(base, 5)
    for y in range(T):
        for x in range(T):
            c.put(x, y, rr[2] if deep else rr[3])
    for _ in range(3):
        x, y = r.randrange(T - 4), r.randrange(T)
        c.hline(x, x + 3, y, rr[4])
        c.put(x + 1, y + 1, rr[3])
    return c


def lava_tile(seed):
    r = rng(seed)
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            v = math.sin((x + seed * 3) * 0.7) + math.cos((y + seed) * 0.8) + r.random() * 0.8
            col = hx('be2633') if v < 0.2 else (hx('f77622') if v < 1.2 else hx('feae34'))
            c.put(x, y, col)
    for _ in range(3):
        c.put(r.randrange(T), r.randrange(T), hx('fee761'))
    return c


def basalt_tile(seed):
    r = rng(seed)
    c = Canvas(T, T)
    rr = R('#4a3436', 5)
    for y in range(T):
        for x in range(T):
            v = r.random()
            c.put(x, y, rr[3] if v > 0.2 else (rr[2] if v > 0.06 else rr[4]))
    # cracks with a faint glow
    x, y = r.randrange(T), r.randrange(T)
    for i in range(7):
        c.put(x % T, y % T, hx('7a2a1a') if i % 3 else hx('c8501a'))
        x += r.choice([-1, 0, 1])
        y += 1
    for _ in range(2):
        c.put(r.randrange(T), r.randrange(T), hx('2a1c22'))
    return c


def cobble_tile(seed, base='#8f8f9c'):
    r = rng(seed)
    c = Canvas(T, T)
    rr = R(base, 5)
    c.rect(0, 0, T, T, rr[0])
    for row in range(4):
        off = 2 if row % 2 else 0
        for col in range(4):
            cx = col * 4 + off + 1.5 + r.uniform(-0.4, 0.4)
            cy = row * 4 + 1.5 + r.uniform(-0.3, 0.3)
            shade_i = r.choice([2, 3, 3, 4])
            c.ellipse(cx, cy, 1.9, 1.6, rr[shade_i])
            c.put(int(cx) - 1, int(cy) - 1, rr[4])
    return c


def lava_tile2(seed):
    r = rng(seed)
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            v = math.sin((x * 0.9 + seed) * 0.8 + math.sin(y * 0.5 + seed) * 1.5) + math.cos((y + seed * 2) * 0.7) + r.random() * 0.6
            col = hx('a22633') if v < -0.3 else (hx('e43b44') if v < 0.5 else (hx('f77622') if v < 1.3 else hx('feae34')))
            c.put(x, y, col)
    for _ in range(4):
        c.put(r.randrange(T), r.randrange(T), hx('fee761'))
    return c


def pit_tile(edge=False, base='#0c0a14'):
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            c.put(x, y, hx(base))
    if edge:
        # cliff face visible below a floor tile
        fr = R('#4a3f5c')
        for y in range(0, 7):
            for x in range(T):
                col = fr[2] if (x + y) % 5 else fr[1]
                if y > 4:
                    col = mix(fr[0], hx(base), (y - 4) / 3)
                c.put(x, y, col)
    return c


def wall_tiles(style):
    """Returns (top, front) tiles for a wall style."""
    styles = {
        'stone': ('#4a4d5c', '#6b6f80', 'brick'),
        'brick': ('#5e3428', '#8a4b3a', 'brick'),
        'wood': ('#5e3c26', '#8a5a3a', 'plank'),
        'crystal': ('#2f6f8a', '#5fb6d6', 'crystal'),
        'obsidian': ('#241d30', '#3a2f4a', 'brick'),
        'hedge': ('#2a5c34', '#3e8948', 'leaf'),
        'coral': ('#a8705a', '#e0a888', 'brick'),
        'mushroom': ('#583670', '#8a5aa8', 'cap'),
        'town': ('#6e6e7c', '#9a9aa6', 'brick'),
        'cave': ('#2e283a', '#5a5068', 'rock'),
    }
    top_c, front_c, pat = styles[style]
    tr = R(top_c, 5)
    fr = R(front_c, 5)
    top = Canvas(T, T)
    r = rng(hash(style) % 1000)
    for y in range(T):
        for x in range(T):
            col = tr[2] if r.random() > 0.15 else tr[1]
            top.put(x, y, col)
    top.hline(0, 15, 0, tr[3])
    top.hline(0, 15, 15, tr[0])
    if pat == 'leaf':
        for _ in range(14):
            top.put(r.randrange(T), r.randrange(T), tr[4])
    front = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            front.put(x, y, fr[3])
    # top lip of the wall front
    front.hline(0, 15, 0, tr[1])
    front.hline(0, 15, 1, tr[2])
    if pat == 'brick':
        for row, yy in enumerate(range(3, 16, 4)):
            front.hline(0, 15, yy, fr[1])
            off = 0 if row % 2 else 4
            for xx in range(off, 16, 8):
                front.vline(xx, yy - 3, yy - 1, fr[1])
            for xx in range(0, 16):
                front.put(xx, yy - 3, fr[4] if (xx + off) % 8 else fr[2])
    elif pat == 'plank':
        for xx in range(0, 16, 4):
            front.vline(xx, 2, 15, fr[1])
            front.vline(xx + 1, 2, 15, fr[4])
        front.put(2, 5, fr[0])
        front.put(10, 11, fr[0])
    elif pat == 'crystal':
        for k in range(3):
            x0 = 2 + k * 5
            front.poly([(x0, 15), (x0 + 2, 4 + k), (x0 + 4, 15)], fr[4])
            front.vline(x0 + 2, 6 + k, 14, hx('d6f3ff'))
    elif pat == 'leaf':
        for _ in range(26):
            front.put(r.randrange(T), r.randrange(2, T), fr[r.choice([1, 2, 4])])
    elif pat == 'cap':
        for k in range(3):
            front.disc(3 + k * 5, 7 + (k % 2) * 4, 2, fr[4])
    elif pat == 'rock':
        for _ in range(5):
            x, y = r.randrange(T), r.randrange(3, T)
            front.disc(x, y, 2, fr[r.choice([2, 4])])
    front.hline(0, 15, 15, fr[0])
    return top, front


# ------------------------------------------------------------ fringe masks
def fringe_masks():
    """Alpha masks for 8 neighbor directions (where the neighbor's terrain bleeds in)."""
    r = rng(77)
    masks = {}
    depth = [3 + int(1.5 * math.sin(i * 0.9) + r.random() * 1.5) for i in range(T)]

    def mk(fn):
        m = [[0] * T for _ in range(T)]
        for y in range(T):
            for x in range(T):
                m[y][x] = 1 if fn(x, y) else 0
        return m
    masks['n'] = mk(lambda x, y: y < depth[x])
    masks['s'] = mk(lambda x, y: (T - 1 - y) < depth[(x + 5) % T])
    masks['w'] = mk(lambda x, y: x < depth[(y + 3) % T])
    masks['e'] = mk(lambda x, y: (T - 1 - x) < depth[(y + 9) % T])
    rad = 4.5
    masks['nw'] = mk(lambda x, y: (x + 0.5) ** 2 + (y + 0.5) ** 2 < rad * rad)
    masks['ne'] = mk(lambda x, y: (T - x - 0.5) ** 2 + (y + 0.5) ** 2 < rad * rad)
    masks['sw'] = mk(lambda x, y: (x + 0.5) ** 2 + (T - y - 0.5) ** 2 < rad * rad)
    masks['se'] = mk(lambda x, y: (T - x - 0.5) ** 2 + (T - y - 0.5) ** 2 < rad * rad)
    return masks


def apply_mask(tile, mask, edge_dark=None):
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            if mask[y][x]:
                c.put(x, y, tile.get(x, y))
    # darker rim at the mask border for readability
    if edge_dark is not None:
        for y in range(T):
            for x in range(T):
                if mask[y][x]:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < T and 0 <= yy < T and not mask[yy][xx]:
                            c.put(x, y, shade(tile.get(x, y), edge_dark))
                            break
    return c


# ------------------------------------------------------------ terrain set
TERRAINS = {
    # name: (generator, priority)  higher priority bleeds over lower
    'deep_water': (lambda s: water_tile(s, '#2560b0', True), 0),
    'water': (lambda s: water_tile(s, '#3a8ad8'), 1),
    'lava': (lambda s: lava_tile2(s), 2),
    'swamp_water': (lambda s: water_tile(s, '#4f6b4a'), 1),
    'sand': (lambda s: noise_tile(s, '#e4c98a', [('#cdae6e', 3, 1), ('#f4e3b0', 3, 1)]), 3),
    'desert': (lambda s: noise_tile(s, '#d9a75a', [('#b9864a', 4, 2)]), 4),
    'ash': (lambda s: noise_tile(s, '#4a4048', [('#2e2630', 4, 1), ('#be2633', 1, 1)]), 5),
    'snow': (lambda s: noise_tile(s, '#e6eef6', [('#c0cbdc', 4, 2)], 0.1), 6),
    'swamp': (lambda s: grass_tile(s, '#5b7a45'), 7),
    'mushroom': (lambda s: noise_tile(s, '#6e5a8a', [('#9a7ab8', 4, 1), ('#4a3a66', 3, 2)]), 8),
    'grass': (lambda s: grass_tile(s, '#5aa04a'), 9),
    'forest': (lambda s: grass_tile(s, '#3f7f3c'), 10),
    'dirt': (lambda s: noise_tile(s, '#9a7050', [('#7a5640', 4, 1), ('#b88a62', 3, 1)]), 11),
    'cobble': (lambda s: cobble_tile(s, '#8f8f9c'), 12),
    'plaza': (lambda s: stone_floor(s, '#b8b0a0'), 13),
    # dungeon floors
    'df_cave': (lambda s: stone_floor(s, '#7a6e72', slab=False), 20),
    'df_lava': (lambda s: basalt_tile(s), 20),
    'df_forest': (lambda s: grass_tile(s, '#4a7a3a'), 20),
    'df_mushroom': (lambda s: noise_tile(s, '#5a4a72', [('#b088d0', 3, 1), ('#3a2e52', 4, 2)]), 20),
    'df_grass': (lambda s: grass_tile(s, '#6aae52'), 20),
    'df_beach': (lambda s: noise_tile(s, '#e8d29a', [('#ccb37a', 3, 1), ('#ffffff', 1, 1)]), 20),
    'df_stone': (lambda s: stone_floor(s, '#7a7a88'), 20),
}

DECOS = {}


def deco_tiles():
    out = {}
    r = rng(5)
    # flowers
    for k, col in enumerate(('#e43b44', '#fee761', '#ffffff', '#b55088')):
        c = Canvas(T, T)
        for _ in range(3):
            x, y = r.randrange(2, 14), r.randrange(2, 14)
            c.put(x, y + 1, hx('265c42'))
            c.put(x, y, hx(col))
            c.put(x + 1, y, shade(hx(col), -0.3))
        out['flower%d' % k] = c
    for k in range(2):
        c = Canvas(T, T)
        for _ in range(4):
            x, y = r.randrange(1, 15), r.randrange(3, 15)
            c.put(x, y, hx('2f6b3b'))
            c.put(x, y - 1, hx('3e8948'))
            c.put(x + 1, y, hx('3e8948'))
            c.put(x - 1, y - 2, hx('63c74d'))
        out['tuft%d' % k] = c
    c = Canvas(T, T)
    for _ in range(4):
        x, y = r.randrange(1, 15), r.randrange(1, 15)
        c.put(x, y, hx('8b9bb4'))
        c.put(x + 1, y, hx('5a6988'))
    out['pebble'] = c
    c = Canvas(T, T)
    c.line(4, 9, 10, 7, hx('e4e8ef'))
    c.disc(4, 9, 1.2, hx('e4e8ef'))
    c.disc(10, 7, 1.2, hx('c0cbdc'))
    out['bone'] = c
    c = Canvas(T, T)
    c.disc(6, 8, 2, hx('f6757a'))
    c.put(6, 8, hx('ffffff'))
    c.disc(11, 11, 1.5, hx('ead4aa'))
    out['shell'] = c
    for k, col in enumerate(('#e43b44', '#9b5de5')):
        c = Canvas(T, T)
        for _ in range(2):
            x, y = r.randrange(3, 13), r.randrange(5, 14)
            c.vline(x, y - 1, y, hx('ead4aa'))
            c.hline(x - 1, x + 1, y - 2, hx(col))
            c.put(x, y - 3, hx(col))
            c.put(x - 1, y - 2, hx('ffffff'))
        out['shroom%d' % k] = c
    c = Canvas(T, T)
    for _ in range(3):
        x, y = r.randrange(2, 14), r.randrange(2, 14)
        c.put(x, y, hx('6b6f80'))
        c.put(x + 1, y, hx('4f5263'))
    out['rubble'] = c
    c = Canvas(T, T)
    for _ in range(3):
        x, y = r.randrange(2, 14), r.randrange(2, 14)
        c.put(x, y, hx('fee761'))
    out['ember'] = c
    c = Canvas(T, T)
    for x in range(3, 13):
        c.put(x, 8 + int(math.sin(x) * 1.2), hx('e4e8ef'))
    out['snowdrift'] = c
    return out


def build_tiles(out_dir, manifest):
    names = []
    images = []
    for name, (gen, prio) in TERRAINS.items():
        for v in range(4):
            names.append('%s_%d' % (name, v))
            images.append(gen(v * 31 + len(name)))
    for k, (name, img) in enumerate(deco_tiles().items()):
        names.append('deco_' + name)
        images.append(img)
    for style in ('stone', 'brick', 'wood', 'crystal', 'obsidian', 'hedge', 'coral', 'mushroom', 'town', 'cave'):
        top, front = wall_tiles(style)
        names += ['wall_%s_top' % style, 'wall_%s_front' % style]
        images += [top, front]
    names += ['pit', 'pit_edge']
    images += [pit_tile(False), pit_tile(True)]
    # fringes for every terrain (8 dirs)
    masks = fringe_masks()
    for name, (gen, prio) in TERRAINS.items():
        if name.startswith('df_'):
            continue
        base = gen(3)
        for d, m in masks.items():
            names.append('fr_%s_%s' % (name, d))
            images.append(apply_mask(base, m, -0.18 if name not in ('water', 'deep_water', 'swamp_water') else None))
    cols = 16
    rows = (len(images) + cols - 1) // cols
    atlas = Image.new('RGBA', (cols * T, rows * T), CLEAR)
    idx = {}
    for i, (n, im) in enumerate(zip(names, images)):
        atlas.alpha_composite(im.img, ((i % cols) * T, (i // cols) * T))
        idx[n] = [i % cols, i // cols]
    atlas.save(os.path.join(out_dir, 'tiles.png'))
    manifest['tiles'] = {'path': 'res://assets/sprites/world/tiles.png', 'tile': T, 'index': idx,
                         'priority': {n: p for n, (g, p) in TERRAINS.items()}}


# ------------------------------------------------------------ objects
def tree(kind, seed):
    r = rng(seed)
    if kind == 'oak':
        c = Canvas(32, 44)
        bark = R('#733e39')
        leaf = R('#3e8948', 5)
        c.rect(14, 26, 5, 16, bark[2])
        c.vline(14, 26, 41, bark[3])
        c.vline(18, 26, 41, bark[1])
        c.hline(12, 20, 42, bark[1])
        for k in range(10):
            ang = k / 10 * math.tau
            c.disc(16 + math.cos(ang) * 8, 18 + math.sin(ang) * 6, 6, leaf[1 + k % 2])
        c.ellipse(16, 17, 11, 10, None, leaf[1:], light=(-0.5, -0.8))
        for _ in range(8):
            c.put(r.randrange(8, 22), r.randrange(9, 22), leaf[4])
    elif kind == 'big_oak':
        c = Canvas(40, 56)
        bark = R('#5a3a2e')
        leaf = R('#2f6b3b', 5)
        c.rect(17, 32, 7, 22, bark[2])
        c.vline(17, 32, 53, bark[3])
        c.vline(23, 32, 53, bark[1])
        c.line(16, 53, 13, 54, bark[1])
        c.line(24, 53, 27, 54, bark[1])
        for k in range(12):
            ang = k / 12 * math.tau
            c.disc(20 + math.cos(ang) * 11, 22 + math.sin(ang) * 8, 7, leaf[1 + k % 2])
        c.ellipse(20, 21, 14, 12, None, leaf[1:], light=(-0.5, -0.8))
        for _ in range(12):
            c.put(r.randrange(10, 30), r.randrange(11, 30), leaf[4])
    elif kind == 'pine':
        c = Canvas(28, 48)
        bark = R('#5a3a2e')
        leaf = R('#265c42', 5)
        c.rect(12, 38, 4, 9, bark[2])
        for k in range(4):
            top = 4 + k * 8
            w = 5 + k * 3
            c.poly([(14, top), (14 - w, top + 12), (14 + w, top + 12)], leaf[2])
            c.poly([(14, top), (14 + w, top + 12), (16, top + 12)], leaf[1])
            c.hline(14 - w + 1, 14 + w - 1, top + 12, leaf[0])
        for _ in range(5):
            c.put(r.randrange(6, 22), r.randrange(10, 40), hx('e6eef6'))
    elif kind == 'snow_pine':
        c = tree('pine', seed)
        for y in range(c.h):
            for x in range(c.w):
                p = c.get(x, y)
                if p[3] and p[1] > p[0] and (y % 8) < 3:
                    c.put(x, y, hx('e6eef6'))
        return c
    elif kind == 'palm':
        c = Canvas(32, 44)
        bark = R('#b86f50')
        leaf = R('#3e8948', 5)
        for y in range(18, 43):
            x = 15 + int(math.sin(y * 0.15) * 2)
            c.hline(x, x + 2, y, bark[2] if y % 3 else bark[1])
        for ang in (-2.6, -2.0, -1.2, -0.6, 0.0, 0.5):
            ex, ey = 16 + math.cos(ang) * 13, 18 + math.sin(ang) * 7 + 4
            c.thick_line(16, 17, ex, ey, leaf[2], 2)
            c.line(16, 18, ex, ey + 2, leaf[1])
        c.disc(15, 19, 1.5, hx('733e39'))
        c.disc(18, 19, 1.5, hx('733e39'))
    elif kind == 'mushroom_tree':
        c = Canvas(32, 44)
        stem = R('#ead4aa')
        cap = R('#9b5de5', 5)
        c.rect(13, 22, 6, 20, stem[2])
        c.vline(13, 22, 41, stem[3])
        c.vline(18, 22, 41, stem[1])
        c.ellipse(16, 18, 14, 9, None, cap[1:], light=(-0.4, -0.9))
        c.hline(3, 29, 22, cap[0])
        for k in range(5):
            c.disc(8 + k * 4, 13 + (k % 2) * 4, 1.5, hx('f4f1ea'))
    elif kind == 'dead_tree':
        c = Canvas(30, 42)
        bark = R('#5a4a42')
        c.rect(13, 16, 4, 25, bark[2])
        c.vline(13, 16, 40, bark[3])
        c.thick_line(15, 22, 6, 10, bark[2], 2)
        c.thick_line(15, 18, 24, 6, bark[1], 2)
        c.line(6, 10, 3, 9, bark[1])
        c.line(24, 6, 27, 3, bark[1])
        c.line(15, 16, 15, 4, bark[2])
    elif kind == 'cactus':
        c = Canvas(20, 32)
        g = R('#3e8948')
        c.rect(8, 6, 5, 25, g[2])
        c.vline(8, 6, 30, g[3])
        c.vline(12, 6, 30, g[1])
        c.rect(3, 12, 3, 8, g[2])
        c.hline(3, 8, 19, g[2])
        c.rect(15, 9, 3, 7, g[2])
        c.hline(12, 17, 15, g[2])
        c.put(10, 5, hx('e43b44'))
    elif kind == 'swamp_tree':
        c = tree('dead_tree', seed)
        moss = R('#5b7a45')
        for k in range(6):
            x = 5 + k * 4
            c.vline(x, 8 + k % 3, 14 + k % 4, moss[2])
        return c
    elif kind == 'crystal_tree':
        c = Canvas(28, 40)
        cr = R('#2ce8f5', 5)
        for k, (x, h) in enumerate(((8, 20), (14, 30), (20, 18))):
            c.poly([(x - 3, 38), (x, 38 - h), (x + 3, 38)], cr[2 + k % 2])
            c.vline(x, 38 - h + 3, 37, cr[4])
    c.outline()
    return c


def rock(kind, seed, size=1.0, ore=None):
    r = rng(seed)
    w = int(20 * size)
    h = int(16 * size)
    c = Canvas(w + 4, h + 4)
    rr = R('#7a7a88' if kind != 'dark' else '#4a4048', 5)
    c.ellipse(w / 2 + 2, h / 2 + 3, w / 2, h / 2.2, None, rr[1:], light=(-0.5, -0.9))
    c.ellipse(w / 2 - 1, h / 2 + 1, w / 3, h / 3, None, rr[2:], light=(-0.5, -0.9))
    if ore:
        oc = R(ore, 4)
        for _ in range(int(6 * size)):
            x = r.randrange(4, w)
            y = r.randrange(4, h)
            if c.get(x, y)[3]:
                c.put(x, y, oc[2])
                c.put(x + 1, y, oc[3])
                c.put(x, y + 1, oc[1])
    c.outline()
    return c


def bush(seed, berry=None):
    r = rng(seed)
    c = Canvas(20, 16)
    lr = R('#3e8948', 5)
    for k in range(5):
        c.disc(5 + k * 2.5, 9 - (k % 2) * 2, 4, lr[1 + k % 3])
    if berry:
        for _ in range(4):
            c.put(r.randrange(4, 16), r.randrange(5, 12), hx(berry))
    c.outline()
    return c


def building(kind):
    """Town buildings: 2.5D with front wall + roof."""
    specs = {
        'guild': (112, 96, '#8a5a3a', '#a22633', 'guild'),
        'gear': (64, 64, '#b86f50', '#3a4466', 'sword'),
        'blacksmith': (64, 64, '#5a4a42', '#3e2731', 'anvil'),
        'potion': (64, 64, '#c28569', '#3e8948', 'flask'),
        'artifact': (64, 64, '#8b9bb4', '#68386c', 'gem'),
        'magic': (64, 64, '#5a6988', '#124e89', 'star'),
        'food': (64, 64, '#e4a672', '#be4a2f', 'bread'),
        'house': (56, 56, '#c28569', '#733e39', None),
        'house2': (56, 56, '#ead4aa', '#124e89', None),
        'architect': (64, 64, '#c0cbdc', '#feae34', 'compass'),
    }
    W, H, wall, roof, sign = specs[kind]
    c = Canvas(W, H)
    wr = R(wall, 5)
    rr = R(roof, 5)
    roof_h = int(H * 0.5)
    wall_top = roof_h - 4
    # front wall
    for y in range(wall_top, H - 1):
        for x in range(3, W - 3):
            col = wr[3]
            if (y - wall_top) % 6 == 0:
                col = wr[2]
            if x in (3, W - 4):
                col = wr[1]
            c.put(x, y, col)
    # beams (timber frame)
    for x in range(3, W - 3, 14):
        c.vline(x, wall_top, H - 2, shade(wr[1], -0.3))
    c.hline(3, W - 4, H - 2, wr[0])
    # roof (trapezoid with shingles)
    for y in range(2, roof_h):
        inset = max(0, 8 - y // 2)
        for x in range(inset, W - inset):
            col = rr[3] if (y // 3) % 2 == 0 else rr[2]
            if ((x + (y // 3) * 3) % 6) == 0:
                col = rr[1]
            c.put(x, y, col)
    c.hline(0, W - 1, roof_h, rr[0])
    c.hline(1, W - 2, roof_h - 1, rr[1])
    c.hline(8, W - 9, 2, rr[4])
    # door
    dw = 12 if W > 70 else 10
    dx = W // 2 - dw // 2
    dh = 18 if W > 70 else 15
    c.rect(dx, H - 1 - dh, dw, dh, hx('3e2731'))
    c.rect(dx + 1, H - dh, dw - 2, dh - 1, hx('5a3a2e'))
    c.vline(W // 2, H - dh, H - 2, hx('3e2731'))
    c.put(W // 2 + 2, H - dh // 2, hx('feae34'))
    # windows
    for wx in (10, W - 20):
        c.rect(wx, wall_top + 8, 10, 8, hx('3e2731'))
        c.rect(wx + 1, wall_top + 9, 8, 6, hx('fee761') if kind != 'house2' else hx('8fd3ff'))
        c.vline(wx + 5, wall_top + 9, wall_top + 14, hx('3e2731'))
        c.hline(wx + 1, wx + 8, wall_top + 12, hx('3e2731'))
    # chimney for smith / food
    if kind in ('blacksmith', 'food', 'house'):
        c.rect(W - 18, 0, 6, 12, hx('6b6f80'))
        c.hline(W - 19, W - 11, 0, hx('4f5263'))
    # sign board
    if sign:
        sx, sy = W // 2 - 9, wall_top - 2 if kind != 'guild' else wall_top - 10
        c.rect(sx, sy, 18, 12, hx('733e39'))
        c.rect(sx + 1, sy + 1, 16, 10, hx('ead4aa'))
        g = glyph_small(sign)
        c.paste(g, sx + 1, sy)
    if kind == 'guild':
        # banners
        for bx in (14, W - 22):
            c.rect(bx, wall_top + 2, 8, 16, hx('a22633'))
            c.poly([(bx, wall_top + 18), (bx + 4, wall_top + 14), (bx + 8, wall_top + 18)], CLEAR)
            c.disc(bx + 4, wall_top + 8, 2, hx('feae34'))
    c.outline()
    return c


def glyph_small(kind):
    g = Canvas(16, 12)
    if kind == 'sword':
        g.line(4, 9, 11, 2, hx('c0cbdc'))
        g.line(5, 9, 12, 2, hx('8b9bb4'))
        g.line(4, 6, 7, 9, hx('733e39'))
    elif kind == 'anvil':
        g.rect(3, 4, 10, 3, hx('3a4466'))
        g.rect(6, 7, 4, 3, hx('3a4466'))
        g.rect(4, 10, 8, 1, hx('262b44'))
        g.hline(3, 12, 4, hx('8b9bb4'))
    elif kind == 'flask':
        g.rect(7, 1, 2, 3, hx('c0cbdc'))
        g.disc(8, 7, 3.5, hx('e43b44'))
        g.put(6, 6, hx('ffffff'))
    elif kind == 'gem':
        g.poly([(8, 1), (13, 5), (8, 11), (3, 5)], hx('b55088'))
        g.line(3, 5, 13, 5, hx('f6757a'))
        g.put(7, 3, hx('ffffff'))
    elif kind == 'star':
        g.rect(4, 2, 8, 9, hx('124e89'))
        g.vline(4, 2, 10, hx('feae34'))
        g.put(8, 6, hx('fee761'))
        g.put(7, 6, hx('fee761'))
        g.put(8, 5, hx('fee761'))
        g.put(8, 7, hx('fee761'))
    elif kind == 'bread':
        g.ellipse(8, 7, 5, 3, None, R('#e4a672'))
        g.line(5, 6, 6, 5, hx('b86f50'))
        g.line(9, 6, 10, 5, hx('b86f50'))
    elif kind == 'guild':
        g.poly([(8, 1), (13, 3), (12, 9), (8, 11), (4, 9), (3, 3)], hx('a22633'))
        g.line(5, 8, 11, 3, hx('c0cbdc'))
        g.line(5, 3, 11, 8, hx('c0cbdc'))
    elif kind == 'compass':
        g.disc(8, 6, 4, hx('124e89'))
        g.line(8, 3, 8, 9, hx('feae34'))
        g.line(5, 6, 11, 6, hx('ffffff'))
    return g


def town_props():
    out = {}
    # fountain
    c = Canvas(48, 40)
    st = R('#b8b0a0', 5)
    c.ellipse(24, 26, 22, 12, None, st[1:])
    c.ellipse(24, 25, 18, 9, None, R('#3a8ad8', 4))
    c.rect(21, 8, 6, 18, st[3])
    c.vline(21, 8, 25, st[4])
    c.ellipse(24, 9, 7, 3, None, st[2:])
    c.disc(24, 5, 2.5, R('#8fd3ff')[2])
    c.put(23, 3, hx('ffffff'))
    c.outline()
    out['fountain'] = c
    # waypoint stone
    c = Canvas(20, 32)
    rr = R('#5a6988', 5)
    c.poly([(5, 30), (7, 6), (10, 2), (13, 6), (15, 30)], rr[2])
    c.vline(7, 7, 29, rr[4])
    c.vline(10, 8, 26, hx('2ce8f5'))
    c.put(9, 14, hx('2ce8f5'))
    c.put(11, 18, hx('2ce8f5'))
    c.hline(3, 16, 30, rr[0])
    c.outline()
    out['waypoint'] = c
    # lamp post
    c = Canvas(12, 34)
    c.rect(5, 8, 2, 25, hx('3a4466'))
    c.rect(3, 3, 6, 6, hx('262b44'))
    c.rect(4, 4, 4, 4, hx('fee761'))
    c.hline(3, 8, 32, hx('262b44'))
    c.outline()
    out['lamp'] = c
    # barrel, crate
    c = Canvas(14, 16)
    br = R('#b86f50', 4)
    c.ellipse(7, 8, 6, 7, None, br)
    c.hline(1, 13, 4, hx('5a5a66'))
    c.hline(1, 13, 11, hx('5a5a66'))
    c.outline()
    out['barrel'] = c
    c = Canvas(16, 16)
    c.rect(1, 3, 14, 12, hx('b86f50'))
    c.rect(1, 3, 14, 2, hx('e4a672'))
    c.line(2, 6, 13, 13, hx('733e39'))
    c.line(2, 13, 13, 6, hx('733e39'))
    c.outline()
    out['crate'] = c
    # market stall (awning)
    for k, col in enumerate(('#e43b44', '#3a8ad8', '#63c74d')):
        c = Canvas(40, 34)
        c.rect(3, 18, 34, 14, hx('8a5a3a'))
        c.rect(3, 18, 34, 3, hx('b86f50'))
        c.vline(4, 8, 31, hx('5a3a2e'))
        c.vline(35, 8, 31, hx('5a3a2e'))
        for x in range(1, 39):
            stripe = hx(col) if (x // 5) % 2 == 0 else hx('f4f1ea')
            for y in range(4, 11):
                c.put(x, y + (1 if x % 5 == 0 else 0), stripe)
        c.outline()
        out['stall%d' % k] = c
    # wall tower
    c = Canvas(32, 52)
    tr = R('#9a9aa6', 5)
    c.rect(2, 12, 28, 38, tr[2])
    for y in range(14, 50, 5):
        c.hline(2, 29, y, tr[1])
    c.rect(0, 6, 32, 7, tr[3])
    for x in range(0, 32, 6):
        c.rect(x, 2, 4, 5, tr[3])
    c.rect(13, 22, 6, 8, hx('262b44'))
    c.outline()
    out['tower'] = c
    # banner pole
    c = Canvas(14, 36)
    c.vline(3, 2, 34, hx('5a3a2e'))
    c.rect(4, 3, 9, 14, hx('124e89'))
    c.disc(8, 9, 2, hx('feae34'))
    c.outline()
    out['banner'] = c
    # anvil prop
    c = Canvas(18, 12)
    c.rect(2, 2, 14, 3, hx('5a6988'))
    c.rect(6, 5, 6, 4, hx('3a4466'))
    c.rect(4, 9, 10, 2, hx('262b44'))
    c.outline()
    out['anvil'] = c
    # campfire
    c = Canvas(16, 14)
    c.line(2, 12, 13, 9, hx('733e39'))
    c.line(2, 9, 13, 12, hx('5a3a2e'))
    c.outline()
    out['campfire'] = c
    return out


def dungeon_props():
    out = {}
    # entrance ruin (overworld) with portal hole
    for k in range(4):
        c = Canvas(40, 40)
        st = R('#6b6f80', 5)
        c.rect(4, 8, 8, 30, st[2])
        c.rect(28, 8, 8, 30, st[2])
        c.vline(4, 8, 37, st[4])
        c.rect(2, 4, 36, 7, st[3])
        c.hline(2, 37, 4, st[4])
        for y in range(11, 38):
            for x in range(12, 28):
                d = math.hypot(x - 20, (y - 24) * 0.8)
                v = math.sin(d * 0.8 - k * 1.5 + math.atan2(y - 24, x - 20) * 2)
                c.put(x, y, hx('3b1f5c') if v < 0 else hx('8a4fd0'))
        c.disc(20, 24, 2, hx('e0c8ff'))
        c.rect(0, 37, 40, 3, st[1])
        c.outline()
        out['entrance%d' % k] = c
    # exit portal (in dungeon)
    for k in range(4):
        c = Canvas(32, 32)
        for y in range(32):
            for x in range(32):
                d = math.hypot(x - 16, (y - 18) * 1.6)
                if d < 13:
                    v = math.sin(d * 0.9 - k * 1.6 + math.atan2(y - 18, x - 16) * 3)
                    c.put(x, y, hx('1f6b8a') if v < 0 else hx('2ce8f5'))
        c.ellipse(16, 18, 13, 8, None, None) if False else None
        c.outline()
        out['portal%d' % k] = c
    # chests
    for tier, (wood, band) in enumerate((('#b86f50', '#8b9bb4'), ('#5a6988', '#c0cbdc'), ('#a22633', '#feae34'))):
        for state in ('closed', 'open'):
            c = Canvas(20, 18)
            wr = R(wood)
            br = R(band)
            c.rect(2, 8, 16, 9, wr[2])
            c.hline(2, 17, 8, wr[3])
            c.rect(2, 11, 16, 1, br[1])
            c.vline(2, 8, 16, br[2])
            c.vline(17, 8, 16, br[1])
            if state == 'closed':
                c.rect(2, 3, 16, 5, wr[3])
                c.hline(2, 17, 3, wr[3])
                c.hline(3, 16, 2, br[2])
                c.rect(9, 6, 2, 4, br[3])
            else:
                c.rect(3, 6, 14, 3, hx('3e2731'))
                c.rect(2, 0, 16, 4, wr[1])
                c.hline(2, 17, 0, br[2])
                c.put(8, 8, hx('fee761'))
                c.put(11, 7, hx('fee761'))
                c.put(10, 8, hx('ffffff'))
            c.outline()
            out['chest%d_%s' % (tier, state)] = c
    # spikes: 3 states
    for k, h in enumerate((0, 2, 5)):
        c = Canvas(16, 16)
        base = R('#4f5263')
        for (x, y) in ((3, 4), (10, 4), (6, 10), (13, 11)):
            c.disc(x, y, 1.5, base[0])
            if h:
                c.vline(x, y - h, y, hx('e4e8ef'))
                c.put(x, y - h, hx('ffffff'))
                c.put(x + 1, y - h + 1, hx('8b9bb4'))
        out['spike%d' % k] = c
    # arrow trap turret
    c = Canvas(16, 16)
    c.rect(2, 3, 12, 11, hx('4f5263'))
    c.rect(3, 4, 10, 9, hx('6b6f80'))
    c.rect(10, 7, 5, 3, hx('262b44'))
    c.put(6, 7, hx('e43b44'))
    c.outline()
    out['arrow_trap'] = c
    # gas vent
    c = Canvas(16, 16)
    c.ellipse(8, 9, 6, 4, None, R('#4f5263'))
    for x in range(4, 13, 2):
        c.vline(x, 8, 10, hx('181425'))
    c.put(8, 9, hx('63c74d'))
    out['gas_vent'] = c
    # pressure plate
    c = Canvas(16, 16)
    c.rect(3, 4, 10, 9, hx('5a5068'))
    c.rect(4, 5, 8, 7, hx('6b6f80'))
    out['plate'] = c
    # teleport rune
    for k in range(2):
        c = Canvas(16, 16)
        col = hx('b088ff') if k == 0 else hx('e0c8ff')
        for a in range(0, 360, 20):
            c.put(8 + math.cos(math.radians(a)) * 6, 8 + math.sin(math.radians(a)) * 6, col)
        c.line(5, 5, 11, 11, col)
        c.line(11, 5, 5, 11, col)
        out['tele_rune%d' % k] = c
    # pit (open)
    c = Canvas(16, 16)
    c.rect(0, 0, 16, 16, hx('0c0a14'))
    c.hline(0, 15, 0, hx('4a3f5c'))
    c.hline(0, 15, 1, hx('2a2438'))
    out['pit_open'] = c
    # boulder
    for k in range(4):
        c = Canvas(24, 24)
        rr = R('#7a7a88', 5)
        c.ellipse(12, 12, 10, 10, None, rr[1:], light=(-0.5, -0.8))
        a = k * math.pi / 4
        c.line(12 + math.cos(a) * 8, 12 + math.sin(a) * 8, 12 - math.cos(a) * 8, 12 - math.sin(a) * 8, rr[1])
        c.outline()
        out['boulder%d' % k] = c
    # bomb
    for k in range(2):
        c = Canvas(14, 16)
        c.disc(7, 10, 5, hx('262b44'))
        c.put(5, 8, hx('5a6988'))
        c.line(7, 5, 9, 2, hx('ead4aa'))
        c.put(10, 1, hx('fee761') if k == 0 else hx('f77622'))
        c.outline()
        out['bomb%d' % k] = c
    # nest, totem, circle, grave
    c = Canvas(28, 20)
    c.ellipse(14, 12, 12, 6, None, R('#8a6b4a', 5)[1:])
    for k in range(8):
        a = k / 8 * math.tau
        c.line(14 + math.cos(a) * 8, 12 + math.sin(a) * 4, 14 + math.cos(a) * 13, 12 + math.sin(a) * 6, hx('5a3a2e'))
    c.ellipse(14, 11, 6, 3, None, R('#3e2731'))
    c.disc(12, 10, 1.5, hx('e4e8ef'))
    c.disc(16, 11, 1.5, hx('e4e8ef'))
    c.outline()
    out['nest'] = c
    c = Canvas(18, 32)
    tr = R('#733e39', 5)
    c.rect(5, 6, 8, 25, tr[2])
    c.vline(5, 6, 30, tr[4])
    c.rect(4, 6, 10, 9, tr[3])
    c.put(6, 9, hx('e43b44'))
    c.put(11, 9, hx('e43b44'))
    c.hline(6, 11, 12, hx('181425'))
    c.thick_line(1, 4, 5, 8, hx('e4e8ef'), 2)
    c.thick_line(17, 4, 13, 8, hx('e4e8ef'), 2)
    c.outline()
    out['totem'] = c
    c = Canvas(18, 24)
    c.rect(4, 4, 10, 18, hx('6b6f80'))
    c.rect(3, 2, 12, 4, hx('8b9bb4'))
    c.vline(9, 7, 15, hx('4f5263'))
    c.hline(6, 12, 10, hx('4f5263'))
    c.rect(1, 21, 16, 2, hx('5a4a42'))
    c.outline()
    out['grave'] = c
    for k in range(2):
        c = Canvas(40, 24)
        col = hx('e43b44') if k == 0 else hx('ff8a8a')
        for a in range(0, 360, 6):
            r = math.radians(a)
            c.put(20 + math.cos(r) * 17, 12 + math.sin(r) * 9, col)
            c.put(20 + math.cos(r) * 12, 12 + math.sin(r) * 6, col)
        for j in range(5):
            r1 = math.radians(j * 144 - 90)
            r2 = math.radians((j + 1) * 144 - 90)
            c.line(20 + math.cos(r1) * 12, 12 + math.sin(r1) * 6, 20 + math.cos(r2) * 12, 12 + math.sin(r2) * 6, col)
        out['circle%d' % k] = c
    # dungeon pillar / statue / torch
    c = Canvas(16, 32)
    pr = R('#7a7a88', 5)
    c.rect(3, 4, 10, 26, pr[2])
    c.vline(3, 4, 29, pr[4])
    c.vline(12, 4, 29, pr[1])
    c.rect(1, 1, 14, 4, pr[3])
    c.rect(1, 28, 14, 3, pr[1])
    c.outline()
    out['pillar'] = c
    for k in range(2):
        c = Canvas(10, 20)
        c.rect(4, 8, 2, 11, hx('5a3a2e'))
        c.disc(5, 6, 3 - k * 0.5, hx('f77622'))
        c.disc(5, 5 - k, 1.5, hx('fee761'))
        c.outline()
        out['torch%d' % k] = c
    # crystal cluster, mushroom cluster, coral for biomes
    c = Canvas(20, 22)
    for k, (x, h) in enumerate(((5, 10), (10, 18), (15, 12))):
        c.poly([(x - 3, 21), (x, 21 - h), (x + 3, 21)], R('#2ce8f5', 5)[2 + k % 2])
    c.outline()
    out['crystals'] = c
    c = Canvas(20, 20)
    for k, (x, h, col) in enumerate(((5, 10, '#e43b44'), (13, 14, '#9b5de5'))):
        c.rect(x - 1, 19 - h, 3, h, hx('ead4aa'))
        c.ellipse(x, 19 - h, 5, 3, None, R(col))
    c.outline()
    out['shrooms'] = c
    c = Canvas(20, 20)
    for k in range(5):
        c.thick_line(10, 19, 3 + k * 3.5, 5 + (k % 2) * 4, R('#f6757a')[1 + k % 3], 2)
    c.outline()
    out['coral'] = c
    c = Canvas(18, 14)
    c.ellipse(9, 9, 8, 4, None, R('#b86f50'))
    c.thick_line(4, 9, 14, 6, hx('e4e8ef'), 2)
    c.outline()
    out['bones'] = c
    return out


def build_objects(out_dir, manifest):
    objs = {}
    for kind in ('oak', 'big_oak', 'pine', 'snow_pine', 'palm', 'mushroom_tree', 'dead_tree', 'cactus',
                 'swamp_tree', 'crystal_tree'):
        objs['tree_' + kind] = tree(kind, hash(kind) % 997)
    objs['rock_small'] = rock('gray', 1, 0.7)
    objs['rock_big'] = rock('gray', 2, 1.3)
    objs['rock_dark'] = rock('dark', 3, 1.0)
    for ore, col in (('copper', '#d77643'), ('iron', '#c0cbdc'), ('silver', '#e4e8ef'), ('gold', '#feae34'),
                     ('mithril', '#2ce8f5'), ('adamantite', '#b55088'), ('crystal', '#9b5de5')):
        objs['ore_' + ore] = rock('gray' if ore not in ('adamantite', 'crystal') else 'dark', len(ore), 1.0, col)
    objs['bush'] = bush(4)
    objs['bush_berry'] = bush(5, '#e43b44')
    for b in ('guild', 'gear', 'blacksmith', 'potion', 'artifact', 'magic', 'food', 'house', 'house2', 'architect'):
        objs['bld_' + b] = building(b)
    for k, v in town_props().items():
        objs['prop_' + k] = v
    for k, v in dungeon_props().items():
        objs['dg_' + k] = v
    sub = os.path.join(out_dir, 'objects')
    os.makedirs(sub, exist_ok=True)
    meta = {}
    for name, cv in objs.items():
        cv.img.save(os.path.join(sub, name + '.png'))
        meta[name] = {'path': 'res://assets/sprites/world/objects/' + name + '.png', 'w': cv.w, 'h': cv.h}
    manifest['objects'] = meta


def build_all(out_dir, manifest):
    os.makedirs(out_dir, exist_ok=True)
    build_tiles(out_dir, manifest)
    build_objects(out_dir, manifest)
