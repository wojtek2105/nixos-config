#!/usr/bin/env python3
"""Create one isolated FLUX.2 Klein wallpaper candidate; never promote it."""

from __future__ import annotations

import os
import sys
from pathlib import Path

import torch
from diffusers import DiffusionPipeline
from PIL import Image


def positive_int(name: str, default: int) -> int:
    value = int(os.environ.get(name, default))
    if value <= 0:
        raise ValueError(f"{name} must be positive")
    return value


def main() -> int:
    if len(sys.argv) != 4:
        print(f"usage: {sys.argv[0]} INPUT OUTPUT PROMPT", file=sys.stderr)
        return 64

    input_path, output_path, prompt_path = map(Path, sys.argv[1:])
    width = positive_int("FLUX2_WIDTH", 1024)
    height = positive_int("FLUX2_HEIGHT", 288)
    steps = positive_int("FLUX2_STEPS", 4)
    seed = int(os.environ.get("FLUX2_SEED", "24012026"))
    model_id = os.environ.get(
        "FLUX2_MODEL", "black-forest-labs/FLUX.2-klein-4B"
    )
    dtype_name = os.environ.get("FLUX2_DTYPE", "float16")
    dtypes = {
        "bf16": torch.bfloat16,
        "bfloat16": torch.bfloat16,
        "fp16": torch.float16,
        "float16": torch.float16,
    }
    if dtype_name not in dtypes:
        raise ValueError("FLUX2_DTYPE must be fp16/float16 or bf16/bfloat16")
    dtype = dtypes[dtype_name]

    if width % 16 or height % 16:
        raise ValueError("FLUX2_WIDTH and FLUX2_HEIGHT must be divisible by 16")
    if width * 9 != height * 32:
        raise ValueError("test canvas must preserve exact 32:9 aspect ratio")

    source = Image.open(input_path).convert("RGB")
    source = source.resize((width, height), Image.Resampling.LANCZOS)
    prompt = prompt_path.read_text(encoding="utf-8").strip()

    print(f"Loading {model_id} with {dtype_name} and CPU offload", flush=True)
    pipe = DiffusionPipeline.from_pretrained(
        model_id,
        torch_dtype=dtype,
        low_cpu_mem_usage=True,
    )
    if os.environ.get("FLUX2_OFFLOAD", "sequential") == "model":
        pipe.enable_model_cpu_offload()
    else:
        pipe.enable_sequential_cpu_offload()
    if hasattr(pipe, "enable_vae_tiling"):
        pipe.enable_vae_tiling()
    if hasattr(pipe, "vae") and hasattr(pipe.vae, "enable_tiling"):
        pipe.vae.enable_tiling()
    if hasattr(pipe, "vae") and hasattr(pipe.vae, "enable_slicing"):
        pipe.vae.enable_slicing()
    if hasattr(pipe, "enable_attention_slicing"):
        pipe.enable_attention_slicing("max")

    generator = torch.Generator(device="cuda").manual_seed(seed)
    torch.cuda.empty_cache()
    with torch.inference_mode():
        result = pipe(
            image=source,
            prompt=prompt,
            width=width,
            height=height,
            num_inference_steps=steps,
            generator=generator,
        ).images[0]

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = output_path.with_name(f".{output_path.name}.part")
    try:
        result.save(temporary_path, format="PNG", optimize=True)
        temporary_path.replace(output_path)
    finally:
        temporary_path.unlink(missing_ok=True)
    print(f"Candidate saved: {output_path}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
