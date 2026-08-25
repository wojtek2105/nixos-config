#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
wallpaper_root="$repo_root/home/wojtek/wallpapers"
secret_root="${XDG_CONFIG_HOME:-${HOME:?}/.config}/nixos-config/secrets"
key_file="${BFL_API_KEY_FILE:-$secret_root/bfl-wallpapers.key}"
prompt_file="${1:-$wallpaper_root/prompts/flux2/01-moonless-root-archive.txt}"
output_file="${2:-$wallpaper_root/candidates/flux2-max/01-moonless-root-archive-source.jpg}"

# FLUX.2 accepts arbitrary multiples-of-16 dimensions up to 4 MP. This exact
# 32:9 source scales uniformly by 10/7 to the collection's 5120x1440 master.
width="${FLUX_WALLPAPER_WIDTH:-3584}"
height="${FLUX_WALLPAPER_HEIGHT:-1008}"
endpoint="${BFL_API_ENDPOINT:-https://api.bfl.ai/v1/flux-2-max}"

if [[ ! -s "$key_file" ]]; then
  printf 'Brak klucza BFL w %s. Ustaw BFL_API_KEY_FILE.\n' "$key_file" >&2
  exit 1
fi

if [[ ! -s "$prompt_file" ]]; then
  printf 'Brak promptu FLUX w %s.\n' "$prompt_file" >&2
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
submit_file="$tmp_dir/submit.json"
poll_file="$tmp_dir/poll.json"
bfl_key="$(<"$key_file")"

jq -n --rawfile prompt "$prompt_file" \
  --argjson width "$width" --argjson height "$height" '
  {
    prompt: $prompt,
    width: $width,
    height: $height,
    output_format: "jpeg",
    prompt_upsampling: false
  }
' > "$request_file"

curl --fail-with-body --silent --show-error --max-time 60 \
  -H "x-key: $bfl_key" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  --data-binary "@$request_file" \
  "$endpoint" > "$submit_file"

polling_url="$(jq -er '.polling_url' "$submit_file")"
cost="$(jq -r '.cost // "nie podano"' "$submit_file")"
printf 'FLUX.2 Max przyjął zadanie; koszt API: %s kredytów.\n' "$cost"

for _ in $(seq 1 420); do
  curl --fail-with-body --silent --show-error --max-time 30 \
    -H "x-key: $bfl_key" \
    -H 'accept: application/json' \
    "$polling_url" > "$poll_file"

  status="$(jq -r '.status // "unknown"' "$poll_file")"
  case "$status" in
    Ready)
      sample_url="$(jq -er '.result.sample' "$poll_file")"
      curl --fail --silent --show-error --max-time 120 \
        "$sample_url" --output "$output_file"
      cp -- "$prompt_file" "${output_file%.jpg}.prompt.txt"
      unset bfl_key sample_url polling_url
      printf 'Gotowy kandydat FLUX.2 Max: %s\n' "$output_file"
      exit 0
      ;;
    Error|Failed|'Request Moderated'|'Content Moderated')
      unset bfl_key polling_url
      printf 'Generacja FLUX zakończyła się stanem: %s\n' "$status" >&2
      jq -c '{status, details}' "$poll_file" >&2
      exit 2
      ;;
  esac
  sleep 1
done

unset bfl_key polling_url
printf 'Przekroczono 420 s oczekiwania na FLUX.2 Max.\n' >&2
exit 3
