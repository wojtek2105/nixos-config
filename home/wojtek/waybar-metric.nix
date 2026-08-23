{ inputs, pkgs }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
in
pkgs.writeShellApplication {
  name = "waybar-metric";
  runtimeInputs = with pkgs; [
    coreutils
    gawk
    iproute2
    jq
  ];
  text = ''
    component="''${1:-}"

    block() {
      local value="''${1:-0}"
      local levels=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
      (( value < 0 )) && value=0
      (( value > 100 )) && value=100
      printf '%s' "''${levels[value * 7 / 100]}"
    }

    row() {
      local label="$1"
      local value="$2"
      local color="''${3:-${c.bright}}"
      printf '<span foreground="#${c.subtle}">%-16s</span><span foreground="#%s"><b>%12s</b></span>' \
        "$label" "$color" "$value"
    }

    tooltip_start() {
      printf '<span font_family="${theme.fonts.monospace}"><span foreground="#${c.bright}"><b>%s  %s</b></span>\n' \
        "$1" "$2"
    }

    emit() {
      local percentage="$1"
      local icon="$2"
      local color="$3"
      local tooltip="$4"
      local warning="''${5:-75}"
      local critical="''${6:-90}"
      local class=normal

      (( percentage < 0 )) && percentage=0
      (( percentage > 100 )) && percentage=100
      if (( percentage >= critical )); then
        class=critical
      elif (( percentage >= warning )); then
        class=warning
      fi

      jq --null-input --compact-output \
        --arg text "$icon  <span size=\"large\" weight=\"bold\" foreground=\"#$color\">$(block "$percentage")</span>" \
        --arg tooltip "$tooltip</span>" \
        --arg class "$class" \
        --argjson percentage "$percentage" \
        '{text: $text, tooltip: $tooltip, class: $class, percentage: $percentage}'
    }

    max_temperature() {
      local name_pattern="$1"
      local maximum=0 name value
      for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -r "$hwmon/name" ]] || continue
        read -r name < "$hwmon/name" || continue
        [[ "$name" =~ $name_pattern ]] || continue
        for input in "$hwmon"/temp*_input; do
          [[ -r "$input" ]] || continue
          read -r value < "$input" 2>/dev/null || continue
          [[ "$value" =~ ^[0-9]+$ ]] || continue
          (( value > maximum )) && maximum=$value
        done
      done
      printf '%s\n' "$((maximum / 1000))"
    }

    select_amd_gpu() {
      gpu_card=""
      vram_total=0
      local vendor candidate_vram
      for device in /sys/class/drm/card[0-9]*/device; do
        [[ -r "$device/vendor" && -r "$device/mem_info_vram_total" ]] || continue
        read -r vendor < "$device/vendor"
        [[ "$vendor" == 0x1002 ]] || continue
        read -r candidate_vram < "$device/mem_info_vram_total"
        if (( candidate_vram > vram_total )); then
          gpu_card="$device"
          vram_total=$candidate_vram
        fi
      done
    }

    case "$component" in
      cpu)
        state_file="''${XDG_RUNTIME_DIR:?}/waybar-cpu.state"
        read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
        idle_all=$((idle + iowait))
        total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        previous_total=$total
        previous_idle=$idle_all
        if [[ -r "$state_file" ]]; then
          read -r previous_total previous_idle < "$state_file" || true
        fi
        printf '%s %s\n' "$total" "$idle_all" > "$state_file"
        delta=$((total - previous_total))
        idle_delta=$((idle_all - previous_idle))
        (( delta > 0 )) && usage=$(((delta - idle_delta) * 100 / delta)) || usage=0

        read -r load_1 load_5 load_15 _ < /proc/loadavg
        frequency_sum=0
        frequency_count=0
        for input in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do
          [[ -r "$input" ]] || continue
          read -r frequency < "$input" || continue
          [[ "$frequency" =~ ^[0-9]+$ ]] || continue
          frequency_sum=$((frequency_sum + frequency))
          frequency_count=$((frequency_count + 1))
        done
        if (( frequency_count > 0 )); then
          frequency_display="$(awk -v sum="$frequency_sum" -v count="$frequency_count" \
            'BEGIN { printf "%.2f GHz", sum / count / 1000000 }')"
        else
          frequency_display="n/d"
        fi
        cpu_temperature="$(max_temperature '^(k10temp|zenpower)$')"

        tooltip="$(tooltip_start '' 'PROCESOR')"$'\n'
        tooltip+="$(row 'Użycie' "$usage%" '${c.violet}')"$'\n'
        tooltip+="$(row 'Temperatura' "$cpu_temperature°C" '${c.yellow}')"$'\n'
        tooltip+="$(row 'Taktowanie' "$frequency_display")"$'\n'
        tooltip+="$(row 'Load · 1 min' "$load_1")"$'\n'
        tooltip+="$(row 'Load · 5 min' "$load_5")"$'\n'
        tooltip+="$(row 'Load · 15 min' "$load_15")"$'\n'
        tooltip+="$(row 'Wątki' "$(nproc)")"
        emit "$usage" '' '${c.violet}' "$tooltip"
        ;;

      memory)
        read -r total available swap_total swap_free < <(
          awk '
            /^MemTotal:/ { total=$2 }
            /^MemAvailable:/ { available=$2 }
            /^SwapTotal:/ { swap_total=$2 }
            /^SwapFree:/ { swap_free=$2 }
            END { print total, available, swap_total, swap_free }
          ' /proc/meminfo
        )
        used=$((total - available))
        percentage=$((used * 100 / total))
        swap_used=$((swap_total - swap_free))
        used_display="$(awk -v value="$used" 'BEGIN { printf "%.1f GiB", value / 1048576 }')"
        total_display="$(awk -v value="$total" 'BEGIN { printf "%.1f GiB", value / 1048576 }')"
        available_display="$(awk -v value="$available" 'BEGIN { printf "%.1f GiB", value / 1048576 }')"
        swap_display="$(awk -v used="$swap_used" -v total="$swap_total" \
          'BEGIN { printf "%.1f / %.1f GiB", used / 1048576, total / 1048576 }')"

        tooltip="$(tooltip_start '' 'PAMIĘĆ RAM')"$'\n'
        tooltip+="$(row 'Użycie' "$percentage%" '${c.accent}')"$'\n'
        tooltip+="$(row 'Zajęte' "$used_display")"$'\n'
        tooltip+="$(row 'Dostępne' "$available_display" '${c.green}')"$'\n'
        tooltip+="$(row 'Łącznie' "$total_display")"$'\n'
        tooltip+="$(row 'Swap' "$swap_display")"
        emit "$percentage" '' '${c.accent}' "$tooltip"
        ;;

      network)
        interface="$(
          ip route show default 2>/dev/null | awk 'NR == 1 { print $5 }' || true
        )"
        rx_bytes=0
        tx_bytes=0
        if [[ -n "$interface" ]]; then
          [[ -r "/sys/class/net/$interface/statistics/rx_bytes" ]] \
            && read -r rx_bytes < "/sys/class/net/$interface/statistics/rx_bytes"
          [[ -r "/sys/class/net/$interface/statistics/tx_bytes" ]] \
            && read -r tx_bytes < "/sys/class/net/$interface/statistics/tx_bytes"
        fi
        now="$(date +%s)"
        state_file="''${XDG_RUNTIME_DIR:?}/waybar-network.state"
        previous_rx=$rx_bytes
        previous_tx=$tx_bytes
        previous_time=$now
        if [[ -r "$state_file" ]]; then
          read -r previous_rx previous_tx previous_time < "$state_file" || true
        fi
        printf '%s %s %s\n' "$rx_bytes" "$tx_bytes" "$now" > "$state_file"
        elapsed=$((now - previous_time))
        (( elapsed > 0 )) || elapsed=1
        rx_rate=$(((rx_bytes - previous_rx) / elapsed))
        tx_rate=$(((tx_bytes - previous_tx) / elapsed))
        (( rx_rate >= 0 )) || rx_rate=0
        (( tx_rate >= 0 )) || tx_rate=0
        total_rate=$((rx_rate + tx_rate))
        if (( total_rate >= 104857600 )); then percentage=100
        elif (( total_rate >= 52428800 )); then percentage=85
        elif (( total_rate >= 10485760 )); then percentage=70
        elif (( total_rate >= 1048576 )); then percentage=55
        elif (( total_rate >= 102400 )); then percentage=40
        elif (( total_rate >= 10240 )); then percentage=25
        elif (( total_rate > 0 )); then percentage=10
        else percentage=0
        fi
        rx_display="$(numfmt --to=iec-i --suffix=B/s "$rx_rate" 2>/dev/null || printf '0 B/s')"
        tx_display="$(numfmt --to=iec-i --suffix=B/s "$tx_rate" 2>/dev/null || printf '0 B/s')"
        ip_address="$(
          if [[ -n "$interface" ]]; then
            ip -4 -o address show dev "$interface" 2>/dev/null \
              | awk 'NR == 1 { sub(/\/.*/, "", $4); print $4 }' || true
          fi
        )"

        tooltip="$(tooltip_start '󰓅' 'SIEĆ')"
        tooltip+=$'\n'"$(row 'Interfejs' "''${interface:-brak}")"$'\n'
        tooltip+="$(row 'Adres IPv4' "''${ip_address:-brak}")"$'\n'
        tooltip+="$(row 'Pobieranie' "$rx_display" '${c.green}')"$'\n'
        tooltip+="$(row 'Wysyłanie' "$tx_display" '${c.violet}')"
        emit "$percentage" '󰓅' '${c.green}' "$tooltip" 101 101
        ;;

      disk)
        read -r total used available percentage < <(
          df -Pk / | awk 'NR == 2 { gsub(/%/, "", $5); print $2, $3, $4, $5 }'
        )
        total_display="$(awk -v value="$total" 'BEGIN { printf "%.0f GiB", value / 1048576 }')"
        used_display="$(awk -v value="$used" 'BEGIN { printf "%.0f GiB", value / 1048576 }')"
        available_display="$(awk -v value="$available" 'BEGIN { printf "%.0f GiB", value / 1048576 }')"

        tooltip="$(tooltip_start '󰋊' 'DYSK SYSTEMOWY')"
        tooltip+=$'\n'"$(row 'Punkt montowania' '/')"$'\n'
        tooltip+="$(row 'Użycie' "$percentage%" '${c.orange}')"$'\n'
        tooltip+="$(row 'Zajęte' "$used_display")"$'\n'
        tooltip+="$(row 'Wolne' "$available_display" '${c.green}')"$'\n'
        tooltip+="$(row 'Łącznie' "$total_display")"
        emit "$percentage" '󰋊' '${c.orange}' "$tooltip" 80 92
        ;;

      gpu)
        select_amd_gpu
        usage=0
        vram_used=0
        gpu_temperature=0
        if [[ -n "$gpu_card" ]]; then
          usage="$(head -n 1 "$gpu_card/gpu_busy_percent" 2>/dev/null || printf 0)"
          [[ "$usage" =~ ^[0-9]+$ ]] || usage=0
          read -r vram_used < "$gpu_card/mem_info_vram_used" || vram_used=0
          for input in "$gpu_card"/hwmon/hwmon*/temp*_input; do
            [[ -r "$input" ]] || continue
            read -r value < "$input" 2>/dev/null || continue
            [[ "$value" =~ ^[0-9]+$ ]] || continue
            (( value > gpu_temperature )) && gpu_temperature=$value
          done
        fi
        gpu_temperature=$((gpu_temperature / 1000))
        (( vram_total > 0 )) && vram_percentage=$((vram_used * 100 / vram_total)) || vram_percentage=0
        vram_used_display="$(awk -v value="$vram_used" 'BEGIN { printf "%.1f GiB", value / 1073741824 }')"
        vram_total_display="$(awk -v value="$vram_total" 'BEGIN { printf "%.1f GiB", value / 1073741824 }')"

        tooltip="$(tooltip_start '󰢮' 'GPU')"
        tooltip+=$'\n'"$(row 'Użycie rdzenia' "$usage%" '${c.blue}')"$'\n'
        tooltip+="$(row 'VRAM' "$vram_percentage%" '${c.magenta}')"$'\n'
        tooltip+="$(row 'VRAM zajęte' "$vram_used_display")"$'\n'
        tooltip+="$(row 'VRAM łącznie' "$vram_total_display")"$'\n'
        tooltip+="$(row 'Temperatura' "$gpu_temperature°C" '${c.yellow}')"
        emit "$usage" '󰢮' '${c.blue}' "$tooltip"
        ;;

      temperature)
        cpu_temperature="$(max_temperature '^(k10temp|zenpower)$')"
        gpu_temperature="$(max_temperature '^amdgpu$')"
        nvme_temperature="$(max_temperature '^nvme$')"
        maximum=$cpu_temperature
        (( gpu_temperature > maximum )) && maximum=$gpu_temperature
        (( nvme_temperature > maximum )) && maximum=$nvme_temperature

        tooltip="$(tooltip_start '' 'TEMPERATURY')"
        tooltip+=$'\n'"$(row 'CPU' "$cpu_temperature°C" '${c.violet}')"$'\n'
        tooltip+="$(row 'GPU' "$gpu_temperature°C" '${c.blue}')"$'\n'
        tooltip+="$(row 'NVMe' "$nvme_temperature°C" '${c.orange}')"$'\n'
        tooltip+="$(row 'Najwyższa' "$maximum°C" '${c.yellow}')"
        emit "$maximum" '' '${c.yellow}' "$tooltip" 75 90
        ;;

      *)
        printf 'Użycie: waybar-metric {cpu|memory|network|disk|gpu|temperature}\n' >&2
        exit 2
        ;;
    esac
  '';
}
