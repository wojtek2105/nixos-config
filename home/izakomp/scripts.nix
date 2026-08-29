{ pkgs }:

let
  displayRefreshRate = pkgs.writeShellApplication {
    name = "display-refresh-rate";
    runtimeInputs = with pkgs; [
      hyprland
      jq
    ];
    text = ''
      refresh_rate="$(
        hyprctl monitors -j 2>/dev/null \
          | jq -r '[.[] | select(.disabled != true) | .refreshRate] | if length > 0 then max | round else 60 end' \
          || true
      )"

      if [[ ! "$refresh_rate" =~ ^[0-9]+$ ]] \
        || (( refresh_rate < 30 || refresh_rate > 1000 )); then
        refresh_rate=60
      fi

      printf '%s\n' "$refresh_rate"
    '';
  };

  powerSourceState = pkgs.writeShellApplication {
    name = "power-source-state";
    text = ''
      battery_present=false
      external_power=false

      # Discover power supplies by type so this also works on hosts that do not
      # call their devices BAT0 or AC0.
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
              [[ "$online" == 1 ]] && external_power=true
            fi
            ;;
        esac
      done

      if [[ "$battery_present" == true && "$external_power" == false ]]; then
        printf 'battery\n'
      else
        # Desktops and machines without a readable battery are treated as
        # externally powered, which is the safe choice for suspend and FPS.
        printf 'external\n'
      fi
    '';
  };

  screensaverRefreshRate = pkgs.writeShellApplication {
    name = "screensaver-refresh-rate";
    runtimeInputs = [
      displayRefreshRate
      powerSourceState
    ];
    text = ''
      refresh_rate="$(display-refresh-rate)"

      # Text effects keep the monitor's full refresh rate on external power,
      # but avoid rendering more than 60 frames per second on battery.
      if [[ "$(power-source-state)" == battery ]] && (( refresh_rate > 60 )); then
        refresh_rate=60
      fi

      printf '%s\n' "$refresh_rate"
    '';
  };

  displayPowerRefresh = pkgs.writeShellApplication {
    name = "display-power-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.hyprland
      pkgs.jq
      pkgs.systemd
      powerSourceState
    ];
    text = ''
      read_plan() {
        local power_source monitors_json

        power_source="$(power-source-state)"
        monitors_json="$(hyprctl monitors -j 2>/dev/null || true)"
        [[ -n "$monitors_json" ]] || return 1

        jq -er --arg power "$power_source" '
          first(
            .[]
            | select(.disabled != true)
            | select(.name | test("^eDP(-|$)"))
          ) as $monitor
          | ($monitor.width | tostring) + "x" + ($monitor.height | tostring) as $resolution
          | [
              $monitor.availableModes[]
              | . as $mode
              | capture("^(?<resolution>[0-9]+x[0-9]+)@(?<refresh>[0-9.]+)Hz$")
              | select(.resolution == $resolution)
              | .mode = $mode
              | .refresh = (.refresh | tonumber)
            ] as $modes
          | if ($modes | length) == 0 then error("no matching modes") else . end
          | (if $power == "battery"
             then ($modes | min_by((.refresh - 60) * (.refresh - 60)))
             else ($modes | max_by(.refresh))
             end) as $target
          | [
              $monitor.name,
              $target.mode,
              (($monitor.x | tostring) + "x" + ($monitor.y | tostring)),
              ($monitor.scale | tostring),
              ($monitor.refreshRate | round | tostring),
              ($target.refresh | round | tostring),
              $power
            ]
          | @tsv
        ' <<< "$monitors_json"
      }

      show_status() {
        local plan output mode position scale current target power
        plan="$(read_plan)" || {
          printf 'Brak aktywnej wewnętrznej matrycy eDP albo zgodnego trybu.\n'
          return 0
        }
        IFS=$'\t' read -r output mode position scale current target power <<< "$plan"
        printf 'zasilanie=%s wyjście=%s obecnie=%sHz docelowo=%s (%s) pozycja=%s skala=%s\n' \
          "$power" "$output" "$current" "$mode" "$target" "$position" "$scale"
      }

      apply_refresh() {
        local plan output mode position scale current target power expression
        plan="$(read_plan)" || return 0
        IFS=$'\t' read -r output mode position scale current target power <<< "$plan"

        if [[ "$current" == "$target" ]]; then
          return 0
        fi

        expression="$(
          jq -nr \
            --arg output "$output" \
            --arg mode "$mode" \
            --arg position "$position" \
            --argjson scale "$scale" \
            '"hl.monitor({ output = " + ($output | tojson)
              + ", mode = " + ($mode | tojson)
              + ", position = " + ($position | tojson)
              + ", scale = " + ($scale | tostring) + " })"'
        )"

        printf 'Ustawiam %s na %s (%s, pozycja %s, skala %s).\n' \
          "$output" "$mode" "$power" "$position" "$scale"
        hyprctl eval "$expression" >/dev/null
      }

      case "''${1:-apply}" in
        apply)
          apply_refresh
          ;;
        status)
          show_status
          ;;
        watch)
          # Apply once at login, then react to AC adapter and USB-C power
          # events. A short debounce folds the several udev notifications from
          # one cable transition into one harmless idempotent update.
          apply_refresh || true
          while IFS= read -r event; do
            [[ "$event" == UDEV* ]] || continue
            sleep 1
            apply_refresh || true
          done < <(stdbuf -oL udevadm monitor --udev --subsystem-match=power_supply)
          ;;
        *)
          printf 'Użycie: display-power-refresh [apply|status|watch]\n' >&2
          exit 64
          ;;
      esac
    '';
  };

  zenRunOrRaise = pkgs.writeShellApplication {
    name = "zen-run-or-raise";
    runtimeInputs = with pkgs; [
      coreutils
      hyprland
      jq
      util-linux
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:?}/zen-run-or-raise"
      mkdir -p "$runtime_dir"
      exec 9>"$runtime_dir/lock"
      flock --nonblock 9 || exit 0

      clients_json="$(hyprctl clients -j 2>/dev/null || true)"
      zen_address=""

      if [[ -n "$clients_json" ]]; then
        # Hyprland numbers the most recently focused window with the lowest
        # focusHistoryID. Zen releases have reported both "zen" and channel-
        # specific classes such as "zen-twilight", so accept either form in
        # both class fields.
        zen_address="$(
          jq -r '
            [
              .[]
              | select(.mapped != false)
              | select(
                  ((.class // "") | ascii_downcase | test("^zen($|-)"))
                  or ((.initialClass // "") | ascii_downcase | test("^zen($|-)"))
                )
            ]
            | sort_by(
                if (.focusHistoryID // -1) >= 0
                then .focusHistoryID
                else 2147483647
                end
              )
            | .[0].address // empty
          ' <<< "$clients_json" 2>/dev/null || true
        )"
      fi

      if [[ "$zen_address" =~ ^0x[0-9a-fA-F]+$ ]] \
        && hyprctl dispatch \
          "hl.dsp.focus({ window = \"address:$zen_address\" })" \
          >/dev/null 2>&1; then
        exit 0
      fi

      # Ignore an accidental second key event while the first Zen window is
      # still starting and has not appeared in Hyprland's client list yet.
      now="$(date +%s)"
      last_launch=0
      if [[ -r "$runtime_dir/last-launch" ]]; then
        read -r last_launch < "$runtime_dir/last-launch" || last_launch=0
      fi
      if [[ "$last_launch" =~ ^[0-9]+$ ]] && (( now - last_launch < 3 )); then
        exit 0
      fi
      printf '%s\n' "$now" > "$runtime_dir/last-launch"

      # Do not let the browser inherit the advisory lock for its whole life.
      flock --unlock 9
      exec 9>&-
      exec zen-twilight
    '';
  };
in
{
  display-refresh-rate = displayRefreshRate;
  display-power-refresh = displayPowerRefresh;
  power-source-state = powerSourceState;
  screensaver-refresh-rate = screensaverRefreshRate;
  zen-run-or-raise = zenRunOrRaise;
}
