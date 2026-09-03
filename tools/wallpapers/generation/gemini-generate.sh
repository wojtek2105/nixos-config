#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
wallpaper_root="$repo_root/home/base/wallpapers"
secret_root="${XDG_CONFIG_HOME:-${HOME:?}/.config}/nixos-config/secrets"
key_file="${GEMINI_API_KEY_FILE:-$secret_root/gemini-wallpapers.key}"
prompt_file="${1:-}"
output_file="${2:-}"

# Nano Banana Pro creates the native core from the prompt's own size and aspect
# instructions. No separate size parameter is needed.
model="${GEMINI_MODEL:-gemini-3-pro-image}"
endpoint="${GEMINI_ENDPOINT:-https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent}"

if [[ -z "$prompt_file" ]]; then
  printf 'Użycie: %s PROMPT_FILE OUTPUT_FILE\n' "$0" >&2
  exit 64
fi

if [[ ! -s "$key_file" ]]; then
  printf 'Brak klucza Gemini API w %s. Ustaw GEMINI_API_KEY_FILE.\n' "$key_file" >&2
  exit 1
fi

if [[ ! -s "$prompt_file" ]]; then
  printf 'Brak promptu w %s.\n' "$prompt_file" >&2
  exit 1
fi

if [[ -z "$output_file" ]]; then
  printf 'Podaj ścieżkę wyjściową (drugi argument).\n' >&2
  exit 64
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
api_key="$(<"$key_file")"

jq -n \
  --rawfile prompt "$prompt_file" '
  {
    contents: [
      {
        role: "user",
        parts: [
          { text: $prompt }
        ]
      }
    ],
    generationConfig: {
      responseModalities: ["IMAGE"]
    }
  }
' > "$request_file"

http_code="$(curl --silent --show-error --max-time 420 \
  --output "$response_file" --write-out '%{http_code}' \
  -H 'Content-Type: application/json' \
  -H "x-goog-api-key: $api_key" \
  --data-binary "@$request_file" \
  "$endpoint")"

if [[ ! "$http_code" =~ ^2 ]]; then
  error_msg="$(jq -r '.error.message // "UnknownError"' "$response_file" 2>/dev/null || printf 'UnknownError')"
  unset api_key
  printf 'Gemini API zwróciło HTTP %s: %s\n' "$http_code" "$error_msg" >&2
  exit 2
fi

image_b64="$(jq -er '
  .candidates[0].content.parts[]
  | select(.inlineData != null)
  | .inlineData.data
' "$response_file" 2>/dev/null || printf '')"

if [[ -z "$image_b64" ]]; then
  unset api_key
  printf 'Brak obrazu w odpowiedzi Gemini. Odpowiedź:\n' >&2
  jq -c '.candidates[0].content.parts[] | {mimeType: .mimeType, text: (.text // null)}' \
    "$response_file" 2>/dev/null >&2
  exit 2
fi

printf '%s' "$image_b64" | base64 --decode > "$output_file"
cp -- "$prompt_file" "${output_file%.png}.prompt.txt"

unset api_key
printf 'Gotowy kandydat modelu %s: %s\n' "$model" "$output_file"
