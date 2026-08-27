{ backlightDevice, desktopFeatures, inputs, lib, pkgs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
  scripts = import ./scripts.nix { inherit pkgs; };
  laptopEnabled = desktopFeatures.laptop or false;
  screenRecordingEnabled = desktopFeatures.screenRecording or false;
  personalApps = desktopFeatures.personalApps or { };
  easyeffectsEnabled = personalApps.easyeffects or false;
  plexampEnabled = personalApps.plexamp or false;

  wallpaperPathsFor = wallpapers:
    lib.concatMapStringsSep "\n        "
      (wallpaper: lib.escapeShellArg (toString wallpaper))
      wallpapers;

  rotate-wallpaper = pkgs.writeShellApplication {
    name = "rotate-wallpaper";
    runtimeInputs = with pkgs; [
      awww
      coreutils
      hyprland
      jq
    ];
    text = ''
      wallpapers_16x9=(
        ${wallpaperPathsFor theme.wallpapers.aspect16x9}
      )
      wallpapers_21x9=(
        ${wallpaperPathsFor theme.wallpapers.aspect21x9}
      )
      wallpapers_32x9=(
        ${wallpaperPathsFor theme.wallpapers.aspect32x9}
      )
      transitions=(wave grow wipe outer wave grow outer wipe)
      positions=(right bottom-right top-left center left top-right bottom-left center)

      scene_count="''${#wallpapers_16x9[@]}"
      if (( scene_count == 0 )) \
        || (( ''${#wallpapers_21x9[@]} != scene_count )) \
        || (( ''${#wallpapers_32x9[@]} != scene_count )); then
        printf 'Wallpaper aspect lists must be non-empty and have equal lengths.\n' >&2
        exit 1
      fi

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-rotation"
      state_file="$state_dir/index"
      session_marker="''${XDG_RUNTIME_DIR:?}/wallpaper-rotation-initialized"
      mkdir -p "$state_dir"

      index=0
      if [[ -r "$state_file" ]]; then
        read -r previous_index < "$state_file" || previous_index=-1
        if [[ "$previous_index" =~ ^[0-9]+$ ]]; then
          index=$(((previous_index + 1) % scene_count))
        fi
      fi

      for _ in {1..30}; do
        awww query >/dev/null 2>&1 && break
        sleep 0.1
      done

      transition_type="''${transitions[index % ''${#transitions[@]}]}"
      transition_angle=$(((index * 137 + 23) % 360))
      transition_pos="''${positions[index % ''${#positions[@]}]}"
      transition_wave="$((14 + (index % 3) * 3)),$((24 + (index % 4) * 4))"

      # The daemon has no image at the beginning of a session. Grow the first
      # wallpaper from the center instead of flashing it in with a plain fade.
      if [[ ! -e "$session_marker" ]]; then
        transition_type=grow
        transition_pos=center
      fi

      monitor_rows="$(
        hyprctl monitors -j \
          | jq -r '
              .[]
              | select(.disabled != true)
              | [
                  .name,
                  ([.width, .height] | max),
                  ([.width, .height] | min),
                  ((.refreshRate // 60) | round)
                ]
              | @tsv
            '
      )"

      if [[ -z "$monitor_rows" ]]; then
        printf 'Hyprland did not report an active monitor.\n' >&2
        exit 1
      fi

      # Pick the nearest stored landscape family from the monitor's real
      # geometry. Ratios are scaled by 10000 to avoid a floating-point helper:
      # 16:9 = 1.7778, 3440:1440 = 2.3889, 32:9 = 3.5556.
      while IFS=$'\t' read -r output long_edge short_edge refresh_rate; do
        if (( short_edge <= 0 )); then
          printf 'Ignoring monitor %s with invalid geometry.\n' "$output" >&2
          continue
        fi

        ratio=$((long_edge * 10000 / short_edge))
        distance_16x9=$((ratio - 17778))
        distance_21x9=$((ratio - 23889))
        distance_32x9=$((ratio - 35556))
        if (( distance_16x9 < 0 )); then
          distance_16x9=$((-distance_16x9))
        fi
        if (( distance_21x9 < 0 )); then
          distance_21x9=$((-distance_21x9))
        fi
        if (( distance_32x9 < 0 )); then
          distance_32x9=$((-distance_32x9))
        fi

        if (( distance_32x9 <= distance_21x9 && distance_32x9 <= distance_16x9 )); then
          wallpaper="''${wallpapers_32x9[index]}"
        elif (( distance_21x9 <= distance_16x9 )); then
          wallpaper="''${wallpapers_21x9[index]}"
        else
          wallpaper="''${wallpapers_16x9[index]}"
        fi

        if [[ ! "$refresh_rate" =~ ^[0-9]+$ ]] \
          || (( refresh_rate < 30 || refresh_rate > 1000 )); then
          refresh_rate=60
        fi

        awww img "$wallpaper" \
          --outputs "$output" \
          --resize crop \
          --crop-gravity right \
          --transition-type "$transition_type" \
          --transition-angle "$transition_angle" \
          --transition-pos "$transition_pos" \
          --transition-bezier 0.16,1,0.3,1 \
          --transition-wave "$transition_wave" \
          --transition-duration 2.4 \
          --transition-fps "$refresh_rate"
      done <<< "$monitor_rows"

      touch "$session_marker"
      printf '%s\n' "$index" > "$state_file"
    '';
  };

  suspend-on-battery = pkgs.writeShellApplication {
    name = "suspend-on-battery";
    runtimeInputs = [
      pkgs.systemd
      scripts.power-source-state
    ];
    text = ''
      [[ "$(power-source-state)" == battery ]] || exit 0
      exec systemctl suspend
    '';
  };

in
{
  home.activation.removeAutogeneratedHyprlandStub =
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      legacy_config="$HOME/.config/hypr/hyprland.conf"

      if [[ -f "$legacy_config" && ! -L "$legacy_config" ]] \
        && ${pkgs.gnugrep}/bin/grep -q '^# This config is a STUB!' "$legacy_config"; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$legacy_config"
      fi
    '';

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    configType = "lua";
    systemd.enable = true;
    systemd.enableXdgAutostart = true;
    extraLuaFiles."config" = builtins.replaceStrings
      [
        "@POLKIT_AGENT@"
        "@ACTIVE_BORDER@"
        "@ACTIVE_BORDER_ALT@"
        "@INACTIVE_BORDER@"
        "@SHADOW@"
        "@BIND_PERSONAL_APPS@"
        "@BIND_SCREEN_RECORDING@"
        "@BIND_LAPTOP@"
      ]
      [
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        c.accent
        c.yellow
        c.muted
        c.background
        (lib.concatStrings [
          (lib.optionalString plexampEnabled ''
            bind_exec(mod .. " + M", "plexamp")
          '')
          (lib.optionalString easyeffectsEnabled ''
            bind_exec(mod .. " + SHIFT + A", "easyeffects")
          '')
        ])
        (lib.optionalString screenRecordingEnabled ''
          bind_exec("ALT + Z", "gsr-control toggle-show")
          bind_exec(mod .. " + G", "gsr-control toggle-show")
          bind_exec(mod .. " + R", "gsr-control replay-save")
          bind_exec(mod .. " + SHIFT + R", "gsr-control toggle-replay")
        '')
        (lib.optionalString laptopEnabled ''
          bind_exec("XF86MonBrightnessUp", "swayosd-client --brightness=+5 --device=${backlightDevice}", { locked = true, repeating = true })
          bind_exec("XF86MonBrightnessDown", "swayosd-client --brightness=-5 --device=${backlightDevice}", { locked = true, repeating = true })
        '')
      ]
      (builtins.readFile ./hyprland.lua);

    settings = {
      # The actual configuration is kept in hyprland.lua. Home Manager writes
      # and loads it from the generated hyprland.lua entry point.
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 2;
      };
      background = {
        monitor = "";
        color = "rgba(${c.background}ff)";
        blur_passes = 3;
        blur_size = 8;
      };
      input-field = {
        monitor = "";
        size = "300, 56";
        outline_thickness = 2;
        dots_size = 0.25;
        dots_spacing = 0.25;
        outer_color = "rgba(${c.accent}ff)";
        inner_color = "rgba(${c.surface}ee)";
        font_color = "rgba(${c.foreground}ff)";
        fade_on_empty = false;
        placeholder_text = "<i>Hasło…</i>";
        position = "0, -80";
        halign = "center";
        valign = "center";
      };
      label = {
        monitor = "";
        text = "cmd[update:1000] echo \"$(date +'%H:%M')\"";
        color = "rgba(${c.foreground}ff)";
        font_size = 72;
        font_family = "${theme.fonts.monospace} Bold";
        position = "0, 80";
        halign = "center";
        valign = "center";
      };
    };
  };

  services.awww.enable = true;

  home.packages = lib.optionals laptopEnabled [ scripts.display-power-refresh ];

  systemd.user.services.display-power-refresh = lib.mkIf laptopEnabled {
    Unit = {
      Description = "Switch the internal display refresh rate with power source";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${scripts.display-power-refresh}/bin/display-power-refresh watch";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.rotate-wallpaper = {
    Unit = {
      Description = "Rotate Biscuit wallpapers";
      After = [ "awww.service" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${rotate-wallpaper}/bin/rotate-wallpaper";
    };
  };

  systemd.user.timers.rotate-wallpaper = {
    Unit = {
      Description = "Rotate Biscuit wallpapers every five minutes";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Timer = {
      # Give Awww two seconds to expose its Wayland socket after login.
      OnActiveSec = "2s";
      # Rotate often enough to vary the OLED image without keeping a daemon busy.
      OnUnitActiveSec = "5min";
      AccuracySec = "1s";
      Unit = "rotate-wallpaper.service";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = lib.concatStringsSep "; " (
          [ "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'" ]
          ++ lib.optional laptopEnabled
            "${scripts.display-power-refresh}/bin/display-power-refresh apply"
        );
        ignore_dbus_inhibit = false;
        ignore_systemd_inhibit = false;
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "pidof hyprlock || screensaver";
        }
        {
          # Keep the animated saver visible for a full five minutes. Lock just
          # before DPMS powers the panel down so wake-up still requires auth.
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 601;
          # Lua-configured Hyprland 0.55+ expects a Lua dispatcher expression;
          # the old `dispatch dpms off` form is rejected as invalid syntax.
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
        }
        {
          timeout = 1800;
          on-timeout = "${suspend-on-battery}/bin/suspend-on-battery";
        }
      ];
    };
  };

}
