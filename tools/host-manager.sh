#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="$repo_root/tools/host-manager.sh"

if ! command -v nix >/dev/null 2>&1; then
  printf 'Host Manager wymaga polecenia nix. Uruchom go na NixOS lub w środowisku z Nixem.\n' >&2
  exit 127
fi

if [[ -z "${HOST_MANAGER_SHELL:-}" ]] \
  && { ! command -v gum >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; }; then
  printf 'Uruchamiam jednorazowy nix shell z Gum, jq i Git…\n'
  exec env HOST_MANAGER_SHELL=1 nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#findutils \
    nixpkgs#git nixpkgs#gnused nixpkgs#gum nixpkgs#jq \
    --command bash "$script_path" "$@"
fi

for command in gum jq git; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Brakuje %s w tymczasowym środowisku.\n' "$command" >&2
    exit 127
  }
done

host_pattern='^[a-z0-9][a-z0-9-]*$'
name_pattern='^[a-z_][a-z0-9_-]*$'
module_keys=(common bootSplash desktop developmentCore hardwareAmdGpu hardwareAsusLaptop lanMouse x1e)
feature_keys=(amdGpuMetrics bluetooth docker ollama ollamaFarm gaming vr screenRecording hardwareDiagnostics schedulerBenchmark laptop voxtype)
personal_app_keys=(discord easyeffects plexamp)
menu_separator=$'\037'

# Each entry is intentionally explained in the TUI.  Manifest keys are stable
# implementation details, whereas the manager is meant to be usable without
# knowing the repository's Nix module names.
module_label() {
  case "$1" in
    common) printf 'Podstawa systemu' ;;
    bootSplash) printf 'Ekran startowy' ;;
    desktop) printf 'Pulpit Hyprland' ;;
    developmentCore) printf 'Narzędzia programistyczne' ;;
    hardwareAmdGpu) printf 'Grafika AMD' ;;
    hardwareAsusLaptop) printf 'Laptop ASUS ROG' ;;
    lanMouse) printf 'Mysz i klawiatura przez LAN' ;;
    x1e) printf 'Snapdragon X Elite (X1E)' ;;
  esac
}

module_description() {
  case "$1" in
    common) printf 'Pakiety bazowe, lokalizacja i ustawienia wspólne dla każdego hosta.' ;;
    bootSplash) printf 'Czarny ekran Plymouth z maskotką podczas uruchamiania.' ;;
    desktop) printf 'Greetd, Hyprland, audio PipeWire i sesja graficzna użytkownika.' ;;
    developmentCore) printf 'Podstawowy zestaw CLI do programowania i administracji systemem.' ;;
    hardwareAmdGpu) printf 'Sterownik amdgpu i ustawienia wymagane przez kartę Radeon.' ;;
    hardwareAsusLaptop) printf 'asusd, asusctl oraz profile energii i chłodzenia laptopów ROG.' ;;
    lanMouse) printf 'Udostępnia mysz i klawiaturę między komputerami w lokalnej sieci.' ;;
    x1e) printf 'Zewnętrzna obsługa laptopów Snapdragon X Elite; tylko ARM64.' ;;
  esac
}

feature_label() {
  case "$1" in
    amdGpuMetrics) printf 'Metryki AMD GPU' ;;
    bluetooth) printf 'Bluetooth' ;;
    docker) printf 'Docker' ;;
    ollama) printf 'Ollama' ;;
    ollamaFarm) printf 'Farma agentów Ollama' ;;
    gaming) printf 'Granie' ;;
    vr) printf 'VR / ALVR' ;;
    screenRecording) printf 'Nagrywanie ekranu' ;;
    hardwareDiagnostics) printf 'Diagnostyka sprzętu' ;;
    schedulerBenchmark) printf 'Benchmark schedulerów' ;;
    laptop) printf 'Funkcje laptopa' ;;
    voxtype) printf 'Dyktowanie Voxtype' ;;
  esac
}

feature_description() {
  case "$1" in
    amdGpuMetrics) printf 'Temperatury, użycie GPU i VRAM w Ironbarze oraz btop.' ;;
    bluetooth) printf 'Usługa BlueZ i integracja Bluetooth w panelu.' ;;
    docker) printf 'Silnik kontenerów i grupa docker dla wskazanego użytkownika.' ;;
    ollama) printf 'Lokalne modele AI w kontenerze; wymaga włączonego Dockera.' ;;
    ollamaFarm) printf 'Zdalne profile Cline dla farmy modeli; wyłącz dla hosta wyłącznie lokalnego.' ;;
    gaming) printf 'Steam, GameMode i optymalizacja responsywności podczas gier.' ;;
    vr) printf 'ALVR, Steam i ADB do przewodowego zestawu VR Quest.' ;;
    screenRecording) printf 'GPU Screen Recorder i bufor powtórek dla sesji Hyprland.' ;;
    hardwareDiagnostics) printf 'Narzędzia do ręcznej diagnostyki sprzętu, nie codzienne metryki.' ;;
    schedulerBenchmark) printf 'Narzędzia obciążeniowe do porównania schedulerów; nie do codziennego użycia.' ;;
    laptop) printf 'Pokrywa, bateria, jasność i elementy panelu właściwe dla laptopa.' ;;
    voxtype) printf 'Lokalne polskie dyktowanie Whisper uruchamiane skrótem klawiszowym.' ;;
  esac
}

personal_app_label() {
  case "$1" in
    discord) printf 'Discord' ;;
    easyeffects) printf 'EasyEffects' ;;
    plexamp) printf 'Plexamp' ;;
  esac
}

personal_app_description() {
  case "$1" in
    discord) printf 'Klient komunikatora Discord.' ;;
    easyeffects) printf 'Korektor i efekty dźwięku PipeWire.' ;;
    plexamp) printf 'Odtwarzacz muzyki Plexamp.' ;;
  esac
}

die() {
  gum style --foreground 196 "$1" >&2
  exit 2
}

render_menu() {
  local title="$1" description="$2" selected="$3"
  shift 3
  local index=0 entry key label details state marker
  clear
  gum style --border double --border-foreground 99 --padding '0 2' --margin '1 2 0' \
    --foreground 255 "$title"
  [[ -n "$description" ]] && gum style --foreground 250 --margin '0 4 1' "$description"
  for entry in "$@"; do
    IFS="$menu_separator" read -r key label details state <<< "$entry"
    if [[ "$state" == true || "$state" == on ]]; then state='WŁ.'; else state='WYŁ.'; fi
    if (( index == selected )); then
      marker='❯'
      gum style --foreground 212 --bold " $marker $label  [$state]"
      gum style --foreground 255 --margin '0 4 0 7' "$details"
    else
      gum style --foreground 245 "   $label  [$state]"
    fi
    ((index += 1))
  done
  gum style --foreground 99 --margin '1 4 0' '↑/↓ wybór   → lub Enter dalej/zmień   ← lub Esc wstecz'
}

# Return the selected internal key.  Right behaves exactly like Enter, while
# Left always leaves the current level so the manager can be used one-handed.
menu_select() {
  local title="$1" description="$2"
  shift 2
  local selected=0 count="$#" key entry
  while true; do
    # menu_select is used in command substitutions; keep the visual UI on the
    # terminal and reserve stdout solely for the selected internal key.
    render_menu "$title" "$description" "$selected" "$@" >&2
    IFS= read -rsn1 key </dev/tty
    if [[ "$key" == $'\e' ]]; then
      IFS= read -rsn2 -t 0.05 key </dev/tty || true
      case "$key" in
        '[A') selected=$(( (selected - 1 + count) % count )) ;;
        '[B') selected=$(( (selected + 1) % count )) ;;
        '[C') IFS="$menu_separator" read -r key _ <<< "${@:$((selected + 1)):1}"; printf '%s\n' "$key"; return ;;
        '[D'|'') printf '%s\n' '__back__'; return ;;
      esac
    elif [[ "$key" == $'\n' || "$key" == $'\r' ]]; then
      IFS="$menu_separator" read -r key _ <<< "${@:$((selected + 1)):1}"
      printf '%s\n' "$key"
      return
    fi
  done
}

host_path() {
  printf '%s/hosts/%s' "$repo_root" "$1"
}

json_path() {
  printf '%s/host.json' "$(host_path "$1")"
}

valid_host() {
  [[ "$1" =~ $host_pattern ]]
}

valid_name() {
  [[ "$1" =~ $name_pattern ]]
}

ensure_profile() {
  [[ -f "$repo_root/home/$1/default.nix" && -f "$repo_root/home/$1/theme.nix" ]]
}

ensure_overlay() {
  local overlay="$1" overlay_dir="$repo_root/home/individual/$1"
  [[ -z "$overlay" || "$overlay" == "null" ]] && return
  valid_name "$overlay" || die "Nakładka ma nieprawidłową nazwę."
  if [[ ! -f "$overlay_dir/override.nix" ]]; then
    mkdir -p "$overlay_dir"
    printf '%s\n' '{ ... }:' '' '{' "  # Indywidualne dodatki dla $overlay; baza pozostaje w home/base." '}' > "$overlay_dir/override.nix"
  fi
}

validate_json() {
  local host="$1" json="${2:-$(json_path "$host")}" 
  jq -e . "$json" >/dev/null || die "host.json nie jest poprawnym JSON-em."
  jq -e '
    (.features.ollama | not) or .features.docker
  ' "$json" >/dev/null || die "Ollama wymaga włączonego Dockera."
  jq -e '
    (.features.ollamaFarm | not) or .features.ollama
  ' "$json" >/dev/null || die "Farma agentów Ollama wymaga włączonej Ollamy."
  jq -e '
    (.modules.hardwareAsusLaptop | not) or .modules.hardwareAmdGpu
  ' "$json" >/dev/null || die "Moduł ASUS wymaga modułu AMD GPU."
  jq -e '
    (.features.laptop | not) or .modules.desktop
  ' "$json" >/dev/null || die "Funkcja laptop wymaga modułu desktop."
  jq -e '
    (.modules.x1e | not) or .system == "aarch64-linux"
  ' "$json" >/dev/null || die "Moduł X1E wymaga systemu aarch64-linux."
  local profile
  profile="$(jq -r '.homeProfile' "$json")"
  ensure_profile "$profile" || die "Brakuje profilu home/$profile."
}

save_json() {
  local host="$1" source="$2" destination temporary
  destination="$(json_path "$host")"
  temporary="$(mktemp "${destination}.XXXXXX")"
  jq --sort-keys . "$source" > "$temporary"
  mv "$temporary" "$destination"
}

new_host_json() {
  local host="$1" username="$2" description="$3" overlay="$4" system="$5" scale="$6"
  jq -n \
    --arg host "$host" \
    --arg username "$username" \
    --arg description "$description" \
    --arg overlay "$overlay" \
    --arg system "$system" \
    --argjson scale "$scale" '
      {
        hostName: $host,
        system: $system,
        username: $username,
        userDescription: $description,
        homeProfile: $username,
        homeOverlay: $overlay,
        uiScale: $scale,
        backlightDevice: null,
        trackball: null,
        replayConfig: { captureSource: "focused_monitor" },
        systemSettings: {
          bootTimeout: 1,
          ignoreLidSwitch: false,
          lanMousePeerHost: null,
          stateVersion: "26.05"
        },
        modules: {
          common: true,
          bootSplash: true,
          desktop: true,
          developmentCore: true,
          hardwareAmdGpu: false,
          hardwareAsusLaptop: false,
          lanMouse: false,
          x1e: false
        },
        features: {
          amdGpuMetrics: false,
          bluetooth: false,
          docker: false,
          ollama: false,
          ollamaFarm: false,
          gaming: false,
          vr: false,
          screenRecording: false,
          hardwareDiagnostics: false,
          schedulerBenchmark: false,
          laptop: false,
          voxtype: false,
          personalApps: { discord: false, easyeffects: false, plexamp: false }
        }
      }
    '
}

write_host_adapter() {
  local host="$1" directory
  directory="$(host_path "$host")"
  printf '%s\n' 'let' '  host = builtins.fromJSON (builtins.readFile ./host.json);' 'in' '{' '  configuration = ./configuration.nix;' '  inherit (host) backlightDevice features homeOverlay homeProfile hostName replayConfig system systemSettings trackball uiScale userDescription username;' '  hostModules = host.modules;' '}' > "$directory/default.nix"
  printf '%s\n' '{ ... }:' '' '{' '  imports = [' '    ./hardware-configuration.nix' '    ../../modules/host-base.nix' '  ];' '}' > "$directory/configuration.nix"
}

new_host() {
  local host username description overlay system scale directory profile_dir temporary
  host="$(gum input --prompt 'Host: ' --placeholder 'nowy-host')"
  valid_host "$host" || die "Host może zawierać małe litery, cyfry i myślniki."
  directory="$(host_path "$host")"
  [[ ! -e "$directory" ]] || die "Katalog hosts/$host już istnieje."
  username="$(gum input --prompt 'Użytkownik: ' --placeholder 'nowy-user')"
  valid_name "$username" || die "Użytkownik może zawierać małe litery, cyfry, _ i -."
  description="$(gum input --prompt 'Opis użytkownika: ' --value "$username")"
  overlay="$(gum input --prompt 'Nazwa indywidualnej nakładki: ' --value "$username")"
  ensure_overlay "$overlay"
  profile_dir="$repo_root/home/$username"
  if [[ ! -e "$profile_dir/default.nix" ]]; then
    mkdir -p "$profile_dir"
    printf '%s\n' '{ ... }:' '' '{' '  imports = [ ../base/default.nix ];' '}' > "$profile_dir/default.nix"
  fi
  system="$(menu_select 'Architektura hosta' 'Dobierz ją do procesora docelowego komputera.' \
    "x86_64-linux${menu_separator}Komputer Intel / AMD${menu_separator}Typowe pecety i laptopy z procesorem x86_64.${menu_separator}off" \
    "aarch64-linux${menu_separator}Komputer ARM64${menu_separator}Snapdragon i inne komputery ARM64; wymagane również dla modułu X1E.${menu_separator}off")"
  [[ "$system" != '__back__' ]] || return
  scale="$(menu_select 'Skala interfejsu' 'Skala 2 jest właściwa dla ekranów HiDPI; większość monitorów używa skali 1.' \
    "1${menu_separator}Skala 1${menu_separator}Natywna gęstość dla standardowych monitorów.${menu_separator}off" \
    "2${menu_separator}Skala 2${menu_separator}Czytelniejszy interfejs na gęstych ekranach HiDPI.${menu_separator}off")"
  [[ "$scale" != '__back__' ]] || return

  mkdir "$directory"
  trap 'rmdir -- "$directory" 2>/dev/null || true' ERR
  temporary="$(mktemp)"
  new_host_json "$host" "$username" "$description" "$overlay" "$system" "$scale" > "$temporary"
  save_json "$host" "$temporary"
  rm -f "$temporary"
  write_host_adapter "$host"
  trap - ERR
  gum style --foreground 212 "Utworzono hosts/$host/. Wygeneruj jeszcze hardware-configuration.nix na docelowym sprzęcie."
  gum style --foreground 214 "Nowy katalog jest objęty allowlistą .gitignore; dodaj hosts/$host przed commitem."
  edit_host "$host"
}

toggle_group() {
  local host="$1" path="$2" title="$3"
  shift 3
  local key state temporary choice description label
  while true; do
    local -a choices=()
    for key in "$@"; do
      state="$(jq -r --arg path "$path" --arg key "$key" 'getpath($path | split("."))[$key]' "$(json_path "$host")")"
      case "$path" in
        modules) label="$(module_label "$key")"; description="$(module_description "$key")" ;;
        features) label="$(feature_label "$key")"; description="$(feature_description "$key")" ;;
        features.personalApps) label="$(personal_app_label "$key")"; description="$(personal_app_description "$key")" ;;
      esac
      choices+=("$key$menu_separator$label$menu_separator$description$menu_separator$state")
    done
    choices+=("__back__$menu_separator Wróć$menu_separator Powrót do ustawień hosta bez zmiany.$menu_separator off")
    choice="$(menu_select "$title" 'Wybierz pozycję, aby przełączyć jej stan. Zależności są sprawdzane przed zapisem.' "${choices[@]}")"
    [[ "$choice" != '__back__' ]] || return
    temporary="$(mktemp)"
    cp "$(json_path "$host")" "$temporary"
    # Toggle only the selected key; this keeps the name, description and
    # resulting state together instead of requiring a cryptic multi-select.
    jq --arg path "$path" --arg key "$choice" 'setpath($path | split(".") + [$key]; (getpath($path | split("."))[$key] | not))' "$temporary" > "${temporary}.next"
    mv "${temporary}.next" "$temporary"
    validate_json "$host" "$temporary"
    save_json "$host" "$temporary"
    rm -f "$temporary"
  done
}

edit_basics() {
  local host="$1" json temporary value
  json="$(json_path "$host")"
  temporary="$(mktemp)"
  cp "$json" "$temporary"
  value="$(gum input --prompt 'Hostname sieciowy: ' --value "$(jq -r '.hostName' "$json")")"
  valid_host "$value" || die "Hostname może zawierać małe litery, cyfry i myślniki."
  jq --arg value "$value" '.hostName = $value' "$temporary" > "${temporary}.next" && mv "${temporary}.next" "$temporary"
  value="$(gum input --prompt 'Użytkownik: ' --value "$(jq -r '.username' "$json")")"
  valid_name "$value" || die "Użytkownik ma nieprawidłową nazwę."
  jq --arg value "$value" '.username = $value' "$temporary" > "${temporary}.next" && mv "${temporary}.next" "$temporary"
  value="$(gum input --prompt 'Opis użytkownika: ' --value "$(jq -r '.userDescription' "$json")")"
  jq --arg value "$value" '.userDescription = $value' "$temporary" > "${temporary}.next" && mv "${temporary}.next" "$temporary"
  value="$(gum input --prompt 'Indywidualna nakładka: ' --value "$(jq -r '.homeOverlay // ""' "$json")")"
  ensure_overlay "$value"
  jq --arg value "$value" '.homeProfile = .username | .homeOverlay = (if $value == "" then null else $value end)' "$temporary" > "${temporary}.next" && mv "${temporary}.next" "$temporary"
  value="$(menu_select 'Architektura hosta' 'Wybierz architekturę procesora tego komputera.' \
    "x86_64-linux${menu_separator}Komputer Intel / AMD${menu_separator}Typowy pecet lub laptop z procesorem x86_64.${menu_separator}off" \
    "aarch64-linux${menu_separator}Komputer ARM64${menu_separator}Snapdragon i inne komputery ARM64; wymagane dla X1E.${menu_separator}off")"
  [[ "$value" != '__back__' ]] || return
  jq --arg value "$value" '.system = $value' "$temporary" > "${temporary}.next" && mv "${temporary}.next" "$temporary"
  value="$(menu_select 'Skala interfejsu' 'Skala 2 jest właściwa dla ekranów HiDPI.' \
    "1${menu_separator}Skala 1${menu_separator}Natywna gęstość dla standardowych monitorów.${menu_separator}off" \
    "2${menu_separator}Skala 2${menu_separator}Czytelniejszy interfejs na gęstych ekranach HiDPI.${menu_separator}off")"
  [[ "$value" != '__back__' ]] || return
  jq --argjson value "$value" '.uiScale = $value' "$temporary" > "${temporary}.next" && mv "${temporary}.next" "$temporary"
  validate_json "$host" "$temporary"
  save_json "$host" "$temporary"
  rm -f "$temporary"
}

run_action() {
  local host="$1" action command
  action="$(menu_select 'Następny krok' 'Manager nie uruchamia poleceń bez Twojego dodatkowego potwierdzenia.' \
    "save${menu_separator}Tylko zapisz${menu_separator}Pozostaw zmiany w katalogu roboczym.${menu_separator}off" \
    "check${menu_separator}Sprawdź flake${menu_separator}Ewaluuje wszystkie outputy bez aktywacji systemu.${menu_separator}off" \
    "build${menu_separator}Zbuduj konfigurację${menu_separator}Buduje wybrany host bez aktywacji.${menu_separator}off" \
    "test${menu_separator}Aktywuj tymczasowo${menu_separator}nixos-rebuild test; zmiany znikną po restarcie.${menu_separator}off" \
    "switch${menu_separator}Aktywuj na stałe${menu_separator}nixos-rebuild switch; stosuj po pomyślnym teście.${menu_separator}off")"
  case "$action" in
    save|'__back__') return ;;
    check) command=(nix flake check path:.) ;;
    build) command=(nix build "path:.#nixosConfigurations.$host.config.system.build.toplevel" --no-link) ;;
    test) command=(sudo nixos-rebuild test --flake "path:.#$host") ;;
    switch) command=(sudo nixos-rebuild switch --flake "path:.#$host") ;;
  esac
  gum confirm "Uruchomić: ${command[*]}?" || return
  (cd "$repo_root" && "${command[@]}")
}

edit_host() {
  local host="$1" action
  while true; do
    action="$(menu_select "Host: $host" "Użytkownik: $(jq -r '.username' "$(json_path "$host")") · wspólny profil: home/$(jq -r '.homeProfile' "$(json_path "$host")"). Nakładka rozszerza bazę, ale jej nie kopiuje." \
      "basics${menu_separator}Dane podstawowe${menu_separator}Nazwa hosta, konto użytkownika, nakładka, architektura i skala.${menu_separator}off" \
      "modules${menu_separator}Moduły systemowe${menu_separator}Elementy konstrukcyjne NixOS, np. pulpit, GPU i sprzęt.${menu_separator}off" \
      "features${menu_separator}Funkcje hosta${menu_separator}Opcjonalne możliwości, np. Docker, Bluetooth, VR i nagrywanie.${menu_separator}off" \
      "apps${menu_separator}Aplikacje osobiste${menu_separator}Opcjonalne programy sesji użytkownika.${menu_separator}off" \
      "json${menu_separator}Pokaż manifest JSON${menu_separator}Podgląd dokładnie tego, co zostanie użyte przez flake.${menu_separator}off" \
      "diff${menu_separator}Pokaż różnice i wybierz akcję${menu_separator}Przegląd zmian, potem opcjonalny check, build, test lub switch.${menu_separator}off" \
      "__back__${menu_separator}Wróć${menu_separator}Powrót do listy hostów.${menu_separator}off")"
    case "$action" in
      basics) edit_basics "$host" ;;
      modules) toggle_group "$host" modules 'Moduły systemowe' "${module_keys[@]}" ;;
      features) toggle_group "$host" features 'Funkcje hosta' "${feature_keys[@]}" ;;
      apps) toggle_group "$host" features.personalApps 'Aplikacje osobiste' "${personal_app_keys[@]}" ;;
      json) jq . "$(json_path "$host")" | gum pager ;;
      diff) git -C "$repo_root" diff -- "hosts/$host" | gum pager; run_action "$host" ;;
      '__back__') return ;;
    esac
  done
}

choose_existing_host() {
  local host description username profile
  local -a choices=()
  while IFS= read -r host; do
    username="$(jq -r '.username' "$(json_path "$host")")"
    profile="$(jq -r '.homeProfile' "$(json_path "$host")")"
    description="Konto ${username}; wspólny profil home/${profile}."
    choices+=("$host$menu_separator$host$menu_separator$description$menu_separator off")
  done < <(find "$repo_root/hosts" -mindepth 2 -maxdepth 2 -name host.json -printf '%h\n' | sed 's#.*/##' | sort)
  choices+=("__back__$menu_separator Wróć$menu_separator Powrót do ekranu głównego.$menu_separator off")
  host="$(menu_select 'Wybierz host' 'Każdy host ma osobny manifest sprzętu i może współdzielić profil Home Managera.' "${choices[@]}")"
  [[ "$host" != '__back__' ]] && edit_host "$host"
}

if [[ "${1:-}" == "--new" ]]; then
  new_host
  exit 0
fi

case "$(menu_select 'NixOS Host Manager' 'Deklaratywne hosty NixOS i współdzielone profile Home Managera.' \
  "new${menu_separator}Utwórz host od zera${menu_separator}Tworzy manifest host.json i stałe adaptery Nix; konfigurację sprzętu dodajesz na docelowym urządzeniu.${menu_separator}off" \
  "edit${menu_separator}Edytuj istniejący host${menu_separator}Zmień konto, moduły i funkcje bez ręcznego edytowania Nix.${menu_separator}off" \
  "quit${menu_separator}Zakończ${menu_separator}Wyjdź bez wprowadzania zmian.${menu_separator}off")" in
  new) new_host ;;
  edit) choose_existing_host ;;
esac
