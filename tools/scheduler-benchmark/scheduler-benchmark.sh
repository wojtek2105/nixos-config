set -o errexit
set -o nounset
set -o pipefail

reporter="${SCHEDULER_BENCH_REPORTER:-$(cd "$(dirname "$0")" && pwd)/report.py}"
benchmark_unit="scx-scheduler-benchmark.service"

usage() {
  cat <<'EOF'
Porównuje EEVDF, bpfland, LAVD i Flash w dwóch profilach CPU.
Profil GPU pozostaje dostępny jako jawny test diagnostyczny.
Harness używa LAVD 1.1.2; pozostałe schedulery SCX pochodzą z flake.lock.

Użycie:
  scheduler-benchmark run [opcje]
  scheduler-benchmark status
  scheduler-benchmark report KATALOG_WYNIKÓW

Opcje run:
  --runs N                    Liczba powtórzeń na scheduler i profil (domyślnie 2)
  --schedulers LISTA         eevdf,bpfland,lavd,flash
  --profiles LISTA           Profile oddzielone przecinkami
                             (domyślnie desktop-cpu,gaming-cpu; dostępny też gpu)
  --desktop-duration SEK     Czas próbnika pulpitu (domyślnie 30)
  --desktop-period-us US     Okres próbki pulpitu (domyślnie 10000)
  --cooldown SEK             Przerwa między próbami (domyślnie 10)
  --gaming-size WxH|auto     Rozdzielczość profilu CPU gaming (domyślnie aktywny monitor)
  --gpu-size WxH|auto        Rozdzielczość profilu GPU (domyślnie aktywny monitor)
  --gpu-prime WARTOŚĆ        GPU Mesa: auto, default, 1! lub pci-...! (domyślnie auto)
  --output KATALOG           Katalog końcowego raportu
  --allow-battery            Zezwól na niemiarodajny test na baterii
  --yes                      Pomiń pytanie o rozpoczęcie
  -h, --help                 Pokaż pomoc

Domyślny raport:
  docs/benchmark-results/RRRR-MM-DD_GG-MM-SS/

Skrypt przełącza scheduler tylko na czas pomiaru i przywraca scx.service także
po Ctrl+C. Nie zmienia deklaratywnej konfiguracji NixOS.
EOF
}

active_state() {
  if [[ -r /sys/kernel/sched_ext/state ]]; then
    tr -d '\n' < /sys/kernel/sched_ext/state
  else
    printf 'unavailable'
  fi
}

active_ops() {
  local path value
  for path in /sys/kernel/sched_ext/*/ops; do
    [[ -r "$path" ]] || continue
    value="$(tr -d '\n' < "$path")"
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return
    fi
  done
  printf 'eevdf'
}

detect_power_source() {
  local battery_present=false
  local external_power=false
  local online supply supply_type

  for supply in /sys/class/power_supply/*; do
    [[ -r "$supply/type" ]] || continue
    read -r supply_type < "$supply/type"
    case "$supply_type" in
      Battery)
        battery_present=true
        ;;
      Mains|UPS|USB|USB_DCP|USB_CDP|USB_ACA|USB_C|USB_PD|USB_PD_DRP|Apple_Brick_ID|Wireless)
        if [[ -r "$supply/online" ]]; then
          read -r online < "$supply/online"
          if [[ "$online" == 1 ]]; then
            external_power=true
          fi
        fi
        ;;
    esac
  done

  if [[ "$battery_present" == true && "$external_power" == false ]]; then
    printf 'battery'
  else
    printf 'external'
  fi
}

detect_monitor_size() {
  local monitor_json
  monitor_json="$(hyprctl monitors -j 2>/dev/null)"
  python3 -c '
import json, sys
monitors = [m for m in json.load(sys.stdin) if not m.get("disabled")]
if not monitors:
    raise SystemExit(1)
monitor = next((m for m in monitors if m.get("focused")), None)
if monitor is None:
    monitor = max(monitors, key=lambda m: m.get("width", 0) * m.get("height", 0))
width = int(monitor.get("width", 0))
height = int(monitor.get("height", 0))
if width < 1 or height < 1:
    raise SystemExit(1)
print(f"{width}x{height}")
' <<< "$monitor_json"
}

detect_gpu_prime() {
  local boot_vga card card_name device pci_selector
  local first_nondefault_device=""
  local -A gpu_devices=()

  for card in /sys/class/drm/card[0-9]*; do
    card_name="${card##*/}"
    [[ "$card_name" =~ ^card[0-9]+$ ]] || continue
    [[ -e "$card/device" ]] || continue
    device="$(readlink -f "$card/device")"
    [[ -n "$device" ]] || continue
    gpu_devices["$device"]=1
    boot_vga=""
    if [[ -r "$card/device/boot_vga" ]]; then
      read -r boot_vga < "$card/device/boot_vga"
    fi
    if [[ "$boot_vga" == 0 && -z "$first_nondefault_device" ]]; then
      first_nondefault_device="${device##*/}"
    fi
  done

  if (( ${#gpu_devices[@]} > 1 )); then
    if [[ -n "$first_nondefault_device" ]]; then
      # Dokładny adres PCI jest stabilniejszy niż kolejność kart. Mesa wymaga
      # podkreśleń zamiast dwukropków i kropek; profil Vulkan użyje też !.
      pci_selector="${first_nondefault_device//[:.]/_}"
      printf 'pci-%s!' "$pci_selector"
    else
      # Gdy sterownik nie ujawnia boot_vga, numer 1 nadal oznacza pierwsze GPU
      # inne niż domyślne.
      printf '1!'
    fi
  else
    printf 'default'
  fi
}

validate_positive_integer() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 1 )); then
    printf '%s musi być dodatnią liczbą całkowitą.\n' "$name" >&2
    exit 2
  fi
}

validate_size() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[0-9]+x[0-9]+$ ]]; then
    printf '%s musi mieć format WxH, np. 2560x1440.\n' "$name" >&2
    exit 2
  fi
}

validate_gpu_prime() {
  local value="$1"
  if [[ "$value" != auto && "$value" != default && ! "$value" =~ ^([0-9]+|pci-[0-9A-Fa-f_]+)!?$ ]]; then
    printf '%s\n' \
      '--gpu-prime musi być równe auto/default, numerowi Mesa (np. 1!) albo identyfikatorowi pci-....' \
      >&2
    exit 2
  fi
}

validate_list() {
  local kind="$1"
  local values="$2"
  local value
  local -a parsed_values
  IFS=',' read -r -a parsed_values <<< "$values"
  for value in "${parsed_values[@]}"; do
    case "$kind:$value" in
      scheduler:eevdf|scheduler:bpfland|scheduler:lavd|scheduler:flash)
        ;;
      profile:desktop-cpu|profile:gaming-cpu|profile:gpu)
        ;;
      *)
        printf 'Nieobsługiwana wartość %s: %s\n' "$kind" "$value" >&2
        exit 2
        ;;
    esac
  done
}

show_status() {
  printf 'sched_ext state: %s\n' "$(active_state)"
  printf 'active ops:      %s\n' "$(active_ops)"
  printf 'scx.service:     %s\n' "$(systemctl is-active scx.service 2>/dev/null || true)"
  systemctl show scx.service -p ExecStart --value 2>/dev/null || true
}

command_name="${1:-run}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$command_name" in
  -h|--help|help)
    usage
    exit 0
    ;;
  status)
    show_status
    exit 0
    ;;
  report)
    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 2
    fi
    result_directory="$1"
    python3 "$reporter" report \
      --results-dir "$result_directory/raw/results" \
      --metadata "$result_directory/metadata.json" \
      --output "$result_directory/REPORT.md" \
      --csv "$result_directory/results.csv"
    printf 'Odświeżono raport: %s/REPORT.md\n' "$result_directory"
    exit 0
    ;;
  run)
    ;;
  *)
    printf 'Nieznane polecenie: %s\n' "$command_name" >&2
    usage >&2
    exit 2
    ;;
esac

runs=2
schedulers_csv="eevdf,bpfland,lavd,flash"
profiles_csv="desktop-cpu,gaming-cpu"
desktop_duration=30
desktop_period_us=10000
cooldown=10
gaming_size="auto"
gpu_size="auto"
gpu_prime="auto"
output_directory=""
allow_battery=false
assume_yes=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)
      runs="${2:?Brak wartości dla --runs}"
      shift 2
      ;;
    --schedulers)
      schedulers_csv="${2:?Brak wartości dla --schedulers}"
      shift 2
      ;;
    --profiles)
      profiles_csv="${2:?Brak wartości dla --profiles}"
      shift 2
      ;;
    --desktop-duration)
      desktop_duration="${2:?Brak wartości dla --desktop-duration}"
      shift 2
      ;;
    --desktop-period-us)
      desktop_period_us="${2:?Brak wartości dla --desktop-period-us}"
      shift 2
      ;;
    --cooldown)
      cooldown="${2:?Brak wartości dla --cooldown}"
      shift 2
      ;;
    --gaming-size)
      gaming_size="${2:?Brak wartości dla --gaming-size}"
      shift 2
      ;;
    --gpu-size)
      gpu_size="${2:?Brak wartości dla --gpu-size}"
      shift 2
      ;;
    --gpu-prime)
      gpu_prime="${2:?Brak wartości dla --gpu-prime}"
      shift 2
      ;;
    --output)
      output_directory="${2:?Brak wartości dla --output}"
      shift 2
      ;;
    --allow-battery)
      allow_battery=true
      shift
      ;;
    --yes)
      assume_yes=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Nieznana opcja: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

validate_positive_integer "--runs" "$runs"
validate_positive_integer "--desktop-duration" "$desktop_duration"
validate_positive_integer "--desktop-period-us" "$desktop_period_us"
validate_positive_integer "--cooldown" "$cooldown"
validate_list scheduler "$schedulers_csv"
validate_list profile "$profiles_csv"

declare -a schedulers profiles
IFS=',' read -r -a schedulers <<< "$schedulers_csv"
IFS=',' read -r -a profiles <<< "$profiles_csv"

has_game_profile=false
has_gaming_cpu_profile=false
has_gpu_profile=false

for required_command in python3 stress-ng systemctl systemd-run systemd-inhibit; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'Brakuje wymaganego polecenia: %s\n' "$required_command" >&2
    exit 1
  fi
done

for profile in "${profiles[@]}"; do
  if [[ "$profile" == gaming-cpu || "$profile" == gpu ]]; then
    has_game_profile=true
    if [[ "$profile" == gaming-cpu ]]; then
      has_gaming_cpu_profile=true
    else
      has_gpu_profile=true
    fi
    for required_command in supertuxkart gamemoderun hyprctl; do
      if ! command -v "$required_command" >/dev/null 2>&1; then
        printf 'Brakuje wymaganego polecenia: %s\n' "$required_command" >&2
        exit 1
      fi
    done
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
      printf 'Profile graficzne wymagają aktywnej sesji Wayland.\n' >&2
      exit 1
    fi
  fi
done

detected_monitor_size=""
if [[ "$gaming_size" == auto && "$has_gaming_cpu_profile" == true ]] || \
  [[ "$gpu_size" == auto && "$has_gpu_profile" == true ]]
then
  if ! detected_monitor_size="$(detect_monitor_size)"; then
    printf 'Nie udało się odczytać rozdzielczości aktywnego monitora przez hyprctl.\n' >&2
    exit 1
  fi
fi
if [[ "$gaming_size" == auto && "$has_gaming_cpu_profile" == true ]]; then
  gaming_size="$detected_monitor_size"
fi
if [[ "$gpu_size" == auto && "$has_gpu_profile" == true ]]; then
  gpu_size="$detected_monitor_size"
fi
if [[ "$gaming_size" != auto ]]; then
  validate_size "--gaming-size" "$gaming_size"
fi
if [[ "$gpu_size" != auto ]]; then
  validate_size "--gpu-size" "$gpu_size"
fi
if [[ "$gpu_prime" == auto && "$has_game_profile" == true ]]; then
  gpu_prime="$(detect_gpu_prime)"
fi
validate_gpu_prime "$gpu_prime"

if [[ "$(detect_power_source)" == battery && "$allow_battery" != true ]]; then
  printf 'Benchmark wymaga zasilania zewnętrznego. Użyj --allow-battery tylko do diagnostyki.\n' >&2
  exit 1
fi

if [[ "${SCHEDULER_BENCH_INHIBITED:-0}" != 1 ]]; then
  export SCHEDULER_BENCH_INHIBITED=1
  declare -a inhibit_arguments
  inhibit_arguments=(
    run
    --runs "$runs"
    --schedulers "$schedulers_csv"
    --profiles "$profiles_csv"
    --desktop-duration "$desktop_duration"
    --desktop-period-us "$desktop_period_us"
    --cooldown "$cooldown"
    --gaming-size "$gaming_size"
    --gpu-size "$gpu_size"
    --gpu-prime "$gpu_prime"
  )
  if [[ -n "$output_directory" ]]; then
    inhibit_arguments+=(--output "$output_directory")
  fi
  if [[ "$allow_battery" == true ]]; then
    inhibit_arguments+=(--allow-battery)
  fi
  if [[ "$assume_yes" == true ]]; then
    inhibit_arguments+=(--yes)
  fi
  exec systemd-inhibit \
    --what=sleep:idle \
    --mode=block \
    --why="Benchmark schedulerów" \
    "$0" "${inhibit_arguments[@]}"
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
run_id="$(date +%F_%H-%M-%S)"
if [[ -z "$output_directory" ]]; then
  output_directory="$repo_root/docs/benchmark-results/$run_id"
fi
output_directory="$(realpath -m "$output_directory")"
if [[ -e "$output_directory" ]]; then
  printf 'Katalog wynikowy już istnieje, wybierz nowy przez --output: %s\n' \
    "$output_directory" >&2
  exit 1
fi

logical_cpus="$(nproc)"
desktop_workers=$((logical_cpus - 2))
if (( desktop_workers < 1 )); then
  desktop_workers=1
fi
gaming_workers="$logical_cpus"
total_cases=$((${#schedulers[@]} * ${#profiles[@]} * runs))

printf 'Plan: %s prób (%s schedulerów × %s profili × %s powtórzeń).\n' \
  "$total_cases" "${#schedulers[@]}" "${#profiles[@]}" "$runs"
printf 'Schedulery: %s\n' "$schedulers_csv"
if [[ ",$schedulers_csv," == *,lavd,* ]]; then
  printf 'LAVD:       %s\n' "$(scx_lavd --version | head -n 1)"
fi
printf 'Profile:    %s\n' "$profiles_csv"
if [[ "$has_game_profile" == true ]]; then
  printf 'GPU Mesa:   %s\n' "$gpu_prime"
  if [[ "$has_gaming_cpu_profile" == true ]]; then
    printf 'CPU gaming: %s (Vulkan, low, pełny ekran; render target sprawdzany)\n' \
      "$gaming_size"
  fi
  if [[ "$has_gpu_profile" == true ]]; then
    printf 'V-Sync:     wyłączony (Vulkan CPU: immediate; OpenGL GPU: swap 0; limit STK: 9999 FPS)\n'
  else
    printf 'V-Sync:     wyłączony (Vulkan CPU: immediate; limit STK: 9999 FPS)\n'
  fi
fi
printf 'Raport:     %s\n' "$output_directory"
printf 'Zamknij zbędne aplikacje i wyłącz replay/nagrywanie przed rozpoczęciem.\n'

if [[ "$assume_yes" != true ]]; then
  read -r -p 'Rozpocząć benchmark? [y/N] ' answer
  case "$answer" in
    y|Y|yes|YES|tak|TAK)
      ;;
    *)
      printf 'Anulowano.\n'
      exit 0
      ;;
  esac
fi

lock_file="${XDG_RUNTIME_DIR:-/tmp}/scheduler-benchmark.lock"
exec 9>"$lock_file"
if ! flock -n 9; then
  printf 'Inny benchmark schedulerów już działa.\n' >&2
  exit 1
fi

sudo -v
original_state="$(active_state)"
original_ops="$(active_ops)"
if systemctl is-active --quiet scx.service; then
  original_service_active=true
else
  original_service_active=false
fi
if [[ "$original_state" == enabled && "$original_service_active" != true ]]; then
  printf 'Aktywny scheduler nie jest zarządzany przez scx.service; nie potrafię go bezpiecznie odtworzyć.\n' >&2
  exit 1
fi

work_directory="$(mktemp -d "${TMPDIR:-/tmp}/scheduler-benchmark.XXXXXX")"
mkdir -p "$work_directory/raw/results" "$work_directory/raw/logs"

python3 "$reporter" metadata \
  --output "$work_directory/metadata.json" \
  --repo-root "$repo_root" \
  --runs "$runs" \
  --schedulers "$schedulers_csv" \
  --profiles "$profiles_csv" \
  --desktop-duration "$desktop_duration" \
  --desktop-period-us "$desktop_period_us" \
  --cooldown "$cooldown" \
  --gaming-size "$gaming_size" \
  --gpu-size "$gpu_size" \
  --gpu-prime "$gpu_prime" \
  --original-state "$original_state" \
  --original-ops "$original_ops"

scheduler_touched=false
finalized=false
background_pid=""
game_pid=""
sudo_keepalive_pid=""
scheduler_arguments=()

scheduler_args_label() {
  if (( ${#scheduler_arguments[@]} > 0 )); then
    printf '%s' "${scheduler_arguments[*]}"
  else
    printf 'default'
  fi
}

stop_background() {
  if [[ -n "$background_pid" ]]; then
    if kill -0 "$background_pid" 2>/dev/null; then
      kill "$background_pid" 2>/dev/null || true
    fi
    wait "$background_pid" 2>/dev/null || true
  fi
  background_pid=""
}

stop_game() {
  if [[ -n "$game_pid" ]]; then
    if kill -0 "$game_pid" 2>/dev/null; then
      kill "$game_pid" 2>/dev/null || true
    fi
    wait "$game_pid" 2>/dev/null || true
  fi
  game_pid=""
}

stop_benchmark_scheduler() {
  sudo systemctl stop "$benchmark_unit" >/dev/null 2>&1 || true
}

dump_scheduler_log() {
  local profile="$1"
  local scheduler="$2"
  local round="$3"
  local started_at="$4"
  local log_path="$work_directory/raw/logs/${profile}_${scheduler}_${round}_scheduler.log"

  {
    printf 'captured_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'sched_ext_state=%s\n' "$(active_state)"
    printf 'active_ops=%s\n' "$(active_ops)"
    printf 'scheduler_args=%s\n\n' "$(scheduler_args_label)"
    systemctl status "$benchmark_unit" --no-pager || true
    journalctl -u "$benchmark_unit" --since "$started_at" --no-pager || true
  } >"$log_path" 2>&1

  printf 'raw/logs/%s' "$(basename "$log_path")"
}

wait_for_sched_ext_disabled() {
  local attempt
  for ((attempt = 0; attempt < 50; attempt++)); do
    [[ "$(active_state)" != enabled ]] && return 0
    sleep 0.1
  done
  return 1
}

restore_original_scheduler() {
  [[ "$scheduler_touched" == true ]] || return 0
  stop_benchmark_scheduler
  wait_for_sched_ext_disabled || true
  if [[ "$original_service_active" == true ]]; then
    sudo systemctl start scx.service
  else
    sudo systemctl stop scx.service >/dev/null 2>&1 || true
  fi
  scheduler_touched=false
}

finalize_results() {
  local report_error_log="$work_directory/raw/logs/report-generation.log"
  [[ "$finalized" == false ]] || return 0
  finalized=true
  if ! python3 "$reporter" report \
    --results-dir "$work_directory/raw/results" \
    --metadata "$work_directory/metadata.json" \
    --output "$work_directory/REPORT.md" \
    --csv "$work_directory/results.csv" \
    2>"$report_error_log"
  then
    printf 'Nie udało się wygenerować REPORT.md; zachowuję dane surowe i %s.\n' \
      "$report_error_log" >&2
  fi
  mkdir -p "$output_directory"
  cp -a "$work_directory/." "$output_directory/"
  printf '\nZapisano raport i komplet logów: %s\n' "$output_directory"
}

cleanup() {
  local exit_code
  exit_code=$?
  trap - EXIT INT TERM
  stop_game
  stop_background
  restore_original_scheduler || true
  if [[ -n "$sudo_keepalive_pid" ]]; then
    kill "$sudo_keepalive_pid" 2>/dev/null || true
  fi
  finalize_results
  exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

(
  trap - EXIT INT TERM
  while kill -0 "$$" 2>/dev/null; do
    sudo -n true 2>/dev/null || true
    sleep 45
  done
) &
sudo_keepalive_pid=$!

activate_scheduler() {
  local scheduler="$1"
  local profile="$2"
  local binary expected attempt

  scheduler_arguments=()
  scheduler_touched=true
  stop_background
  stop_benchmark_scheduler
  sudo systemctl stop scx.service || return 1
  wait_for_sched_ext_disabled || return 1

  if [[ "$scheduler" == eevdf ]]; then
    return 0
  fi

  if ! binary="$(command -v "scx_$scheduler")"; then
    return 1
  fi
  expected="$scheduler"
  case "$profile:$scheduler" in
    desktop-cpu:bpfland|desktop-cpu:flash)
      ;;
    desktop-cpu:lavd)
      scheduler_arguments=(--autopilot)
      ;;
    gaming-cpu:bpfland|gpu:bpfland)
      scheduler_arguments=(-m performance -P)
      ;;
    gaming-cpu:lavd|gpu:lavd)
      # Keep LAVD's official 5000 us pinned-task slice. The former 500 us
      # override multiplied scheduling churn under full CPU saturation and
      # coincided with an RCU-stall watchdog exit on SCX 1.1.3.
      scheduler_arguments=(--performance)
      ;;
    gaming-cpu:flash|gpu:flash)
      scheduler_arguments=(-m performance)
      ;;
  esac

  sudo systemctl reset-failed "$benchmark_unit" >/dev/null 2>&1 || true
  sudo systemd-run \
    --quiet \
    --collect \
    --unit="$benchmark_unit" \
    --service-type=simple \
    --property=Restart=no \
    -- "$binary" "${scheduler_arguments[@]}" \
    || return 1

  for ((attempt = 0; attempt < 100; attempt++)); do
    if [[ "$(active_state)" == enabled && "$(active_ops)" == *"$expected"* ]]; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

record_failure() {
  local profile="$1"
  local scheduler="$2"
  local round="$3"
  local started_at="$4"
  local raw_log="$5"
  local error="$6"
  local result_path="$work_directory/raw/results/${profile}_${scheduler}_${round}.json"
  local fallback_path="$work_directory/raw/results/${profile}_${scheduler}_${round}.failure.txt"
  if ! python3 "$reporter" failure \
    --output "$result_path" \
    --profile "$profile" \
    --scheduler "$scheduler" \
    --run "$round" \
    --active-ops "$(active_ops)" \
    "--scheduler-args=$(scheduler_args_label)" \
    --raw-log "$raw_log" \
    --started-at "$started_at" \
    --error "$error"
  then
    printf 'profile=%s\nscheduler=%s\nrun=%s\nerror=%s\nraw_log=%s\n' \
      "$profile" "$scheduler" "$round" "$error" "$raw_log" \
      >"$fallback_path"
    printf 'Nie udało się zapisać JSON-u błędu; zapisano %s i test jest kontynuowany.\n' \
      "$fallback_path" >&2
  fi
}

run_desktop_test() {
  local scheduler="$1"
  local round="$2"
  local stem="desktop-cpu_${scheduler}_${round}"
  local load_log="$work_directory/raw/logs/${stem}_stress-ng.log"
  local result_path="$work_directory/raw/results/${stem}.json"
  local started_at load_exit reporter_exit
  started_at="$(date --iso-8601=seconds)"

  stress-ng \
    --cpu "$desktop_workers" \
    --cpu-method matrixprod \
    --timeout "$((desktop_duration + 5))s" \
    --metrics-brief \
    --verify \
    --log-file "$load_log" \
    >"${load_log%.log}.stdout.log" 2>&1 &
  background_pid=$!
  sleep 2

  reporter_exit=0
  python3 "$reporter" latency \
    --output "$result_path" \
    --scheduler "$scheduler" \
    --run "$round" \
    --duration "$desktop_duration" \
    --period-us "$desktop_period_us" \
    --warmup 1 \
    --background-workers "$desktop_workers" \
    --active-ops "$(active_ops)" \
    "--scheduler-args=$(scheduler_args_label)" \
    --raw-log "raw/logs/$(basename "$load_log")" \
    --started-at "$started_at" \
    || reporter_exit=$?

  load_exit=0
  wait "$background_pid" 2>/dev/null || load_exit=$?
  background_pid=""
  (( reporter_exit == 0 && load_exit == 0 ))
}

game_arguments=()
game_environment=()

build_game_arguments() {
  local profile="$1"
  local size="$2"

  game_arguments=(
    --benchmark
    --unlock-all
    --xmas=2
    --easter=2
    --no-sound
    --fullscreen
    "--screensize=$size"
    --disable-addon-karts
    --disable-addon-tracks
    --log=nocolor
  )

  if [[ "$profile" == gaming-cpu ]]; then
    # Niski preset i 720p ograniczają presję GPU, dzięki czemu wynik reaguje
    # głównie na obsługę wątku gry pod równoległym obciążeniem procesora.
    game_arguments+=(
      --render-driver=vulkan
      --enable-texture-compression
      --enable-glow
      --disable-bloom
      --disable-light-shaft
      --disable-dof
      --enable-motion-blur
      --disable-mlaa
      --disable-ssao
      --disable-ibl
      --disable-hd-textures
      --enable-dynamic-lights
      --anisotropic=4
      --shadows=0
    )
  else
    # OpenGL celowo omija regresję Vulkan STK 1.5, która uruchamiała ten build
    # w fixed pipeline. Jakość Ultimate jest zapisana przed startem w kompletnym
    # config.xml; STK 1.5 nie obsługuje odpowiadających jej przełączników CLI.
    game_arguments+=(
      --render-driver=opengl
    )
  fi
}

build_game_environment() {
  local profile="$1"
  local size="$2"
  local state_directory="$3"
  local config_directory="$state_directory/config/supertuxkart/config-0.10"
  local width="${size%x*}"
  local height="${size#*x}"
  local anisotropic bloom degraded_ibl dof effective_gpu_prime geometry_level
  local hd_textures hq_mipmap light_scatter light_shaft mlaa particles pcss
  local non_ge_fullscreen_desktop renderer shadows ssao ssr
  local vulkan_fullscreen_desktop

  if [[ "$profile" == gaming-cpu ]]; then
    renderer=vulkan
    vulkan_fullscreen_desktop=true
    non_ge_fullscreen_desktop=false
    particles=1
    geometry_level=0
    anisotropic=4
    bloom=false
    light_shaft=false
    dof=false
    hd_textures=2
    mlaa=false
    ssao=false
    light_scatter=false
    shadows=0
    degraded_ibl=true
    pcss=false
    ssr=false
    hq_mipmap=false
  else
    renderer=opengl
    vulkan_fullscreen_desktop=false
    non_ge_fullscreen_desktop=true
    particles=2
    geometry_level=5
    anisotropic=16
    bloom=true
    light_shaft=true
    dof=true
    hd_textures=3
    mlaa=true
    ssao=true
    light_scatter=true
    shadows=1024
    degraded_ibl=false
    pcss=true
    ssr=true
    hq_mipmap=true
  fi

  mkdir -p \
    "$config_directory" \
    "$state_directory/data" \
    "$work_directory/game-cache" \
    "$work_directory/mesa-shader-cache"

  # Ustawienia wpływające na urządzenie renderujące muszą istnieć przed startem.
  # Tokeny zachowują jeden kompletny schemat v8 dla obu jakości i rozdzielczości;
  # profil GPU ustawia tu wszystkie składowe natywnego presetu 7 (Ultimate).
  install -m 0600 "$SCHEDULER_BENCH_STK_CONFIG" "$config_directory/config.xml"
  sed -i \
    -e "s/@WIDTH@/$width/g" \
    -e "s/@HEIGHT@/$height/g" \
    -e "s/@PARTICLES@/$particles/g" \
    -e "s/@GEOMETRY_LEVEL@/$geometry_level/g" \
    -e "s/@ANISOTROPIC@/$anisotropic/g" \
    -e "s/@HD_TEXTURES@/$hd_textures/g" \
    -e "s/@BLOOM@/$bloom/g" \
    -e "s/@LIGHT_SHAFT@/$light_shaft/g" \
    -e "s/@DOF@/$dof/g" \
    -e "s/@MLAA@/$mlaa/g" \
    -e "s/@SSAO@/$ssao/g" \
    -e "s/@LIGHT_SCATTER@/$light_scatter/g" \
    -e "s/@SHADOWS@/$shadows/g" \
    -e "s/@DEGRADED_IBL@/$degraded_ibl/g" \
    -e "s/@PCSS@/$pcss/g" \
    -e "s/@SSR@/$ssr/g" \
    -e "s/@HQ_MIPMAP@/$hq_mipmap/g" \
    -e "s/@RENDER_DRIVER@/$renderer/g" \
    -e "s/@VULKAN_FULLSCREEN_DESKTOP@/$vulkan_fullscreen_desktop/g" \
    -e "s/@NON_GE_FULLSCREEN_DESKTOP@/$non_ge_fullscreen_desktop/g" \
    "$config_directory/config.xml"

  # Osobne katalogi XDG nie dotykają prywatnych ustawień gry. Cache shaderów
  # jest wspólny dla prób, ponieważ przed pomiarami wykonujemy kontrolny replay.
  game_environment=(
    "XDG_CONFIG_HOME=$state_directory/config"
    "XDG_DATA_HOME=$state_directory/data"
    "XDG_CACHE_HOME=$work_directory/game-cache"
    "MESA_SHADER_CACHE_DIR=$work_directory/mesa-shader-cache"
    "vblank_mode=0"
    "IRR_DEVICE_TYPE=wayland"
  )
  if [[ "$renderer" == vulkan ]]; then
    game_environment+=("MESA_VK_WSI_PRESENT_MODE=immediate")
  fi
  if [[ "$gpu_prime" != default ]]; then
    effective_gpu_prime="$gpu_prime"
    if [[ "$renderer" == opengl ]]; then
      effective_gpu_prime="${effective_gpu_prime%\!}"
    elif [[ "$effective_gpu_prime" != *'!' ]]; then
      effective_gpu_prime="${effective_gpu_prime}!"
    fi
    game_environment+=("DRI_PRIME=$effective_gpu_prime")
  fi
}

find_supertuxkart_window() {
  hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys
try:
    windows = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
for window in reversed(windows):
    identity = " ".join(
        str(window.get(field, ""))
        for field in ("class", "initialClass", "title", "initialTitle")
    ).lower()
    if "supertuxkart" in identity:
        print(window.get("address", ""))
        break
'
}

wait_for_supertuxkart_track() {
  local game_log="$1"
  local process_pid="$2"
  local attempt current_size last_size=-1 quiet_ticks=0
  local replay_seen=false

  # `Replay: Reading ...` pojawia się dopiero podczas ładowania właściwego
  # toru. Czekamy jeszcze na 1 s ciszy w logu, aby nie przełączać okna na
  # ekranie startowym aplikacji ani podczas kompilacji ostatnich shaderów.
  # STK uruchamia profiler dopiero po późniejszej, 2-sekundowej fazie SET.
  for ((attempt = 0; attempt < 1200; attempt++)); do
    if ! kill -0 "$process_pid" 2>/dev/null; then
      printf 'STK zakończył proces przed końcem ładowania toru.\n' >&2
      return 1
    fi
    if [[ "$replay_seen" == false ]] &&
      grep -q "Replay: Reading replay file .*benchmark_black_forest\.replay" \
        "$game_log" 2>/dev/null
    then
      replay_seen=true
    fi

    if [[ "$replay_seen" == true ]]; then
      current_size="$(stat -c %s "$game_log" 2>/dev/null || printf '0')"
      if [[ "$current_size" == "$last_size" ]]; then
        quiet_ticks=$((quiet_ticks + 1))
      else
        quiet_ticks=0
        last_size="$current_size"
      fi
      (( quiet_ticks >= 20 )) && return 0
    fi
    sleep 0.05
  done

  printf 'STK nie potwierdził końca ładowania toru przed limitem czasu.\n' >&2
  return 1
}

dispatch_hyprland_lua() {
  local stage="$1"
  local expression="$2"
  local response=""

  # Od Hyprlanda 0.55 `hyprctl dispatch` przyjmuje wyrażenie Lua zwracające
  # dispatcher. Zachowujemy jego odpowiedź, aby kolejna awaria nie kończyła się
  # wyłącznie ogólnym komunikatem o nieudanej sekwencji.
  if ! response="$(hyprctl dispatch "$expression" 2>&1)"; then
    printf 'Hyprland: etap „%s” nie powiódł się: %s\n' \
      "$stage" "${response:-brak odpowiedzi hyprctl}" >&2
    return 1
  fi
}

validate_supertuxkart_fullscreen() {
  local address="$1"

  python3 - "$address" <<'PY'
import json
import subprocess
import sys


def hyprland_json(command):
    return json.loads(
        subprocess.check_output(
            ["hyprctl", command, "-j"], text=True, stderr=subprocess.DEVNULL
        )
    )


address = sys.argv[1].lower()
clients = hyprland_json("clients")
window = next(
    (item for item in clients if str(item.get("address", "")).lower() == address),
    None,
)
if window is None:
    raise SystemExit("okno STK zniknęło przed sprawdzeniem fullscreen")

monitor_id = window.get("monitor")
monitors = hyprland_json("monitors")
monitor = next((item for item in monitors if item.get("id") == monitor_id), None)
if monitor is None:
    raise SystemExit(f"brak monitora Hyprland o ID {monitor_id}")

scale = float(monitor.get("scale", 1.0) or 1.0)
expected_width = round(float(monitor.get("width", 0)) / scale)
expected_height = round(float(monitor.get("height", 0)) / scale)
transform = int(monitor.get("transform", 0) or 0)
if transform % 2:
    expected_width, expected_height = expected_height, expected_width

size = window.get("size") or [0, 0]
actual_width, actual_height = map(int, size[:2])
states = (window.get("fullscreen"), window.get("fullscreenClient"))
fullscreen = any(
    state is True
    or (
        isinstance(state, int)
        and not isinstance(state, bool)
        and state & 2
    )
    for state in states
)
tolerance = 4
geometry_matches = (
    abs(actual_width - expected_width) <= tolerance
    and abs(actual_height - expected_height) <= tolerance
)
if not fullscreen or not geometry_matches:
    raise SystemExit(
        "stan={} rozmiar={}x{}, oczekiwano fullscreen {}x{}".format(
            states,
            actual_width,
            actual_height,
            expected_width,
            expected_height,
        )
    )

print(f"fullscreen {actual_width}x{actual_height} jednostek logicznych")
PY
}

apply_hyprland_game_fullscreen() {
  local profile="$1"
  local game_log="$2"
  local process_pid="$3"
  local address="" geometry=""
  local attempt validation_error=""

  [[ "$profile" == gpu ]] || return 0
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 0
  command -v hyprctl >/dev/null 2>&1 || return 0

  # STK prosi o fullscreen zanim powierzchnia OpenGL ma finalny rozmiar. Po
  # zniknięciu ekranu ładowania odtwarzamy skuteczną kolejność użytkownika:
  # najpierw Super+F (maximized), potem Super+Shift+F (pełny ekran bez paneli).
  wait_for_supertuxkart_track "$game_log" "$process_pid" || return 1

  for ((attempt = 0; attempt < 40; attempt++)); do
    kill -0 "$process_pid" 2>/dev/null || return 1
    address="$(find_supertuxkart_window)"
    [[ -n "$address" ]] && break
    sleep 0.05
  done
  if [[ -z "$address" ]]; then
    printf 'Nie znaleziono okna STK do automatycznego przełączenia fullscreen.\n' >&2
    return 1
  fi

  # To są dokładne odpowiedniki aktywnych bindów z hyprland.lua. `toggle` jest
  # zamierzone: STK zgłasza klientowi fullscreen przed finalnym rozmiarem
  # powierzchni, a sprawdzona ręcznie sekwencja przeprowadza okno przez oba
  # stany i wymusza ponowną negocjację render targetu.
  dispatch_hyprland_lua \
    'fokus na oknie STK' \
    "hl.dsp.focus({ window = \"address:$address\" })" \
    || return 1
  dispatch_hyprland_lua \
    'Super+F — maximized' \
    "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", window = \"address:$address\" })" \
    || return 1
  sleep 0.25
  dispatch_hyprland_lua \
    'Super+Shift+F — fullscreen' \
    "hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\", window = \"address:$address\" })" \
    || return 1

  for ((attempt = 0; attempt < 20; attempt++)); do
    if geometry="$(validate_supertuxkart_fullscreen "$address" 2>&1)"; then
      printf 'STK: tor załadowany, potwierdzono %s.\n' "$geometry"
      return 0
    fi
    validation_error="$geometry"
    sleep 0.05
  done
  printf 'Nie potwierdzono pełnoekranowej geometrii STK: %s\n' \
    "$validation_error" >&2
  return 1
}

run_game_process() {
  local profile="$1"
  local size="$2"
  local game_log="$3"
  local internal_log="$4"
  local performance_report="$5"
  local state_directory="$6"
  local config_directory fullscreen_exit=0 fullscreen_log fullscreen_output=""
  local last_report_index process_exit
  local -a performance_candidates

  build_game_arguments "$profile" "$size"
  build_game_environment "$profile" "$size" "$state_directory"

  env "${game_environment[@]}" \
    gamemoderun supertuxkart "${game_arguments[@]}" \
      >"$game_log" 2>&1 &
  game_pid=$!
  fullscreen_log="${game_log%.log}_hyprland.log"
  if ! fullscreen_output="$(
    apply_hyprland_game_fullscreen "$profile" "$game_log" "$game_pid" 2>&1
  )"; then
    fullscreen_exit=1
    if [[ -n "$fullscreen_output" ]]; then
      printf '%s\n' "$fullscreen_output" >&2
    fi
    printf 'Automatyczna sekwencja Super+F, Super+Shift+F nie powiodła się.\n' >&2
    {
      [[ -z "$fullscreen_output" ]] || printf '%s\n' "$fullscreen_output"
      printf 'Automatyczna sekwencja Super+F, Super+Shift+F nie powiodła się.\n'
    } >"$fullscreen_log"
    kill "$game_pid" 2>/dev/null || true
  elif [[ -n "$fullscreen_output" ]]; then
    printf '%s\n' "$fullscreen_output"
    printf '%s\n' "$fullscreen_output" >"$fullscreen_log"
  fi
  process_exit=0
  wait "$game_pid" || process_exit=$?
  game_pid=""
  if (( fullscreen_exit != 0 && process_exit == 0 )); then
    process_exit="$fullscreen_exit"
  fi

  config_directory="$state_directory/config/supertuxkart/config-0.10"
  if [[ -f "$config_directory/stdout.log" ]]; then
    cp "$config_directory/stdout.log" "$internal_log"
  else
    cp "$game_log" "$internal_log"
  fi

  shopt -s nullglob
  performance_candidates=("$config_directory"/stdout.log.perf-report-*.csv)
  shopt -u nullglob
  if (( ${#performance_candidates[@]} > 0 )); then
    last_report_index=$((${#performance_candidates[@]} - 1))
    cp "${performance_candidates[$last_report_index]}" "$performance_report"
  fi

  return "$process_exit"
}

prewarm_game_tests() {
  local profile size quality renderer stem game_exit internal_log performance_report
  for profile in "${profiles[@]}"; do
    case "$profile" in
      gaming-cpu)
        size="$gaming_size"
        quality=low
        renderer=vulkan
        ;;
      gpu)
        size="$gpu_size"
        quality=ultimate
        renderer=opengl
        ;;
      *)
        continue
        ;;
    esac

    stem="prewarm_${profile}"
    internal_log="$work_directory/raw/logs/${stem}_supertuxkart-internal.log"
    performance_report="$work_directory/raw/logs/${stem}_supertuxkart.csv"
    printf 'Rozgrzewanie cache gry: %s (%s)...\n' "$profile" "$size"
    game_exit=0
    run_game_process \
      "$profile" \
      "$size" \
      "$work_directory/raw/logs/${stem}.log" \
      "$internal_log" \
      "$performance_report" \
      "$work_directory/game-state/${stem}" \
      || game_exit=$?
    if (( game_exit != 0 )) || \
      [[ ! -s "$performance_report" ]] || \
      ! grep -q "Steady FPS" "$internal_log"
    then
      if [[ "$profile" == gpu ]]; then
        printf 'Kontrolny replay SuperTuxKart nie uruchomił się poprawnie; sprawdź %s oraz %s.\n' \
          "$work_directory/raw/logs/${stem}.log" \
          "$work_directory/raw/logs/${stem}_hyprland.log" >&2
      else
        printf 'Kontrolny replay SuperTuxKart nie uruchomił się poprawnie; sprawdź %s.\n' \
          "$work_directory/raw/logs/${stem}.log" >&2
      fi
      return 1
    fi
    if ! python3 "$reporter" validate-game-prewarm \
        --profile "$profile" \
        --renderer "$renderer" \
        --quality "$quality" \
        --internal-log "$internal_log" \
        --benchmark-report "$performance_report" \
        --config "$work_directory/game-state/${stem}/config/supertuxkart/config-0.10/config.xml" \
        --size "$size"
    then
      printf 'Kontrolny profil %s nie spełnia wymagań renderera lub render targetu; sprawdź %s.\n' \
        "$profile" \
        "$internal_log" >&2
      return 1
    fi
  done
}

run_game_test() {
  local profile="$1"
  local scheduler="$2"
  local round="$3"
  local size="$4"
  local stem="${profile}_${scheduler}_${round}"
  local game_log="$work_directory/raw/logs/${stem}_supertuxkart.log"
  local internal_log="$work_directory/raw/logs/${stem}_supertuxkart-internal.log"
  local performance_report="$work_directory/raw/logs/${stem}_supertuxkart.csv"
  local stress_log="$work_directory/raw/logs/${stem}_stress-ng.log"
  local state_directory="$work_directory/game-state/${stem}"
  local result_path="$work_directory/raw/results/${stem}.json"
  local background_workers started_at game_exit quality renderer
  started_at="$(date --iso-8601=seconds)"

  if [[ "$profile" == gaming-cpu ]]; then
    stress-ng \
      --cpu "$gaming_workers" \
      --cpu-method matrixprod \
      --timeout 1h \
      --metrics-brief \
      --log-file "$stress_log" \
      >"${stress_log%.log}.stdout.log" 2>&1 &
    background_pid=$!
    sleep 2
  fi

  game_exit=0
  run_game_process \
    "$profile" \
    "$size" \
    "$game_log" \
    "$internal_log" \
    "$performance_report" \
    "$state_directory" \
    || game_exit=$?

  stop_background

  if [[ "$profile" == gaming-cpu ]]; then
    background_workers="$gaming_workers"
  else
    background_workers=0
  fi
  if [[ "$profile" == gaming-cpu ]]; then
    quality=low
    renderer=vulkan
  else
    quality=ultimate
    renderer=opengl
  fi

  python3 "$reporter" game \
    --output "$result_path" \
    --profile "$profile" \
    --scheduler "$scheduler" \
    --run "$round" \
    --log "$game_log" \
    --internal-log "$internal_log" \
    --benchmark-report "$performance_report" \
    --config "$state_directory/config/supertuxkart/config-0.10/config.xml" \
    --size "$size" \
    --quality "$quality" \
    --renderer "$renderer" \
    --gpu-prime "$gpu_prime" \
    --process-exit "$game_exit" \
    --background-workers "$background_workers" \
    --gamemode enabled \
    --active-ops "$(active_ops)" \
    "--scheduler-args=$(scheduler_args_label)" \
    --raw-log "raw/logs/$(basename "$game_log")" \
    --started-at "$started_at" \
    || return 1

  return "$game_exit"
}

if ! prewarm_game_tests; then
  exit 1
fi
sleep "$cooldown"

completed_cases=0
for profile in "${profiles[@]}"; do
  printf '\n=== Profil: %s ===\n' "$profile"
  for ((round = 1; round <= runs; round++)); do
    printf '\n--- Runda %s/%s ---\n' "$round" "$runs"
    for offset in "${!schedulers[@]}"; do
      scheduler_index=$(((round - 1 + offset) % ${#schedulers[@]}))
      scheduler="${schedulers[$scheduler_index]}"
      completed_cases=$((completed_cases + 1))
      printf '[%s/%s] %s / %s / runda %s\n' \
        "$completed_cases" "$total_cases" "$profile" "$scheduler" "$round"
      started_at="$(date --iso-8601=seconds)"

      if ! activate_scheduler "$scheduler" "$profile"; then
        raw_log="$(dump_scheduler_log "$profile" "$scheduler" "$round" "$started_at")"
        record_failure "$profile" "$scheduler" "$round" "$started_at" "$raw_log" \
          "Nie udało się aktywować schedulera"
        sleep "$cooldown"
        continue
      fi
      sleep 3

      case "$profile" in
        desktop-cpu)
          if ! run_desktop_test "$scheduler" "$round"; then
            raw_log="raw/logs/desktop-cpu_${scheduler}_${round}_stress-ng.log"
            record_failure "$profile" "$scheduler" "$round" "$started_at" "$raw_log" \
              "Niepowodzenie profilu desktop-cpu"
          fi
          ;;
        gaming-cpu)
          if ! run_game_test "$profile" "$scheduler" "$round" "$gaming_size"; then
            printf 'SuperTuxKart zakończył próbę kodem błędu; szczegóły zapisano w raporcie.\n' >&2
            result_path="$work_directory/raw/results/${profile}_${scheduler}_${round}.json"
            if [[ ! -f "$result_path" ]]; then
              raw_log="raw/logs/${profile}_${scheduler}_${round}_supertuxkart.log"
              record_failure "$profile" "$scheduler" "$round" "$started_at" "$raw_log" \
                "Niepowodzenie profilu gaming-cpu"
            fi
          fi
          ;;
        gpu)
          if ! run_game_test "$profile" "$scheduler" "$round" "$gpu_size"; then
            printf 'SuperTuxKart zakończył próbę kodem błędu; szczegóły zapisano w raporcie.\n' >&2
            result_path="$work_directory/raw/results/${profile}_${scheduler}_${round}.json"
            if [[ ! -f "$result_path" ]]; then
              raw_log="raw/logs/${profile}_${scheduler}_${round}_supertuxkart.log"
              record_failure "$profile" "$scheduler" "$round" "$started_at" "$raw_log" \
                "Niepowodzenie profilu gpu"
            fi
          fi
          ;;
      esac

      dump_scheduler_log "$profile" "$scheduler" "$round" "$started_at" >/dev/null
      sleep "$cooldown"
    done
  done
done

restore_original_scheduler
finalize_results

printf '\nGotowe. Najpierw otwórz:\n  %s/REPORT.md\n' "$output_directory"
