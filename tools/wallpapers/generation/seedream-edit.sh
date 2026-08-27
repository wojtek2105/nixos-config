#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
wallpaper_root="$repo_root/home/wojtek/wallpapers"
secret_root="${XDG_CONFIG_HOME:-${HOME:?}/.config}/nixos-config/secrets"
key_file="${ARK_API_KEY_FILE:-$secret_root/byteplus-wallpapers.key}"
source_file="${1:-$wallpaper_root/work/01-frieren-grimoire-vault-core.png}"
prompt_file="${2:-$wallpaper_root/prompts/final-18/01-frieren-grimoire-vault.lite.txt}"
output_file="${3:-$wallpaper_root/work/01-frieren-grimoire-vault-master.png}"
reference_file="${SEEDREAM_REFERENCE_FILE:-}"

# Keep the native DQHD canvas during image-to-image repair. Seedream receives
# the local source as an in-request data URI, so it never needs public hosting.
image_size="${SEEDREAM_WALLPAPER_SIZE:-5120x1440}"
model="${SEEDREAM_MODEL:-seedream-5-0-lite-260128}"
endpoint="${ARK_IMAGE_ENDPOINT:-https://ark.ap-southeast.bytepluses.com/api/v3/images/generations}"

if [[ ! -s "$key_file" ]]; then
  printf 'Brak klucza BytePlus ModelArk w %s. Ustaw ARK_API_KEY_FILE.\n' "$key_file" >&2
  exit 1
fi

if [[ ! -s "$source_file" ]]; then
  printf 'Brak obrazu źródłowego w %s.\n' "$source_file" >&2
  exit 1
fi

if [[ ! -s "$prompt_file" ]]; then
  printf 'Brak promptu edycji Seedream w %s.\n' "$prompt_file" >&2
  exit 1
fi

if [[ -n "$reference_file" && ! -s "$reference_file" ]]; then
  printf 'Brak obrazu referencyjnego w %s.\n' "$reference_file" >&2
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

if [[ -n "${MAGICK_BIN:-}" ]]; then
  magick_bin="$MAGICK_BIN"
elif command -v magick >/dev/null 2>&1; then
  magick_bin="$(command -v magick)"
else
  magick_candidates=(/nix/store/*-imagemagick-*/bin/magick)
  magick_bin="${magick_candidates[0]:-}"
fi

if [[ -z "$magick_bin" || ! -x "$magick_bin" ]]; then
  printf 'Nie znaleziono ImageMagick. Ustaw MAGICK_BIN.\n' >&2
  exit 1
fi

# Model zawsze otrzymuje prawdziwy PNG 2560x1440. Prawostronny crop zachowuje
# akcję przygotowaną pod pulpit, a proporcjonalne skalowanie nie rozciąga JPG.
normalized_source="$tmp_dir/source.png"
"$magick_bin" "$source_file" \
  -auto-orient -resize '2560x1440^' -gravity east -extent 2560x1440 \
  -strip -define png:color-type=2 "$normalized_source"

encoded_image_file="$tmp_dir/source.b64"
encoded_reference_file="$tmp_dir/reference.b64"
request_file="$tmp_dir/request.json"
response_file="$tmp_dir/response.json"
download_file="$tmp_dir/generated-image"
base64 --wrap=0 "$normalized_source" > "$encoded_image_file"
if [[ -n "$reference_file" ]]; then
  normalized_reference="$tmp_dir/reference.png"
  "$magick_bin" "$reference_file" -auto-orient -strip "$normalized_reference"
  base64 --wrap=0 "$normalized_reference" > "$encoded_reference_file"
else
  : > "$encoded_reference_file"
fi
ark_key="$(<"$key_file")"

# Seedream 4.5 i 4.0 zwracają wyłącznie JPEG i odrzucają output_format.
# Wynik jest niżej normalizowany do PNG niezależnie od wersji modelu.
supports_output_format=true
if [[ "$model" == seedream-4-5-* || "$model" == seedream-4-0-* ]]; then
  supports_output_format=false
fi

jq -n \
  --rawfile prompt "$prompt_file" \
  --rawfile encoded_image "$encoded_image_file" \
  --rawfile encoded_reference "$encoded_reference_file" \
  --arg model "$model" \
  --arg size "$image_size" \
  --argjson supports_output_format "$supports_output_format" '
    ({
      model: $model,
      prompt: $prompt,
      image: (
        if $encoded_reference == "" then
          "data:image/png;base64," + $encoded_image
        else
          [
            "data:image/png;base64," + $encoded_image,
            "data:image/png;base64," + $encoded_reference
          ]
        end
      ),
      size: $size,
      response_format: "url",
      watermark: false
    } + if $supports_output_format then { output_format: "png" } else {} end)
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
  printf 'Szczegóły odpowiedzi ukryto, aby nie ujawniać identyfikatorów konta ani żądania.\n' >&2
  exit 2
fi

image_url="$(jq -er '.data[0].url' "$response_file")"
curl --fail --silent --show-error --max-time 180 \
  "$image_url" --output "$download_file"
"$magick_bin" "$download_file" \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$output_file"
cp -- "$prompt_file" "${output_file%.png}.prompt.txt"

unset ark_key image_url
printf 'Gotowa poprawka modelu %s: %s\n' "$model" "$output_file"
