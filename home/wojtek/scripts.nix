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

  zenRunOrRaise = pkgs.writeShellApplication {
    name = "zen-run-or-raise";
    runtimeInputs = with pkgs; [
      hyprland
      jq
    ];
    text = ''
      clients_json="$(hyprctl clients -j 2>/dev/null || true)"
      zen_address=""

      if [[ -n "$clients_json" ]]; then
        # Hyprland numbers the most recently focused window with the lowest
        # focusHistoryID. Match both class fields because one can change after
        # mapping while StartupWMClass remains zen-twilight.
        zen_address="$(
          jq -r '
            [
              .[]
              | select(.mapped != false)
              | select(
                  ((.class // "") | ascii_downcase) == "zen-twilight"
                  or ((.initialClass // "") | ascii_downcase) == "zen-twilight"
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

      if [[ -n "$zen_address" ]] \
        && hyprctl dispatch focuswindow "address:$zen_address" >/dev/null 2>&1; then
        exit 0
      fi

      exec zen-twilight
    '';
  };
in
{
  display-refresh-rate = displayRefreshRate;
  power-source-state = powerSourceState;
  screensaver-refresh-rate = screensaverRefreshRate;
  zen-run-or-raise = zenRunOrRaise;
}
