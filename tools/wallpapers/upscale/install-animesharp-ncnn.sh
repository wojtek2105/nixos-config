#!/usr/bin/env bash
set -euo pipefail

# Pinned author-provided NCNN build of 4x-AnimeSharp. The immutable revision
# and checksums keep a later upstream replacement from silently changing the
# model used for the wallpaper collection.
revision="94dab98f2766c5a182c7f86aa7a2eed388f0257c"
model_name="4x-AnimeSharp-fp16"
data_root="${XDG_DATA_HOME:-${HOME:?}/.local/share}"
models_root="${ANIMESHARP_MODELS:-$data_root/animesharp-ncnn/models}"
base_url="https://huggingface.co/Kim2091/AnimeSharp/resolve/$revision/NCNN"

mkdir -p "$models_root"

download_model_file() {
  local suffix="$1"
  local expected_sha256="$2"
  local destination="$models_root/$model_name.$suffix"
  local temporary

  if [[ -s "$destination" ]] \
    && printf '%s  %s\n' "$expected_sha256" "$destination" | sha256sum --check --status; then
    printf 'Model już istnieje i ma poprawną sumę: %s\n' "$destination"
    return
  fi

  temporary="$(mktemp "$models_root/.${model_name}.${suffix}.XXXXXX")"
  trap 'rm -f -- "$temporary"' RETURN
  curl --fail --location --retry 3 --output "$temporary" \
    "$base_url/$model_name.$suffix"
  printf '%s  %s\n' "$expected_sha256" "$temporary" | sha256sum --check --status \
    || { printf 'Błędna suma SHA-256 dla %s.\n' "$suffix" >&2; exit 1; }
  mv -- "$temporary" "$destination"
  trap - RETURN
  printf 'Zainstalowano: %s\n' "$destination"
}

download_model_file param 0332002123306541c803cd675280eee7f9cdd96f0804a47129f86ebbf9ed4174
download_model_file bin e01e08a518c815f38a99b265d7221e2801c8429ff35e3f14403693a81cd78252

printf 'AnimeSharp NCNN jest gotowy w: %s\n' "$models_root"
printf 'Licencja modelu: CC BY-NC-SA 4.0 (użytek niekomercyjny).\n'
