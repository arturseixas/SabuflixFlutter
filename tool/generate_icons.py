#!/usr/bin/env python3
"""Generates the Sabuflix app icon for every platform.

The mark is a white play triangle on the app's blue → indigo gradient, in the
same squircle proportion Apple and Android use. Everything is rasterised here
with the standard library (zlib for PNG deflate), so regenerating the icon
never depends on an image toolchain being installed:

    python3 tool/generate_icons.py

Run it after changing COLOR_START/COLOR_END or the geometry constants below.
"""

from __future__ import annotations

import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Theme accent (#0A84FF) blending into indigo, on the diagonal.
COLOR_START = (10, 132, 255)
COLOR_END = (94, 92, 230)

# Fraction of the canvas taken by the squircle's corner radius.
CORNER_RATIO = 0.2237

SUPERSAMPLE = 6


# --- Geometry -----------------------------------------------------------


def rounded_rect_span(y, x0, y0, x1, y1, r):
    """Horizontal span of a rounded rectangle at height *y*."""
    if y < y0 or y > y1:
        return None
    if r <= 0:
        return (x0, x1)
    if y < y0 + r:
        dy = (y0 + r) - y
    elif y > y1 - r:
        dy = y - (y1 - r)
    else:
        return (x0, x1)
    dx = math.sqrt(max(r * r - dy * dy, 0.0))
    return (x0 + r - dx, x1 - r + dx)


def polygon_span(y, points):
    """Horizontal span of a convex polygon at height *y*."""
    xs = []
    count = len(points)
    for i in range(count):
        ax, ay = points[i]
        bx, by = points[(i + 1) % count]
        if ay == by:
            continue
        lo, hi = (ay, by) if ay < by else (by, ay)
        if y < lo or y > hi:
            continue
        t = (y - ay) / (by - ay)
        xs.append(ax + (bx - ax) * t)
    if len(xs) < 2:
        return None
    return (min(xs), max(xs))


def play_triangle(size, ratio):
    """Play mark, nudged right so it reads as optically centred."""
    width = size * ratio
    height = width * 1.12
    cx = size / 2 + width * 0.06
    cy = size / 2
    return [
        (cx - width * 0.44, cy - height / 2),
        (cx + width * 0.56, cy),
        (cx - width * 0.44, cy + height / 2),
    ]


def coverage_row(y, size, span_fn):
    """Anti-aliased coverage for one output row.

    Exact in x (the span is analytic), supersampled in y.
    """
    cov = [0.0] * size
    inc = 1.0 / SUPERSAMPLE
    for step in range(SUPERSAMPLE):
        span = span_fn(y + (step + 0.5) / SUPERSAMPLE)
        if span is None:
            continue
        a, b = span
        a = max(a, 0.0)
        b = min(b, float(size))
        if b <= a:
            continue
        first = int(math.floor(a))
        last = min(int(math.ceil(b)), size)
        for x in range(first, last):
            left = a if a > x else x
            right = b if b < x + 1 else x + 1
            if right > left:
                cov[x] += (right - left) * inc
    return cov


# --- Rendering ----------------------------------------------------------


def gradient(size, x, y):
    t = (x + y) / (2.0 * max(size - 1, 1))
    t = min(max(t, 0.0), 1.0)
    r = COLOR_START[0] + (COLOR_END[0] - COLOR_START[0]) * t
    g = COLOR_START[1] + (COLOR_END[1] - COLOR_START[1]) * t
    b = COLOR_START[2] + (COLOR_END[2] - COLOR_START[2]) * t

    # Soft specular highlight in the upper-left, the way iOS icons catch light.
    hx = (x / size - 0.3)
    hy = (y / size - 0.22)
    glow = max(0.0, 1.0 - math.sqrt(hx * hx + hy * hy) / 0.62) ** 2
    r += (255 - r) * glow * 0.30
    g += (255 - g) * glow * 0.30
    b += (255 - b) * glow * 0.30
    return int(r), int(g), int(b)


def render(size, *, inset=0.0, rounded=True, mark_ratio=0.42, background=True, mark=True):
    """Renders one icon as RGBA bytes."""
    pad = size * inset
    x0, y0 = pad, pad
    x1, y1 = size - pad, size - pad
    radius = (x1 - x0) * CORNER_RATIO if rounded else 0.0

    triangle = play_triangle(size, mark_ratio)

    def bg_span(y):
        return rounded_rect_span(y, x0, y0, x1, y1, radius)

    def mark_span(y):
        return polygon_span(y, triangle)

    out = bytearray(size * size * 4)
    for y in range(size):
        bg = coverage_row(y, size, bg_span) if background else None
        fg = coverage_row(y, size, mark_span) if mark else None
        base = y * size * 4

        for x in range(size):
            r = g = b = 0
            alpha = 0.0

            if bg is not None and bg[x] > 0:
                r, g, b = gradient(size, x, y)
                alpha = bg[x]

            if fg is not None and fg[x] > 0:
                # White mark over whatever is underneath, premultiplied by its
                # own coverage so the edges stay clean on transparency too.
                cover = fg[x]
                out_alpha = alpha + cover * (1 - alpha)
                if out_alpha > 0:
                    r = int((255 * cover + r * alpha * (1 - cover)) / out_alpha)
                    g = int((255 * cover + g * alpha * (1 - cover)) / out_alpha)
                    b = int((255 * cover + b * alpha * (1 - cover)) / out_alpha)
                alpha = out_alpha

            index = base + x * 4
            out[index] = min(r, 255)
            out[index + 1] = min(g, 255)
            out[index + 2] = min(b, 255)
            out[index + 3] = int(round(min(alpha, 1.0) * 255))

    return bytes(out)


def flatten(rgba, size, background=(0, 0, 0)):
    """Drops the alpha channel — iOS rejects icons with transparency."""
    out = bytearray(size * size * 4)
    for i in range(size * size):
        a = rgba[i * 4 + 3] / 255
        for c in range(3):
            value = rgba[i * 4 + c] * a + background[c] * (1 - a)
            out[i * 4 + c] = int(round(value))
        out[i * 4 + 3] = 255
    return bytes(out)


# --- PNG / ICO ----------------------------------------------------------


def png_bytes(rgba, size):
    raw = bytearray()
    stride = size * 4
    for y in range(size):
        raw.append(0)  # filter type: none
        raw.extend(rgba[y * stride:(y + 1) * stride])

    def chunk(tag, data):
        return (
            struct.pack('>I', len(data))
            + tag
            + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    return (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
        + chunk(b'IEND', b'')
    )


def write_png(path, rgba, size):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'wb') as handle:
        handle.write(png_bytes(rgba, size))
    print(f'  {path} ({size}×{size})')


def write_ico(path, frames):
    """Vista-era ICO: every frame stored as a PNG."""
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)

    encoded = [(size, png_bytes(rgba, size)) for size, rgba in frames]
    header = struct.pack('<HHH', 0, 1, len(encoded))
    offset = 6 + 16 * len(encoded)

    entries = bytearray()
    for size, data in encoded:
        entries += struct.pack(
            '<BBBBHHII',
            0 if size >= 256 else size,
            0 if size >= 256 else size,
            0,
            0,
            1,
            32,
            len(data),
            offset,
        )
        offset += len(data)

    with open(full, 'wb') as handle:
        handle.write(header)
        handle.write(entries)
        for _, data in encoded:
            handle.write(data)
    print(f'  {path} ({", ".join(str(s) for s, _ in encoded)})')


# --- Targets ------------------------------------------------------------


def main():
    print('Android')
    for folder, size in [
        ('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192),
    ]:
        icon = render(size, inset=0.02)
        write_png(f'android/app/src/main/res/mipmap-{folder}/ic_launcher.png', icon, size)

    # Adaptive icon: the launcher masks these itself, so the background is a
    # full-bleed square and the mark sits inside the 66% safe zone.
    for folder, size in [
        ('mdpi', 108), ('hdpi', 162), ('xhdpi', 216), ('xxhdpi', 324), ('xxxhdpi', 432),
    ]:
        background = render(size, rounded=False, mark=False)
        foreground = render(size, background=False, mark_ratio=0.33)
        write_png(f'android/app/src/main/res/mipmap-{folder}/ic_launcher_background.png', background, size)
        write_png(f'android/app/src/main/res/mipmap-{folder}/ic_launcher_foreground.png', foreground, size)

    print('iOS')
    ios = [
        ('20x20@1x', 20), ('20x20@2x', 40), ('20x20@3x', 60),
        ('29x29@1x', 29), ('29x29@2x', 58), ('29x29@3x', 87),
        ('40x40@1x', 40), ('40x40@2x', 80), ('40x40@3x', 120),
        ('60x60@2x', 120), ('60x60@3x', 180),
        ('76x76@1x', 76), ('76x76@2x', 152),
        ('83.5x83.5@2x', 167),
        ('1024x1024@1x', 1024),
    ]
    for name, size in ios:
        icon = flatten(render(size, rounded=False), size)
        write_png(f'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-{name}.png', icon, size)

    print('macOS')
    for size in [16, 32, 64, 128, 256, 512, 1024]:
        # macOS icons keep their own rounded shape and sit in a margin.
        icon = render(size, inset=0.09)
        write_png(f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png', icon, size)

    print('Windows')
    write_ico(
        'windows/runner/resources/app_icon.ico',
        [(size, render(size, inset=0.02)) for size in [16, 32, 48, 64, 128, 256]],
    )

    print('Web')
    write_png('web/favicon.png', render(32, inset=0.02), 32)
    for size in [192, 512]:
        write_png(f'web/icons/Icon-{size}.png', render(size, inset=0.02), size)
        # Maskable icons are cropped by the browser: full bleed, smaller mark.
        write_png(
            f'web/icons/Icon-maskable-{size}.png',
            render(size, rounded=False, mark_ratio=0.30),
            size,
        )

    print('Linux / in-app')
    write_png('assets/icon/app_icon.png', render(1024, inset=0.02), 1024)


if __name__ == '__main__':
    main()
