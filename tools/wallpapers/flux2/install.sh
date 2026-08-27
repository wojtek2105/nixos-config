#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
runtime_root="${FLUX2_RUNTIME_ROOT:-${XDG_DATA_HOME:-${HOME:?}/.local/share}/wallpaper-flux2-klein}"
rocm_image="${FLUX2_ROCM_IMAGE:-rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.10.0}"
diffusers_commit="${FLUX2_DIFFUSERS_COMMIT:-0f1abc4ae8b0eb2a3b40e82a310507281144c423}"

if ! command -v docker >/dev/null 2>&1; then
  printf 'Brak klienta Docker. Włącz funkcję docker dla hosta i przebuduj system.\n' >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  printf 'Docker nie działa. Uruchom go ręcznie: sudo systemctl start docker\n' >&2
  exit 1
fi

mkdir -p "$runtime_root/python" "$runtime_root/hf-cache" "$runtime_root/home"

printf 'Pobieram oficjalny obraz AMD ROCm: %s\n' "$rocm_image"
docker pull "$rocm_image"

printf 'Instaluję backend FLUX.2 w %s/python\n' "$runtime_root"
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --env HOME=/workspace/home \
  --env PIP_DISABLE_PIP_VERSION_CHECK=1 \
  --volume "$runtime_root:/workspace" \
  --volume "$repo_root:/repo:ro" \
  --workdir /workspace \
  --env FLUX2_DIFFUSERS_COMMIT="$diffusers_commit" \
  "$rocm_image" \
  bash -lc '
    set -euo pipefail
    rm -rf /workspace/python.next
    mkdir -p /workspace/python.next

    # Never let pip resolve torch here: PyPI may choose a CUDA wheel which
    # shadows the HIP-enabled torch already supplied by the AMD image.
    python3 -m pip install --no-deps --target /workspace/python.next \
      --requirement /repo/tools/wallpapers/flux2/requirements-runtime.txt
    python3 -m pip install --no-deps --target /workspace/python.next \
      "git+https://github.com/huggingface/diffusers.git@${FLUX2_DIFFUSERS_COMMIT}"

    PYTHONPATH=/workspace/python.next python3 -c '\''import accelerate, diffusers, torch, transformers; assert torch.version.hip is not None, f"overlay shadowed ROCm torch: {torch.__version__}"; print("verified torch", torch.__version__, "HIP", torch.version.hip); print("verified diffusers", diffusers.__version__)'\''

    rm -rf /workspace/python.previous
    if [[ -d /workspace/python ]]; then
      mv /workspace/python /workspace/python.previous
    fi
    mv /workspace/python.next /workspace/python
    rm -rf /workspace/python.previous
  '

printf '\nŚrodowisko gotowe (Diffusers %s).\n' "$diffusers_commit"
printf 'FLUX.2 Klein 4B ma otwarte wagi Apache-2.0; HF_TOKEN jest opcjonalny.\n'
printf 'Overlay nie zawiera torch/CUDA; używa wyłącznie PyTorch HIP z obrazu AMD.\n'
printf 'Uruchom tools/wallpapers/flux2/run-6800s.sh gpu-info przed testem.\n'
