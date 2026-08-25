#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
wallpaper_root="$repo_root/home/wojtek/wallpapers"
prompt_root="$wallpaper_root/prompts"
global_prompt="${WALLPAPER_GLOBAL_PROMPT:-$prompt_root/00-global-production.txt}"
# Optional model-specific geometry contract, for example the removable matte
# used to obtain a native 32:9 art strip from Gemini Pro's 21:9 canvas.
framing_prompt="${WALLPAPER_FRAMING_PROMPT:-}"
# Override for isolated provider/model comparisons; the production collection
# continues to use sources/ unless a caller explicitly selects another path.
source_root="${WALLPAPER_SOURCE_ROOT:-$wallpaper_root/sources}"
secret_root="${XDG_CONFIG_HOME:-${HOME:?}/.config}/nixos-config/secrets"
key_file="${GEMINI_API_KEY_FILE:-$secret_root/gemini-wallpapers.key}"
model="${GEMINI_IMAGE_MODEL:-gemini-3.1-flash-image}"
# Gemini Pro tops out at 21:9, while Flash can provide the collection's 4:1
# source. Keep both knobs explicit so a model test cannot silently change the
# production geometry or quality tier.
aspect_ratio="${WALLPAPER_ASPECT_RATIO:-4:1}"
image_size="${WALLPAPER_IMAGE_SIZE:-4K}"
api_url="https://generativelanguage.googleapis.com/v1beta/interactions"
from_scene="${1:-01}"
to_scene="${2:-22}"

if [[ ! -s "$key_file" ]]; then
  printf 'Brak klucza Gemini w %s. Ustaw GEMINI_API_KEY_FILE.\n' "$key_file" >&2
  exit 1
fi

if [[ ! -s "$global_prompt" ]]; then
  printf 'Brak globalnego promptu w %s. Ustaw WALLPAPER_GLOBAL_PROMPT.\n' "$global_prompt" >&2
  exit 1
fi

if [[ -n "$framing_prompt" && ! -s "$framing_prompt" ]]; then
  printf 'Brak promptu kadrowania w %s. Ustaw WALLPAPER_FRAMING_PROMPT.\n' "$framing_prompt" >&2
  exit 1
fi

mkdir -p "$source_root"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

gemini_key="$(<"$key_file")"
failures=()

for scene_prompt in "$prompt_root"/[0-9][0-9]-*.txt; do
  scene_file="$(basename -- "$scene_prompt")"
  scene_id="${scene_file%%-*}"
  [[ "$scene_id" == "00" || "$scene_id" == "99" ]] && continue
  (( 10#$scene_id < 10#$from_scene || 10#$scene_id > 10#$to_scene )) && continue

  slug="${scene_file%.txt}"
  output="$source_root/${slug}-source.jpg"
  final_prompt="$source_root/${slug}-source.prompt.txt"
  combined_prompt="$tmp_dir/${slug}.prompt.txt"

  if [[ -e "$output" && "${WALLPAPER_OVERWRITE:-0}" != "1" ]]; then
    printf '[%s] pomijam istniejący plik: %s\n' "$scene_id" "$output"
    continue
  fi

  {
    printf '%s\n\n' '=== GLOBAL CONTRACT ==='
    sed -n '1,$p' "$global_prompt"
    if [[ -n "$framing_prompt" ]]; then
      printf '%s\n\n' '=== PROVIDER FRAMING CONTRACT ==='
      sed -n '1,$p' "$framing_prompt"
    fi
    printf '%s\n\n' '=== SCENE BRIEF ==='
    sed -n '1,$p' "$scene_prompt"
  } > "$combined_prompt"

  request="$tmp_dir/${slug}.request.json"
  response="$tmp_dir/${slug}.response.json"
  encoded="$tmp_dir/${slug}.base64"
  candidate="$tmp_dir/${slug}.jpg"

  jq -n --rawfile prompt "$combined_prompt" --arg model "$model" \
    --arg aspect_ratio "$aspect_ratio" --arg image_size "$image_size" '
    {
      model: $model,
      input: $prompt,
      response_format: {
        type: "image",
        mime_type: "image/jpeg",
        aspect_ratio: $aspect_ratio,
        image_size: $image_size
      }
    }
  ' > "$request"

  printf '[%s] generuję %s...\n' "$scene_id" "$slug"
  generated=0
  for attempt in 1 2 3; do
    if curl --fail-with-body --silent --show-error --max-time 420 \
      -H "x-goog-api-key: $gemini_key" \
      -H 'Content-Type: application/json' \
      --data-binary "@$request" \
      "$api_url" > "$response"; then
      if jq -r '
          .steps[]?
          | select(.type == "model_output")
          | .content[]?
          | select(.type == "image" and .data != null)
          | .data
        ' "$response" > "$encoded" && [[ -s "$encoded" ]]; then
        base64 --decode "$encoded" > "$candidate"
        mv -- "$candidate" "$output"
        cp -- "$combined_prompt" "$final_prompt"
        generated=1
        break
      fi
    fi
    printf '[%s] próba %s/3 nie zwróciła obrazu.\n' "$scene_id" "$attempt" >&2
  done

  if (( generated == 0 )); then
    failures+=("$slug")
    printf '[%s] NIEPOWODZENIE: %s\n' "$scene_id" "$slug" >&2
  else
    printf '[%s] gotowe źródło: %s\n' "$scene_id" "$output"
  fi
done

unset gemini_key

if (( ${#failures[@]} > 0 )); then
  printf 'Nie wygenerowano %s scen:\n' "${#failures[@]}" >&2
  printf '  %s\n' "${failures[@]}" >&2
  exit 2
fi

printf 'Wygenerowano cały wybrany zakres %s–%s.\n' "$from_scene" "$to_scene"
