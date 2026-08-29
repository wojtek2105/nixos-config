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
    # ``clamp`` does not turn NaN into a valid value.  Casting an unchecked NaN
    # to uint8 can silently produce a black pixel, so never serialize a
    # numerically invalid model result.
    if not torch.isfinite(tensor).all().item():
        raise FloatingPointError("Próba zapisu tensora z NaN lub Inf")
    array = (
        tensor.squeeze(0)
        .detach()
        .float()
        .clamp_(0.0, 1.0)
        .permute(1, 2, 0)
        .cpu()
        .numpy()
    )
    # A three-channel uint8 array is inferred as RGB by Pillow.  Omitting the
    # deprecated explicit mode keeps the output identical and the log clean.
    return Image.fromarray(np.rint(array * 255.0).astype(np.uint8))


def resize_crop_left(image: Image.Image, target_width: int, target_height: int) -> Image.Image:
    """Resize without distortion, discarding only excess pixels on the left."""
    resized_width = math.ceil(image.width * target_height / image.height)
    if resized_width < target_width:
        raise ValueError(
            f"{image.width}x{image.height} jest węższy niż docelowe "
            f"{target_width}x{target_height}; nie można przyciąć tylko lewej strony"
        )
    resized = image.resize((resized_width, target_height), Image.Resampling.LANCZOS)
    return resized.crop((resized_width - target_width, 0, resized_width, target_height))


def upscale_tiled(
    image: Image.Image,
    model: ImageModelDescriptor,
    device: torch.device,
    dtype: torch.dtype,
    tile: int,
    overlap: int,
    pad_multiple: int,
    scale: int,
    warmup_passes: int,
) -> Image.Image:
    original_width, original_height = image.size
    padded_width = math.ceil(original_width / tile) * tile
    padded_height = math.ceil(original_height / tile) * tile
    if (padded_width, padded_height) != image.size:
        # Nomos can become numerically unstable on a narrow final core tile.
        # Reflect-pad only the working canvas to full cores, then crop the SR
        # result back to the exact source dimensions below.
        source_array = np.asarray(image, dtype=np.uint8)
        padded_array = np.pad(
            source_array,
            (
                (0, padded_height - original_height),
                (0, padded_width - original_width),
                (0, 0),
            ),
            mode="reflect",
        )
        working_image = Image.fromarray(padded_array)
    else:
        working_image = image

    width, height = working_image.size
    # Every core, including top-left, needs the same halo.  Clamping patch
    # coordinates at image edges gave the first 256 px core less context than
    # interior tiles and made Nomos deterministically paint a bad square.
    # Reflect-padding the working canvas supplies real neighbouring texture
    # without ever using the source image as the output fallback.
    if overlap:
        context_array = np.pad(
            np.asarray(working_image, dtype=np.uint8),
            ((overlap, overlap), (overlap, overlap), (0, 0)),
            mode="reflect",
        )
        context_image = Image.fromarray(context_array)
    else:
        context_image = working_image
    result = Image.new("RGB", (width * scale, height * scale))

    if warmup_passes:
        # ROCm 7.2 can return a visually corrupted but finite first DAT result
        # while its kernels initialize.  Execute the exact first patch more
        # than once, discard every result, then start the real tiled render.
        warmup_patch = context_image.crop((0, 0, tile + 2 * overlap, tile + 2 * overlap))
        for warmup_index in range(1, warmup_passes + 1):
            warmup_tensor = image_to_tensor(warmup_patch, device, dtype)
            warmup_pad_right = (-warmup_tensor.shape[-1]) % pad_multiple
            warmup_pad_bottom = (-warmup_tensor.shape[-2]) % pad_multiple
            if warmup_pad_right or warmup_pad_bottom:
                warmup_tensor = functional.pad(
                    warmup_tensor,
                    (0, warmup_pad_right, 0, warmup_pad_bottom),
                    mode="reflect",
                )
            print(
                f"  WARMUP {warmup_index}/{warmup_passes} "
                f"patch={warmup_patch.width}x{warmup_patch.height}; wynik odrzucony",
                flush=True,
            )
            with torch.inference_mode():
                warmup_output = model(warmup_tensor)
            # ROCm work is asynchronous.  Do not let tile 1 start while a
            # flaky kernel initialization is still in flight.
            torch.cuda.synchronize(device)
            del warmup_tensor, warmup_output
            torch.cuda.empty_cache()

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

            patch_x0 = core_x0 - overlap
            patch_y0 = core_y0 - overlap
            patch_x1 = core_x1 + overlap
            patch_y1 = core_y1 + overlap
            patch = context_image.crop(
                (
                    patch_x0 + overlap,
                    patch_y0 + overlap,
                    patch_x1 + overlap,
                    patch_y1 + overlap,
                )
            )
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
            finite = torch.isfinite(enhanced)
            if not finite.all().item():
                # ``sum`` on a large bool tensor has produced nonsensical
                # values on some HIP builds; count the invalid entries instead.
                invalid_values = int((~finite).count_nonzero().item())
                raise FloatingPointError(
                    "Model zwrócił NaN/Inf "
                    f"dla kafla core={core_x0},{core_y0}-{core_x1},{core_y1} "
                    f"(patch={patch.width}x{patch.height}, dtype={enhanced.dtype}, "
                    f"nieprawidłowe wartości={invalid_values})"
                )
            del finite
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

    return result.crop((0, 0, original_width * scale, original_height * scale))


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
    black_preserve_threshold: int,
    warmup_passes: int,
    target_width: int | None,
    target_height: int | None,
) -> None:
    with Image.open(input_path) as source_image:
        source = source_image.convert("RGB")
    if target_width is None:
        output_source = source
    else:
        assert target_height is not None
        output_source = resize_crop_left(source, target_width, target_height)
    source_black = np.all(
        np.asarray(output_source, dtype=np.uint8) <= black_preserve_threshold,
        axis=2,
    )

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
        f"target={output_source.width}x{output_source.height}",
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
        warmup_passes,
    )
    if target_width is None:
        enhanced = four_x.resize(output_source.size, Image.Resampling.LANCZOS)
    else:
        assert target_height is not None
        enhanced = resize_crop_left(four_x, target_width, target_height)
    del four_x

    # Keeping part of the original limits hallucinated facial details while
    # retaining the extra high-frequency information recovered by the model.
    final = Image.blend(output_source, enhanced, blend)
    if sharpen > 0:
        final = final.filter(ImageFilter.UnsharpMask(radius=0.6, percent=sharpen, threshold=3))
    if source_black.any():
        # Restore OLED-off source pixels after blend and sharpen.  The default
        # threshold is exactly #000000, so near-black shading still receives SR.
        final_array = np.asarray(final, dtype=np.uint8).copy()
        final_array[source_black] = 0
        final = Image.fromarray(final_array, "RGB")

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
    parser.add_argument(
        "--input-file",
        type=Path,
        help="Process one arbitrary image path instead of a collection slug",
    )
    parser.add_argument(
        "--output-file",
        type=Path,
        help="Required together with --input-file; destination stays under staging",
    )
    parser.add_argument("--target-width", type=int, help="Optional final output width")
    parser.add_argument("--target-height", type=int, help="Optional final output height")
    parser.add_argument(
        "--slug",
        action="append",
        dest="slugs",
        help="Process one manifest slug; repeat the option for a selected list",
    )
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
    black_preserve_threshold = env_int("NOMOS_BLACK_PRESERVE_THRESHOLD", 0)
    source_scale = env_float("NOMOS_SOURCE_SCALE", 1.0)
    min_vram_gib = env_float("NOMOS_MIN_VRAM_GIB", 0.0)
    min_free_vram_gib = env_float("NOMOS_MIN_FREE_VRAM_GIB", 0.0)
    requested_dtype = os.environ.get("NOMOS_DTYPE", "bfloat16").lower()
    overwrite = os.environ.get("NOMOS_OVERWRITE", "0") == "1"
    auto_tile = os.environ.get("NOMOS_AUTO_TILE", "1") not in {"0", "no", "false", "off"}
    warmup_enabled = os.environ.get("NOMOS_WARMUP", "1") not in {"0", "no", "false", "off"}
    warmup_passes = env_int("NOMOS_WARMUP_PASSES", 2) if warmup_enabled else 0

    if tile < 64 or overlap < 0 or overlap * 2 >= tile:
        raise ValueError("NOMOS_TILE >= 64 oraz 0 <= NOMOS_OVERLAP < NOMOS_TILE/2")
    if pad_multiple < 1 or not 0.0 <= blend <= 1.0:
        raise ValueError("Nieprawidłowy NOMOS_PAD_MULTIPLE lub NOMOS_BLEND")
    if not 0.25 <= source_scale <= 1.0:
        raise ValueError("NOMOS_SOURCE_SCALE musi mieścić się w zakresie 0.25–1.0")
    if not 0 <= black_preserve_threshold <= 255:
        raise ValueError("NOMOS_BLACK_PRESERVE_THRESHOLD musi mieścić się w zakresie 0–255")
    if min_free_vram_gib < 0.0:
        raise ValueError("NOMOS_MIN_FREE_VRAM_GIB nie może być ujemne")
    if not 0 <= warmup_passes <= 4:
        raise ValueError("NOMOS_WARMUP_PASSES musi mieścić się w zakresie 0–4")
    if (args.input_file is None) != (args.output_file is None):
        raise ValueError("--input-file i --output-file muszą wystąpić razem")
    if (args.target_width is None) != (args.target_height is None):
        raise ValueError("--target-width i --target-height muszą wystąpić razem")
    if args.target_width is not None and (args.target_width < 1 or args.target_height < 1):
        raise ValueError("Docelowy wymiar musi być dodatni")
    if args.target_width is not None and args.input_file is None:
        raise ValueError("Docelowy wymiar jest dostępny tylko z --input-file")
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
    free_vram_bytes, total_vram_bytes = torch.cuda.mem_get_info(device)
    free_vram_gib = free_vram_bytes / (1024**3)
    if free_vram_gib < min_free_vram_gib:
        raise RuntimeError(
            f"Przed ładowaniem modelu wolne jest tylko {free_vram_gib:.2f} GiB VRAM "
            f"z {total_vram_bytes / (1024**3):.2f} GiB; profil wymaga co najmniej "
            f"{min_free_vram_gib:.2f} GiB. Zamknij procesy używające GPU i spróbuj ponownie."
        )
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
        f"source_scale={source_scale:.2f} blend={blend:.2f} sharpen={sharpen} "
        f"black_preserve_threshold={black_preserve_threshold} warmup_passes={warmup_passes}",
        flush=True,
    )

    if args.input_file is not None:
        if not args.input_file.is_file():
            raise FileNotFoundError(f"Brak pliku wejściowego: {args.input_file}")
        if args.output_file.is_file() and not overwrite:
            print(f"skip {args.input_file}: wynik już istnieje: {args.output_file}", flush=True)
            return 0
        print(f"[file] enhance {args.input_file} -> {args.output_file}", flush=True)
        enhance_one(
            args.input_file,
            args.output_file,
            model,
            device,
            dtype,
            tile,
            overlap,
            pad_multiple,
            scale,
            source_scale,
            blend,
            sharpen,
            black_preserve_threshold,
            warmup_passes,
            args.target_width,
            args.target_height,
        )
        return 0

    with args.manifest.open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    items = manifest.get("wallpapers", [])
    if len(items) != 48:
        raise ValueError("Manifest musi zawierać dokładnie 48 tapet")
    slugs = [item["slug"] for item in items]
    if args.slugs:
        unknown_slugs = [slug for slug in args.slugs if slug not in slugs]
        if unknown_slugs:
            raise ValueError(f"Brak slugów w manifeście: {', '.join(unknown_slugs)}")
        # Preserve the caller's order, but do not infer the same wallpaper twice.
        slugs = list(dict.fromkeys(args.slugs))
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
                        black_preserve_threshold,
                        warmup_passes,
                        None,
                        None,
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
