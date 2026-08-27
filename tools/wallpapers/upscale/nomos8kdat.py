#!/usr/bin/env python3
"""Conservative, tiled 4xNomos8kDAT enhancement for the wallpaper collection."""

from __future__ import annotations

import argparse
import gc
import json
import math
import os
from pathlib import Path
import sys
import time

import numpy as np
from PIL import Image, ImageFilter
import torch
import torch.nn.functional as functional
from spandrel import ImageModelDescriptor, ModelLoader


def env_int(name: str, default: int) -> int:
    return int(os.environ.get(name, default))


def env_float(name: str, default: float) -> float:
    return float(os.environ.get(name, default))


def image_to_tensor(image: Image.Image, device: torch.device, dtype: torch.dtype) -> torch.Tensor:
    array = np.array(image, dtype=np.float32, copy=True) / 255.0
    tensor = torch.from_numpy(array).permute(2, 0, 1).unsqueeze(0)
    return tensor.to(device=device, dtype=dtype)


def tensor_to_image(tensor: torch.Tensor) -> Image.Image:
    array = (
        tensor.squeeze(0)
        .detach()
        .float()
        .clamp_(0.0, 1.0)
        .permute(1, 2, 0)
        .cpu()
        .numpy()
    )
    return Image.fromarray(np.rint(array * 255.0).astype(np.uint8), "RGB")


def upscale_tiled(
    image: Image.Image,
    model: ImageModelDescriptor,
    device: torch.device,
    dtype: torch.dtype,
    tile: int,
    overlap: int,
    pad_multiple: int,
    scale: int,
) -> Image.Image:
    width, height = image.size
    result = Image.new("RGB", (width * scale, height * scale))
    tiles_x = math.ceil(width / tile)
    tiles_y = math.ceil(height / tile)
    tile_count = tiles_x * tiles_y
    tile_number = 0
    progress_started = time.monotonic()

    for core_y0 in range(0, height, tile):
        core_y1 = min(core_y0 + tile, height)
        for core_x0 in range(0, width, tile):
            core_x1 = min(core_x0 + tile, width)
            tile_number += 1

            patch_x0 = max(0, core_x0 - overlap)
            patch_y0 = max(0, core_y0 - overlap)
            patch_x1 = min(width, core_x1 + overlap)
            patch_y1 = min(height, core_y1 + overlap)
            patch = image.crop((patch_x0, patch_y0, patch_x1, patch_y1))
            tile_started = time.monotonic()
            print(
                f"  START tile {tile_number}/{tile_count} "
                f"core={core_x0},{core_y0}-{core_x1},{core_y1} "
                f"patch={patch.width}x{patch.height}",
                flush=True,
            )
            tensor = image_to_tensor(patch, device, dtype)

            pad_right = (-tensor.shape[-1]) % pad_multiple
            pad_bottom = (-tensor.shape[-2]) % pad_multiple
            if pad_right or pad_bottom:
                tensor = functional.pad(
                    tensor,
                    (0, pad_right, 0, pad_bottom),
                    mode="reflect",
                )

            with torch.inference_mode():
                enhanced = model(tensor)
            enhanced = enhanced[
                :,
                :,
                : patch.height * scale,
                : patch.width * scale,
            ]

            crop_x0 = (core_x0 - patch_x0) * scale
            crop_y0 = (core_y0 - patch_y0) * scale
            crop_x1 = crop_x0 + (core_x1 - core_x0) * scale
            crop_y1 = crop_y0 + (core_y1 - core_y0) * scale
            core = tensor_to_image(enhanced).crop((crop_x0, crop_y0, crop_x1, crop_y1))
            result.paste(core, (core_x0 * scale, core_y0 * scale))

            del tensor, enhanced, core
            tile_seconds = time.monotonic() - tile_started
            elapsed = time.monotonic() - progress_started
            eta = (elapsed / tile_number) * (tile_count - tile_number)
            allocated = torch.cuda.memory_allocated(device) / (1024**3)
            reserved = torch.cuda.memory_reserved(device) / (1024**3)
            print(
                f"  DONE  tile {tile_number}/{tile_count} "
                f"time={tile_seconds:.1f}s avg={elapsed / tile_number:.1f}s "
                f"ETA={eta / 60:.1f}min "
                f"VRAM={allocated:.2f}GiB reserved={reserved:.2f}GiB",
                flush=True,
            )

    return result


def enhance_one(
    input_path: Path,
    output_path: Path,
    model: ImageModelDescriptor,
    device: torch.device,
    dtype: torch.dtype,
    tile: int,
    overlap: int,
    pad_multiple: int,
    scale: int,
    source_scale: float,
    blend: float,
    sharpen: int,
) -> None:
    with Image.open(input_path) as source_image:
        source = source_image.convert("RGB")
    if source.size != (5120, 1440):
        raise ValueError(f"{input_path}: oczekiwano 5120x1440, jest {source.size[0]}x{source.size[1]}")

    if source_scale == 1.0:
        model_source = source
    else:
        model_source = source.resize(
            (
                round(source.width * source_scale),
                round(source.height * source_scale),
            ),
            Image.Resampling.LANCZOS,
        )
    print(
        f"  model input={model_source.width}x{model_source.height} "
        f"4x output={model_source.width * scale}x{model_source.height * scale} "
        f"target={source.width}x{source.height}",
        flush=True,
    )
    four_x = upscale_tiled(
        model_source,
        model,
        device,
        dtype,
        tile,
        overlap,
        pad_multiple,
        scale,
    )
    enhanced = four_x.resize(source.size, Image.Resampling.LANCZOS)
    del four_x

    # Keeping part of the original limits hallucinated facial details while
    # retaining the extra high-frequency information recovered by the model.
    final = Image.blend(source, enhanced, blend)
    if sharpen > 0:
        final = final.filter(ImageFilter.UnsharpMask(radius=0.6, percent=sharpen, threshold=3))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_suffix(output_path.suffix + ".part")
    final.save(temporary, format="PNG", optimize=True, compress_level=9)
    os.replace(temporary, output_path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--slug", help="Process only one manifest slug")
    parser.add_argument("--batch-index", type=int, help="Zero-based batch index")
    parser.add_argument("--batch-count", type=int, help="Number of equal batches")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tile = env_int("NOMOS_TILE", 512)
    overlap = env_int("NOMOS_OVERLAP", 32)
    pad_multiple = env_int("NOMOS_PAD_MULTIPLE", 64)
    blend = env_float("NOMOS_BLEND", 0.65)
    sharpen = env_int("NOMOS_SHARPEN", 15)
    source_scale = env_float("NOMOS_SOURCE_SCALE", 1.0)
    min_vram_gib = env_float("NOMOS_MIN_VRAM_GIB", 0.0)
    requested_dtype = os.environ.get("NOMOS_DTYPE", "bfloat16").lower()
    overwrite = os.environ.get("NOMOS_OVERWRITE", "0") == "1"
    auto_tile = os.environ.get("NOMOS_AUTO_TILE", "1") not in {"0", "no", "false", "off"}

    if tile < 64 or overlap < 0 or overlap * 2 >= tile:
        raise ValueError("NOMOS_TILE >= 64 oraz 0 <= NOMOS_OVERLAP < NOMOS_TILE/2")
    if pad_multiple < 1 or not 0.0 <= blend <= 1.0:
        raise ValueError("Nieprawidłowy NOMOS_PAD_MULTIPLE lub NOMOS_BLEND")
    if not 0.25 <= source_scale <= 1.0:
        raise ValueError("NOMOS_SOURCE_SCALE musi mieścić się w zakresie 0.25–1.0")
    if not torch.cuda.is_available() or torch.version.hip is None:
        raise RuntimeError("ROCm GPU jest niedostępne")
    detected_vram_gib = torch.cuda.get_device_properties(0).total_memory / (1024**3)
    if detected_vram_gib < min_vram_gib:
        raise RuntimeError(
            f"Wybrano GPU z {detected_vram_gib:.2f} GiB VRAM; "
            f"profil wymaga co najmniej {min_vram_gib:.2f} GiB. "
            "Ustaw właściwy NOMOS_GPU_ORDINAL."
        )

    device = torch.device("cuda:0")
    descriptor = ModelLoader().load_from_file(args.model)
    if not isinstance(descriptor, ImageModelDescriptor):
        raise TypeError("Checkpoint nie jest modelem obrazu obsługiwanym przez Spandrel")
    scale = int(descriptor.scale)
    if scale != 4:
        raise ValueError(f"Oczekiwano modelu 4x, wykryto {scale}x")

    if requested_dtype in {"bfloat16", "bf16"}:
        if not descriptor.supports_bfloat16:
            raise ValueError("Checkpoint nie deklaruje bezpiecznej obsługi BF16")
        dtype = torch.bfloat16
    elif requested_dtype in {"float32", "fp32"}:
        dtype = torch.float32
    elif requested_dtype in {"float16", "fp16"}:
        if not descriptor.supports_half:
            raise ValueError("DAT nie obsługuje bezpiecznie FP16; użyj BF16 albo FP32")
        dtype = torch.float16
    else:
        raise ValueError("NOMOS_DTYPE musi mieć wartość bfloat16, float32 lub float16")

    descriptor.model.to(dtype=dtype)
    model = descriptor.cuda().eval()
    print(
        f"GPU={torch.cuda.get_device_name(0)} VRAM={detected_vram_gib:.2f}GiB "
        f"HIP={torch.version.hip} "
        f"dtype={requested_dtype} tile={tile} overlap={overlap} "
        f"source_scale={source_scale:.2f} blend={blend:.2f} sharpen={sharpen}",
        flush=True,
    )

    with args.manifest.open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    items = manifest.get("wallpapers", [])
    if len(items) != 48:
        raise ValueError("Manifest musi zawierać dokładnie 48 tapet")
    slugs = [item["slug"] for item in items]
    if args.slug:
        if args.slug not in slugs:
            raise ValueError(f"Brak sluga w manifeście: {args.slug}")
        slugs = [args.slug]
    elif args.batch_index is not None or args.batch_count is not None:
        if args.batch_index is None or args.batch_count is None:
            raise ValueError("--batch-index i --batch-count muszą wystąpić razem")
        if args.batch_count < 1 or not 0 <= args.batch_index < args.batch_count:
            raise ValueError("Batch wymaga 0 <= index < count")
        if len(slugs) % args.batch_count != 0:
            raise ValueError("Kolekcji nie można równo podzielić na podaną liczbę partii")
        batch_size = len(slugs) // args.batch_count
        batch_start = args.batch_index * batch_size
        slugs = slugs[batch_start : batch_start + batch_size]
        print(
            f"batch={args.batch_index + 1}/{args.batch_count} "
            f"items={batch_size} manifest_range={batch_start + 1}-{batch_start + batch_size}",
            flush=True,
        )

    failures = 0
    for index, slug in enumerate(slugs, start=1):
        input_path = args.input_dir / f"{slug}.png"
        output_path = args.output_dir / f"{slug}.png"
        if output_path.is_file() and output_path.stat().st_size > 0 and not overwrite:
            print(f"[{index}/{len(slugs)}] skip {slug}: wynik już istnieje", flush=True)
            continue
        print(f"[{index}/{len(slugs)}] enhance {slug}", flush=True)
        try:
            tile_candidates = [tile]
            if auto_tile:
                tile_candidates.extend(
                    candidate
                    for candidate in (832, 768, 704, 640, 576, 512, 448, 384, 320)
                    if candidate < tile
                )
            for candidate_index, candidate_tile in enumerate(tile_candidates):
                try:
                    enhance_one(
                        input_path,
                        output_path,
                        model,
                        device,
                        dtype,
                        candidate_tile,
                        overlap,
                        pad_multiple,
                        scale,
                        source_scale,
                        blend,
                        sharpen,
                    )
                    if candidate_tile != tile:
                        print(f"  ukończono z fallback tile={candidate_tile}", flush=True)
                    break
                except torch.OutOfMemoryError:
                    if candidate_index + 1 == len(tile_candidates):
                        raise
                    next_tile = tile_candidates[candidate_index + 1]
                    print(
                        f"  OOM tile={candidate_tile}; czyszczę VRAM i ponawiam "
                        f"całą tapetę z tile={next_tile}",
                        file=sys.stderr,
                        flush=True,
                    )
                # Run cleanup after leaving the exception handler so Python no
                # longer retains the failed inference traceback and its tensors.
                gc.collect()
                torch.cuda.empty_cache()
        except Exception as error:  # continue the overnight batch after one bad file
            failures += 1
            print(f"ERROR {slug}: {error}", file=sys.stderr, flush=True)
        finally:
            torch.cuda.empty_cache()

    if failures:
        print(f"Nieukończone pozycje: {failures}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
