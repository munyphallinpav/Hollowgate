"""Item icons (16x16), skill glyphs (16x16 white), held weapons and FX textures."""
import math
import os
from PIL import Image
from pix import Canvas, hx, ramp, shade, mix, CLEAR, rng

S = 16


def R(c, n=4):
    return ramp(c, n)


def fin(c, outline=True):
    if outline:
        c.outline()
    return c


# ------------------------------------------------------------------ item icons
def ic_sword(blade='#c0cbdc', hilt='#733e39', guard='#feae34'):
    c = Canvas(S, S)
    b = R(blade)
    c.thick_line(4, 11, 13, 2, b[2], 2)
    c.line(5, 11, 13, 3, b[3])
    c.line(2, 9, 6, 13, hx(guard))
    c.line(1, 14, 4, 11, hx(hilt))
    return fin(c)


def ic_spear():
    c = Canvas(S, S)
    c.line(1, 14, 11, 4, hx('8a5a3a'))
    c.line(2, 14, 12, 4, hx('733e39'))
    c.poly([(10, 3), (14, 1), (12, 5)], hx('c0cbdc'))
    c.put(12, 3, hx('ffffff'))
    return fin(c)


def ic_hammer():
    c = Canvas(S, S)
    c.thick_line(2, 14, 9, 7, hx('733e39'), 2)
    c.poly([(7, 2), (14, 9), (11, 12), (4, 5)], hx('8b9bb4'))
    c.line(7, 2, 14, 9, hx('c0cbdc'))
    return fin(c)


def ic_dagger():
    c = Canvas(S, S)
    c.thick_line(6, 10, 12, 4, hx('c0cbdc'), 2)
    c.put(13, 3, hx('ffffff'))
    c.line(4, 8, 8, 12, hx('feae34'))
    c.line(3, 13, 5, 11, hx('3e2731'))
    return fin(c)


def ic_wand():
    c = Canvas(S, S)
    c.thick_line(3, 13, 10, 6, hx('733e39'), 2)
    c.disc(11.5, 4.5, 2.6, hx('2ce8f5'))
    c.put(11, 3, hx('ffffff'))
    return fin(c)


def ic_grimoire(col='#68386c'):
    c = Canvas(S, S)
    r = R(col)
    c.rect(3, 2, 10, 12, r[2])
    c.vline(3, 2, 13, r[1])
    c.rect(12, 3, 1, 10, hx('ead4aa'))
    c.disc(8, 8, 2, hx('feae34'))
    c.put(8, 8, hx('fee761'))
    return fin(c)


def ic_bow():
    c = Canvas(S, S)
    for a in range(-60, 61, 6):
        r = math.radians(a)
        c.put(4 + math.cos(r) * 9, 8 + math.sin(r) * 7, hx('8a5a3a'))
        c.put(3 + math.cos(r) * 9, 8 + math.sin(r) * 7, hx('b86f50'))
    c.line(8, 2, 8, 14, hx('e4e8ef'))
    return fin(c)


def ic_gun():
    c = Canvas(S, S)
    c.rect(2, 5, 12, 3, hx('5a6988'))
    c.hline(2, 13, 5, hx('8b9bb4'))
    c.rect(3, 8, 3, 5, hx('733e39'))
    c.put(7, 8, hx('3a4466'))
    c.put(14, 6, hx('262b44'))
    return fin(c)


def ic_armor(kind):
    c = Canvas(S, S)
    col = {'heavy': '#8b9bb4', 'light': '#c0cbdc', 'leather': '#b86f50', 'robe': '#3b3fa0'}[kind]
    r = R(col)
    if kind == 'robe':
        c.poly([(5, 2), (11, 2), (14, 14), (2, 14)], r[2])
        c.vline(8, 3, 13, hx('feae34'))
        c.hline(2, 13, 14, r[1])
    else:
        c.rect(4, 3, 8, 10, r[2])
        c.rect(2, 3, 3, 5, r[1])
        c.rect(11, 3, 3, 5, r[1])
        c.hline(6, 9, 3, CLEAR)
        c.put(7, 4, CLEAR)
        c.put(8, 4, CLEAR)
        c.vline(5, 5, 12, r[3])
        if kind == 'heavy':
            c.hline(4, 11, 8, r[0])
            c.put(8, 6, hx('feae34'))
        if kind == 'leather':
            c.hline(4, 11, 10, hx('3e2731'))
    return fin(c)


def ic_necklace():
    c = Canvas(S, S)
    for a in range(0, 181, 12):
        r = math.radians(a)
        c.put(8 + math.cos(r) * 6, 3 + math.sin(r) * 7, hx('feae34'))
    c.poly([(8, 9), (11, 12), (8, 15), (5, 12)], hx('e43b44'))
    c.put(7, 11, hx('ffffff'))
    return fin(c)


def ic_ring():
    c = Canvas(S, S)
    for a in range(0, 360, 10):
        r = math.radians(a)
        c.put(8 + math.cos(r) * 4.5, 10 + math.sin(r) * 3.5, hx('feae34'))
    c.poly([(8, 3), (10, 5), (8, 7), (6, 5)], hx('2ce8f5'))
    c.put(7, 4, hx('ffffff'))
    return fin(c)


def ic_bracelet():
    c = Canvas(S, S)
    for a in range(0, 360, 8):
        r = math.radians(a)
        c.put(8 + math.cos(r) * 6, 8 + math.sin(r) * 4, hx('c0cbdc'))
        c.put(8 + math.cos(r) * 5, 8 + math.sin(r) * 3, hx('8b9bb4'))
    c.disc(8, 11.5, 1.5, hx('63c74d'))
    return fin(c)


def ic_potion(col, size=1.0, shape='round'):
    c = Canvas(S, S)
    glass = hx('c0cbdc')
    r = R(col)
    c.rect(6, 1, 4, 2, hx('8a5a3a'))
    c.rect(7, 3, 2, 3, glass)
    rad = 4.5 * size
    if shape == 'round':
        c.disc(8, 10, rad + 0.6, glass)
        c.disc(8, 10, rad, r[2])
        c.disc(8, 11, rad - 1.5, r[1])
    else:
        c.rect(4, 6, 8, 9, glass)
        c.rect(5, 7, 6, 7, r[2])
        c.rect(5, 11, 6, 3, r[1])
    c.put(6, 8, hx('ffffff'))
    return fin(c)


def ic_food(kind):
    c = Canvas(S, S)
    if kind == 'bread':
        c.ellipse(8, 9, 6, 4, None, R('#e4a672'))
        for x in (5, 8, 11):
            c.line(x, 7, x + 1, 6, hx('b86f50'))
    elif kind == 'apple':
        c.disc(8, 9, 5, hx('e43b44'))
        c.disc(7, 8, 3, hx('f6757a'))
        c.line(8, 4, 9, 2, hx('733e39'))
        c.put(10, 3, hx('63c74d'))
        c.put(6, 7, hx('ffffff'))
    elif kind in ('raw_meat', 'grilled_meat'):
        col = '#e45a6a' if kind == 'raw_meat' else '#9a5a3a'
        c.ellipse(9, 7, 5, 4, None, R(col))
        c.thick_line(4, 12, 7, 9, hx('ead4aa'), 2)
        c.disc(3, 13, 1.5, hx('ffffff'))
        if kind == 'grilled_meat':
            c.line(7, 5, 11, 9, hx('5a3a2e'))
    elif kind in ('fish_stew', 'hearty_stew'):
        c.ellipse(8, 10, 7, 4, None, R('#8b9bb4'))
        c.ellipse(8, 8, 6, 2, None, None)
        c.ellipse(8, 8, 5.5, 2, R('#feae34' if kind == 'fish_stew' else '#b86f50')[2])
        c.put(6, 8, hx('63c74d'))
        c.put(10, 8, hx('e43b44'))
        c.line(9, 4, 9, 6, hx('e4e8ef'))
    elif kind == 'honey_cake':
        c.rect(3, 7, 10, 6, hx('e4a672'))
        c.rect(3, 6, 10, 2, hx('feae34'))
        c.put(5, 8, hx('feae34'))
        c.put(10, 9, hx('feae34'))
        c.disc(8, 4, 1.5, hx('e43b44'))
    elif kind == 'feast':
        c.ellipse(8, 11, 7, 3, None, R('#c0cbdc'))
        c.ellipse(8, 8, 5, 4, None, R('#9a5a3a'))
        c.put(4, 9, hx('63c74d'))
        c.put(12, 9, hx('e43b44'))
        c.put(8, 4, hx('fee761'))
    elif kind == 'berries':
        for (x, y) in ((6, 8), (9, 7), (8, 10), (11, 10), (5, 11)):
            c.disc(x, y, 1.7, hx('9b5de5'))
            c.put(x - 1, y - 1, hx('e0c8ff'))
        c.put(9, 4, hx('63c74d'))
    elif kind == 'fish':
        c.ellipse(7, 8, 5, 3, None, R('#3a8ad8'))
        c.poly([(11, 8), (15, 5), (15, 11)], hx('2560b0'))
        c.put(4, 7, hx('181425'))
    return fin(c)


def ic_mat(kind):
    c = Canvas(S, S)
    r = rng(len(kind) * 13)
    if kind in ('wood', 'hardwood'):
        col = '#b86f50' if kind == 'wood' else '#733e39'
        for k in range(2):
            c.thick_line(2, 10 - k * 4, 13, 6 - k * 4 + 4, R(col)[2 - k], 3)
        c.disc(13, 10, 1.6, hx('ead4aa'))
    elif kind == 'stone':
        c.ellipse(8, 9, 6, 4.5, None, R('#8b9bb4'))
    elif kind.startswith('ore_'):
        col = {'ore_copper': '#d77643', 'ore_iron': '#c0cbdc', 'ore_silver': '#ffffff', 'ore_gold': '#feae34',
               'ore_mithril': '#2ce8f5', 'ore_adamantite': '#b55088'}[kind]
        c.poly([(3, 12), (5, 5), (10, 3), (13, 7), (12, 13)], hx('5a5a66'))
        for _ in range(5):
            x, y = r.randrange(5, 12), r.randrange(5, 12)
            c.put(x, y, hx(col))
            c.put(x + 1, y, shade(hx(col), -0.3))
    elif kind == 'crystal_shard':
        c.poly([(8, 1), (12, 7), (8, 15), (4, 7)], hx('9b5de5'))
        c.line(8, 2, 8, 14, hx('e0c8ff'))
    elif kind == 'enchant_stone':
        c.disc(8, 8, 5, hx('124e89'))
        c.disc(8, 8, 3, hx('2ce8f5'))
        c.put(7, 6, hx('ffffff'))
        c.line(8, 3, 8, 13, hx('feae34'))
    elif kind == 'arcane_dust':
        for _ in range(14):
            c.put(r.randrange(3, 13), r.randrange(5, 14), hx(r.choice(['e0c8ff', '9b5de5', 'ffffff'])))
    elif kind == 'monster_core':
        c.disc(8, 8, 5, hx('a22633'))
        c.disc(8, 8, 3, hx('e43b44'))
        c.disc(7, 7, 1.2, hx('fee761'))
    elif kind == 'leather':
        c.poly([(3, 4), (13, 3), (12, 13), (4, 12)], hx('b86f50'))
        c.line(4, 5, 12, 5, hx('e4a672'))
    elif kind == 'cloth':
        c.poly([(2, 5), (14, 4), (13, 12), (3, 13)], hx('ead4aa'))
        c.line(3, 8, 13, 8, hx('c0b59a'))
    elif kind == 'slime_gel':
        c.ellipse(8, 10, 5, 4, None, R('#63c74d'))
        c.put(6, 8, hx('ffffff'))
    elif kind == 'wolf_pelt':
        c.poly([(2, 6), (14, 4), (13, 12), (3, 13)], hx('8b9bb4'))
        c.line(3, 7, 12, 6, hx('c0cbdc'))
    elif kind in ('tiger_fang', 'vampire_fang'):
        col = '#ffffff' if kind == 'tiger_fang' else '#e43b44'
        c.poly([(5, 2), (11, 2), (8, 14)], hx('ead4aa'))
        c.line(8, 3, 8, 12, hx(col))
    elif kind == 'bear_claw':
        for k in range(3):
            c.thick_line(4 + k * 3, 3, 6 + k * 3, 13, hx('e4e8ef'), 1.5)
    elif kind == 'goblin_ear':
        c.poly([(3, 10), (13, 3), (11, 12)], hx('63c74d'))
        c.line(5, 10, 12, 5, hx('3e8948'))
    elif kind == 'ogre_hide':
        c.poly([(2, 5), (14, 3), (13, 13), (3, 12)], hx('9aa35a'))
        for _ in range(4):
            c.put(r.randrange(4, 12), r.randrange(5, 11), hx('5b7a45'))
    elif kind == 'bone':
        c.thick_line(3, 12, 12, 3, hx('e4e8ef'), 2)
        for (x, y) in ((3, 12), (12, 3)):
            c.disc(x, y, 1.6, hx('ffffff'))
    elif kind == 'rotten_flesh':
        c.ellipse(8, 9, 5, 4, None, R('#8fb08a'))
        c.put(6, 8, hx('3e2731'))
    elif kind == 'ancient_bark':
        c.rect(4, 2, 8, 12, hx('733e39'))
        for y in range(3, 14, 3):
            c.hline(4, 11, y, hx('5a3a2e'))
        c.put(6, 6, hx('63c74d'))
    elif kind == 'dryad_petal':
        for k in range(5):
            a = k / 5 * math.tau
            c.disc(8 + math.cos(a) * 3.5, 8 + math.sin(a) * 3.5, 2.2, hx('f6757a'))
        c.disc(8, 8, 1.5, hx('fee761'))
    elif kind == 'lizard_scale':
        c.poly([(8, 2), (13, 8), (8, 14), (3, 8)], hx('3e8948'))
        c.line(8, 3, 8, 13, hx('63c74d'))
    elif kind == 'mermaid_pearl':
        c.disc(8, 8, 4.5, hx('e4e8ef'))
        c.disc(7, 7, 2, hx('ffffff'))
        c.put(10, 10, hx('b088d0'))
    elif kind == 'wyvern_wing':
        c.poly([(2, 12), (8, 2), (14, 6), (11, 13)], hx('8a5a3a'))
        c.line(8, 2, 6, 12, hx('5a3a2e'))
        c.line(8, 2, 11, 12, hx('5a3a2e'))
    elif kind == 'dragon_scale':
        c.poly([(8, 1), (14, 6), (11, 14), (5, 14), (2, 6)], hx('be2633'))
        c.poly([(8, 4), (11, 7), (8, 11), (5, 7)], hx('feae34'))
    elif kind in ('phoenix_feather', 'feather'):
        col = '#f77622' if kind == 'phoenix_feather' else '#e4e8ef'
        c.thick_line(3, 13, 12, 3, hx(col), 3)
        c.line(3, 13, 13, 2, hx('fee761') if kind == 'phoenix_feather' else hx('8b9bb4'))
    elif kind == 'herb':
        c.line(8, 14, 8, 6, hx('3e8948'))
        c.disc(6, 6, 2, hx('63c74d'))
        c.disc(10, 8, 2, hx('63c74d'))
        c.disc(8, 4, 2, hx('63c74d'))
    return fin(c)


def ic_special(kind, col=None):
    c = Canvas(S, S)
    if kind == 'spellbook':
        r = R(col)
        c.rect(3, 2, 10, 12, r[2])
        c.vline(3, 2, 13, r[1])
        c.rect(12, 3, 1, 10, hx('f4f1ea'))
        c.disc(8, 8, 2.5, r[3])
        c.disc(8, 8, 1.2, hx('ffffff'))
    elif kind == 'scroll':
        c.rect(4, 3, 8, 10, hx('ead4aa'))
        c.rect(3, 2, 10, 2, hx('c0b59a'))
        c.rect(3, 12, 10, 2, hx('c0b59a'))
        for y in (6, 8, 10):
            c.hline(5, 10, y, hx('8a6b4a'))
    elif kind == 'dungeon_crystal':
        c.poly([(8, 1), (13, 6), (8, 15), (3, 6)], hx('68386c'))
        c.poly([(8, 3), (11, 6), (8, 12), (5, 6)], hx('b088ff'))
        c.put(7, 5, hx('ffffff'))
    elif kind == 'gold':
        for (x, y) in ((6, 10), (10, 10), (8, 7)):
            c.ellipse(x, y, 3.5, 2.5, None, R('#feae34'))
    elif kind == 'bag':
        c.ellipse(8, 10, 6, 5, None, R('#b86f50'))
        c.rect(6, 3, 4, 3, hx('8a5a3a'))
        c.hline(5, 10, 5, hx('feae34'))
    elif kind == 'key':
        c.disc(5, 6, 3, hx('feae34'))
        c.disc(5, 6, 1.4, CLEAR)
        c.line(7, 8, 13, 14, hx('feae34'))
        c.line(11, 12, 12, 11, hx('feae34'))
    elif kind == 'quest':
        c.rect(4, 2, 8, 12, hx('ead4aa'))
        c.vline(8, 4, 9, hx('a22633'))
        c.put(8, 11, hx('a22633'))
    return fin(c)


def build_item_icons():
    icons = {}
    icons['sword'] = ic_sword()
    icons['spear'] = ic_spear()
    icons['hammer'] = ic_hammer()
    icons['dagger'] = ic_dagger()
    icons['wand'] = ic_wand()
    icons['grimoire'] = ic_grimoire()
    icons['bow'] = ic_bow()
    icons['gun'] = ic_gun()
    for k in ('heavy', 'light', 'leather', 'robe'):
        icons['armor_' + k] = ic_armor(k)
    icons['necklace'] = ic_necklace()
    icons['ring'] = ic_ring()
    icons['bracelet'] = ic_bracelet()
    for k, (col, sz) in {'hp_s': ('#e43b44', 0.7), 'hp_m': ('#e43b44', 0.9), 'hp_l': ('#e43b44', 1.1),
                         'mp_s': ('#3a8ad8', 0.7), 'mp_m': ('#3a8ad8', 0.9), 'mp_l': ('#3a8ad8', 1.1),
                         'elixir': ('#b55088', 1.0), 'antidote': ('#63c74d', 0.8)}.items():
        icons['pot_' + k] = ic_potion(col, sz)
    for k, col in {'str': '#f77622', 'int': '#9b5de5', 'def': '#8b9bb4', 'spd': '#2ce8f5'}.items():
        icons['pot_' + k] = ic_potion(col, 1.0, 'square')
    for k in ('bread', 'apple', 'raw_meat', 'grilled_meat', 'fish_stew', 'hearty_stew', 'honey_cake', 'feast',
              'berries', 'fish'):
        icons['food_' + k] = ic_food(k)
    for k in ('wood', 'hardwood', 'stone', 'ore_copper', 'ore_iron', 'ore_silver', 'ore_gold', 'ore_mithril',
              'ore_adamantite', 'crystal_shard', 'enchant_stone', 'arcane_dust', 'monster_core', 'leather', 'cloth',
              'slime_gel', 'wolf_pelt', 'tiger_fang', 'bear_claw', 'goblin_ear', 'ogre_hide', 'bone', 'rotten_flesh',
              'ancient_bark', 'dryad_petal', 'lizard_scale', 'mermaid_pearl', 'vampire_fang', 'wyvern_wing',
              'dragon_scale', 'phoenix_feather', 'feather', 'herb'):
        icons['mat_' + k] = ic_mat(k)
    for el, col in (('light', '#fee761'), ('dark', '#68386c'), ('fire', '#e43b44'), ('water', '#3a8ad8'),
                    ('earth', '#b86f50'), ('wind', '#3e8948'), ('neutral', '#8b9bb4')):
        icons['book_' + el] = ic_special('spellbook', col)
    for k in ('scroll', 'dungeon_crystal', 'gold', 'bag', 'key', 'quest'):
        icons[k] = ic_special(k)
    return icons


# ------------------------------------------------------------------ skill glyphs (white)
W1 = hx('ffffff')
W2 = hx('d8dee9')
W3 = hx('9aa6b8')


def glyph(name):
    c = Canvas(S, S)
    if name == 'sword':
        c.thick_line(4, 12, 13, 3, W1, 2)
        c.line(2, 10, 6, 14, W2)
    elif name == 'slash':
        for a in range(-80, 60, 6):
            r = math.radians(a)
            c.put(6 + math.cos(r) * 8, 9 + math.sin(r) * 7, W1)
            c.put(6 + math.cos(r) * 6, 9 + math.sin(r) * 5, W3)
        c.line(2, 13, 9, 6, W2)
    elif name == 'shield':
        c.poly([(3, 2), (13, 2), (13, 8), (8, 14), (3, 8)], W2)
        c.poly([(5, 4), (11, 4), (11, 8), (8, 11), (5, 8)], W1)
    elif name == 'shout':
        c.disc(5, 8, 3, W1)
        for k in range(3):
            c.line(9 + k * 2, 4 + k, 9 + k * 2, 12 - k, W2 if k % 2 else W1)
    elif name == 'whirl':
        for t in range(0, 60):
            a = t * 0.25
            rr = t * 0.11
            c.put(8 + math.cos(a) * rr, 8 + math.sin(a) * rr, W1)
    elif name == 'spikes':
        for k in range(3):
            c.poly([(1 + k * 5, 14), (3 + k * 5, 4 + (k % 2) * 3), (5 + k * 5, 14)], W1 if k != 1 else W2)
    elif name == 'flame':
        c.poly([(8, 1), (13, 10), (11, 14), (5, 14), (3, 10)], W2)
        c.poly([(8, 6), (10, 11), (8, 14), (6, 11)], W1)
    elif name == 'leap':
        for a in range(200, 341, 8):
            r = math.radians(a)
            c.put(8 + math.cos(r) * 6, 11 + math.sin(r) * 8, W1)
        c.poly([(11, 11), (15, 11), (13, 15)], W1)
        c.hline(1, 15, 15, W3)
    elif name == 'bubble':
        for a in range(0, 360, 8):
            r = math.radians(a)
            c.put(8 + math.cos(r) * 6, 8 + math.sin(r) * 6, W1)
        c.put(5, 5, W1)
        c.put(6, 4, W2)
    elif name == 'skull':
        c.disc(8, 7, 5, W1)
        c.rect(5, 11, 6, 3, W1)
        c.rect(5, 6, 2, 2, CLEAR)
        c.rect(9, 6, 2, 2, CLEAR)
        c.put(7, 12, CLEAR)
        c.put(9, 12, CLEAR)
    elif name == 'arrow':
        c.line(2, 14, 13, 3, W1)
        c.poly([(10, 2), (14, 2), (14, 6)], W1)
        c.line(2, 12, 4, 14, W2)
    elif name == 'arrows3':
        for dx in (-3, 0, 3):
            c.line(3, 13, 10 + dx, 2 + abs(dx), W1)
    elif name == 'rain':
        for k in range(4):
            c.line(2 + k * 4, 2 + (k % 2) * 3, 2 + k * 4, 9 + (k % 2) * 3, W1)
            c.put(2 + k * 4, 10 + (k % 2) * 3, W2)
    elif name == 'trap':
        for k in range(5):
            c.poly([(2 + k * 3, 10), (3 + k * 3, 6), (4 + k * 3, 10)], W1)
        c.hline(1, 15, 11, W2)
        c.hline(1, 15, 12, W3)
    elif name == 'backstep':
        c.line(13, 8, 3, 8, W1)
        c.poly([(1, 8), (5, 4), (5, 12)], W1)
        c.line(14, 5, 14, 11, W3)
    elif name == 'vine':
        for t in range(0, 40):
            c.put(2 + t * 0.3, 14 - t * 0.3 + math.sin(t * 0.6) * 2, W1)
        c.disc(5, 9, 1.5, W2)
        c.disc(11, 5, 1.5, W2)
    elif name == 'burst':
        for k in range(8):
            a = k / 8 * math.tau
            c.line(8, 8, 8 + math.cos(a) * 7, 8 + math.sin(a) * 7, W1 if k % 2 else W2)
        c.disc(8, 8, 2.5, W1)
    elif name == 'bird':
        c.poly([(1, 6), (8, 9), (15, 6), (8, 12)], W1)
        c.disc(8, 9, 1.5, W2)
    elif name == 'beam':
        c.rect(1, 6, 14, 4, W2)
        c.hline(1, 15, 8, W1)
        c.disc(2, 8, 2.5, W1)
    elif name == 'orb':
        c.disc(10, 6, 4, W1)
        c.line(1, 14, 7, 9, W2)
        c.line(3, 14, 8, 10, W3)
    elif name == 'step':
        c.ellipse(5, 10, 2, 3.5, W1)
        c.ellipse(11, 5, 2, 3.5, W2)
    elif name == 'dagger':
        c.thick_line(4, 12, 12, 4, W1, 2)
        c.line(3, 9, 7, 13, W2)
    elif name == 'flurry':
        for k in range(3):
            c.line(2 + k * 2, 13 - k * 4, 13, 9 - k * 4, W1 if k != 1 else W2)
    elif name == 'fang':
        c.poly([(3, 3), (7, 3), (5, 13)], W1)
        c.poly([(9, 3), (13, 3), (11, 13)], W1)
    elif name == 'smoke':
        for (x, y, rr) in ((5, 10, 3.5), (10, 9, 4), (8, 5, 3)):
            c.disc(x, y, rr, W2)
        c.disc(7, 8, 2, W1)
    elif name == 'knives':
        for k in range(8):
            a = k / 8 * math.tau
            c.line(8 + math.cos(a) * 3, 8 + math.sin(a) * 3, 8 + math.cos(a) * 7, 8 + math.sin(a) * 7, W1)
    elif name == 'clone':
        c.disc(5, 5, 2.5, W3)
        c.rect(3, 8, 5, 6, W3)
        c.disc(10, 5, 2.5, W1)
        c.rect(8, 8, 5, 6, W1)
    elif name == 'ice':
        c.poly([(8, 1), (11, 8), (8, 15), (5, 8)], W1)
        c.line(2, 8, 14, 8, W2)
    elif name == 'lotus':
        for k in range(5):
            a = math.pi + k * math.pi / 4
            c.poly([(8, 12), (8 + math.cos(a - 0.3) * 6, 12 + math.sin(a - 0.3) * 6),
                    (8 + math.cos(a) * 8, 12 + math.sin(a) * 8), (8 + math.cos(a + 0.3) * 6, 12 + math.sin(a + 0.3) * 6)],
                   W1 if k % 2 else W2)
    elif name == 'meteor':
        c.disc(10, 10, 4, W1)
        c.line(1, 1, 7, 7, W2)
        c.line(3, 1, 8, 6, W3)
        c.line(1, 3, 6, 8, W3)
    elif name == 'tornado':
        for k in range(6):
            w = 7 - k
            c.hline(8 - w + (k % 2), 8 + w + (k % 2), 2 + k * 2, W1 if k % 2 else W2)
    elif name == 'rock':
        c.poly([(3, 12), (4, 6), (8, 3), (13, 6), (12, 13)], W2)
        c.line(5, 7, 9, 5, W1)
    elif name == 'blink':
        c.disc(4, 11, 2, W3)
        c.disc(12, 4, 2.5, W1)
        for k in range(3):
            c.put(6 + k * 2, 9 - k * 2, W2)
    elif name == 'nova':
        for rr in (3, 6):
            for a in range(0, 360, 10):
                r = math.radians(a)
                c.put(8 + math.cos(r) * rr, 8 + math.sin(r) * rr, W1 if rr == 6 else W2)
    elif name == 'prism':
        c.poly([(8, 2), (13, 12), (3, 12)], W2)
        c.line(1, 7, 7, 8, W1)
        c.line(10, 8, 15, 6, W1)
        c.line(10, 9, 15, 10, W1)
    elif name == 'vortex':
        for t in range(0, 70):
            a = -t * 0.22
            rr = t * 0.1
            c.put(8 + math.cos(a) * rr, 8 + math.sin(a) * rr, W1 if t > 30 else W3)
        c.disc(8, 8, 1.5, W1)
    elif name == 'quake':
        c.line(1, 8, 5, 6, W1)
        c.line(5, 6, 8, 10, W1)
        c.line(8, 10, 11, 5, W1)
        c.line(11, 5, 15, 9, W1)
        c.hline(1, 15, 14, W3)
    elif name == 'cross':
        c.rect(7, 2, 3, 12, W1)
        c.rect(3, 5, 11, 3, W1)
    elif name == 'heart':
        c.disc(5.5, 6, 3, W1)
        c.disc(10.5, 6, 3, W1)
        c.poly([(2.5, 7), (13.5, 7), (8, 14)], W1)
    elif name == 'wing':
        c.poly([(2, 13), (4, 4), (14, 2), (10, 8), (12, 10)], W2)
        c.line(4, 12, 12, 4, W1)
    elif name == 'eye':
        c.ellipse(8, 8, 7, 4, W2)
        c.disc(8, 8, 2.5, W1)
        c.put(8, 8, W3)
    elif name == 'boot':
        c.rect(4, 2, 5, 9, W1)
        c.rect(4, 10, 10, 4, W1)
        c.line(1, 6, 3, 6, W3)
        c.line(1, 9, 3, 9, W3)
    elif name == 'clover':
        for (x, y) in ((8, 4), (4, 8), (12, 8), (8, 11)):
            c.disc(x, y, 2.6, W1)
        c.line(8, 9, 10, 15, W2)
    elif name == 'star':
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            rr = 7 if k % 2 == 0 else 3
            pts.append((8 + math.cos(a) * rr, 8 + math.sin(a) * rr))
        c.poly(pts, W1)
    elif name == 'book':
        c.rect(3, 3, 10, 11, W2)
        c.vline(8, 3, 13, W3)
        c.hline(4, 7, 6, W1)
        c.hline(9, 12, 6, W1)
    elif name == 'hourglass':
        c.poly([(3, 2), (13, 2), (8, 8)], W1)
        c.poly([(8, 8), (13, 14), (3, 14)], W2)
    elif name == 'plus':
        c.rect(6, 2, 4, 12, W1)
        c.rect(2, 6, 12, 4, W1)
    elif name == 'chest':
        c.rect(2, 6, 12, 8, W2)
        c.rect(2, 3, 12, 4, W1)
        c.rect(7, 6, 2, 3, W3)
    elif name == 'pick':
        c.line(3, 14, 11, 6, W2)
        for a in range(200, 340, 8):
            r = math.radians(a)
            c.put(10 + math.cos(r) * 6, 9 + math.sin(r) * 6, W1)
    elif name == 'apple':
        c.disc(8, 9, 5, W1)
        c.line(8, 4, 10, 1, W2)
    elif name == 'dash':
        c.poly([(6, 4), (14, 8), (6, 12)], W1)
        for y in (5, 8, 11):
            c.hline(1, 4, y, W3)
    elif name == 'drop':
        c.poly([(8, 1), (13, 10), (8, 14), (3, 10)], W2)
        c.disc(8, 10, 4, W2)
        c.put(6, 9, W1)
    elif name == 'leaf':
        c.poly([(2, 14), (5, 5), (14, 2), (11, 11)], W2)
        c.line(2, 14, 12, 4, W1)
    elif name == 'sun':
        c.disc(8, 8, 3.5, W1)
        for k in range(8):
            a = k / 8 * math.tau
            c.line(8 + math.cos(a) * 5, 8 + math.sin(a) * 5, 8 + math.cos(a) * 7, 8 + math.sin(a) * 7, W2)
    elif name == 'moon':
        c.disc(8, 8, 6, W1)
        c.disc(11, 6, 5, CLEAR)
    elif name == 'hammer':
        c.line(3, 14, 9, 8, W2)
        c.poly([(7, 2), (14, 9), (11, 12), (4, 5)], W1)
    elif name == 'bow':
        for a in range(-60, 61, 6):
            r = math.radians(a)
            c.put(4 + math.cos(r) * 9, 8 + math.sin(r) * 7, W1)
        c.line(8, 2, 8, 14, W3)
    elif name == 'wand':
        c.line(3, 13, 10, 6, W2)
        c.disc(11.5, 4.5, 2.6, W1)
    elif name == 'blood':
        c.poly([(8, 2), (12, 9), (8, 14), (4, 9)], W1)
        c.put(7, 8, W3)
    elif name == 'rage':
        c.poly([(9, 1), (4, 9), (8, 9), (6, 15), (12, 6), (8, 6)], W1)
    elif name == 'elements':
        for k, (x, y) in enumerate(((8, 3), (13, 8), (8, 13), (3, 8))):
            c.disc(x, y, 2.2, W1 if k % 2 else W2)
    elif name == 'mark':
        for a in range(0, 360, 10):
            r = math.radians(a)
            c.put(8 + math.cos(r) * 6, 8 + math.sin(r) * 6, W1)
        c.line(8, 1, 8, 15, W2)
        c.line(1, 8, 15, 8, W2)
    elif name == 'mana':
        c.poly([(8, 1), (14, 8), (8, 15), (2, 8)], W2)
        c.poly([(8, 4), (11, 8), (8, 12), (5, 8)], W1)
    elif name == 'angel':
        c.disc(8, 5, 2.5, W1)
        c.poly([(5, 8), (11, 8), (12, 15), (4, 15)], W1)
        c.poly([(5, 8), (1, 5), (2, 11)], W2)
        c.poly([(11, 8), (15, 5), (14, 11)], W2)
        c.hline(6, 10, 1, W3)
    else:
        c.disc(8, 8, 5, W1)
    return fin(c, outline=False)


GLYPHS = ['sword', 'slash', 'shield', 'shout', 'whirl', 'spikes', 'flame', 'leap', 'bubble', 'skull', 'arrow',
          'arrows3', 'rain', 'trap', 'backstep', 'vine', 'burst', 'bird', 'beam', 'orb', 'step', 'dagger', 'flurry',
          'fang', 'smoke', 'knives', 'clone', 'ice', 'lotus', 'meteor', 'tornado', 'rock', 'blink', 'nova', 'prism',
          'vortex', 'quake', 'cross', 'heart', 'wing', 'eye', 'boot', 'clover', 'star', 'book', 'hourglass', 'plus',
          'chest', 'pick', 'apple', 'dash', 'drop', 'leaf', 'sun', 'moon', 'hammer', 'bow', 'wand', 'blood', 'rage',
          'elements', 'mark', 'mana', 'angel']


# ------------------------------------------------------------------ held weapons (point right)
def held_weapons():
    out = {}
    c = Canvas(22, 8)
    c.thick_line(6, 4, 20, 4, hx('e4e8ef'), 2)
    c.hline(7, 20, 3, hx('ffffff'))
    c.vline(5, 1, 6, hx('feae34'))
    c.hline(1, 4, 4, hx('733e39'))
    out['sword'] = c
    c = Canvas(30, 8)
    c.hline(0, 23, 4, hx('8a5a3a'))
    c.hline(0, 23, 3, hx('b86f50'))
    c.poly([(23, 1), (29, 4), (23, 7)], hx('c0cbdc'))
    out['spear'] = c
    c = Canvas(22, 14)
    c.thick_line(0, 7, 14, 7, hx('733e39'), 2)
    c.rect(14, 1, 7, 12, hx('8b9bb4'))
    c.vline(14, 1, 12, hx('c0cbdc'))
    out['hammer'] = c
    c = Canvas(14, 6)
    c.thick_line(5, 3, 12, 3, hx('e4e8ef'), 1.5)
    c.put(13, 3, hx('ffffff'))
    c.vline(4, 1, 5, hx('feae34'))
    c.hline(0, 3, 3, hx('3e2731'))
    out['dagger'] = c
    c = Canvas(18, 8)
    c.thick_line(0, 4, 12, 4, hx('733e39'), 2)
    c.disc(14, 4, 2.8, hx('2ce8f5'))
    c.put(14, 3, hx('ffffff'))
    out['wand'] = c
    c = Canvas(12, 12)
    c.rect(1, 1, 10, 10, hx('68386c'))
    c.rect(9, 2, 1, 8, hx('ead4aa'))
    c.disc(5, 6, 2, hx('feae34'))
    out['grimoire'] = c
    c = Canvas(10, 24)
    for y in range(1, 23):
        x = 2 + int(5 * math.sin((y - 1) / 22 * math.pi))
        c.put(x, y, hx('8a5a3a'))
        c.put(x + 1, y, hx('b86f50'))
    c.vline(2, 1, 22, hx('e4e8ef'))
    out['bow'] = c
    c = Canvas(18, 10)
    c.rect(4, 2, 13, 3, hx('5a6988'))
    c.hline(4, 16, 2, hx('8b9bb4'))
    c.rect(2, 4, 4, 5, hx('733e39'))
    out['gun'] = c
    for k in out:
        out[k].outline()
    return out


# ------------------------------------------------------------------ fx textures
def fx_textures():
    out = {}
    c = Canvas(32, 32)
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - 15.5, y - 15.5) / 16
            a = max(0.0, 1 - d)
            if a > 0:
                c.px[x, y] = (255, 255, 255, int(255 * a ** 1.6))
    out['soft'] = c
    c = Canvas(64, 64)
    for y in range(64):
        for x in range(64):
            d = math.hypot(x - 31.5, y - 31.5) / 32
            a = max(0.0, 1 - d)
            if a > 0:
                c.px[x, y] = (255, 255, 255, int(255 * a ** 1.2))
    out['light'] = c
    c = Canvas(8, 8)
    c.vline(3, 0, 7, W1)
    c.hline(0, 7, 3, W1)
    c.put(3, 3, W1)
    out['spark'] = c
    c = Canvas(4, 4)
    c.rect(0, 0, 4, 4, W1)
    out['px'] = c
    c = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5) / 8
            if d < 1:
                c.px[x, y] = (230, 230, 240, int(200 * (1 - d ** 2)))
    out['smoke'] = c
    c = Canvas(64, 64)
    for y in range(64):
        for x in range(64):
            d = math.hypot(x - 31.5, y - 31.5)
            if 27 < d < 31:
                c.px[x, y] = (255, 255, 255, 255 if 28 < d < 30 else 140)
    out['ring'] = c
    c = Canvas(16, 8)
    for y in range(8):
        for x in range(16):
            d = ((x - 7.5) / 8) ** 2 + ((y - 3.5) / 4) ** 2
            if d < 1:
                c.px[x, y] = (0, 0, 0, int(110 * (1 - d * 0.5)))
    out['shadow'] = c
    # projectiles (white-ish so they can be tinted) & colored ones
    c = Canvas(14, 5)
    c.hline(0, 11, 2, hx('b86f50'))
    c.poly([(10, 0), (13, 2), (10, 4)], hx('e4e8ef'))
    c.put(0, 1, hx('e43b44'))
    c.put(0, 3, hx('e43b44'))
    c.put(1, 1, hx('e43b44'))
    c.put(1, 3, hx('e43b44'))
    out['arrow'] = c
    c = Canvas(6, 4)
    c.rect(0, 1, 6, 2, hx('fee761'))
    c.put(5, 1, W1)
    out['bullet'] = c
    c = Canvas(12, 12)
    c.disc(6, 6, 5.5, (255, 255, 255, 110))
    c.disc(6, 6, 3.5, (255, 255, 255, 220))
    c.disc(6, 6, 2, W1)
    out['bolt'] = c
    c = Canvas(16, 16)
    c.disc(8, 8, 7, hx('be2633'))
    c.disc(8, 8, 5, hx('f77622'))
    c.disc(9, 7, 3, hx('fee761'))
    out['fireball'] = c
    c = Canvas(18, 6)
    c.poly([(0, 3), (12, 0), (17, 3), (12, 5)], hx('8fd3ff'))
    c.line(2, 3, 16, 3, W1)
    out['ice'] = c
    c = Canvas(10, 10)
    c.ellipse(5, 5, 4.5, 4, None, R('#9a7050'))
    c.outline()
    out['rock'] = c
    c = Canvas(16, 10)
    for a in range(-70, 71, 5):
        r = math.radians(a)
        c.put(4 + math.cos(r) * 9, 5 + math.sin(r) * 4.5, W1)
        c.put(4 + math.cos(r) * 7, 5 + math.sin(r) * 3.5, W2)
    out['crescent'] = c
    c = Canvas(10, 4)
    c.hline(3, 9, 1, hx('e4e8ef'))
    c.hline(3, 8, 2, hx('8b9bb4'))
    c.hline(0, 2, 1, hx('3e2731'))
    out['knife'] = c
    c = Canvas(16, 48)
    c.rect(6, 0, 4, 34, hx('fff6c8'))
    c.vline(7, 0, 33, W1)
    c.poly([(6, 34), (10, 34), (8, 44)], hx('fff6c8'))
    c.rect(1, 34 - 34, 0, 0, W1)
    c.rect(2, 0, 12, 3, hx('feae34'))
    c.rect(7, -6 + 6, 2, 0, W1)
    c.outline()
    # flip so blade points down
    c.img = c.img.transpose(Image.FLIP_TOP_BOTTOM)
    c.px = c.img.load()
    out['holy_sword'] = c
    c = Canvas(28, 28)
    c.disc(14, 14, 11, hx('be2633'))
    c.disc(14, 14, 8, hx('f77622'))
    c.disc(12, 12, 5, hx('fee761'))
    c.disc(11, 11, 2, W1)
    out['meteor'] = c
    c = Canvas(12, 12)
    c.disc(6, 6, 5.5, hx('3b1f5c'))
    c.disc(6, 6, 3.5, hx('9b5de5'))
    c.disc(5, 5, 1.5, hx('e0c8ff'))
    out['dark_orb'] = c
    c = Canvas(10, 10)
    for a in range(0, 360, 30):
        r = math.radians(a)
        c.put(5 + math.cos(r) * 4, 5 + math.sin(r) * 4, hx('fff6c8'))
    c.disc(5, 5, 2.5, W1)
    out['holy_orb'] = c
    c = Canvas(12, 8)
    c.poly([(0, 6), (5, 0), (11, 2), (7, 7)], hx('63c74d'))
    c.line(1, 6, 10, 2, hx('3e8948'))
    out['leaf'] = c
    c = Canvas(12, 12)
    for a in range(0, 360, 10):
        r = math.radians(a)
        c.put(6 + math.cos(r) * 5, 6 + math.sin(r) * 5, hx('bfe8ff'))
    c.put(4, 4, W1)
    out['bubble'] = c
    c = Canvas(14, 14)
    c.thick_line(2, 12, 11, 3, hx('e4e8ef'), 2)
    c.disc(2, 12, 1.6, W1)
    c.disc(11, 3, 1.6, W1)
    out['bone'] = c
    c = Canvas(16, 16)
    for k in range(3):
        c.poly([(1 + k * 5, 15), (3 + k * 5, 2 + (k % 2) * 4), (5 + k * 5, 15)], R('#9a7050')[1 + k % 2])
    c.outline()
    out['spike_rock'] = c
    c = Canvas(12, 16)
    c.poly([(6, 0), (11, 8), (6, 15), (1, 8)], hx('8fd3ff'))
    c.line(6, 1, 6, 14, W1)
    c.outline()
    out['ice_spike'] = c
    c = Canvas(24, 24)
    for y in range(24):
        for x in range(24):
            d = math.hypot(x - 11.5, y - 11.5) / 12
            if d < 1:
                c.px[x, y] = (120, 200, 90, int(150 * (1 - d ** 1.5)))
    out['gas'] = c
    return out


def build_all(out_dir, manifest):
    os.makedirs(out_dir, exist_ok=True)
    icons = build_item_icons()
    names = list(icons)
    cols = 16
    rows = (len(names) + cols - 1) // cols
    atlas = Image.new('RGBA', (cols * S, rows * S), CLEAR)
    idx = {}
    for i, n in enumerate(names):
        atlas.alpha_composite(icons[n].img, ((i % cols) * S, (i // cols) * S))
        idx[n] = [i % cols, i // cols]
    atlas.save(os.path.join(out_dir, 'items.png'))
    manifest['item_icons'] = {'path': 'res://assets/sprites/ui/items.png', 'size': S, 'index': idx}
    atlas = Image.new('RGBA', (cols * S, ((len(GLYPHS) + cols - 1) // cols) * S), CLEAR)
    idx = {}
    for i, n in enumerate(GLYPHS):
        atlas.alpha_composite(glyph(n).img, ((i % cols) * S, (i // cols) * S))
        idx[n] = [i % cols, i // cols]
    atlas.save(os.path.join(out_dir, 'glyphs.png'))
    manifest['glyphs'] = {'path': 'res://assets/sprites/ui/glyphs.png', 'size': S, 'index': idx}
    wdir = os.path.join(out_dir, '..', 'weapons')
    os.makedirs(wdir, exist_ok=True)
    wm = {}
    for n, cv in held_weapons().items():
        cv.img.save(os.path.join(wdir, n + '.png'))
        wm[n] = {'path': 'res://assets/sprites/weapons/' + n + '.png', 'w': cv.w, 'h': cv.h}
    manifest['weapons'] = wm
    fdir = os.path.join(out_dir, '..', 'fx')
    os.makedirs(fdir, exist_ok=True)
    fm = {}
    for n, cv in fx_textures().items():
        cv.img.save(os.path.join(fdir, n + '.png'))
        fm[n] = {'path': 'res://assets/sprites/fx/' + n + '.png', 'w': cv.w, 'h': cv.h}
    manifest['fx'] = fm
