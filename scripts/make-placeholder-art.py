#!/usr/bin/env python3
"""Deterministic cartoon placeholders for the layered portrait slot.

A stylized 3D-cartoon approximation: rounded shapes, soft key light, rim light,
ambient occlusion and big expressive eyes. Not final art. Drop real 1024x1024
PNGs over these names and the app picks them up without a code change.

    python3 scripts/make-placeholder-art.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 2048
OUT = 1024
ROOT = os.path.join(os.path.dirname(__file__), "..", "Resources", "Characters")
PAPER = (0xF6, 0xF0, 0xE4)
WHITE = (255, 255, 255)

PALETTES = {
    "silas": ((0x1B, 0x2A, 0x33), (0x2E, 0x5A, 0x6B), (0xC9, 0xA2, 0x27)),
    "morwenna": ((0x10, 0x33, 0x3A), (0x1F, 0x7A, 0x6E), (0x9F, 0xE3, 0xC8)),
    "mortlake": ((0x2A, 0x23, 0x18), (0x6B, 0x5A, 0x3E), (0xC9, 0xB4, 0x58)),
    "azgorath": ((0x24, 0x0F, 0x0F), (0x7A, 0x1F, 0x14), (0xE0, 0x66, 0x2B)),
    "fennick": ((0x1D, 0x2A, 0x1A), (0x5C, 0x8A, 0x3C), (0xD8, 0xC4, 0x6A)),
    "vyrmathrax": ((0x2A, 0x16, 0x08), (0x8A, 0x3A, 0x12), (0xE8, 0xA3, 0x3D)),
    "grub": ((0x24, 0x1E, 0x12), (0x6E, 0x5A, 0x2A), (0xA8, 0xB4, 0x5C)),
    "aldric": ((0x21, 0x1A, 0x2E), (0x4B, 0x3A, 0x78), (0xCB, 0xB2, 0x6A)),
    "snowqueen": ((0x14, 0x20, 0x2B), (0x4E, 0x7C, 0x96), (0xCF, 0xE6, 0xF2)),
    "bramwell": ((0x1B, 0x24, 0x30), (0x3F, 0x5E, 0x7A), (0xD4, 0xAF, 0x37)),
    "godmother": ((0x2C, 0x1A, 0x26), (0x8A, 0x55, 0x70), (0xF2, 0xC6, 0xD8)),
    "thing": ((0x14, 0x10, 0x1C), (0x3A, 0x24, 0x50), (0x8F, 0xBF, 0x3F)),
}

TRAITS = {
    "silas": dict(hat="tricorn", hair="short", beard="short", ears="round", eyes="round"),
    "morwenna": dict(hat=None, hair="long", beard=None, ears="round", eyes="round"),
    "mortlake": dict(hat="wide", hair="short", beard="long", ears="round", eyes="round"),
    "azgorath": dict(hat=None, hair="bald", beard=None, ears="pointed", horns=True, eyes="slit"),
    "fennick": dict(hat=None, hair="short", beard=None, ears="pointed", eyes="round"),
    "vyrmathrax": dict(hat=None, hair="bald", beard=None, ears="pointed", horns=True, eyes="slit"),
    "grub": dict(hat=None, hair="topknot", beard=None, ears="big", tusks=True, eyes="round"),
    "aldric": dict(hat="wizard", hair="long", beard="long", ears="round", eyes="round"),
    "snowqueen": dict(hat="crown", hair="long", beard=None, ears="round", eyes="round"),
    "bramwell": dict(hat="helmet", hair="short", beard=None, ears="round", eyes="round"),
    "godmother": dict(hat="tiara", hair="bun", beard=None, ears="round", eyes="round"),
    "thing": dict(hat="hood", hair="bald", beard=None, ears="round", eyes="glow"),
}


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def darken(c, t):
    return mix(c, (0, 0, 0), t)


def lighten(c, t):
    return mix(c, (255, 255, 255), t)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def box(x0, y0, x1, y1):
    return [x0 * S, y0 * S, x1 * S, y1 * S]


def bez(p0, p1, p2, p3, n=40):
    points = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t * t * p2[0] + t ** 3 * p3[0]
        y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t * t * p2[1] + t ** 3 * p3[1]
        points.append((x * S, y * S))
    return points


def linear(size, top, bottom):
    image = Image.new("RGBA", size)
    draw = ImageDraw.Draw(image)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        draw.line([(0, y), (size[0], y)], fill=rgba(mix(top, bottom, t)))
    return image


def radial(size, inner, outer, center, radius):
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    cx, cy = center[0] * size[0], center[1] * size[1]
    r = radius * size[0]
    steps = 110
    for i in range(steps, -1, -1):
        t = i / steps
        rr = r * t
        draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=rgba(mix(inner, outer, 1 - t)))
    return image.filter(ImageFilter.GaussianBlur(3))


def mask():
    return Image.new("L", (S, S), 0)


def layer(mask_image, color):
    image = Image.new("RGBA", (S, S), rgba(color))
    image.putalpha(mask_image)
    return image


def soft_shadow(image, shape, color, blur, alpha, offset=(0, 0)):
    shadow = shape.filter(ImageFilter.GaussianBlur(blur))
    shadow = shadow.point(lambda v: v * alpha // 255)
    shadow = ImageChops.offset(shadow, *offset)
    image.alpha_composite(layer(shadow, color))


def gradient_polygon(image, points, top, bottom):
    shape = mask()
    ImageDraw.Draw(shape).polygon(points, fill=255)
    fill = linear((S, S), top, bottom)
    fill.putalpha(shape)
    image.alpha_composite(fill)


def rim_light(image, shape, color, blur=20, alpha=120, offset=(0.02, -0.01)):
    shifted = ImageChops.offset(shape, int(offset[0] * S), int(offset[1] * S))
    edge = ImageChops.subtract(shifted, shape).filter(ImageFilter.GaussianBlur(blur))
    edge = ImageChops.multiply(edge, shape).point(lambda v: v * alpha // 255)
    image.alpha_composite(layer(edge, color))


def body_points():
    points = []
    points += bez((0.02, 1.0), (0.04, 0.82), (0.14, 0.70), (0.28, 0.66))
    points += bez((0.28, 0.66), (0.38, 0.64), (0.44, 0.62), (0.50, 0.61))
    points += bez((0.50, 0.61), (0.56, 0.62), (0.62, 0.64), (0.72, 0.66))
    points += bez((0.72, 0.66), (0.86, 0.70), (0.96, 0.82), (0.98, 1.0))
    points += [(0.98 * S, 1.0 * S), (0.02 * S, 1.0 * S)]
    return points


def draw_body(image, ink, aura, accent):
    shape = mask()
    draw = ImageDraw.Draw(shape)
    draw.polygon(body_points(), fill=255)
    draw.rounded_rectangle(box(0.455, 0.52, 0.545, 0.68), radius=0.03 * S, fill=255)

    fill = linear((S, S), lighten(ink, 0.12), darken(ink, 0.48))
    fill.putalpha(shape)
    image.alpha_composite(fill)

    rim_light(image, shape, accent, blur=22, alpha=110, offset=(0.025, -0.012))

    chin = mask()
    ImageDraw.Draw(chin).ellipse(box(0.33, 0.50, 0.67, 0.67), fill=255)
    chin = ImageChops.multiply(chin, shape)
    soft_shadow(image, chin, (0, 0, 0), 34, 95, (0, 8))

    contact = mask()
    ImageDraw.Draw(contact).ellipse(box(0.16, 0.93, 0.84, 1.02), fill=110)
    soft_shadow(image, contact, (0, 0, 0), 34, 70, (0, 4))


def draw_collar(image, ink, aura, accent):
    points = [
        (0.30 * S, 0.66 * S),
        (0.42 * S, 0.60 * S),
        (0.50 * S, 0.64 * S),
        (0.58 * S, 0.60 * S),
        (0.70 * S, 0.66 * S),
        (0.66 * S, 0.80 * S),
        (0.34 * S, 0.80 * S),
    ]
    gradient_polygon(image, points, mix(ink, aura, 0.52), mix(ink, aura, 0.16))
    ImageDraw.Draw(image).line(
        [(0.42 * S, 0.64 * S), (0.50 * S, 0.70 * S), (0.58 * S, 0.64 * S)],
        fill=rgba(lighten(accent, 0.15), 120),
        width=5,
    )
    for x in (0.38, 0.44, 0.56, 0.62):
        ImageDraw.Draw(image).arc(
            box(x - 0.04, 0.70, x + 0.04, 0.90),
            start=250,
            end=290,
            fill=rgba(darken(ink, 0.25), 55),
            width=4,
        )


def draw_head(image, ink, aura, accent):
    shape = mask()
    ImageDraw.Draw(shape).ellipse(box(0.265, 0.095, 0.735, 0.625), fill=255)

    head = radial(
        (S, S),
        lighten(PAPER, 0.10),
        mix(PAPER, ink, 0.20),
        center=(0.40, 0.27),
        radius=0.38,
    )
    head.putalpha(shape)
    image.alpha_composite(head)

    shade = mask()
    ImageDraw.Draw(shade).ellipse(box(0.48, 0.30, 0.80, 0.66), fill=255)
    shade = ImageChops.multiply(shade, shape)
    soft_shadow(image, shade, ink, 40, 55)

    highlight = mask()
    ImageDraw.Draw(highlight).ellipse(box(0.33, 0.17, 0.55, 0.30), fill=70)
    highlight = ImageChops.multiply(highlight, shape)
    soft_shadow(image, highlight, WHITE, 26, 80)

    edge = shape.filter(ImageFilter.GaussianBlur(2))
    edge = ImageChops.subtract(shape, edge).point(lambda v: v * 90 // 255)
    image.alpha_composite(layer(edge, darken(ink, 0.2)))

    blush = mask()
    bd = ImageDraw.Draw(blush)
    bd.ellipse(box(0.335, 0.40, 0.445, 0.455), fill=55)
    bd.ellipse(box(0.555, 0.40, 0.665, 0.455), fill=55)
    blush = ImageChops.multiply(blush, shape).filter(ImageFilter.GaussianBlur(20))
    image.alpha_composite(layer(blush, mix(accent, PAPER, 0.22)))


def draw_ears(image, traits, ink):
    if traits["ears"] == "pointed":
        for x, direction in ((0.285, -1), (0.715, 1)):
            points = [
                (x * S, 0.33 * S),
                ((x + direction * 0.10) * S, 0.265 * S),
                ((x + direction * 0.005) * S, 0.435 * S),
            ]
            gradient_polygon(image, points, mix(PAPER, ink, 0.04), mix(PAPER, ink, 0.20))
            ImageDraw.Draw(image).line(
                [(x * S, 0.34 * S), ((x + direction * 0.055) * S, 0.30 * S)],
                fill=rgba(mix(ink, PAPER, 0.35), 160),
                width=5,
            )
    elif traits["ears"] == "big":
        for x in (0.245, 0.755):
            ellipse = box(x - 0.06, 0.30, x + 0.06, 0.46)
            ImageDraw.Draw(image).ellipse(ellipse, fill=rgba(mix(PAPER, ink, 0.06)))
            ImageDraw.Draw(image).ellipse(
                box(x - 0.032, 0.33, x + 0.032, 0.42),
                fill=rgba(mix(PAPER, ink, 0.16)),
            )


def draw_hair(image, traits, ink, aura):
    hair = traits["hair"]
    if hair in ("short", "long", "bun", "topknot"):
        cap = mask()
        draw = ImageDraw.Draw(cap)
        draw.ellipse(box(0.262, 0.075, 0.738, 0.42), fill=255)
        cut = mask()
        ImageDraw.Draw(cut).rectangle([0, 0, S, int(0.262 * S)], fill=255)
        cap = ImageChops.multiply(cap, cut).filter(ImageFilter.GaussianBlur(1))
        gradient = linear((S, S), mix(ink, aura, 0.34), darken(ink, 0.25))
        gradient.putalpha(cap)
        image.alpha_composite(gradient)

        highlight = mask()
        ImageDraw.Draw(highlight).arc(
            box(0.30, 0.10, 0.70, 0.36), start=200, end=340, fill=90, width=10
        )
        highlight = ImageChops.multiply(highlight, cap).filter(ImageFilter.GaussianBlur(10))
        image.alpha_composite(layer(highlight, lighten(aura, 0.25)))

        strands = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        sd = ImageDraw.Draw(strands)
        for x0, x1, y1 in ((0.30, 0.27, 0.42), (0.70, 0.73, 0.42), (0.34, 0.32, 0.34)):
            sd.line([(x0 * S, 0.20 * S), (x1 * S, y1 * S)], fill=rgba(darken(ink, 0.1), 150), width=6)
        image.alpha_composite(strands)

    if hair == "bun":
        bun = mask()
        ImageDraw.Draw(bun).ellipse(box(0.56, 0.055, 0.70, 0.195), fill=255)
        gradient = radial((S, S), mix(ink, aura, 0.35), darken(ink, 0.25), center=(0.63, 0.12), radius=0.10)
        gradient.putalpha(bun)
        image.alpha_composite(gradient)

    if hair == "topknot":
        knot = mask()
        draw = ImageDraw.Draw(knot)
        draw.ellipse(box(0.455, 0.03, 0.545, 0.12), fill=255)
        draw.rectangle(box(0.485, 0.11, 0.515, 0.15), fill=255)
        image.alpha_composite(layer(knot, darken(ink, 0.15)))


def draw_beard(image, traits, ink, accent):
    beard = traits["beard"]
    if not beard:
        return
    if beard == "long":
        points = [
            (0.395 * S, 0.475 * S),
            (0.605 * S, 0.475 * S),
            (0.60 * S, 0.66 * S),
            (0.50 * S, 0.75 * S),
            (0.40 * S, 0.66 * S),
        ]
    else:
        points = [
            (0.415 * S, 0.475 * S),
            (0.585 * S, 0.475 * S),
            (0.575 * S, 0.56 * S),
            (0.50 * S, 0.62 * S),
            (0.425 * S, 0.56 * S),
        ]
    gradient_polygon(image, points, mix(ink, accent, 0.18), darken(ink, 0.30))
    for x in (0.45, 0.50, 0.55):
        ImageDraw.Draw(image).line(
            [(x * S, 0.49 * S), (x * S, (0.61 if beard == "long" else 0.55) * S)],
            fill=rgba(accent, 85),
            width=4,
        )


def draw_accessory(image, traits, ink, aura, accent):
    hat = traits["hat"]
    draw = ImageDraw.Draw(image)

    if hat == "tricorn":
        points = [
            (0.24 * S, 0.235 * S),
            (0.33 * S, 0.10 * S),
            (0.50 * S, 0.045 * S),
            (0.67 * S, 0.10 * S),
            (0.76 * S, 0.235 * S),
            (0.50 * S, 0.185 * S),
        ]
        gradient_polygon(image, points, darken(ink, 0.05), darken(ink, 0.35))
        draw.line(points + [points[0]], fill=rgba(accent, 220), width=6)
        draw.ellipse(box(0.47, 0.15, 0.53, 0.19), fill=rgba(accent, 230))
        draw.ellipse(box(0.485, 0.158, 0.505, 0.172), fill=rgba(lighten(accent, 0.4)))

    elif hat == "wide":
        brim = box(0.20, 0.165, 0.80, 0.275)
        draw.ellipse(brim, fill=rgba(darken(ink, 0.12)))
        gradient_polygon(
            image,
            [
                (0.39 * S, 0.05 * S),
                (0.61 * S, 0.05 * S),
                (0.61 * S, 0.20 * S),
                (0.39 * S, 0.20 * S),
            ],
            darken(ink, 0.10),
            darken(ink, 0.32),
        )
        draw.rectangle(box(0.39, 0.175, 0.61, 0.205), fill=rgba(accent, 200))
        draw.arc(box(0.30, 0.17, 0.70, 0.29), start=200, end=340, fill=rgba(accent, 70), width=5)

    elif hat == "wizard":
        points = [(0.50 * S, 0.005 * S), (0.26 * S, 0.24 * S), (0.74 * S, 0.24 * S)]
        gradient_polygon(image, points, darken(ink, 0.05), darken(ink, 0.38))
        draw.line(points + [points[0]], fill=rgba(accent, 200), width=6)
        draw.ellipse(box(0.21, 0.215, 0.79, 0.285), fill=rgba(darken(ink, 0.22)))
        for x, y, r in ((0.42, 0.15, 0.009), (0.55, 0.10, 0.007), (0.48, 0.20, 0.006)):
            draw.ellipse(box(x - r, y - r, x + r, y + r), fill=rgba(lighten(accent, 0.2), 235))

    elif hat == "crown":
        draw.rectangle(box(0.35, 0.16, 0.65, 0.215), fill=rgba(accent, 235))
        for x, top in ((0.36, 0.07), (0.50, 0.045), (0.64, 0.07)):
            gradient_polygon(
                image,
                [(x * S, top * S), ((x - 0.035) * S, 0.17 * S), ((x + 0.035) * S, 0.17 * S)],
                lighten(accent, 0.25),
                accent,
            )
        draw.ellipse(box(0.47, 0.185, 0.53, 0.225), fill=rgba(lighten(accent, 0.35)))
        draw.ellipse(box(0.49, 0.192, 0.51, 0.208), fill=rgba(WHITE, 220))

    elif hat == "helmet":
        cap = mask()
        ImageDraw.Draw(cap).ellipse(box(0.255, 0.085, 0.745, 0.41), fill=255)
        gradient = radial((S, S), lighten(ink, 0.22), darken(ink, 0.30), center=(0.40, 0.16), radius=0.30)
        gradient.putalpha(cap)
        image.alpha_composite(gradient)
        draw.rectangle(box(0.28, 0.285, 0.72, 0.315), fill=rgba(accent, 210))
        draw.arc(box(0.31, 0.20, 0.69, 0.40), start=200, end=340, fill=rgba(ink, 220), width=6)
        draw.pieslice(box(0.45, 0.02, 0.55, 0.16), start=180, end=360, fill=rgba(accent, 215))
        draw.arc(box(0.32, 0.10, 0.68, 0.30), start=210, end=320, fill=rgba(WHITE, 70), width=8)

    elif hat == "tiara":
        draw.arc(box(0.34, 0.13, 0.66, 0.24), start=200, end=340, fill=rgba(accent, 220), width=6)
        for x in (0.40, 0.50, 0.60):
            draw.ellipse(box(x - 0.014, 0.132, x + 0.014, 0.160), fill=rgba(lighten(accent, 0.3)))
            draw.ellipse(box(x - 0.006, 0.138, x + 0.002, 0.146), fill=rgba(WHITE, 200))

    if traits.get("horns"):
        for side in (-1, 1):
            base = 0.5 + side * 0.18
            points = [
                (base * S, 0.20 * S),
                ((base + side * 0.115) * S, 0.005 * S),
                ((base + side * 0.015) * S, 0.075 * S),
                ((base + side * 0.04) * S, 0.21 * S),
            ]
            gradient_polygon(image, points, darken(ink, 0.15), mix(ink, accent, 0.35))
            draw.line(points[:2], fill=rgba(lighten(accent, 0.2), 210), width=5)

    if traits.get("tusks"):
        for side in (-1, 1):
            x = 0.5 + side * 0.055
            gradient_polygon(
                image,
                [(x * S, 0.455 * S), ((x + side * 0.018) * S, 0.455 * S), ((x + side * 0.006) * S, 0.50 * S)],
                lighten(PAPER, 0.25),
                mix(PAPER, accent, 0.2),
            )


def draw_face(image, traits, ink, aura, accent, mouth, eyes_closed):
    draw = ImageDraw.Draw(image)
    eye_y = 0.345

    # Brows: thick, tapered, expressive.
    for cx, side in ((0.435, -1), (0.565, 1)):
        points = [
            ((cx - 0.045) * S, (eye_y - 0.060) * S),
            ((cx + 0.045) * S, (eye_y - 0.052) * S),
            ((cx + 0.040) * S, (eye_y - 0.042) * S),
            ((cx - 0.040) * S, (eye_y - 0.050) * S),
        ]
        draw.polygon(points, fill=rgba(darken(ink, 0.08), 225))

    for cx in (0.435, 0.565):
        if eyes_closed:
            draw.arc(
                box(cx - 0.040, eye_y - 0.018, cx + 0.040, eye_y + 0.022),
                start=200,
                end=340,
                fill=rgba(ink, 240),
                width=6,
            )
            draw.line(
                [((cx - 0.040) * S, (eye_y + 0.006) * S), ((cx - 0.050) * S, (eye_y - 0.002) * S)],
                fill=rgba(ink, 200),
                width=4,
            )
            draw.line(
                [((cx + 0.040) * S, (eye_y + 0.006) * S), ((cx + 0.050) * S, (eye_y - 0.002) * S)],
                fill=rgba(ink, 200),
                width=4,
            )
            continue

        if traits["eyes"] == "glow":
            glow = mask()
            ImageDraw.Draw(glow).ellipse(box(cx - 0.055, eye_y - 0.045, cx + 0.055, eye_y + 0.045), fill=150)
            glow = glow.filter(ImageFilter.GaussianBlur(20))
            image.alpha_composite(layer(glow, accent))

        # Sclera, iris, pupil, catchlight.
        draw.ellipse(box(cx - 0.046, eye_y - 0.030, cx + 0.046, eye_y + 0.030), fill=rgba(lighten(PAPER, 0.16)))
        iris = accent if traits["eyes"] in ("slit", "glow") else mix(ink, aura, 0.35)
        draw.ellipse(box(cx - 0.024, eye_y - 0.024, cx + 0.024, eye_y + 0.024), fill=rgba(iris))
        if traits["eyes"] == "slit":
            draw.ellipse(box(cx - 0.006, eye_y - 0.022, cx + 0.006, eye_y + 0.022), fill=rgba(darken(ink, 0.3)))
        else:
            draw.ellipse(box(cx - 0.011, eye_y - 0.015, cx + 0.011, eye_y + 0.015), fill=rgba(darken(ink, 0.3)))
        draw.ellipse(box(cx - 0.018, eye_y - 0.020, cx - 0.004, eye_y - 0.006), fill=rgba(WHITE, 245))
        draw.ellipse(box(cx + 0.008, eye_y + 0.006, cx + 0.014, eye_y + 0.012), fill=rgba(WHITE, 150))
        # Upper lid shadow.
        draw.arc(
            box(cx - 0.048, eye_y - 0.036, cx + 0.048, eye_y + 0.030),
            start=195,
            end=345,
            fill=rgba(darken(ink, 0.1), 150),
            width=6,
        )

    # Rounded button nose.
    nose = mask()
    ImageDraw.Draw(nose).ellipse(box(0.482, 0.375, 0.518, 0.405), fill=255)
    soft_shadow(image, nose, mix(PAPER, ink, 0.30), 8, 90, (0, 3))
    draw.ellipse(box(0.488, 0.377, 0.502, 0.388), fill=rgba(WHITE, 90))

    # Mouth.
    mouth_y = 0.455
    if mouth == "closed":
        points = bez((0.462, 0.450), (0.482, 0.464), (0.518, 0.464), (0.538, 0.450), n=24)
        draw.line(points, fill=rgba(darken(ink, 0.1), 235), width=6)
        draw.arc(box(0.470, 0.452, 0.530, 0.472), start=20, end=160, fill=rgba(WHITE, 70), width=4)
    elif mouth == "small":
        draw.ellipse(box(0.483, 0.440, 0.517, 0.470), fill=rgba(darken(ink, 0.05)))
        draw.ellipse(box(0.490, 0.456, 0.510, 0.466), fill=rgba(mix(accent, PAPER, 0.45)))
        draw.ellipse(box(0.488, 0.438, 0.512, 0.444), fill=rgba(WHITE, 120))
    elif mouth == "medium":
        draw.ellipse(box(0.468, 0.434, 0.532, 0.474), fill=rgba(darken(ink, 0.05)))
        draw.ellipse(box(0.482, 0.452, 0.518, 0.470), fill=rgba(mix(accent, PAPER, 0.40)))
        draw.ellipse(box(0.474, 0.432, 0.526, 0.440), fill=rgba(WHITE, 150))
    else:
        draw.ellipse(box(0.448, 0.426, 0.552, 0.482), fill=rgba(darken(ink, 0.05)))
        draw.ellipse(box(0.476, 0.456, 0.524, 0.477), fill=rgba(mix(accent, PAPER, 0.38)))
        draw.rectangle(box(0.468, 0.430, 0.532, 0.441), fill=rgba(WHITE, 190))
        draw.arc(box(0.452, 0.428, 0.548, 0.480), start=200, end=340, fill=rgba(lighten(accent, 0.2), 120), width=4)


def add_grain(image):
    alpha = image.getchannel("A")
    noise = Image.effect_noise((S, S), 16).convert("L")
    noise = noise.point(lambda v: v * 16 // 255)
    noise = ImageChops.multiply(noise, alpha)
    tint = Image.new("RGBA", (S, S), rgba((0, 0, 0)))
    tint.putalpha(noise)
    image.alpha_composite(tint)


def add_shadow(image):
    alpha = image.getchannel("A")
    shadow = alpha.filter(ImageFilter.GaussianBlur(28))
    shadow = shadow.point(lambda v: v * 38 // 255)
    shadow = ImageChops.offset(shadow, int(0.008 * S), int(0.014 * S))
    shadow_layer = Image.new("RGBA", (S, S), rgba((0, 0, 0)))
    shadow_layer.putalpha(shadow)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(shadow_layer)
    out.alpha_composite(image)
    return out


def render(palette, traits, mouth="closed", eyes_closed=False):
    ink, aura, accent = palette
    image = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    draw_hair_behind(image, traits, ink, aura)
    draw_body(image, ink, aura, accent)
    draw_collar(image, ink, aura, accent)
    draw_head(image, ink, aura, accent)
    draw_ears(image, traits, ink)
    draw_hair(image, traits, ink, aura)
    draw_beard(image, traits, ink, accent)
    draw_accessory(image, traits, ink, aura, accent)
    draw_face(image, traits, ink, aura, accent, mouth, eyes_closed)
    add_grain(image)
    return add_shadow(image)


def draw_hair_behind(image, traits, ink, aura):
    hair = traits["hair"]
    if hair == "long":
        behind = mask()
        draw = ImageDraw.Draw(behind)
        draw.rounded_rectangle(box(0.215, 0.15, 0.785, 0.78), radius=0.20 * S, fill=255)
        behind = behind.filter(ImageFilter.GaussianBlur(2))
        gradient = linear((S, S), mix(ink, aura, 0.25), darken(ink, 0.35))
        gradient.putalpha(behind)
        image.alpha_composite(gradient)

    if traits["hat"] == "hood":
        hood = mask()
        hd = ImageDraw.Draw(hood)
        hd.polygon(
            [
                (0.20 * S, 0.64 * S),
                (0.24 * S, 0.20 * S),
                (0.50 * S, 0.035 * S),
                (0.76 * S, 0.20 * S),
                (0.80 * S, 0.64 * S),
                (0.64 * S, 0.56 * S),
                (0.36 * S, 0.56 * S),
            ],
            fill=255,
        )
        gradient = linear((S, S), darken(ink, 0.25), darken(ink, 0.55))
        gradient.putalpha(hood)
        image.alpha_composite(gradient)


def eyes_only(frame):
    region = mask()
    draw = ImageDraw.Draw(region)
    for cx in (0.435, 0.565):
        draw.ellipse(box(cx - 0.095, 0.270, cx + 0.095, 0.420), fill=255)
    region = region.filter(ImageFilter.GaussianBlur(14))
    frame.putalpha(ImageChops.multiply(frame.getchannel("A"), region))
    return frame


def save(frame, path):
    frame.resize((OUT, OUT), Image.LANCZOS).save(path, optimize=True)


def main():
    for character, palette in PALETTES.items():
        traits = TRAITS[character]
        folder = os.path.join(ROOT, character)
        os.makedirs(folder, exist_ok=True)
        save(render(palette, traits, "closed", False), os.path.join(folder, "base.png"))
        save(render(palette, traits, "small", False), os.path.join(folder, "mouth-small.png"))
        save(render(palette, traits, "medium", False), os.path.join(folder, "mouth-medium.png"))
        save(render(palette, traits, "wide", False), os.path.join(folder, "mouth-wide.png"))
        save(eyes_only(render(palette, traits, "closed", True)), os.path.join(folder, "eyes-closed.png"))
        print(character)


if __name__ == "__main__":
    main()
