#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
wallpaper_root="$repo_root/home/wojtek/wallpapers"
secret_root="${XDG_CONFIG_HOME:-${HOME:?}/.config}/nixos-config/secrets"
key_file="${ARK_API_KEY_FILE:-$secret_root/byteplus-wallpapers.key}"
prompt_file="${1:-$wallpaper_root/prompts/seedream/01-moonless-root-archive.txt}"
output_file="${2:-$wallpaper_root/candidates/seedream5-lite/01-moonless-root-archive-source.png}"

# Defaults generate the native DQHD master with Seedream 5.0 Lite. Override the
# model and size for a Pro-authored 2560x1440 core before Lite outpainting.
image_size="${SEEDREAM_WALLPAPER_SIZE:-5120x1440}"
model="${SEEDREAM_MODEL:-seedream-5-0-lite-260128}"
endpoint="${ARK_IMAGE_ENDPOINT:-https://ark.ap-southeast.bytepluses.com/api/v3/images/generations}"

if [[ ! -s "$key_file" ]]; then
  printf 'Brak klucza BytePlus ModelArk w %s. Ustaw ARK_API_KEY_FILE.\n' "$key_file" >&2
  exit 1
fi

if [[ ! -s "$prompt_file" ]]; then
  printf 'Brak promptu Seedream w %s.\n' "$prompt_file" >&2
  exit 1
fi

if [[ -e "$output_file" && "${WALLPAPER_OVERWRITE:-0}" != "1" ]]; then
  printf 'Kandydat już istnieje: %s. Ustaw WALLPAPER_OVERWRITE=1, aby go zastąpić.\n' \
    "$output_file" >&2
  exit 1
fi

mkdir -p "$(dirname -- "$output_file")"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

request_file="$tmp_dir/request.json"
response_file="$tmp_dir/response.json"
ark_key="$(<"$key_file")"

jq -n --rawfile prompt "$prompt_file" --arg model "$model" --arg size "$image_size" '
  {
    model: $model,
    prompt: $prompt,
    size: $size,
    response_format: "url",
    output_format: "png",
    watermark: false
  }
' > "$request_file"

http_code="$(curl --silent --show-error --max-time 420 \
  --output "$response_file" --write-out '%{http_code}' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ark_key" \
  --data-binary "@$request_file" \
  "$endpoint")"

if [[ ! "$http_code" =~ ^2 ]]; then
  error_code="$(jq -r '.error.code // "UnknownError"' "$response_file" 2>/dev/null || printf 'UnknownError')"
  unset ark_key
  printf 'Seedream API zwróciło HTTP %s (%s).\n' "$http_code" "$error_code" >&2

  case "$error_code" in
    ModelNotOpen)
      printf 'Aktywuj model %s w konsoli ModelArk dla regionu używanego przez endpoint.\n' "$model" >&2
      ;;
    *)
      printf 'Szczegóły odpowiedzi ukryto, aby nie ujawniać identyfikatorów konta ani żądania.\n' >&2
      ;;
  esac

  exit 2
fi

image_url="$(jq -er '.data[0].url' "$response_file")"
curl --fail --silent --show-error --max-time 180 \
  "$image_url" --output "$output_file"
cp -- "$prompt_file" "${output_file%.png}.prompt.txt"

unset ark_key image_url
printf 'Gotowy kandydat modelu %s: %s\n' "$model" "$output_file"
