#!/usr/bin/env python3
"""
Generate the selected PortMonitor icon (Port Grid) in multiple sizes for
macOS app icon and menu bar tray usage.

This script reproduces the Port Grid glyph from the Pencil file and
exports PNGs at common icon sizes, plus a simple SVG for reference.

It writes files to: assets/icons/port-grid/

Usage:
  python3 scripts/export_port_grid_icons.py

"""

from __future__ import annotations
import os
from typing import Tuple

try:
    from PIL import Image, ImageDraw
except Exception as e:
    raise RuntimeError(
        "Pillow is required to run this script. Install with: python3 -m pip install pillow"
    )


OUT_DIR = os.path.join("assets", "icons", "port-grid")
os.makedirs(OUT_DIR, exist_ok=True)

# Base coordinates taken from the Pencil file (512x512 artboard)
BASE = 512
RECT_POS = [
    (131, 131),
    (221, 131),
    (311, 131),
    (131, 221),
    (221, 221),
    (311, 221),
    (131, 311),
    (221, 311),
    (311, 311),
]
RECT_SIZE = 70
CORNER_RADIUS = 110

# Output sizes
APP_SIZES = [1024, 512, 256, 128, 64, 32, 16]
# Tray sizes include common menu-bar sizes and their @2x variants
TRAY_SIZES = [44, 22, 32, 16]


def draw_app_icon(
    size: int, bg_color: Tuple[int, int, int, int] = (255, 255, 255, 255)
) -> str:
    """Draw the app icon (rounded square background + grid glyph).

    Returns the output path.
    """
    scale = size / BASE
    img = Image.new("RGBA", (size, size), bg_color)
    draw = ImageDraw.Draw(img)

    # Draw rounded rect background (ensures consistent corners)
    radius = int(round(CORNER_RADIUS * scale))
    draw.rounded_rectangle([0, 0, size, size], radius=radius, fill=bg_color)

    # Draw the 3x3 grid glyph (black squares)
    glyph_fill = (0, 0, 0, 255)
    for x, y in RECT_POS:
        left = int(round(x * scale))
        top = int(round(y * scale))
        right = int(round((x + RECT_SIZE) * scale))
        bottom = int(round((y + RECT_SIZE) * scale))
        draw.rectangle([left, top, right, bottom], fill=glyph_fill)

    out_path = os.path.join(OUT_DIR, f"port-grid-{size}.png")
    img.save(out_path)
    return out_path


def draw_tray_icon(size: int, simplify_threshold: int = 24) -> str:
    """Draw a tray (glyph-only) icon with transparent background.

    For very small sizes we simplify the glyph to maintain legibility.
    """
    scale = size / BASE
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    # WHITE glyph for menu bar (not black - macOS dark mode needs white)
    glyph_fill = (255, 255, 255, 255)

    if size < simplify_threshold:
        # produce a simplified 2x2 grid for tiny sizes
        # compute a compact layout centered in the canvas
        sq = max(1, int(round(RECT_SIZE * scale * 1.1)))
        pad = max(1, int(round(6 * scale)))
        grid_w = 2 * sq + pad
        start = (size - grid_w) // 2
        offsets = [(0, 0), (sq + pad, 0), (0, sq + pad), (sq + pad, sq + pad)]
        for dx, dy in offsets:
            left = start + dx
            top = start + dy
            draw.rectangle([left, top, left + sq, top + sq], fill=glyph_fill)
    else:
        # use the original 3x3 layout scaled to the requested size
        for x, y in RECT_POS:
            left = int(round(x * scale))
            top = int(round(y * scale))
            right = int(round((x + RECT_SIZE) * scale))
            bottom = int(round((y + RECT_SIZE) * scale))
            draw.rectangle([left, top, right, bottom], fill=glyph_fill)

    out_path = os.path.join(OUT_DIR, f"port-grid-tray-{size}.png")
    img.save(out_path)
    return out_path


def save_svg() -> str:
    """Emit a simple SVG version of the icon (512x512) for reference.

    This can be edited or used as an authoritative vector source.
    """
    svg_path = os.path.join(OUT_DIR, "port-grid.svg")
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{BASE}" height="{BASE}" viewBox="0 0 {BASE} {BASE}">',
        f'  <rect x="0" y="0" width="{BASE}" height="{BASE}" rx="{CORNER_RADIUS}" fill="#ffffff"/>',
    ]
    for x, y in RECT_POS:
        parts.append(
            f'  <rect x="{x}" y="{y}" width="{RECT_SIZE}" height="{RECT_SIZE}" fill="#000000"/>'
        )
    parts.append("</svg>")
    with open(svg_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(parts))
    return svg_path


def main() -> None:
    print("Generating app icons (rounded white background + black glyph)...")
    generated = []
    for s in APP_SIZES:
        p = draw_app_icon(s)
        print("  ", p)
        generated.append(p)

    print("Generating tray icons (glyph-only, transparent background)...")
    for s in TRAY_SIZES:
        p = draw_tray_icon(s)
        print("  ", p)
        generated.append(p)

    svg = save_svg()
    print("Saved SVG reference:", svg)


if __name__ == "__main__":
    main()
