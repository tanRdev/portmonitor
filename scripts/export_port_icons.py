#!/usr/bin/env python3
"""Export the authoritative Port Monitor app and menu-bar icons."""

from __future__ import annotations

from pathlib import Path
import shutil

from PIL import Image


APP_SOURCE = Path("assets/app-icon-source.png")
APP_VECTOR_SOURCE = Path("assets/app-icon-source.svg")
TRAY_SOURCE = Path("PortMonitor/Assets/MenuBarIcon.png")
TRAY_VECTOR_SOURCE = Path("PortMonitor/Assets/MenuBarIcon.svg")
OUT_DIR = Path("assets/icons/port-socket")
APP_SIZES = (1024, 512, 256, 128, 64, 32, 16)
TRAY_SIZES = (44, 32, 22, 16)


def export_sizes(source: Path, prefix: str, sizes: tuple[int, ...]) -> None:
    with Image.open(source) as image:
        image = image.convert("RGBA")
        for size in sizes:
            output = OUT_DIR / f"{prefix}-{size}.png"
            image.resize((size, size), Image.Resampling.LANCZOS).save(output)
            print(f"Generated: {output}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    export_sizes(APP_SOURCE, "port-socket", APP_SIZES)
    export_sizes(TRAY_SOURCE, "port-socket-tray", TRAY_SIZES)
    shutil.copy2(APP_VECTOR_SOURCE, OUT_DIR / "port-socket.svg")
    shutil.copy2(TRAY_VECTOR_SOURCE, OUT_DIR / "port-socket-tray.svg")


if __name__ == "__main__":
    main()
