#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
wallpaper_root="$repo_root/home/base/wallpapers"
secret_root="${XDG_CONFIG_HOME:-${HOME:?}/.config}/nixos-config/secrets"
key_file="${ARK_API_KEY_FILE:-$secret_root/byteplus-wallpapers.key}"
prompt_file="${1:-$wallpaper_root/prompts/final-18/01-frieren-grimoire-vault.pro.txt}"
output_file="${2:-$wallpaper_root/work/01-frieren-grimoire-vault-core.png}"
global_prompt_file="${SEEDREAM_GLOBAL_PROMPT_FILE:-}"
reference_file="${SEEDREAM_REFERENCE_FILE:-}"

# Defaults create the native 16:9 core with Lite 5.0. Callers may override the
# model explicitly; outpainting remains a separate edit call.
image_size="${SEEDREAM_WALLPAPER_SIZE:-2560x1440}"
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
if [[ -n "$global_prompt_file" && ! -s "$global_prompt_file" ]]; then
  printf 'Brak globalnego kontraktu Seedream w %s.\n' "$global_prompt_file" >&2
  exit 1
fi
if [[ -n "$reference_file" && ! -s "$reference_file" ]]; then
  printf 'Brak referencji stylu Seedream w %s.\n' "$reference_file" >&2
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
encoded_reference_file="$tmp_dir/reference.b64"
download_file="$tmp_dir/generated-image"
if [[ -n "$reference_file" ]]; then
  base64 --wrap=0 "$reference_file" > "$encoded_reference_file"
  case "${reference_file,,}" in
    *.jpg|*.jpeg) reference_mime="image/jpeg" ;;
    *.webp) reference_mime="image/webp" ;;
    *) reference_mime="image/png" ;;
  esac
else
  : > "$encoded_reference_file"
  reference_mime="image/png"
fi
ark_key="$(<"$key_file")"

supports_output_format=true
if [[ "$model" == seedream-4-5-* || "$model" == seedream-4-0-* ]]; then
  supports_output_format=false
fi

jq -n \
  --rawfile global_prompt "${global_prompt_file:-/dev/null}" \
  --rawfile scene_prompt "$prompt_file" \
  --rawfile encoded_reference "$encoded_reference_file" \
  --arg reference_mime "$reference_mime" \
  --arg model "$model" \
  --arg size "$image_size" \
  --argjson supports_output_format "$supports_output_format" '
  {
    model: $model,
    prompt: (
      if $global_prompt == "" then $scene_prompt
      else $global_prompt + "\n\n" + $scene_prompt
      end
    ),
    size: $size,
    response_format: "url",
    watermark: false
  }
  + (if $supports_output_format then {output_format: "png"} else {} end)
  + (
    if $encoded_reference == "" then {}
    else {image: "data:" + $reference_mime + ";base64," + $encoded_reference}
    end
  )
' > "$request_file"

http_code="$(curl --silent --show-error --max-time 420 \
  --output "$response_file" --write-out '%{http_code}' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ark_key" \
  --data-binary "@$request_file" \
  "$endpoint")"

if [[ ! "$http_code" =~ ^2 ]]; then
  error_code="$(jq -r '.error.code // "UnknownError"' "$response_file" 2>/dev/null || printf 'UnknownError')"
  if [[ -n "${SEEDREAM_ERROR_CODE_FILE:-}" ]]; then
    printf '%s\n' "$error_code" > "$SEEDREAM_ERROR_CODE_FILE"
  fi
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
  "$image_url" --output "$download_file"
if [[ -n "${MAGICK_BIN:-}" ]]; then
  magick_bin="$MAGICK_BIN"
elif command -v magick >/dev/null 2>&1; then
  magick_bin="$(command -v magick)"
else
  magick_candidates=(/nix/store/*-imagemagick-*/bin/magick)
  magick_bin="${magick_candidates[0]:-}"
fi
if [[ -n "$magick_bin" && -x "$magick_bin" ]]; then
  "$magick_bin" "$download_file" \
    -strip -define png:color-type=2 -define png:compression-level=9 \
    "$output_file"
else
  mv -- "$download_file" "$output_file"
fi
jq -r '.prompt' "$request_file" > "${output_file%.png}.prompt.txt"

unset ark_key image_url
printf 'Gotowy kandydat modelu %s: %s\n' "$model" "$output_file"
