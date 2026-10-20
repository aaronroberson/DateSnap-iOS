#!/usr/bin/env python3
"""
Generate a transparent PencildMark asset for the Pencil'd asset catalog.

Extracts the Pencil'd mark (spiral-bound calendar with colored pencil emblem)
from the source artwork, strips any background, preserves alpha transparency,
and centers the mark within a square universal asset canvas (default 512x512).

Usage:
    ./scripts/generate-pencild-mark.py
    ./scripts/generate-pencild-mark.py --check
    ./scripts/generate-pencild-mark.py --canvas-size 1024 --target-height 944
    ./scripts/generate-pencild-mark.py --source path/to/logo.png --output path/to/output.png
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys

try:
    from PIL import Image
    import numpy as np
except ImportError as err:
    sys.stderr.write(
        f"Missing required dependency: {err}\n"
        "Ensure Pillow and numpy are installed: pip install pillow numpy\n"
    )
    sys.exit(1)


def find_repository_root() -> Path:
    """Find repository root relative to this script."""
    script_dir = Path(__file__).resolve().parent
    return script_dir.parent


def resolve_default_source(repo_root: Path) -> Path:
    """Locate the highest quality transparent source artwork for the mark."""
    candidates = [
        repo_root / "Pencild.icon" / "Assets" / "pencild-logo-darker.png",
        repo_root / "Assets.xcassets" / "Pencild.icon" / "Assets" / "pencild-logo-darker.png",
    ]
    for path in candidates:
        if path.is_file():
            return path
    raise FileNotFoundError(
        f"Could not find default source artwork in any expected locations:\n"
        + "\n".join(f"  - {c}" for c in candidates)
    )


def resolve_default_output(repo_root: Path) -> Path:
    return repo_root / "Assets.xcassets" / "PencildMark.imageset" / "PencildMark.png"


def create_transparent_mark(
    source_path: Path,
    canvas_size: int = 512,
    target_height: int | None = None,
    tight_crop: bool = False,
    verbose: bool = False,
) -> Image.Image:
    """
    Load the source logo, crop to its non-transparent bounding box,
    scale using high-quality Lanczos resampling, and center on a transparent canvas.
    """
    if verbose:
        print(f"Reading source artwork from: {source_path}")

    source_img = Image.open(source_path).convert("RGBA")
    bbox = source_img.getbbox()
    if not bbox:
        raise ValueError(f"Source image '{source_path}' is completely transparent.")

    cropped = source_img.crop(bbox)
    if verbose:
        print(f"Source size: {source_img.size}, visible bounding box: {bbox} (crop size: {cropped.size})")

    if tight_crop:
        return cropped

    # Default target height scales proportionally with canvas size (472pt for 512pt canvas)
    if target_height is None:
        target_height = int(round(canvas_size * (472.0 / 512.0)))

    aspect_ratio = cropped.width / cropped.height
    target_width = int(round(target_height * aspect_ratio))

    if verbose:
        print(f"Scaling mark to: {target_width}x{target_height} (aspect ratio: {aspect_ratio:.4f})")

    scaled_mark = cropped.resize((target_width, target_height), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    offset_x = (canvas_size - target_width) // 2
    offset_y = (canvas_size - target_height) // 2

    if verbose:
        print(f"Placing mark on {canvas_size}x{canvas_size} transparent canvas at offset ({offset_x}, {offset_y})")

    canvas.paste(scaled_mark, (offset_x, offset_y), scaled_mark)
    return canvas


def verify_asset(
    output_path: Path,
    expected_image: Image.Image,
    verbose: bool = False,
) -> bool:
    """Check if the file at output_path matches the expected generated image."""
    if not output_path.is_file():
        if verbose:
            print(f"FAIL: Output file '{output_path}' does not exist.")
        return False

    existing_img = Image.open(output_path).convert("RGBA")
    if existing_img.size != expected_image.size:
        if verbose:
            print(
                f"FAIL: Dimension mismatch. Existing is {existing_img.size}, expected {expected_image.size}."
            )
        return False

    arr_existing = np.array(existing_img)
    arr_expected = np.array(expected_image)

    # Verify background transparency
    alpha_existing = arr_existing[:, :, 3]
    corner_alphas = [
        alpha_existing[0, 0],
        alpha_existing[0, -1],
        alpha_existing[-1, 0],
        alpha_existing[-1, -1],
    ]
    if any(a != 0 for a in corner_alphas):
        if verbose:
            print(f"FAIL: Corner pixels are not transparent: {corner_alphas}")
        return False

    diff = np.abs(arr_existing.astype(int) - arr_expected.astype(int))
    max_diff = np.max(diff)
    if max_diff > 2:  # allow minimal compression difference
        if verbose:
            print(f"FAIL: Pixel difference detected (max diff: {max_diff}).")
        return False

    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate transparent PencildMark asset for the Pencil'd asset catalog."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=None,
        help="Path to source logo PNG (default: Pencild.icon/Assets/pencild-logo-darker.png)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Path to output PNG (default: Assets.xcassets/PencildMark.imageset/PencildMark.png)",
    )
    parser.add_argument(
        "--canvas-size",
        type=int,
        default=512,
        help="Square canvas size in pixels (default: 512)",
    )
    parser.add_argument(
        "--target-height",
        type=int,
        default=None,
        help="Height of the mark within the canvas (default: 472 for 512 canvas, scales proportionally)",
    )
    parser.add_argument(
        "--tight-crop",
        action="store_true",
        help="Output mark tightly cropped to visible bounds without transparent canvas padding",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify the existing output file matches without writing (exit 0 if matched, 1 if mismatched)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Print detailed execution info",
    )

    args = parser.parse_args()
    repo_root = find_repository_root()

    try:
        source_path = args.source.resolve() if args.source else resolve_default_source(repo_root)
        output_path = args.output.resolve() if args.output else resolve_default_output(repo_root)
    except FileNotFoundError as err:
        sys.stderr.write(f"Error: {err}\n")
        return 1

    generated = create_transparent_mark(
        source_path=source_path,
        canvas_size=args.canvas_size,
        target_height=args.target_height,
        tight_crop=args.tight_crop,
        verbose=args.verbose,
    )

    if args.check:
        matches = verify_asset(output_path, generated, verbose=args.verbose)
        if matches:
            print(f"OK: '{output_path}' is valid and up-to-date with transparent background.")
            return 0
        else:
            sys.stderr.write(
                f"MISMATCH: '{output_path}' is missing or outdated. Run without --check to regenerate.\n"
            )
            return 1

    # Ensure output parent directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)
    generated.save(output_path, "PNG")
    print(f"Generated transparent PencildMark: {output_path} ({generated.size[0]}x{generated.size[1]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
