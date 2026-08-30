#!/usr/bin/env bash
set -euo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
root="${SDXL_OUTPAINT_RUNTIME_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/wallpaper-sdxl-outpaint}"
image="${SDXL_OUTPAINT_ROCM_IMAGE:-rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.10.0}"
input="${1:?podaj obraz źródłowy}"; output="${2:?podaj wynik}"; prompt="${3:?podaj prompt}"
[[ -d "$root/python" ]] || { printf 'Najpierw uruchom install.sh\n' >&2; exit 1; }
docker info >/dev/null || { printf 'Uruchom ręcznie Docker.\n' >&2; exit 1; }
docker run --rm --user "$(id -u):$(id -g)" --device /dev/kfd --device /dev/dri --ipc host \
  --security-opt seccomp=unconfined --group-add "$(stat -c %g /dev/kfd)" \
  -e HOME=/runtime/home -e HF_HOME=/runtime/hf-cache -e PYTHONPATH=/runtime/python \
  -e HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION:-11.0.0}" \
  -v "$root:/runtime" -v "$repo:/repo" -w /repo "$image" \
  python3 tools/wallpapers/sdxl-outpaint/outpaint.py "$input" "$output" "$prompt"
