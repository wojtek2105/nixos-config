{ desktopBar ? "waybar", inputs, pkgs, replayConfig, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
  scripts = import ./scripts.nix { inherit pkgs; };

  tideDefaults = pkgs.runCommand "tide-declarative-defaults.fish" { } ''
    sed -E 's/^(tide_[^ ]+)(.*)$/set -U \1\2/' \
      ${pkgs.fishPlugins.tide}/share/fish/vendor_functions.d/tide/configure/icons.fish \
      ${pkgs.fishPlugins.tide}/share/fish/vendor_functions.d/tide/configure/configs/rainbow.fish \
      > "$out"
  '';

  clipboard-history = pkgs.writeShellApplication {
    name = "clipboard-history";
    runtimeInputs = with pkgs; [
      cliphist
      fuzzel
      wl-clipboard
      wtype
    ];
    text = ''
      chosen="$(cliphist list | fuzzel --dmenu --prompt 'Schowek: ')" || exit 0
      [[ -n "$chosen" ]] || exit 0

      printf '%s\n' "$chosen" | cliphist decode | wl-copy
      sleep 0.1
      wtype -M ctrl -k v -m ctrl
    '';
  };

  screenshot-menu = pkgs.writeShellApplication {
    name = "screenshot-menu";
    runtimeInputs = with pkgs; [
      coreutils
      fuzzel
      grim
      hyprland
      jq
      libnotify
      satty
      slurp
      swayosd
      wl-clipboard
    ];
    text = ''
      osd_success() {
        swayosd-client \
          --custom-message='Screenshot zapisany i skopiowany' \
          --custom-icon=camera-photo-symbolic \
          >/dev/null 2>&1 || true
      }

      screenshot_dir="''${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
      mkdir -p "$screenshot_dir"

      mode="''${1:-}"
      if [[ -z "$mode" ]]; then
        mode="$({
          printf '%s\n' \
            '󰆞  Obszar' \
            '󰖯  Aktywne okno' \
            '󰍹  Cały ekran'
        } | fuzzel --dmenu --only-match --minimal-lines \
          --prompt 'Zrzut ekranu  ›  ' --width 36 --lines 3)" || exit 0
      fi

      case "$mode" in
        area|'󰆞  Obszar') target=area ;;
        window|'󰖯  Aktywne okno') target=active ;;
        full|'󰍹  Cały ekran') target=screen ;;
        *) exit 0 ;;
      esac

      # Give Fuzzel enough time to unmap before resolving the active window.
      sleep 0.2

      output="$screenshot_dir/$(date +%F_%H-%M-%S).png"

      if [[ "$target" == screen ]]; then
        if ! grim "$output"; then
          notify-send --urgency=critical "Screenshot" "Nie udało się przechwycić ekranu."
          exit 1
        fi
        wl-copy --type image/png < "$output"
        osd_success
        exit 0
      fi

      temporary="$(mktemp --tmpdir screenshot.XXXXXX.png)"
      cleanup() {
        rm -f "$temporary"
      }
      trap cleanup EXIT

      if [[ "$target" == area ]]; then
        geometry="$(slurp \
          -b '#${c.background}cc' \
          -c '#${c.accent}ff' \
          -s '#${c.selection}88' \
          -w 2)" || exit 0
        [[ -n "$geometry" ]] || exit 0

        if ! grim -g "$geometry" "$temporary"; then
          notify-send --urgency=critical "Screenshot" "Nie udało się przechwycić obszaru."
          exit 1
        fi
      else
        geometry="$(hyprctl activewindow -j | jq --raw-output --exit-status '
          select(.address != null and .address != "")
          | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
        ')" || {
          notify-send --urgency=critical "Screenshot" "Nie znaleziono aktywnego okna."
          exit 1
        }

        if ! grim -g "$geometry" "$temporary"; then
          notify-send --urgency=critical "Screenshot" "Nie udało się przechwycić aktywnego okna."
          exit 1
        fi
      fi

      satty \
        --filename "$temporary" \
        --output-filename "$output" \
        --fullscreen current-screen \
        --initial-tool pointer \
        --font-family '${theme.fonts.sans}' \
        --copy-command wl-copy \
        --actions-on-enter save-to-clipboard \
        --actions-on-enter save-to-file \
        --actions-on-enter exit \
        --actions-on-escape exit \
        --actions-on-right-click save-to-clipboard \
        --actions-on-right-click save-to-file \
        --actions-on-right-click exit \
        --disable-notifications \
        --no-window-decoration \
        --title 'Edytuj screenshot' \
        --app-id org.polamaniec.screenshot

      if [[ -s "$output" ]]; then
        wl-copy --type image/png < "$output"
        osd_success
      fi
    '';
  };

  hypr-bindings = pkgs.writeShellApplication {
    name = "hypr-bindings";
    runtimeInputs = with pkgs; [
      fuzzel
      gawk
      hyprland
    ];
    text = ''
      hyprctl binds | awk '
        function append(current, value) {
          return current == "" ? value : current "+" value
        }
        function modifiers(mask, result) {
          if (int(mask / 64) % 2) result = append(result, "SUPER")
          if (int(mask / 8) % 2) result = append(result, "ALT")
          if (int(mask / 4) % 2) result = append(result, "CTRL")
          if (int(mask / 1) % 2) result = append(result, "SHIFT")
          return result
        }
        /^[[:space:]]*modmask:/ { mask = $2 }
        /^[[:space:]]*key:/ { key = $2 }
        /^[[:space:]]*dispatcher:/ { dispatcher = $2 }
        /^[[:space:]]*arg:/ {
          $1 = ""
          sub(/^[[:space:]]+/, "")
          argument = $0
        }
        /^$/ && key != "" {
          combo = modifiers(mask)
          if (combo != "") combo = combo "+"
          printf "%-24s %s %s\n", combo key, dispatcher, argument
          mask = key = dispatcher = argument = ""
        }
      ' | sort -u | fuzzel --dmenu --prompt "Skróty: " --width 72 --lines 20
    '';
  };

  wifi-menu = pkgs.writeShellApplication {
    name = "wifi-menu";
    runtimeInputs = with pkgs; [
      gawk
      gum
      libnotify
      networkmanager
    ];
    text = ''
      export LC_ALL=C.UTF-8

      notify_error() {
        notify-send --urgency=critical "Wi-Fi" "$1"
      }

      while true; do
        wifi_state="$(nmcli radio wifi)"
        options=()
        declare -A value_by_option=()

        if [[ "$wifi_state" == enabled ]]; then
          options+=("󰖪  Wyłącz Wi-Fi" "󰑐  Skanuj ponownie" "󰌙  Rozłącz obecną sieć")
          value_by_option["󰖪  Wyłącz Wi-Fi"]="__disable"
          value_by_option["󰑐  Skanuj ponownie"]="__rescan"
          value_by_option["󰌙  Rozłącz obecną sieć"]="__disconnect"

          declare -A seen=()
          declare -A security_by_ssid=()
          while IFS=$'\t' read -r active signal security ssid; do
            [[ -n "$ssid" ]] || continue
            [[ -z "''${seen[$ssid]+x}" ]] || continue
            seen["$ssid"]=1
            security_by_ssid["$ssid"]="$security"

            if (( signal >= 75 )); then
              signal_icon="󰤨"
            elif (( signal >= 50 )); then
              signal_icon="󰤥"
            elif (( signal >= 25 )); then
              signal_icon="󰤢"
            else
              signal_icon="󰤟"
            fi

            [[ "$security" == "--" ]] && lock_icon="󰖩" || lock_icon="󰌾"
            [[ "$active" == "yes" ]] && active_icon="●" || active_icon=" "
            option="$active_icon  $signal_icon  $ssid  $lock_icon  $signal%"
            options+=("$option")
            value_by_option["$option"]="$ssid"
          done < <(nmcli --terse --escape no --separator $'\t' \
            --fields ACTIVE,SIGNAL,SECURITY,SSID device wifi list --rescan no)
        else
          options+=("󰖩  Włącz Wi-Fi")
          value_by_option["󰖩  Włącz Wi-Fi"]="__enable"
        fi

        printf '\033[2J\033[H'
        selected="$(gum choose \
          --header '  Wi-Fi  •  Enter: wybierz  •  Esc: zamknij' \
          --height 16 \
          --cursor '▌ ' \
          --cursor.foreground '#${c.accent}' \
          --header.foreground '#${c.yellow}' \
          --item.foreground '#${c.foreground}' \
          --selected.foreground '#${c.green}' \
          "''${options[@]}")" || exit 0
        choice="''${value_by_option[$selected]}"

        case "$choice" in
          __enable)
            nmcli radio wifi on || notify_error "Nie udało się włączyć Wi-Fi"
            sleep 1
            continue
            ;;
          __disable)
            nmcli radio wifi off || notify_error "Nie udało się wyłączyć Wi-Fi"
            exit 0
            ;;
          __rescan)
            nmcli device wifi rescan || notify_error "Skanowanie nie powiodło się"
            sleep 1
            continue
            ;;
          __disconnect)
            device="$(nmcli --terse --fields DEVICE,TYPE device status \
              | awk -F: '$2 == "wifi" { print $1; exit }')"
            [[ -n "$device" ]] || {
              notify_error "Nie znaleziono interfejsu Wi-Fi"
              exit 1
            }
            if nmcli device disconnect "$device"; then
              notify-send "Wi-Fi" "Rozłączono sieć"
            else
              notify_error "Nie udało się rozłączyć sieci"
            fi
            exit 0
            ;;
        esac

        if nmcli device wifi connect "$choice" >/dev/null 2>&1; then
          notify-send "Wi-Fi" "Połączono z $choice"
          exit 0
        fi

        security="''${security_by_ssid[$choice]:---}"
        [[ "$security" != "--" ]] || {
          notify_error "Nie udało się połączyć z $choice"
          exit 1
        }

        printf '\033[2J\033[H\n  Łączenie z %s\n\n' "$choice"
        if nmcli --ask device wifi connect "$choice"; then
          printf '\n  Połączono.\n'
          notify-send "Wi-Fi" "Połączono z $choice"
        else
          printf '\n  Nie udało się połączyć. Naciśnij Enter, aby zamknąć.\n'
          notify_error "Nie udało się połączyć z $choice"
          read -r _
          exit 1
        fi
        exit 0
      done
    '';
  };

  docker-status = pkgs.writeShellApplication {
    name = "docker-status";
    runtimeInputs = with pkgs; [
      coreutils
      docker-client
      gnused
      jq
      systemd
    ];
    text = ''
      output_mode="''${1:-json}"

      output() {
        case "$output_mode" in
          json)
            jq --null-input --compact-output \
              --arg text "$1" \
              --arg tooltip "$2" \
              --arg class "$3" \
              '{text: $text, tooltip: $tooltip, class: $class}'
            ;;
          label)
            printf '%s\n' "$1"
            ;;
          tooltip)
            printf '%s\n' "$2" | sed -E 's/<[^>]+>//g'
            ;;
          *)
            printf 'Użycie: docker-status [json|label|tooltip]\n' >&2
            exit 2
            ;;
        esac
      }

      if ! systemctl is-active --quiet docker.service; then
        output "  –" $'<b>Docker</b>\nDaemon jest uśpiony. Uruchomi się przy pierwszym użyciu.' "offline"
        exit 0
      fi

      if ! timeout 2 docker info >/dev/null 2>&1; then
        output "  !" $'<b>Docker</b>\nDaemon działa, ale użytkownik nie ma dostępu.' "critical"
        exit 0
      fi

      mapfile -t container_ids < <(docker container ls --all --quiet)
      total="''${#container_ids[@]}"
      if (( total == 0 )); then
        output "  0" $'<b>Docker</b>\nBrak kontenerów.' "ok"
        exit 0
      fi

      inspect_json="$(docker inspect "''${container_ids[@]}")"
      running="$(jq '[.[] | select(.State.Running == true)] | length' <<< "$inspect_json")"
      stopped=$((total - running))
      unhealthy="$(jq '[.[] | select(.State.Health.Status? == "unhealthy")] | length' <<< "$inspect_json")"
      failed="$(jq '[.[] | select(
        (.State.Restarting == true) or
        (.State.Status == "dead") or
        (.State.Status == "exited" and .State.ExitCode != 0)
      )] | length' <<< "$inspect_json")"

      if (( unhealthy > 0 || failed > 0 )); then
        class="critical"
      elif (( stopped > 0 )); then
        class="warning"
      else
        class="ok"
      fi

      tooltip="<b>Docker</b>"$'\n'
      tooltip+="Aktywne: $running   •   Zatrzymane: $stopped"
      (( unhealthy > 0 )) && tooltip+="   •   Unhealthy: $unhealthy"
      (( failed > 0 )) && tooltip+="   •   Błędy: $failed"

      if (( running > 0 )); then
        mapfile -t running_ids < <(docker container ls --quiet)
        stats="$(timeout 4 docker stats --no-stream --format '{{json .}}' "''${running_ids[@]}" 2>/dev/null \
          | jq --raw-input --slurp '
              split("\n")
              | map(select(length > 0) | fromjson)
              | map("\(.Name)   CPU \(.CPUPerc)   RAM \(.MemUsage)")
              | join("\n")
            ')"
        [[ -n "$stats" ]] && tooltip+=$'\n\n<b>Zużycie kontenerów</b>\n'"$stats"
      fi

      problems="$(jq --raw-output '
        .[]
        | select(
            (.State.Restarting == true) or
            (.State.Health.Status? == "unhealthy") or
            (.State.Status == "dead") or
            (.State.Status == "exited" and .State.ExitCode != 0)
          )
        | "\(.Name | ltrimstr("/"))   \(.State.Status)   exit=\(.State.ExitCode)"
      ' <<< "$inspect_json")"
      [[ -n "$problems" ]] && tooltip+=$'\n\n<b>Problemy</b>\n'"$problems"

      output "  $running/$total" "$tooltip" "$class"
    '';
  };

  desktop-panel = pkgs.writeShellApplication {
    name = "desktop-panel";
    runtimeInputs = with pkgs; [
      bluetui
      btop
      foot
      lazydocker
      util-linux
      wifi-menu
      wiremix
    ];
    text = ''
      panel="''${1:-}"
      lock_file="''${XDG_RUNTIME_DIR:?}/desktop-panel.lock"

      exec 9>"$lock_file"
      flock --nonblock 9 || exit 0

      case "$panel" in
        metrics)
          exec foot --app-id=desktop-metrics --title=Zasoby \
            --window-size-chars=120x36 btop
          ;;
        audio)
          exec foot --app-id=desktop-audio --title=Dźwięk \
            --window-size-chars=100x30 wiremix
          ;;
        wifi)
          exec foot --app-id=desktop-wifi --title=Wi-Fi \
            --window-size-chars=76x24 wifi-menu
          ;;
        bluetooth)
          exec foot --app-id=desktop-bluetooth --title=Bluetooth \
            --window-size-chars=86x26 bluetui
          ;;
        docker)
          exec foot --app-id=desktop-docker --title=Docker \
            --window-size-chars=110x32 lazydocker
          ;;
        *)
          printf 'Użycie: desktop-panel {metrics|audio|wifi|bluetooth|docker}\n' >&2
          exit 2
          ;;
      esac
    '';
  };

  screensaver-run = pkgs.writeShellApplication {
    name = "screensaver-run";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      scripts.display-refresh-rate
      terminaltexteffects
    ];
    text = ''
      cleanup() {
        printf '\033[?25h'
        jobs -pr | xargs -r kill 2>/dev/null || true
      }
      trap cleanup EXIT INT TERM HUP

      printf '\033]11;#${c.background}\007\033[2J\033[H\033[?25l'

      wait_for_terminal_resize() {
        local deadline=$((SECONDS + 2))
        while (( SECONDS < deadline )) && [[ "$(stty size 2>/dev/null)" == "24 80" ]]; do
          sleep 0.02
        done
      }

      wait_for_terminal_resize

      refresh_rate="$(display-refresh-rate)"

      # TTE expresses most motion as distance or delay per rendered frame.
      # Normalize it to wall-clock time so a 240 Hz monitor is smoother, not
      # twice as fast as the laptop panel, then slow the effects by 6x.
      animation_speed() {
        awk -v value="$1" -v fps="$refresh_rate" \
          'BEGIN { printf "%.4f", value * 60 / fps / 6.0 }'
      }

      animation_frames() {
        awk -v value="$1" -v fps="$refresh_rate" \
          'BEGIN {
            frames = value * fps / 60 * 6.0
            if (frames < 1) frames = 1
            printf "%d", frames + 0.5
          }'
      }

      effects=(bouncyballs rain rings scattered slide wipe)

      while true; do
        effect="''${effects[RANDOM % ''${#effects[@]}]}"
        effect_args=()
        case "$effect" in
          bouncyballs)
            effect_args=(
              --ball-delay "$(animation_frames 4)"
              --movement-speed "$(animation_speed 0.45)"
              --ball-colors ${c.orange} ${c.yellow} ${c.accent}
              --final-gradient-stops ${c.accent} ${c.orange} ${c.bright}
            )
            ;;
          rain)
            effect_args=(
              --movement-speed "$(animation_speed 0.33)-$(animation_speed 0.57)"
              --rain-colors ${c.violet} ${c.blue} ${c.accent}
              --final-gradient-stops ${c.violet} ${c.accent} ${c.bright}
            )
            ;;
          rings)
            effect_args=(
              --spin-duration "$(animation_frames 200)"
              --spin-speed "$(animation_speed 0.25)-$(animation_speed 1.0)"
              --disperse-duration "$(animation_frames 200)"
              --ring-colors ${c.accent} ${c.orange} ${c.yellow}
              --final-gradient-stops ${c.accent} ${c.orange} ${c.bright}
            )
            ;;
          scattered)
            effect_args=(
              --movement-speed "$(animation_speed 0.5)"
              --final-gradient-frames "$(animation_frames 9)"
              --final-gradient-stops ${c.violet} ${c.accent} ${c.bright}
            )
            ;;
          slide)
            effect_args=(
              --movement-speed "$(animation_speed 0.8)"
              --gap "$(animation_frames 2)"
              --final-gradient-frames "$(animation_frames 6)"
              --final-gradient-stops ${c.orange} ${c.accent} ${c.bright}
            )
            ;;
          wipe)
            effect_args=(
              --wipe-delay "$(animation_frames 1)"
              --final-gradient-frames "$(animation_frames 3)"
              --final-gradient-stops ${c.violet} ${c.accent} ${c.orange} ${c.bright}
            )
            ;;
        esac

        tte --input-file "''${XDG_CONFIG_HOME:-$HOME/.config}/screensaver/wojtech.txt" \
          --frame-rate "$refresh_rate" \
          --canvas-width 0 \
          --canvas-height 0 \
          --anchor-canvas c \
          --anchor-text c \
          --reuse-canvas \
          --no-eol \
          --no-restore-cursor \
          "$effect" "''${effect_args[@]}" &
        effect_pid=$!

        while kill -0 "$effect_pid" 2>/dev/null; do
          if read -r -n 1 -t 0.2; then
            exit 0
          fi
        done
        wait "$effect_pid" || true
      done
    '';
  };

  screensaver = pkgs.writeShellApplication {
    name = "screensaver";
    runtimeInputs = with pkgs; [
      foot
      procps
      screensaver-run
    ];
    text = ''
      pgrep -f '[o]rg.polamaniec.screensaver' >/dev/null && exit 0

      exec foot \
        --app-id=org.polamaniec.screensaver \
        --override=main.font='${theme.fonts.monospace}:size=16' \
        --override=main.pad=0x0 \
        --override=colors.background=${c.background} \
        -e screensaver-run org.polamaniec.screensaver
    '';
  };
in

{
  imports = [
    inputs.zen-browser.homeModules.twilight
    ./desktop.nix
    ./hyprland.nix
    ./notifications.nix
    ./osd.nix
    ./zen.nix
  ] ++ [
    (if desktopBar == "ironbar" then ./ironbar.nix else ./waybar.nix)
  ];

  assertions = [
    {
      assertion = builtins.elem desktopBar [ "waybar" "ironbar" ];
      message = "desktopBar musi mieć wartość 'waybar' albo 'ironbar'.";
    }
  ];

  home = {
    username = "wojtek";
    homeDirectory = "/home/wojtek";
    stateVersion = "26.05";

    packages = with pkgs; [
      cliphist
      clipboard-history
      discord
      hypr-bindings
      playerctl
      screenshot-menu
      screensaver
      docker-status
      desktop-panel
      wl-clipboard
      wlogout
    ];

    sessionVariables = {
      BROWSER = "zen-twilight";
      EDITOR = "nvim";
      TERMINAL = "foot";
      VISUAL = "nvim";
      NIXOS_OZONE_WL = "1";
    };
  };

  programs.home-manager.enable = true;

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "biscuit";
      theme_background = false;
      truecolor = true;
      rounded_corners = true;
      vim_keys = true;
    };
  };

  # btop writes this file itself on exit; the declarative profile is canonical.
  xdg.configFile."btop/btop.conf".force = true;
  xdg.configFile."btop/themes/biscuit.theme".source =
    "${inputs.biscuit-desktop}/btop.theme";

  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "tide";
        src = pkgs.fishPlugins.tide.src;
      }
    ];
    interactiveShellInit = ''
      set -g fish_greeting

      set -U _tide_color_dark_blue ${c.violet}
      set -U _tide_color_dark_green ${c.green}
      set -U _tide_color_gold ${c.yellow}
      set -U _tide_color_green ${c.green}
      set -U _tide_color_light_blue ${c.blue}
      source ${tideDefaults}

      set -U tide_left_prompt_items pwd git newline character
      set -U tide_right_prompt_items status cmd_duration jobs nix_shell time
      set -U tide_cmd_duration_threshold 1000
      set -U tide_cmd_duration_icon '󱎫'
      set -U tide_git_icon ''
      set -U tide_prompt_add_newline_before true
      set -U tide_time_format '%H:%M'

      # Biscuit de Mar Dark powerline palette.
      set -U tide_pwd_bg_color ${c.accent}
      set -U tide_pwd_color_anchors ${c.bright}
      set -U tide_pwd_color_dirs ${c.bright}
      set -U tide_pwd_color_truncated_dirs ${c.subtle}
      set -U tide_git_bg_color ${c.green}
      set -U tide_git_bg_color_unstable ${c.yellow}
      set -U tide_git_bg_color_urgent ${c.orange}
      set -U tide_git_color_branch ${c.background}
      set -U tide_git_color_conflicted ${c.background}
      set -U tide_git_color_dirty ${c.background}
      set -U tide_git_color_operation ${c.background}
      set -U tide_git_color_staged ${c.background}
      set -U tide_git_color_stash ${c.background}
      set -U tide_git_color_untracked ${c.background}
      set -U tide_git_color_upstream ${c.background}
      set -U tide_status_bg_color ${c.surface}
      set -U tide_status_bg_color_failure ${c.red}
      set -U tide_status_color ${c.green}
      set -U tide_status_color_failure ${c.bright}
      set -U tide_cmd_duration_bg_color ${c.yellow}
      set -U tide_cmd_duration_color ${c.background}
      set -U tide_jobs_bg_color ${c.selection}
      set -U tide_jobs_color ${c.foreground}
      set -U tide_nix_shell_bg_color ${c.violet}
      set -U tide_nix_shell_color ${c.bright}
      set -U tide_time_bg_color ${c.selection}
      set -U tide_time_color ${c.foreground}
      set -U tide_prompt_color_frame_and_connection ${c.muted}
      set -U tide_prompt_color_separator_same_color ${c.subtle}
    '';
  };

  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    escapeTime = 0;
    historyLimit = 100000;
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
    extraConfig = ''
      set -g default-shell ${pkgs.fish}/bin/fish
      set -g focus-events on
      set -g renumber-windows on
      set -g status-position top
      set -g status-style 'bg=#${c.background},fg=#${c.foreground}'
      set -g window-status-current-style 'bg=#${c.accent},fg=#${c.bright},bold'
      set -as terminal-features ',foot:RGB'
      set -g allow-passthrough on
    '';
  };

  programs.lazygit = {
    enable = true;
    settings.gui = {
      border = "rounded";
      nerdFontsVersion = "3";
      theme = {
        activeBorderColor = [ "#${c.accent}" "bold" ];
        inactiveBorderColor = [ "#${c.muted}" ];
        searchingActiveBorderColor = [ "#${c.yellow}" "bold" ];
        optionsTextColor = [ "#${c.violet}" ];
        selectedLineBgColor = [ "#${c.selection}" ];
        selectedRangeBgColor = [ "#${c.surface}" ];
        cherryPickedCommitBgColor = [ "#${c.violet}" ];
        cherryPickedCommitFgColor = [ "#${c.bright}" ];
        unstagedChangesColor = [ "#${c.orange}" ];
        defaultFgColor = [ "#${c.foreground}" ];
      };
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    plugins = [
      {
        plugin = pkgs.vimUtils.buildVimPlugin {
          pname = "biscuit-nvim";
          version = "unstable-2026-08-23";
          src = inputs.biscuit-nvim;
        };
        config = "colorscheme biscuit";
      }
    ];
    initLua = ''
      vim.opt.termguicolors = true
      vim.opt.number = true
      vim.opt.cursorline = true
      vim.opt.signcolumn = "yes"
    '';
  };

  xdg.configFile."gpu-screen-recorder/config_ui".text = ''
    main.wayland_warning_shown true
    main.hotkeys_enable_option disable_hotkeys
    replay.record_options.record_area_option ${replayConfig.captureSource}
    replay.record_options.fps ${toString replayConfig.fps}
    replay.record_options.video_bitrate ${toString replayConfig.videoBitrate}
    replay.record_options.video_quality custom
    replay.record_options.codec ${replayConfig.videoCodec}
    replay.record_options.audio_codec ${replayConfig.audioCodec}
    replay.record_options.framerate_mode cfr
    replay.record_options.advanced_view true
    replay.record_options.audio_track_item false [add_audio_track]
    replay.record_options.audio_track_item false default_output
    replay.record_options.audio_track_item false default_input
    replay.record_options.audio_track_item false [add_audio_track]
    replay.record_options.audio_track_item false default_output
    replay.record_options.audio_track_item false [add_audio_track]
    replay.record_options.audio_track_item false default_input
    replay.turn_on_replay_automatically_mode dont_turn_on_automatically
    replay.restart_replay_on_save false
    replay.save_directory /home/wojtek/Videos/Replays
    replay.container mp4
    replay.time ${toString replayConfig.seconds}
    replay.replay_storage ram
  '';

  xdg.configFile."screensaver/wojtech.txt".text = ''
     ▄█     █▄   ▄██████▄       ▄█       ███        ▄████████  ▄████████    ▄█    █▄
    ███     ███ ███    ███     ███   ▀█████████▄   ███    ███ ███    ███   ███    ███
    ███     ███ ███    ███     ███      ▀███▀▀██   ███    █▀  ███    █▀    ███    ███
    ███     ███ ███    ███     ███       ███   ▀  ▄███▄▄▄     ███         ▄███▄▄▄▄███▄▄
    ███     ███ ███    ███     ███       ███     ▀▀███▀▀▀     ███        ▀▀███▀▀▀▀███▀
    ███     ███ ███    ███     ███       ███       ███    █▄  ███    █▄    ███    ███
    ███ ▄█▄ ███ ███    ███     ███       ███       ███    ███ ███    ███   ███    ███
     ▀███▀███▀   ▀██████▀  █▄ ▄███      ▄████▀     ██████████ ████████▀    ███    █▀
                           ▀▀▀▀▀▀
  '';

  # wlogout 1.2.x expects consecutive JSON objects, not a JSON array.
  xdg.configFile."wlogout/layout".text = builtins.concatStringsSep "\n" (map builtins.toJSON [
    {
      label = "lock";
      action = "hyprlock";
      text = "Zablokuj";
      keybind = "l";
    }
    {
      label = "suspend";
      action = "systemctl suspend";
      text = "Uśpij";
      keybind = "u";
    }
    {
      label = "logout";
      action = "hyprctl dispatch exit";
      text = "Wyloguj";
      keybind = "e";
    }
    {
      label = "reboot";
      action = "systemctl reboot";
      text = "Uruchom ponownie";
      keybind = "r";
    }
    {
      label = "shutdown";
      action = "systemctl poweroff";
      text = "Wyłącz";
      keybind = "s";
    }
  ]) + "\n";

  xdg.configFile."wlogout/style.css".text = ''
    * {
      background-image: none;
      font-family: "${theme.fonts.interface}";
      font-size: 15px;
      font-weight: 600;
    }

    window {
      background: alpha(#${c.background}, 0.88);
    }

    button {
      color: #${c.foreground};
      background-color: alpha(#${c.surface}, 0.96);
      border: 1px solid alpha(#${c.muted}, 0.72);
      border-radius: 18px;
      margin: 12px;
      background-repeat: no-repeat;
      background-position: center;
      background-size: 72px;
      box-shadow: 0 8px 28px alpha(#${c.background}, 0.70);
      transition: 150ms ease-in-out;
    }

    button:hover,
    button:focus {
      color: #${c.bright};
      background-color: #${c.selection};
      border-color: #${c.accent};
      box-shadow: inset 0 -4px #${c.accent};
    }

    #lock {
      background-image: url("${pkgs.wlogout}/share/wlogout/icons/lock.png");
    }

    #suspend {
      background-image: url("${pkgs.wlogout}/share/wlogout/icons/suspend.png");
    }

    #logout {
      background-image: url("${pkgs.wlogout}/share/wlogout/icons/logout.png");
    }

    #reboot {
      background-image: url("${pkgs.wlogout}/share/wlogout/icons/reboot.png");
    }

    #shutdown {
      background-image: url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png");
    }
  '';

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
