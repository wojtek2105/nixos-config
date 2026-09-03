{ inputs, pkgs }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
  p = theme.metricPopup;
in
pkgs.writeShellApplication {
  name = "ironbar-metric";
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

    temperature_percentage() {
      local temperature="''${1:-0}"
      # Skala zaczyna się od 40°C: poniżej temperatury spoczynkowej nie ma
      # wypełnienia, a 100°C pozostaje pełną skalą termiczną.
      local idle_baseline=40
      local full_scale=100

      (( temperature <= idle_baseline )) && {
        printf '0\n'
        return
      }
      (( temperature >= full_scale )) && {
        printf '100\n'
        return
      }
      printf '%s\n' "$(((temperature - idle_baseline) * 100 / (full_scale - idle_baseline)))"
    }

    temperature_indicator_color() {
      local temperature="''${1:-0}"
      # At 85°C the yellow thermal indicator becomes red to make sustained
      # high heat visible before the existing 90°C critical status threshold.
      (( temperature >= 85 )) && printf '%s\n' '${c.red}' || printf '%s\n' '${c.yellow}'
    }

    markup_escape() {
      printf '%s' "$1" \
        | sed \
          -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&apos;/g"
    }

    pad_right() {
      local text="$1"
      local width="$2"
      local missing=$((width - ''${#text}))
      printf '%s' "$text"
      (( missing > 0 )) && printf '%*s' "$missing" ""
    }

    pad_left() {
      local text="$1"
      local width="$2"
      local missing=$((width - ''${#text}))
      (( missing > 0 )) && printf '%*s' "$missing" ""
      printf '%s' "$text"
    }

    row() {
      local label="$1"
      local value="$2"
      local color="''${3:-${p.value}}"
      local weight="''${4:-bold}"
      local padded_label padded_value
      padded_label="$(pad_right "$label" 16)"
      padded_value="$(pad_left "$value" 12)"
      printf '<span foreground="#${p.label}" weight="500">%s</span><span foreground="#%s" weight="%s">%s</span>' \
        "$(markup_escape "$padded_label")" "$color" "$weight" "$(markup_escape "$padded_value")"
    }

    secondary_row() {
      row "$1" "$2" "''${3:-${p.secondary}}" 600
    }

    detail_row() {
      row "$1" "$2" "''${3:-${p.label}}" 500
    }

    tooltip_start() {
      local color="''${3:-${p.value}}"
      printf '<span font_family="${theme.fonts.monospace}" line_height="1.5"><span foreground="#%s" size="large" weight="bold">%s</span><span foreground="#${c.bright}" size="large" weight="bold">  %s</span>\n' \
        "$color" "$(markup_escape "$1")" "$(markup_escape "$2")"
    }

    status_color() {
      local value="''${1:-0}"
      local normal="$2"
      local warning_at="''${3:-75}"
      local critical_at="''${4:-90}"

      if (( value >= critical_at )); then
        printf '%s\n' '${p.critical}'
      elif (( value >= warning_at )); then
        printf '%s\n' '${p.warning}'
      else
        printf '%s\n' "$normal"
      fi
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
          printf '%s\n' "$tooltip</span>"
          ;;
        tooltip_plain)
          printf '%s\n' "$tooltip</span>" \
            | sed -E \
              -e 's/<[^>]+>//g' \
              -e 's/&amp;/\&/g' \
              -e 's/&lt;/</g' \
              -e 's/&gt;/>/g' \
              -e 's/&quot;/"/g' \
              -e "s/&apos;/'/g"
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

    adaptive_scale() {
      local component="$1"
      local floor="''${2:-1}"
      local scale_file="''${XDG_RUNTIME_DIR:?}/ironbar-$component-scale"
      local ceiling="$floor"
      local candidate=""

      if [[ -r "$scale_file" ]]; then
        read -r candidate < "$scale_file" || true
        if [[ "$candidate" =~ ^[0-9]+$ ]] && (( candidate >= floor )); then
          ceiling=$candidate
        fi
      fi
      printf '%s\n' "$ceiling"
    }

    adaptive_percentage() {
      local rate="''${1:-0}"
      local component="$2"
      local floor="$3"
      local ceiling percentage
      ceiling="$(adaptive_scale "$component" "$floor")"

      if (( rate <= 0 )); then
        printf '0\n'
        return
      fi
      percentage=$((rate * 100 / ceiling))
      (( percentage > 100 )) && percentage=100
      printf '%s\n' "$percentage"
    }

    network_percentage() {
      adaptive_percentage "$1" network 10485760
    }

    disk_io_percentage() {
      adaptive_percentage "$1" disk 104857600
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
        state_file="''${XDG_RUNTIME_DIR:?}/ironbar-cpu.state"
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
        cpu_temperature_percentage="$(temperature_percentage "$cpu_temperature")"
        cpu_temperature_bar_color="$(temperature_indicator_color "$cpu_temperature")"
        bars="$(gauge "$usage" '${c.violet}')$(gauge "$cpu_temperature_percentage" "$cpu_temperature_bar_color" '°')"
        usage_color="$(status_color "$usage" '${p.cpu}')"
        temperature_color="$(status_color "$cpu_temperature" '${p.thermal}')"

        tooltip="$(tooltip_start '' 'PROCESOR · CPU / °C' '${p.cpu}')"$'\n'
        tooltip+="$(row 'Użycie' "$usage%" "$usage_color")"$'\n'
        tooltip+="$(row 'Temperatura' "$cpu_temperature°C" "$temperature_color")"$'\n'
        tooltip+="$(secondary_row 'Taktowanie' "$frequency_display")"$'\n'
        tooltip+="$(secondary_row 'Load · 1 min' "$load_1")"$'\n'
        tooltip+="$(detail_row 'Load · 5 min' "$load_5")"$'\n'
        tooltip+="$(detail_row 'Load · 15 min' "$load_15")"$'\n'
        tooltip+="$(detail_row 'Wątki' "$(nproc)")"
        emit "$level" '' "$bars" "$tooltip"
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

        zram_total=0
        zram_original=0
        zram_compressed=0
        zram_physical=0
        zram_algorithm=""
        for device in /sys/block/zram*; do
          [[ -r "$device/disksize" && -r "$device/mm_stat" ]] || continue
          read -r device_total < "$device/disksize" || continue
          [[ "$device_total" =~ ^[0-9]+$ ]] || continue
          (( device_total > 0 )) || continue

          device_original=0
          device_compressed=0
          device_physical=0
          read -r device_original device_compressed device_physical _ < "$device/mm_stat" \
            || continue
          [[ "$device_original" =~ ^[0-9]+$ ]] || device_original=0
          [[ "$device_compressed" =~ ^[0-9]+$ ]] || device_compressed=0
          [[ "$device_physical" =~ ^[0-9]+$ ]] || device_physical=0

          zram_total=$((zram_total + device_total))
          zram_original=$((zram_original + device_original))
          zram_compressed=$((zram_compressed + device_compressed))
          zram_physical=$((zram_physical + device_physical))

          if [[ -z "$zram_algorithm" && -r "$device/comp_algorithm" ]]; then
            zram_algorithm="$(sed -n 's/.*\[\([^]]*\)\].*/\1/p' "$device/comp_algorithm")"
          fi
        done

        if (( zram_total > 0 )); then
          zram_percentage=$((zram_original * 100 / zram_total))
          (( zram_percentage > 100 )) && zram_percentage=100
          zram_logical_display="$(numfmt --to=iec-i --suffix=B "$zram_original" 2>/dev/null || printf '0 B')"
          zram_total_display="$(numfmt --to=iec-i --suffix=B "$zram_total" 2>/dev/null || printf '0 B')"
          zram_physical_display="$(numfmt --to=iec-i --suffix=B "$zram_physical" 2>/dev/null || printf '0 B')"
          zram_display="$zram_logical_display / $zram_total_display"
          if (( zram_original > 0 )); then
            zram_savings=$(((zram_original - zram_physical) * 100 / zram_original))
            (( zram_savings < 0 )) && zram_savings=0
            (( zram_savings > 100 )) && zram_savings=100
          else
            zram_savings=0
          fi
          if (( zram_original > 0 && zram_compressed > 0 )); then
            zram_ratio="$(awk -v original="$zram_original" -v compressed="$zram_compressed" \
              'BEGIN { printf "%.2f×", original / compressed }')"
          else
            zram_ratio="—"
          fi
          [[ -n "$zram_algorithm" ]] || zram_algorithm="n/d"
        fi

        level=$percentage
        bars="$(gauge "$percentage" '${c.accent}')"
        memory_title='PAMIĘĆ · RAM'
        if (( zram_total > 0 )); then
          (( zram_percentage > level )) && level=$zram_percentage
          bars+="$(gauge "$zram_percentage" '${c.blue}' '')"
          bars+="$(gauge "$zram_savings" '${c.green}' '')"
          memory_title+=' / ZRAM'
        elif (( swap_total > 0 )); then
          (( swap_percentage > level )) && level=$swap_percentage
          bars+="$(gauge "$swap_percentage" '${c.blue}' '')"
          memory_title+=' / SWAP'
        fi
        memory_color="$(status_color "$percentage" '${p.memory}')"
        swap_color="$(status_color "$swap_percentage" '${p.upload}')"

        tooltip="$(tooltip_start '' "$memory_title" '${p.memory}')"$'\n'
        tooltip+="$(row 'Użycie' "$percentage%" "$memory_color")"$'\n'
        tooltip+="$(row 'Dostępne' "$available_display" '${p.positive}')"$'\n'
        tooltip+="$(secondary_row 'Zajęte' "$used_display")"$'\n'
        if (( zram_total > 0 )); then
          zram_color="$(status_color "$zram_percentage" '${p.gpu}')"
          (( zram_original > 0 )) \
            && savings_color='${p.positive}' \
            || savings_color='${p.label}'
          tooltip+="$(row 'ZRAM użycie' "$zram_percentage%" "$zram_color")"$'\n'
          tooltip+="$(row 'Oszczędność' "$zram_savings%" "$savings_color")"$'\n'
          tooltip+="$(secondary_row 'ZRAM logiczne' "$zram_display")"$'\n'
          tooltip+="$(secondary_row 'ZRAM w RAM' "$zram_physical_display")"$'\n'
          tooltip+="$(detail_row 'Kompresja' "$zram_ratio")"$'\n'
          tooltip+="$(detail_row 'Algorytm' "$zram_algorithm")"$'\n'
        elif (( swap_total > 0 )); then
          tooltip+="$(row 'Swap użycie' "$swap_percentage%" "$swap_color")"$'\n'
          tooltip+="$(detail_row 'Swap' "$swap_display")"$'\n'
        fi
        tooltip+="$(detail_row 'Łącznie' "$total_display")"
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
        state_file="''${XDG_RUNTIME_DIR:?}/ironbar-network.state"
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
        network_scale="$(adaptive_scale network 10485760)"
        network_scale_display="$(numfmt --to=iec-i --suffix=B/s "$network_scale" 2>/dev/null || printf '10 MiB/s')"
        ip_address="$(
          if [[ -n "$interface" ]]; then
            ip -4 -o address show dev "$interface" 2>/dev/null \
              | awk 'NR == 1 { sub(/\/.*/, "", $4); print $4 }' || true
          fi
        )"

        tooltip="$(tooltip_start '󰓅' 'SIEĆ · ↓ / ↑' '${p.positive}')"
        tooltip+=$'\n'"$(row 'Pobieranie' "$rx_display" '${p.positive}')"$'\n'
        tooltip+="$(row 'Wysyłanie' "$tx_display" '${p.upload}')"$'\n'
        tooltip+="$(secondary_row 'Interfejs' "''${interface:-brak}")"$'\n'
        tooltip+="$(detail_row 'Adres IPv4' "''${ip_address:-brak}")"$'\n'
        tooltip+="$(detail_row 'Skala wykresu' "$network_scale_display")"
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
        state_file="''${XDG_RUNTIME_DIR:?}/ironbar-disk.state"
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
        disk_scale="$(adaptive_scale disk 104857600)"
        disk_scale_display="$(numfmt --to=iec-i --suffix=B/s "$disk_scale" 2>/dev/null || printf '100 MiB/s')"
        bars="$(gauge "$percentage" '${c.orange}')$(gauge "$read_percentage" '${c.green}' '↓')$(gauge "$write_percentage" '${c.violet}' '↑')"
        disk_usage_color="$(status_color "$percentage" '${p.disk}' 80 92)"

        tooltip="$(tooltip_start '󰋊' 'DYSK · % / ↓ / ↑' '${p.disk}')"
        tooltip+=$'\n'"$(row 'Użycie' "$percentage%" "$disk_usage_color")"$'\n'
        tooltip+="$(row 'Wolne' "$available_display" '${p.positive}')"$'\n'
        tooltip+="$(row 'Odczyt' "$read_display" '${p.positive}')"$'\n'
        tooltip+="$(row 'Zapis' "$write_display" '${p.upload}')"$'\n'
        tooltip+="$(secondary_row 'Zajęte' "$used_display")"$'\n'
        tooltip+="$(detail_row 'Łącznie' "$total_display")"$'\n'
        tooltip+="$(detail_row 'Punkt montowania' '/')"$'\n'
        tooltip+="$(detail_row 'Skala wykresu' "$disk_scale_display")"
        emit "$percentage" '󰋊' "$bars" "$tooltip" 80 92
        ;;

      gpu)
        select_amd_gpu
        gpu_runtime_status=""
        if [[ -n "$gpu_card" && -r "$gpu_card/power/runtime_status" ]]; then
          read -r gpu_runtime_status < "$gpu_card/power/runtime_status" || true
        fi
        if [[ -n "$gpu_runtime_status" && "$gpu_runtime_status" != active ]]; then
          bars='<span foreground="#${c.subtle}" size="large" weight="bold">Zz</span>'
          tooltip="$(tooltip_start '󰢮' 'GPU · UŚPIONA' '${p.gpu}')"$'\n'
          tooltip+="$(row 'Stan' 'uśpiona (D3)' '${p.positive}')"$'\n'
          tooltip+="$(secondary_row 'Metryki' 'wstrzymane')"$'\n'
          tooltip+="$(detail_row 'Wybudzenie' 'automatyczne')"
          emit 0 '󰢮' "$bars" "$tooltip"
          exit 0
        fi

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
        gpu_temperature_percentage="$(temperature_percentage "$gpu_temperature")"
        gpu_temperature_bar_color="$(temperature_indicator_color "$gpu_temperature")"
        bars="$(gauge "$usage" '${c.blue}')$(gauge "$vram_percentage" '${c.magenta}' 'V')$(gauge "$gpu_temperature_percentage" "$gpu_temperature_bar_color" '°')"
        gpu_usage_color="$(status_color "$usage" '${p.gpu}')"
        vram_color="$(status_color "$vram_percentage" '${p.vram}')"
        gpu_temperature_color="$(status_color "$gpu_temperature" '${p.thermal}')"

        tooltip="$(tooltip_start '󰢮' 'GPU · RDZEŃ / VRAM / °C' '${p.gpu}')"
        tooltip+=$'\n'"$(row 'Użycie rdzenia' "$usage%" "$gpu_usage_color")"$'\n'
        tooltip+="$(row 'Temperatura' "$gpu_temperature°C" "$gpu_temperature_color")"$'\n'
        tooltip+="$(row 'VRAM' "$vram_percentage%" "$vram_color")"$'\n'
        tooltip+="$(secondary_row 'VRAM zajęte' "$vram_used_display")"$'\n'
        tooltip+="$(detail_row 'VRAM łącznie' "$vram_total_display")"
        emit "$level" '󰢮' "$bars" "$tooltip"
        ;;

      *)
        printf 'Użycie: ironbar-metric {cpu|memory|network|disk|gpu}\n' >&2
        exit 2
        ;;
    esac
  '';
}
