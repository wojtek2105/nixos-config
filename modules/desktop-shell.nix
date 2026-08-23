{ desktopBar ? "waybar", pkgs, ... }:

let
  desktop-benchmark = pkgs.writeShellApplication {
    name = "desktop-benchmark";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      procps
    ];
    text = ''
      duration="''${1:-60}"
      if [[ ! "$duration" =~ ^[0-9]+$ ]] || (( duration < 10 )); then
        printf 'Użycie: desktop-benchmark [sekundy >= 10]\n' >&2
        exit 2
      fi

      variant=${desktopBar}
      process_pattern='${
        if desktopBar == "ironbar" then
          "ironbar|\\.ironbar-wrappe|\\.ironbar-wrapped|swaync|\\.swaync-wrapped|\\.swaync-client-|awww-daemon|\\.awww-daemon-wr"
        else
          "waybar|\\.waybar-wrapped|swaync|\\.swaync-wrapped|\\.swaync-client-|awww-daemon|\\.awww-daemon-wr"
      }'

      cpu_snapshot() {
        awk '/^cpu / {
          idle=$5+$6
          total=0
          for (i=2; i<=NF; i++) total+=$i
          print total, idle
        }' /proc/stat
      }

      process_ticks() {
        local total=0 comm stat
        for process in /proc/[0-9]*; do
          [[ -r "$process/comm" && -r "$process/stat" ]] || continue
          read -r comm < "$process/comm" || continue
          [[ "$comm" =~ ^($process_pattern)$ ]] || continue
          stat="$(<"$process/stat")"
          stat="''${stat#*) }"
          read -r -a fields <<< "$stat"
          total=$((total + fields[11] + fields[12]))
        done
        printf '%s\n' "$total"
      }

      shell_pss_kib() {
        local total=0 comm value
        for process in /proc/[0-9]*; do
          [[ -r "$process/comm" && -r "$process/smaps_rollup" ]] || continue
          read -r comm < "$process/comm" || continue
          [[ "$comm" =~ ^($process_pattern)$ ]] || continue
          value="$(awk '/^Pss:/ { print $2 }' "$process/smaps_rollup" 2>/dev/null || true)"
          total=$((total + ''${value:-0}))
        done
        printf '%s\n' "$total"
      }

      matched_processes() {
        local comm
        for process in /proc/[0-9]*; do
          [[ -r "$process/comm" ]] || continue
          read -r comm < "$process/comm" || continue
          [[ "$comm" =~ ^($process_pattern)$ ]] || continue
          printf '%s\n' "$comm"
        done | sort -u | paste -sd, -
      }

      gpu_busy() {
        local total=0 count=0 value
        for input in /sys/class/drm/card[0-9]*/device/gpu_busy_percent; do
          [[ -r "$input" ]] || continue
          read -r value < "$input" 2>/dev/null || continue
          [[ "$value" =~ ^[0-9]+$ ]] || continue
          total=$((total + value))
          count=$((count + 1))
        done
        (( count > 0 )) && printf '%s\n' "$((total / count))" || printf '%s\n' -1
      }

      battery_power_uw() {
        local total=0 count=0 value
        for input in /sys/class/power_supply/BAT*/power_now; do
          [[ -r "$input" ]] || continue
          read -r value < "$input" 2>/dev/null || continue
          [[ "$value" =~ ^[0-9]+$ ]] || continue
          total=$((total + value))
          count=$((count + 1))
        done
        (( count > 0 )) && printf '%s\n' "$total" || printf '%s\n' -1
      }

      printf 'Benchmark pulpitu: %s, %ss\n' "$variant" "$duration"
      printf 'Nie ruszaj myszy i nie uruchamiaj programów. Start za 5 sekund...\n'
      sleep 5

      read -r cpu_start idle_start < <(cpu_snapshot)
      ticks_start="$(process_ticks)"
      gpu_sum=0
      gpu_samples=0
      power_sum=0
      power_samples=0

      for ((second=0; second<duration; second++)); do
        gpu="$(gpu_busy)"
        if (( gpu >= 0 )); then
          gpu_sum=$((gpu_sum + gpu))
          gpu_samples=$((gpu_samples + 1))
        fi
        power="$(battery_power_uw)"
        if (( power >= 0 )); then
          power_sum=$((power_sum + power))
          power_samples=$((power_samples + 1))
        fi
        sleep 1
      done

      read -r cpu_end idle_end < <(cpu_snapshot)
      ticks_end="$(process_ticks)"
      pss_kib="$(shell_pss_kib)"
      cpu_delta=$((cpu_end - cpu_start))
      idle_delta=$((idle_end - idle_start))
      clock_ticks="$(getconf CLK_TCK)"

      system_cpu="$(awk -v total="$cpu_delta" -v idle="$idle_delta" \
        'BEGIN { if (total > 0) printf "%.2f", (total-idle)*100/total; else print "0.00" }')"
      shell_cpu="$(awk -v ticks="$((ticks_end - ticks_start))" -v hz="$clock_ticks" -v seconds="$duration" \
        'BEGIN { printf "%.3f", ticks*100/hz/seconds }')"
      shell_pss="$(awk -v kib="$pss_kib" 'BEGIN { printf "%.1f", kib/1024 }')"

      (( gpu_samples > 0 )) \
        && gpu_average="$(awk -v sum="$gpu_sum" -v count="$gpu_samples" 'BEGIN { printf "%.2f", sum/count }')" \
        || gpu_average="niedostępne"
      (( power_samples > 0 )) \
        && power_average="$(awk -v sum="$power_sum" -v count="$power_samples" 'BEGIN { printf "%.2f", sum/count/1000000 }')" \
        || power_average="niedostępne"

      printf '\nvariant=%s\n' "$variant"
      printf 'duration_seconds=%s\n' "$duration"
      printf 'system_cpu_percent=%s\n' "$system_cpu"
      printf 'resident_shell_cpu_percent=%s\n' "$shell_cpu"
      printf 'shell_pss_mib=%s\n' "$shell_pss"
      printf 'gpu_busy_average_percent=%s\n' "$gpu_average"
      printf 'battery_power_average_w=%s\n' "$power_average"
      printf 'matched_processes='
      matched_processes || true
    '';
  };
in
{
  environment.systemPackages = [ desktop-benchmark ];
}
