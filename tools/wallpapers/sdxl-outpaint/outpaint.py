#!/usr/bin/env python3
"""Mask-only SDXL outpaint: the model receives only a left-side edit mask."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import torch
from diffusers import AutoPipelineForInpainting
from PIL import Image, ImageDraw


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(f"usage: {sys.argv[0]} SOURCE OUTPUT PROMPT")
    source_path, output_path, prompt_path = map(Path, sys.argv[1:])
    width = int(os.environ.get("SDXL_OUTPAINT_WIDTH", "2560"))
    height = int(os.environ.get("SDXL_OUTPAINT_HEIGHT", "720"))
    steps = int(os.environ.get("SDXL_OUTPAINT_STEPS", "36"))
    overlap = int(os.environ.get("SDXL_OUTPAINT_OVERLAP", "512"))
    if width * 9 != height * 32 or width % 8 or height % 8:
        raise ValueError("canvas must be an 8-aligned 32:9 size")
    core_width = width // 2
    if not 0 <= overlap < core_width:
        raise ValueError("SDXL_OUTPAINT_OVERLAP must fit inside the right core")
    core = Image.open(source_path).convert("RGB")
    core = core.resize((core_width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (width, height), "black")
    canvas.paste(core, (core_width, 0))
    mask = Image.new("L", (width, height), 0)
    # A wide environmental overlap lets roots, mist and lighting blend before
    # the protected character area; 512 px is safe for the current right core.
    ImageDraw.Draw(mask).rectangle((0, 0, core_width + overlap - 1, height), fill=255)
    pipe = AutoPipelineForInpainting.from_pretrained(
        os.environ.get("SDXL_OUTPAINT_MODEL", "diffusers/stable-diffusion-xl-1.0-inpainting-0.1"),
        torch_dtype=torch.float16,
        variant="fp16",
    )
    pipe.enable_model_cpu_offload()
    pipe.enable_vae_tiling()
    generator = torch.Generator("cuda").manual_seed(int(os.environ.get("SDXL_OUTPAINT_SEED", "42")))
    result = pipe(
        prompt=prompt_path.read_text(encoding="utf-8"), image=canvas, mask_image=mask,
        width=width, height=height, num_inference_steps=steps, guidance_scale=6.5,
        generator=generator,
    ).images[0]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(output_path)


if __name__ == "__main__":
    main()
