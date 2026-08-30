#!/usr/bin/env bash
set -euo pipefail
root="${SDXL_OUTPAINT_RUNTIME_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/wallpaper-sdxl-outpaint}"
image="${SDXL_OUTPAINT_ROCM_IMAGE:-rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.10.0}"
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
docker info >/dev/null || { printf 'Uruchom ręcznie Docker przed instalacją.\n' >&2; exit 1; }
mkdir -p "$root"/{home,hf-cache}
docker pull "$image"
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/runtime/home \
  -v "$root:/runtime" -v "$repo:/repo:ro" "$image" bash -lc '
    set -euo pipefail
    rm -rf /runtime/python.next; mkdir /runtime/python.next
    python3 -m pip install --no-deps --target /runtime/python.next -r /repo/tools/wallpapers/sdxl-outpaint/requirements-runtime.txt
    PYTHONPATH=/runtime/python.next python3 -c "import torch; assert torch.version.hip; import diffusers"
    rm -rf /runtime/python; mv /runtime/python.next /runtime/python
  '
printf 'Gotowe: %s\n' "$root"
