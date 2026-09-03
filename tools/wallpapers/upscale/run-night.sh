#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
data_root="${XDG_DATA_HOME:-${HOME:?}/.local/share}"
realesrgan_bin="${REALESRGAN_BIN:-$data_root/realesrgan-ncnn-vulkan/realesrgan-ncnn-vulkan}"
models_root="${REALESRGAN_MODELS:-$data_root/realesrgan-ncnn-vulkan/models}"
model="${REALESRGAN_MODEL:-realesrgan-x4plus-anime}"
scale="${REALESRGAN_SCALE:-4}"
tile="${REALESRGAN_TILE:-256}"
gpu_id="${REALESRGAN_GPU_ID:-1}"
shard_count="${UPSCALE_SHARDS:-4}"
log_dir="$repo_root/home/base/wallpapers/work/import-48/upscale-logs"

run_worker() {
  local shard="$1"
  local total="$2"

  printf 'START shard=%s/%s model=%s scale=%s tile=%s gpu=%s stage=%s time=%s\n' \
    "$shard" "$total" "$model" "$scale" "$tile" "$gpu_id" \
    "${UPSCALE_STAGE_NAME:-upscaled-32x9}" "$(date --iso-8601=seconds)"
  set +e
  env \
    REALESRGAN_BIN="$realesrgan_bin" \
    REALESRGAN_MODELS="$models_root" \
    REALESRGAN_MODEL="$model" \
    REALESRGAN_SCALE="$scale" \
    REALESRGAN_TILE="$tile" \
    REALESRGAN_GPU_ID="$gpu_id" \
    "$repo_root/tools/wallpapers/upscale/collection.sh" run "$shard" "$total"
  local worker_status="$?"
  printf 'END shard=%s status=%s time=%s\n' \
    "$shard" "$worker_status" "$(date --iso-8601=seconds)"
  return "$worker_status"
}

if [[ ! -x "$realesrgan_bin" ]]; then
  printf 'Brak wykonywalnej binarki Real-ESRGAN: %s\n' "$realesrgan_bin" >&2
  printf 'Pobierz pakiet Linux i ustaw REALESRGAN_BIN przed uruchomieniem.\n' >&2
  exit 1
fi
if [[ ! -d "$models_root" ]]; then
  printf 'Brak katalogu modeli Real-ESRGAN: %s\n' "$models_root" >&2
  exit 1
fi
if [[ ! "$shard_count" =~ ^[1-9][0-9]*$ ]]; then
  printf 'UPSCALE_SHARDS musi być dodatnią liczbą.\n' >&2
  exit 64
fi

# Private entry point used below. `setsid` places this worker and every process
# it starts (including Real-ESRGAN) in an independent process group. This lets
# the parent stop the complete inference tree reliably after Ctrl+C.
if [[ "${1:-}" == "--worker" ]]; then
  if [[ $# -ne 3 || ! "$2" =~ ^[0-9]+$ || ! "$3" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Nieprawidłowe argumenty wewnętrznego workera.\n' >&2
    exit 64
  fi
  if (( 10#$2 >= 10#$3 )); then
    printf 'Indeks wewnętrznego workera wykracza poza liczbę shardów.\n' >&2
    exit 64
  fi
  run_worker "$2" "$3"
  exit "$?"
fi

mkdir -p "$log_dir"
pids=()
cleanup_needed=1

stop_workers() {
  local signal="${1:-TERM}"
  local pid

  (( cleanup_needed == 1 )) || return 0
  cleanup_needed=0
  trap - INT TERM HUP EXIT
  printf '\nZatrzymuję wszystkie procesy upscalingu...\n' >&2
  for pid in "${pids[@]}"; do
    # Each PID is also the process-group ID created by setsid.
    kill -"$signal" -- "-$pid" 2>/dev/null || kill -"$signal" "$pid" 2>/dev/null || true
  done
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done
  printf 'Procesy upscalingu zostały zatrzymane.\n' >&2
}

interrupt_workers() {
  stop_workers INT
  exit 130
}

terminate_workers() {
  stop_workers TERM
  exit 143
}

trap interrupt_workers INT
trap terminate_workers TERM HUP
trap 'stop_workers TERM' EXIT

for (( shard = 0; shard < shard_count; shard++ )); do
  log_file="$log_dir/shard-$shard.log"
  : > "$log_file"
  setsid "$repo_root/tools/wallpapers/upscale/run-night.sh" \
    --worker "$shard" "$shard_count" >"$log_file" 2>&1 &
  pid="$!"
  pids+=("$pid")
  printf 'Uruchomiono shard %d/%d (PID %s), log: %s\n' \
    "$((shard + 1))" "$shard_count" "$pid" "$log_file"
done

failures=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    failures=$((failures + 1))
  fi
done

cleanup_needed=0
trap - INT TERM HUP EXIT

if (( failures > 0 )); then
  printf 'Upscaling zakończone błędami workerów: %d.\n' "$failures" >&2
  exit 1
fi
printf 'Upscaling zakończone dla wszystkich shardów.\n'
