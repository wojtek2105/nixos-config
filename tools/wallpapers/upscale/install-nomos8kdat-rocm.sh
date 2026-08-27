#!/usr/bin/env bash
set -euo pipefail

data_root="${XDG_DATA_HOME:-${HOME:?}/.local/share}"
runtime_root="${NOMOS_RUNTIME_ROOT:-$data_root/wallpaper-nomos8kdat}"
model_dir="$runtime_root/models"
python_dir="$runtime_root/python"
image="${NOMOS_ROCM_IMAGE:-rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.10.0}"
model_name="4xNomos8kDAT.safetensors"
# The checkpoint itself is pinned by SHA-256. Using the stable resolve URL
# avoids tying the installer to the earlier README-only commit, which did not
# yet contain the current safetensors filename.
model_url="https://huggingface.co/Phips/4xNomos8kDAT/resolve/main/$model_name"
model_sha256="1ddb1be06180daae8d583ef387c1020abed32085a0448bca624f4f4310949868"

case "$runtime_root" in
  /|"${HOME:?}"|"$data_root")
    printf 'NOMOS_RUNTIME_ROOT wskazuje zbyt szeroki katalog: %s\n' "$runtime_root" >&2
    exit 64
    ;;
esac

for command in docker curl sha256sum; do
  command -v "$command" >/dev/null 2>&1 || { printf 'Brak polecenia: %s\n' "$command" >&2; exit 1; }
done
docker info >/dev/null
mkdir -p "$model_dir"

if [[ ! -s "$model_dir/$model_name" ]] \
  || ! printf '%s  %s\n' "$model_sha256" "$model_dir/$model_name" | sha256sum --check --status; then
  temporary_model="$(mktemp "$model_dir/.${model_name}.XXXXXX")"
  trap 'rm -f -- "$temporary_model"' EXIT
  printf 'Pobieranie %s (około 154 MB)...\n' "$model_name"
  curl --fail --location --retry 3 --output "$temporary_model" "$model_url"
  printf '%s  %s\n' "$model_sha256" "$temporary_model" | sha256sum --check --status \
    || { printf 'Błędna suma SHA-256 modelu.\n' >&2; exit 1; }
  mv -- "$temporary_model" "$model_dir/$model_name"
  trap - EXIT
fi

next_python="$runtime_root/python.next"
previous_python="$runtime_root/python.previous"
rm -rf -- "$next_python"
mkdir -p "$next_python"

printf 'Przygotowanie lekkiego środowiska Spandrel bez podmiany PyTorch ROCm...\n'
docker run --rm \
  -v "$runtime_root:/runtime" \
  -w /runtime \
  "$image" \
  bash -lc '
    set -euo pipefail
    python3 -m pip install --no-deps --target /runtime/python.next \
      spandrel==0.4.2 \
      safetensors==0.8.0 \
      einops==0.8.2 \
      typing_extensions==4.16.0 \
      pillow==11.3.0
    PYTHONPATH=/runtime/python.next python3 -c "
import torch
assert torch.version.hip, torch.__version__
from PIL import Image
from spandrel import ImageModelDescriptor, ModelLoader
print(\"torch\", torch.__version__, \"HIP\", torch.version.hip)
print(\"Spandrel i Pillow gotowe\")
"
  '

rm -rf -- "$previous_python"
if [[ -d "$python_dir" ]]; then
  mv -- "$python_dir" "$previous_python"
fi
mv -- "$next_python" "$python_dir"
rm -rf -- "$previous_python"

printf 'Gotowe. Model: %s\n' "$model_dir/$model_name"
printf 'Najpierw test: tools/wallpapers/upscale/run-nomos-6800s.sh test 01-frieren\n'
