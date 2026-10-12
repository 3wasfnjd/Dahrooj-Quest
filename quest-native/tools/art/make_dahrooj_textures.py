"""Dahrooj's fur map and face drawings, ported from the web game's canvas code
(src/reference/character.js furMap and src/reference/face.js drawFace).
python3 make_dahrooj_textures.py <quest-native/assets/character>

Drawn at 4x and downsampled, as the canvas would antialias."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "../../assets/character")
os.makedirs(OUT, exist_ok=True)
INK = (0x2c, 0x2d, 0x3d)


def fur_map():
    w, h, k = 512, 256, 4
    base = Image.new("RGBA", (w * k, h * k), (0xf4, 0xf4, 0xf4, 255))
    # Grey patches (blurred), wrapped around u so the seam does not show.
    patches = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(patches)
    for (x, y, rx, ry, a) in [(.35, .46, .125, .28, .1), (.075, .56, .06, .2, 0), (.72, .5, .09, .22, -.2), (.88, .72, .06, .12, .3)]:
        for dx in (-w, 0, w):
            pts = []
            for i in range(33):
                t = i / 32 * math.pi * 2
                q = 1 + .08 * math.sin(t * 3 + x * 9) + .05 * math.sin(t * 7 + y * 7)
                px, py = math.cos(t) * rx * w * q, math.sin(t) * ry * h * q
                cx = px * math.cos(a) - py * math.sin(a) + x * w + dx
                cy = px * math.sin(a) + py * math.cos(a) + y * h
                pts.append((cx * k, cy * k))
            d.polygon(pts, fill=(0xad, 0xad, 0xad, 255))
    patches = patches.filter(ImageFilter.GaussianBlur(4 * k))
    base.alpha_composite(patches)
    # 2000 short fibres.
    fib = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    for i in range(2000):
        x, y, a = (i * 137.51) % w, (i * 53.71) % h, math.sin(i * 2.3) * .8
        col = (255, 255, 255, int(.30 * 255)) if i % 3 else (40, 40, 40, int(.12 * 255))
        one = Image.new("RGBA", (1, 1))
        dd = ImageDraw.Draw(fib)
        dd.line([(x * k, y * k), ((x + math.sin(a) * 4) * k, (y + 3 + math.cos(a) * 3) * k)], fill=col, width=int(1.1 * k))
    base.alpha_composite(fib)
    base.resize((w, h), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, "fur.png"))


FACE_SPAN = math.pi * .62


def face(name):
    """The drawn part of a face (mouth, blush, drawn eyes); 3D eyes cover open/focus/wide/joy."""
    size, k = 256, 4
    S = size * k
    R = size / 2 / (FACE_SPAN / 2) * .97 * k
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    c = ImageDraw.Draw(im)
    ox = oy = S / 2
    P = lambda x, y: (ox + x, oy + y)
    no_eyes = name in ("open", "focus", "wide", "joy")
    er, ex, ey = R * .19, R * .31, -R * .08
    blush = .25

    def arc_stroke(cx, cy, rx, ry, a0, a1, width, col, steps=40):
        pts = [P(cx + math.cos(a0 + (a1 - a0) * i / steps) * rx, cy + math.sin(a0 + (a1 - a0) * i / steps) * ry) for i in range(steps + 1)]
        c.line(pts, fill=col, width=int(width), joint="curve")
        for p in (pts[0], pts[-1]):
            c.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=col)

    if not no_eyes:
        for side in (-1, 1):
            x = side * ex
            if name == "closed":
                s = 1 if x < 0 else -1
                pts = [P(x - er * .6 * s, ey - er * .6), P(x + er * .45 * s, ey), P(x - er * .6 * s, ey + er * .6)]
                c.line(pts, fill=INK, width=int(er * .42), joint="curve")
            elif name in ("squint", "laugh"):
                pts = []
                for i in range(21):  # quadratic curve
                    t = i / 20
                    p0, p1, p2 = (x - er * .75, ey + er * .35), (x, ey - er * .75), (x + er * .75, ey + er * .35)
                    pts.append(P((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
                c.line(pts, fill=INK, width=int(er * .42), joint="curve")
    if name == "wide":
        c.ellipse([*P(-R * .07, R * .32 - R * .09), *P(R * .07, R * .32 + R * .09)], fill=INK)
    if name == "joy":
        arc_stroke(0, R * .1, R * .24, R * .24, math.pi * .18, math.pi * .82, max(1.2 * k, R * .07), INK)
    if name == "laugh":
        my, mw, mh = R * .2, R * .27, R * .24
        mouth = Image.new("L", (S, S), 0)
        md = ImageDraw.Draw(mouth)
        pts = [P(-mw, my)] + [P(math.cos(math.pi * i / 30) * mw * (1 if True else 1), my + math.sin(math.pi * i / 30) * mh) for i in range(31)]
        pts = [P(math.cos(math.pi * i / 30) * mw, my + math.sin(math.pi * i / 30) * mh) for i in range(31)]
        md.polygon(pts, fill=255)
        layer = Image.new("RGBA", (S, S), (0x4a, 0x17, 0x12, 255))
        tongue = ImageDraw.Draw(layer)
        tongue.ellipse([*P(-mw * .6, my + mh * .95 - mh * .45), *P(mw * .6, my + mh * .95 + mh * .45)], fill=(0xd8, 0x50, 0x5a, 255))
        im.paste(layer, (0, 0), mouth)
    if name in ("joy", "laugh"):
        blush = .9
    bl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bl)
    for side in (-1, 1):
        cx, cy = side * R * .55, R * .2
        bd.ellipse([*P(cx - R * .13, cy - R * .07), *P(cx + R * .13, cy + R * .07)], fill=(200, 60, 50, int(255 * .35 * blush)))
    im.alpha_composite(bl)
    im.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, "face_%s.png" % name))


fur_map()
for n in ("open", "focus", "wide", "joy", "closed", "squint", "laugh"):
    face(n)
print("dahrooj textures written to", OUT)
