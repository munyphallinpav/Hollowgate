"""Tiny pixel-art toolkit used to generate all Hollowgate sprites.

Everything is drawn procedurally with PIL so the art can be regenerated or
tweaked by editing these scripts (python3 tools/art/build_all.py).
"""
import math
import random
from PIL import Image

# ---------------------------------------------------------------- colors
def hx(s):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def clamp(v, a=0, b=255):
    return max(a, min(b, int(round(v))))


def mix(c1, c2, t):
    return tuple(clamp(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (c1[3] if len(c1) > 3 else 255,)


def shade(c, amt):
    """amt < 0 darkens with a cool hue shift, amt > 0 lightens with a warm shift."""
    r, g, b = c[0], c[1], c[2]
    a = c[3] if len(c) > 3 else 255
    if amt < 0:
        t = -amt
        tgt = (30, 18, 52)
        return (clamp(r + (tgt[0] - r) * t), clamp(g + (tgt[1] - g) * t), clamp(b + (tgt[2] - b) * t * 0.8), a)
    t = amt
    tgt = (255, 248, 220)
    return (clamp(r + (tgt[0] - r) * t), clamp(g + (tgt[1] - g) * t), clamp(b + (tgt[2] - b) * t), a)


def ramp(base, n=4):
    """Return [darkest .. lightest] shades of base."""
    b = hx(base) if isinstance(base, str) else base
    if n == 3:
        return [shade(b, -0.35), b, shade(b, 0.3)]
    if n == 4:
        return [shade(b, -0.55), shade(b, -0.25), b, shade(b, 0.32)]
    return [shade(b, -0.6), shade(b, -0.35), shade(b, -0.12), b, shade(b, 0.25), shade(b, 0.5)][:n]


OUTLINE = hx('181425')
CLEAR = (0, 0, 0, 0)

ELEMENT_COLORS = {
    'light': '#ffe98a', 'dark': '#9b5de5', 'fire': '#ff6a2a',
    'water': '#3fa9f5', 'earth': '#c08a4a', 'wind': '#6ee7a8', 'none': '#d8dee9',
}


# ---------------------------------------------------------------- canvas
class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new('RGBA', (w, h), CLEAR)
        self.px = self.img.load()

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            if len(c) == 4 and c[3] < 255:
                if c[3] == 0:
                    return
                base = self.px[x, y]
                if base[3] == 0:
                    self.px[x, y] = c
                else:
                    t = c[3] / 255.0
                    self.px[x, y] = (clamp(base[0] + (c[0] - base[0]) * t), clamp(base[1] + (c[1] - base[1]) * t),
                                     clamp(base[2] + (c[2] - base[2]) * t), 255)
            else:
                self.px[x, y] = c if len(c) == 4 else c + (255,)

    def erase(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = CLEAR

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.put(xx, yy, c)

    def hline(self, x0, x1, y, c):
        for x in range(int(min(x0, x1)), int(max(x0, x1)) + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(int(min(y0, y1)), int(max(y0, y1)) + 1):
            self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def thick_line(self, x0, y0, x1, y1, c, t=2):
        r = t / 2.0
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(steps + 1):
            px = x0 + (x1 - x0) * i / steps
            py = y0 + (y1 - y0) * i / steps
            self.disc(px, py, r, c)

    def disc(self, cx, cy, r, c):
        for yy in range(int(cy - r - 1), int(cy + r + 2)):
            for xx in range(int(cx - r - 1), int(cx + r + 2)):
                if (xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= r * r:
                    self.put(xx, yy, c)

    def ellipse(self, cx, cy, rx, ry, c, shade_ramp=None, light=(-0.6, -0.7)):
        """Filled ellipse. If shade_ramp is given, shade by a light direction."""
        lx, ly = light
        for yy in range(int(cy - ry - 1), int(cy + ry + 2)):
            for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
                nx = (xx + 0.5 - cx) / max(rx, 0.01)
                ny = (yy + 0.5 - cy) / max(ry, 0.01)
                d = nx * nx + ny * ny
                if d <= 1.0:
                    if shade_ramp:
                        # simple lambert: dot of normal with light
                        nz = math.sqrt(max(0.0, 1 - d))
                        lit = (nx * lx + ny * ly + nz * 0.55)
                        n = len(shade_ramp)
                        idx = int((lit + 0.55) / 1.6 * n)
                        idx = max(0, min(n - 1, idx))
                        self.put(xx, yy, shade_ramp[idx])
                    else:
                        self.put(xx, yy, c)

    def poly(self, pts, c):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for yy in range(int(min(ys)), int(max(ys)) + 1):
            for xx in range(int(min(xs)), int(max(xs)) + 1):
                if point_in_poly(xx + 0.5, yy + 0.5, pts):
                    self.put(xx, yy, c)

    def outline(self, col=None, factor=0.3, diagonal=False):
        """Selective outline: each empty pixel touching a filled one gets a darkened copy."""
        src = self.img.copy()
        sp = src.load()
        nbrs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            nbrs += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
        for y in range(self.h):
            for x in range(self.w):
                if sp[x, y][3] != 0:
                    continue
                best = None
                for dx, dy in nbrs:
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and sp[xx, yy][3] > 0:
                        best = sp[xx, yy]
                        break
                if best is not None:
                    if col is not None:
                        self.px[x, y] = col
                    else:
                        d = shade(best, -0.78)
                        self.px[x, y] = (clamp(d[0] * factor + OUTLINE[0] * (1 - factor)),
                                         clamp(d[1] * factor + OUTLINE[1] * (1 - factor)),
                                         clamp(d[2] * factor + OUTLINE[2] * (1 - factor)), 255)

    def paste(self, other, x, y):
        self.img.alpha_composite(other.img if isinstance(other, Canvas) else other, (int(x), int(y)))
        self.px = self.img.load()

    def flipped(self):
        c = Canvas(self.w, self.h)
        c.img = self.img.transpose(Image.FLIP_LEFT_RIGHT)
        c.px = c.img.load()
        return c

    def recolor(self, mapping):
        for y in range(self.h):
            for x in range(self.w):
                p = self.px[x, y]
                if p[3] and p[:3] in mapping:
                    self.px[x, y] = mapping[p[:3]] + (p[3],)


def point_in_poly(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
            inside = not inside
        j = i
    return inside


# ---------------------------------------------------------------- sheets
class Sheet:
    """Collects animation frames into a sprite sheet + manifest entry.

    Rows = animations (optionally per direction), cols = frames.
    """

    def __init__(self, name, fw, fh):
        self.name, self.fw, self.fh = name, fw, fh
        self.anims = []  # (anim_name, [Canvas], fps, loop)

    def add(self, anim, frames, fps=8, loop=True):
        self.anims.append((anim, frames, fps, loop))

    def save(self, path):
        cols = max(len(f) for _, f, _, _ in self.anims)
        img = Image.new('RGBA', (cols * self.fw, len(self.anims) * self.fh), CLEAR)
        meta = {'frame_w': self.fw, 'frame_h': self.fh, 'anims': {}}
        for row, (anim, frames, fps, loop) in enumerate(self.anims):
            for i, fr in enumerate(frames):
                img.alpha_composite(fr.img, (i * self.fw, row * self.fh))
            meta['anims'][anim] = {'row': row, 'count': len(frames), 'fps': fps, 'loop': loop}
        img.save(path)
        return meta


def rng(seed):
    return random.Random(seed)
