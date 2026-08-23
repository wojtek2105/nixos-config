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
    gnused
    iproute2
    jq
  ];
  text = ''
    component="''${1:-}"
    output_mode="''${2:-json}"

    gauge() {
      local value="''${1:-0}"
      local color="$2"
      local label="''${3:-}"
      local levels=(▁ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
      local index

      (( value < 0 )) && value=0
      (( value > 100 )) && value=100
      index=$((value * 8 / 100))
      (( value > 0 && index == 0 )) && index=1

      printf '<span font_family="${theme.fonts.monospace}"><span foreground="#${c.bright}" size="small" weight="bold">%s</span><span foreground="#%s" size="large">%s</span></span> ' \
        "$label" "$color" "''${levels[index]}"
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
      local indicators="$3"
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

      case "$output_mode" in
        json)
          jq --null-input --compact-output \
            --arg text "$icon  $indicators" \
            --arg tooltip "$tooltip</span>" \
            --arg class "$class" \
            --argjson percentage "$percentage" \
            '{text: $text, tooltip: $tooltip, class: $class, percentage: $percentage}'
          ;;
        tooltip)
          printf '%s\n' "$tooltip</span>" | sed -E 's/<[^>]+>//g'
          ;;
        percentage)
          printf '%s\n' "$percentage"
          ;;
        *)
          printf 'Nieznany format wyjścia: %s\n' "$output_mode" >&2
          exit 2
          ;;
      esac
    }

    network_percentage() {
      local rate="''${1:-0}"
      if (( rate >= 104857600 )); then printf '100\n'
      elif (( rate >= 52428800 )); then printf '88\n'
      elif (( rate >= 10485760 )); then printf '72\n'
      elif (( rate >= 1048576 )); then printf '56\n'
      elif (( rate >= 102400 )); then printf '40\n'
      elif (( rate >= 10240 )); then printf '24\n'
      elif (( rate > 0 )); then printf '12\n'
      else printf '0\n'
      fi
    }

    disk_io_percentage() {
      local rate="''${1:-0}"
      if (( rate >= 1073741824 )); then printf '100\n'
      elif (( rate >= 524288000 )); then printf '90\n'
      elif (( rate >= 262144000 )); then printf '80\n'
      elif (( rate >= 104857600 )); then printf '68\n'
      elif (( rate >= 52428800 )); then printf '56\n'
      elif (( rate >= 10485760 )); then printf '44\n'
      elif (( rate >= 1048576 )); then printf '30\n'
      elif (( rate > 0 )); then printf '14\n'
      else printf '0\n'
      fi
    }

    disk_bytes_total() {
      awk '
        $3 ~ /^(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$/ {
          read_sectors += $6
          written_sectors += $10
        }
        END { printf "%.0f %.0f\n", read_sectors * 512, written_sectors * 512 }
      ' /proc/diskstats
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
        level=$usage
        (( cpu_temperature > level )) && level=$cpu_temperature
        bars="$(gauge "$usage" '${c.violet}')$(gauge "$cpu_temperature" '${c.yellow}' '°')"

        tooltip="$(tooltip_start '' 'PROCESOR · CPU / °C')"$'\n'
        tooltip+="$(row 'Użycie' "$usage%" '${c.violet}')"$'\n'
        tooltip+="$(row 'Temperatura' "$cpu_temperature°C" '${c.yellow}')"$'\n'
        tooltip+="$(row 'Taktowanie' "$frequency_display")"$'\n'
        tooltip+="$(row 'Load · 1 min' "$load_1")"$'\n'
        tooltip+="$(row 'Load · 5 min' "$load_5")"$'\n'
        tooltip+="$(row 'Load · 15 min' "$load_15")"$'\n'
        tooltip+="$(row 'Wątki' "$(nproc)")"
        emit "$level" '' "$bars" "$tooltip"
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
        (( swap_total > 0 )) \
          && swap_percentage=$((swap_used * 100 / swap_total)) \
          || swap_percentage=0
        used_display="$(awk -v value="$used" 'BEGIN { printf "%.1f GiB", value / 1048576 }')"
        total_display="$(awk -v value="$total" 'BEGIN { printf "%.1f GiB", value / 1048576 }')"
        available_display="$(awk -v value="$available" 'BEGIN { printf "%.1f GiB", value / 1048576 }')"
        swap_display="$(awk -v used="$swap_used" -v total="$swap_total" \
          'BEGIN { printf "%.1f / %.1f GiB", used / 1048576, total / 1048576 }')"
        level=$percentage
        bars="$(gauge "$percentage" '${c.accent}')"
        memory_title='PAMIĘĆ · RAM'
        if (( swap_total > 0 )); then
          (( swap_percentage > level )) && level=$swap_percentage
          bars+="$(gauge "$swap_percentage" '${c.blue}' 'S')"
          memory_title+=' / SWAP'
        fi

        tooltip="$(tooltip_start '' "$memory_title")"$'\n'
        tooltip+="$(row 'Użycie' "$percentage%" '${c.accent}')"$'\n'
        tooltip+="$(row 'Zajęte' "$used_display")"$'\n'
        tooltip+="$(row 'Dostępne' "$available_display" '${c.green}')"$'\n'
        tooltip+="$(row 'Łącznie' "$total_display")"
        if (( swap_total > 0 )); then
          tooltip+=$'\n'"$(row 'Swap' "$swap_display")"$'\n'
          tooltip+="$(row 'Swap użycie' "$swap_percentage%" '${c.blue}')"
        fi
        emit "$level" '' "$bars" "$tooltip"
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
        rx_percentage="$(network_percentage "$rx_rate")"
        tx_percentage="$(network_percentage "$tx_rate")"
        level=$rx_percentage
        (( tx_percentage > level )) && level=$tx_percentage
        bars="$(gauge "$rx_percentage" '${c.green}' '↓')$(gauge "$tx_percentage" '${c.violet}' '↑')"
        rx_display="$(numfmt --to=iec-i --suffix=B/s "$rx_rate" 2>/dev/null || printf '0 B/s')"
        tx_display="$(numfmt --to=iec-i --suffix=B/s "$tx_rate" 2>/dev/null || printf '0 B/s')"
        ip_address="$(
          if [[ -n "$interface" ]]; then
            ip -4 -o address show dev "$interface" 2>/dev/null \
              | awk 'NR == 1 { sub(/\/.*/, "", $4); print $4 }' || true
          fi
        )"

        tooltip="$(tooltip_start '󰓅' 'SIEĆ · ↓ / ↑')"
        tooltip+=$'\n'"$(row 'Interfejs' "''${interface:-brak}")"$'\n'
        tooltip+="$(row 'Adres IPv4' "''${ip_address:-brak}")"$'\n'
        tooltip+="$(row 'Pobieranie' "$rx_display" '${c.green}')"$'\n'
        tooltip+="$(row 'Wysyłanie' "$tx_display" '${c.violet}')"
        emit "$level" '󰓅' "$bars" "$tooltip" 101 101
        ;;

      disk)
        read -r total used available percentage < <(
          df -Pk / | awk 'NR == 2 { gsub(/%/, "", $5); print $2, $3, $4, $5 }'
        )
        total_display="$(awk -v value="$total" 'BEGIN { printf "%.0f GiB", value / 1048576 }')"
        used_display="$(awk -v value="$used" 'BEGIN { printf "%.0f GiB", value / 1048576 }')"
        available_display="$(awk -v value="$available" 'BEGIN { printf "%.0f GiB", value / 1048576 }')"

        read -r read_bytes written_bytes < <(disk_bytes_total)
        now="$(date +%s)"
        state_file="''${XDG_RUNTIME_DIR:?}/waybar-disk.state"
        previous_read=$read_bytes
        previous_written=$written_bytes
        previous_time=$now
        if [[ -r "$state_file" ]]; then
          read -r previous_read previous_written previous_time < "$state_file" || true
        fi
        printf '%s %s %s\n' "$read_bytes" "$written_bytes" "$now" > "$state_file"
        elapsed=$((now - previous_time))
        (( elapsed > 0 )) || elapsed=1
        read_rate=$(((read_bytes - previous_read) / elapsed))
        write_rate=$(((written_bytes - previous_written) / elapsed))
        (( read_rate >= 0 )) || read_rate=0
        (( write_rate >= 0 )) || write_rate=0
        read_percentage="$(disk_io_percentage "$read_rate")"
        write_percentage="$(disk_io_percentage "$write_rate")"
        read_display="$(numfmt --to=iec-i --suffix=B/s "$read_rate" 2>/dev/null || printf '0 B/s')"
        write_display="$(numfmt --to=iec-i --suffix=B/s "$write_rate" 2>/dev/null || printf '0 B/s')"
        bars="$(gauge "$percentage" '${c.orange}')$(gauge "$read_percentage" '${c.green}' '↓')$(gauge "$write_percentage" '${c.violet}' '↑')"

        tooltip="$(tooltip_start '󰋊' 'DYSK · % / ↓ / ↑')"
        tooltip+=$'\n'"$(row 'Punkt montowania' '/')"$'\n'
        tooltip+="$(row 'Użycie' "$percentage%" '${c.orange}')"$'\n'
        tooltip+="$(row 'Odczyt' "$read_display" '${c.green}')"$'\n'
        tooltip+="$(row 'Zapis' "$write_display" '${c.violet}')"$'\n'
        tooltip+="$(row 'Zajęte' "$used_display")"$'\n'
        tooltip+="$(row 'Wolne' "$available_display" '${c.green}')"$'\n'
        tooltip+="$(row 'Łącznie' "$total_display")"
        emit "$percentage" '󰋊' "$bars" "$tooltip" 80 92
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
        level=$usage
        (( vram_percentage > level )) && level=$vram_percentage
        (( gpu_temperature > level )) && level=$gpu_temperature
        bars="$(gauge "$usage" '${c.blue}')$(gauge "$vram_percentage" '${c.magenta}' 'V')$(gauge "$gpu_temperature" '${c.yellow}' '°')"

        tooltip="$(tooltip_start '󰢮' 'GPU · RDZEŃ / VRAM / °C')"
        tooltip+=$'\n'"$(row 'Użycie rdzenia' "$usage%" '${c.blue}')"$'\n'
        tooltip+="$(row 'VRAM' "$vram_percentage%" '${c.magenta}')"$'\n'
        tooltip+="$(row 'VRAM zajęte' "$vram_used_display")"$'\n'
        tooltip+="$(row 'VRAM łącznie' "$vram_total_display")"$'\n'
        tooltip+="$(row 'Temperatura' "$gpu_temperature°C" '${c.yellow}')"
        emit "$level" '󰢮' "$bars" "$tooltip"
        ;;

      *)
        printf 'Użycie: waybar-metric {cpu|memory|network|disk|gpu}\n' >&2
        exit 2
        ;;
    esac
  '';
}
