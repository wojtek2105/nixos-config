{ pkgs }:

{
  display-refresh-rate = pkgs.writeShellApplication {
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
}
