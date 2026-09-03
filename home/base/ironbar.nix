{ backlightDevice, config, desktopFeatures, inputs, lib, pkgs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
  s = theme.semantic;
  voxtypeEnabled = desktopFeatures.voxtype or false;
  # Ironbar 0.19 dispatches legacy workspace commands, which Hyprland's Lua
  # provider rejects. Keep the focused compatibility patch local until a
  # Nixpkgs update includes Ironbar's upstream fix (PR #1554).
  ironbar = pkgs.ironbar.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (builtins.toFile "ironbar-lua-workspace-click-minimal.patch" ''
        diff --git a/src/clients/compositor/hyprland.rs b/src/clients/compositor/hyprland.rs
        index e538e80de..b88778145 100644
        --- a/src/clients/compositor/hyprland.rs
        +++ b/src/clients/compositor/hyprland.rs
        @@ -9,5 +9,5 @@ use hyprland::ctl::switch_xkb_layout;
         use hyprland::data::{Devices, Workspace as HWorkspace, Workspaces};
        -use hyprland::dispatch::{Dispatch, DispatchType, WorkspaceIdentifierWithSpecial};
        +use hyprland::dispatch::{Dispatch, DispatchType};
         use hyprland::event_listener::EventListener;
         use hyprland::prelude::*;
         use hyprland::shared::{HyprDataVec, WorkspaceType};
        @@ -406,9 +406,9 @@ impl Client {
        ${" "}#[cfg(feature = "workspaces+hyprland")]
        ${" "}impl super::WorkspaceClient for Client {
             fn focus(&self, id: i64) {
        -        let identifier = WorkspaceIdentifierWithSpecial::Id(id as i32);
        +        let arguments = format!("{{workspace=\"{id}\"}}");
        ${" "}
        -        if let Err(e) = Dispatch::call(DispatchType::Workspace(identifier)) {
        +        if let Err(e) = Dispatch::call(DispatchType::Custom("hl.dsp.focus", &arguments)) {
                     error!("Couldn't focus workspace '{id}': {e:#}");
                 }
             }
      '')
      /* Historical malformed patch retained only until this repair is
         committed; it is deliberately excluded from the patches list.
      (builtins.toFile "ironbar-lua-workspace-click.patch" ''
        diff --git a/Cargo.toml b/Cargo.toml
        index 4bba58231..f483a2802 100644
        --- a/Cargo.toml
        +++ b/Cargo.toml
        @@ -117,7 +117,7 @@ volume = ["libpulse-binding"]
         workspaces = ["futures-lite"]
         "workspaces+all" = ["workspaces", "workspaces+sway", "workspaces+hyprland", "workspaces+niri"]
         "workspaces+sway" = ["workspaces", "sway"]
        -"workspaces+hyprland" = ["workspaces", "hyprland"]
        +"workspaces+hyprland" = ["workspaces", "hyprland", "dep:serde_json"]
         "workspaces+niri" = ["workspaces", "niri"]
        ${" "}
         sway = ["swayipc-async", "futures-lite"]
        diff --git a/src/clients/compositor/hyprland.rs b/src/clients/compositor/hyprland.rs
        index e538e80de..061f7961e 100644
        --- a/src/clients/compositor/hyprland.rs
        +++ b/src/clients/compositor/hyprland.rs
        @@ -12,6 +12,12 @@ use hyprland::dispatch::{Dispatch, DispatchType, WorkspaceIdentifierWithSpecial}
         use hyprland::event_listener::EventListener;
         use hyprland::prelude::*;
         use hyprland::shared::{HyprDataVec, WorkspaceType};
        +#[cfg(feature = "workspaces+hyprland")]
        +use serde::Deserialize;
        +#[cfg(feature = "workspaces+hyprland")]
        +use std::io::{Read, Write};
        +#[cfg(feature = "workspaces+hyprland")]
        +use std::os::unix::net::UnixStream;
         use tokio::sync::broadcast::{Receiver, Sender, channel};
         use tracing::{debug, error, info, warn};
        ${" "}
        @@ -35,6 +41,9 @@ pub struct Client {
             #[cfg(feature = "workspaces+hyprland")]
             workspace: TxRx<WorkspaceUpdate>,
        ${" "}
        +    #[cfg(feature = "workspaces+hyprland")]
        +    use_lua_dispatch: bool,
        +
             #[cfg(feature = "keyboard+hyprland")]
             keyboard_layout: TxRx<KeyboardLayoutUpdate>,
        ${" "}
        @@ -47,6 +56,8 @@ impl Client {
             let instance = Self {
                 #[cfg(feature = "workspaces+hyprland")]
                 workspace: TxRx::new(),
        +        #[cfg(feature = "workspaces+hyprland")]
        +        use_lua_dispatch: detect_lua_config(),
                 #[cfg(feature = "keyboard+hyprland")]
                 keyboard_layout: TxRx::new(),
                 #[cfg(feature = "bindmode+hyprland")]
        @@ -406,9 +417,15 @@ impl Client {
        #[cfg(feature = "workspaces+hyprland")]
        impl super::WorkspaceClient for Client {
             fn focus(&self, id: i64) {
        -        let identifier = WorkspaceIdentifierWithSpecial::Id(id as i32);
        +        let res = if self.use_lua_dispatch {
        +            let arg = format!("{{workspace=\"{id}\"}}");
        +            Dispatch::call(DispatchType::Custom("hl.dsp.focus", &arg))
        +        } else {
        +            let identifier = WorkspaceIdentifierWithSpecial::Id(id as i32);
        +            Dispatch::call(DispatchType::Workspace(identifier))
        +        };
        ${" "}
        -        if let Err(e) = Dispatch::call(DispatchType::Workspace(identifier)) {
        +        if let Err(e) = res {
                     error!("Couldn't focus workspace '{id}': {e:#}");
                 }
             }
        @@ -497,6 +514,40 @@ impl BindModeClient for Client {
            }
        }
        ${" "}
        +#[cfg(feature = "workspaces+hyprland")]
        +fn detect_lua_config() -> bool {
        +    match get_hyprland_config_provider() {
        +        Ok(provider) => provider == "lua",
        +        Err(err) => {
        +            warn!("Failed to detect Hyprland config provider, assuming legacy: {err}");
        +            false
        +        }
        +    }
        +}
        +
        +#[cfg(feature = "workspaces+hyprland")]
        +#[derive(Deserialize)]
        +struct HyprlandStatus {
        +    #[serde(rename = "configProvider")]
        +    config_provider: String,
        +}
        +
        +#[cfg(feature = "workspaces+hyprland")]
        +fn get_hyprland_config_provider() -> std::result::Result<String, Box<dyn std::error::Error>> {
        +    let runtime_dir = std::env::var("XDG_RUNTIME_DIR")
        +        .or_else(|_| std::env::var("UID").map(|uid| format!("/run/user/{uid}")))?;
        +    let instance = std::env::var("HYPRLAND_INSTANCE_SIGNATURE")?;
        +    let socket_path = format!("{runtime_dir}/hypr/{instance}/.socket.sock");
        +
        +    let mut stream = UnixStream::connect(socket_path)?;
        +    stream.write_all(b"j/status")?;
        +
        +    let mut response = String::new();
        +    stream.read_to_string(&mut response)?;
        +
        +    Ok(serde_json::from_str::<HyprlandStatus>(&response)?.config_provider)
        +}
        +
         fn get_workspace_name(name: WorkspaceType) -> String {
             match name {
                 WorkspaceType::Regular(name) => name,
      '') */
    ];
  });
  ironbarMetric = import ./ironbar-metric.nix { inherit inputs pkgs; };
  metricPopupRefresh = pkgs.writeShellApplication {
    name = "ironbar-metric-popup-refresh";
    runtimeInputs = [
      pkgs.coreutils
      ironbar
      pkgs.util-linux
      ironbarMetric
    ];
    text = ''
      state_file="''${XDG_RUNTIME_DIR:?}/ironbar-metric-popup.state"
      lock_file="''${XDG_RUNTIME_DIR:?}/ironbar-metric-popup.lock"
      exec 9>"$lock_file"

      while true; do
        # Popup values should feel live without keeping a collector running
        # after hover ends or spawning helpers at the Cairo redraw rate.
        sleep 2

        token=""
        component=""
        [[ -r "$state_file" ]] \
          && read -r token component < "$state_file" \
          || exit 0
        case "$component" in
          cpu|memory|network|disk|gpu) ;;
          *) exit 0 ;;
        esac

        if ! tooltip="$(ironbar-metric "$component" tooltip)"; then
          continue
        fi

        # Serialize the final state check with hover enter/exit. A collector
        # from an older popup must never overwrite a newly selected metric.
        flock 9
        current_token=""
        current_component=""
        [[ -r "$state_file" ]] \
          && read -r current_token current_component < "$state_file" \
          || true
        if [[ "$current_token" != "$token" \
          || "$current_component" != "$component" ]]; then
          flock -u 9
          exit 0
        fi
        ironbar var set "metric_''${component}_tooltip" "$tooltip"
        flock -u 9
      done
    '';
  };
  metricPopupControl = pkgs.writeShellApplication {
    name = "ironbar-metric-popup";
    runtimeInputs = [
      pkgs.coreutils
      ironbar
      pkgs.systemd
      pkgs.util-linux
      ironbarMetric
    ];
    text = ''
      action="''${1:-}"
      component="''${2:-}"
      guard_file="''${XDG_RUNTIME_DIR:?}/ironbar-metric-popup.guard"
      state_file="''${XDG_RUNTIME_DIR:?}/ironbar-metric-popup.state"
      lock_file="''${XDG_RUNTIME_DIR:?}/ironbar-metric-popup.lock"
      refresh_service="ironbar-metric-popup-refresh.service"
      exec 9>"$lock_file"

      hold_popup() {
        printf 'hold-%s-%s\n' "$$" "$(date +%s%N)" > "$guard_file"
      }

      case "$action" in
        show)
          case "$component" in
            cpu|memory|network|disk|gpu) ;;
            *) exit 2 ;;
          esac
          # Invalidate a pending close before collecting tooltip data. This
          # prevents an older mouse-exit event from hiding the new popup.
          flock 9
          hold_popup
          active_token="show-$$-$(date +%s%N)"
          printf '%s %s\n' "$active_token" "$component" > "$state_file"
          ironbar var set "metric_''${component}_tooltip" \
            "$(ironbar-metric "$component" tooltip)"
          ironbar bar main show-popup "metric-$component"
          systemctl --user restart --no-block "$refresh_service"
          flock -u 9
          ;;
        hold)
          # Entering the popup cancels the close scheduled while crossing the
          # six-pixel gap between the bar and the popup surface.
          flock 9
          hold_popup
          flock -u 9
          ;;
        close)
          token="close-$$-$(date +%s%N)"
          flock 9
          printf '%s\n' "$token" > "$guard_file"
          flock -u 9
          # A short grace period lets the cursor cross the popup gap without
          # making the panel feel sticky after a real mouse exit.
          sleep 0.18
          flock 9
          current=""
          [[ -r "$guard_file" ]] && read -r current < "$guard_file" || true
          if [[ "$current" == "$token" ]]; then
            printf 'closed\n' > "$state_file"
            systemctl --user stop --no-block "$refresh_service"
            ironbar bar main hide-popup
          fi
          flock -u 9
          ;;
        *)
          exit 2
          ;;
      esac
    '';
  };
  amdGpuEnabled = desktopFeatures.amdGpu or false;
  dockerEnabled = desktopFeatures.docker or false;
  laptopEnabled = desktopFeatures.laptop or false;
  bluetoothEnabled = desktopFeatures.bluetooth or false;
  homeDirectory = config.home.homeDirectory;
  username = config.home.username;

  metric = {
    component,
    icon,
    interval,
    last ? false,
    width,
  }: {
    type = "custom";
    name = "metric-${component}";
    class = "island metric metric-${component}${lib.optionalString last " metric-last"}";
    disable_popup = true;
    bar = [
      {
        type = "button";
        class = "metric-button";
        on_click = "!desktop-panel metrics";
        # The stable button and popup share a cancellable close guard so the
        # cursor can cross the gap without closing the details underneath it.
        on_mouse_enter = "${metricPopupControl}/bin/ironbar-metric-popup show ${component}";
        on_mouse_exit = "${metricPopupControl}/bin/ironbar-metric-popup close";
        widgets = [
          {
            type = "label";
            class = "metric-icon";
            label = icon;
          }
          {
            type = "cairo";
            path = "${homeDirectory}/.config/ironbar/${component}.lua";
            frequency = interval;
            inherit width;
            height = 23;
          }
        ];
      }
    ];
    popup = [
      {
        type = "label";
        class = "metric-tooltip metric-tooltip-${component}";
        label = "#metric_${component}_tooltip";
        justify = "left";
        on_mouse_enter = "${metricPopupControl}/bin/ironbar-metric-popup hold";
        on_mouse_exit = "${metricPopupControl}/bin/ironbar-metric-popup close";
      }
    ];
  };

  ironbarConfig = {
    name = "main";
    position = "top";
    anchor_to_edges = true;
    height = 30;
    layer = "top";
    ironvar_defaults = {
      metric_cpu_tooltip = "";
      metric_memory_tooltip = "";
      metric_network_tooltip = "";
      metric_disk_tooltip = "";
      metric_gpu_tooltip = "";
      docker_tooltip = "";
    };
    popup_gap = 6;
    # GTK autohide grabs pointer focus and creates a show/close loop for popups
    # opened from hover. Metrics close themselves after a real mouse exit;
    # click-opened native popups close when toggled or replaced by another one.
    popup_autohide = false;
    margin = {
      top = 4;
      bottom = 0;
      left = 6;
      right = 6;
    };

    start = [
      {
        type = "label";
        name = "global-menu";
        class = "island global-menu";
        label = "󰌌";
        tooltip = "Menu pulpitu\nAplikacje, narzędzia, screenshoty i zasilanie\nSuper+D";
        on_click_left = "global-menu";
      }
      {
        type = "workspaces";
        name = "workspace-island";
        class = "island";
        all_monitors = true;
        sort = "index";
        format = "{label}";
      }
      (metric {
        component = "cpu";
        icon = "";
        interval = 2000;
        width = 33;
      })
      (metric {
        component = "memory";
        icon = "";
        interval = 3000;
        # RAM usage, logical ZRAM fill and real compression savings. Reading
        # procfs/sysfs every three seconds is cheap and starts no helper daemon.
        width = 51;
      })
      (metric {
        component = "network";
        icon = "󰛳";
        interval = 2000;
        width = 33;
      })
      (metric {
        component = "disk";
        icon = "󰋊";
        interval = 15000;
        last = !amdGpuEnabled;
        width = 51;
      })
    ] ++ lib.optionals amdGpuEnabled [
      (metric {
        component = "gpu";
        icon = "󰢮";
        # The Cairo widget checks runtime_status on every redraw, but samples
        # the hardware only every 7 seconds while it is active. This leaves a
        # full window for the driver's 5-second runtime autosuspend.
        interval = 2000;
        width = 51;
      })
    ] ++ lib.optionals dockerEnabled [
      {
        type = "script";
        name = "docker";
        class = "island docker";
        cmd = "docker-status label";
        mode = "poll";
        # Docker is started manually, so a one-minute label refresh is enough.
        # Container stats are more expensive and are fetched only on hover.
        interval = 60000;
        tooltip = "#docker_tooltip";
        on_mouse_enter = ''
          ${ironbar}/bin/ironbar var set docker_tooltip "$(docker-status tooltip)"
        '';
        on_click_left = "desktop-panel docker";
      }
    ];

    center = [
      {
        type = "clock";
        name = "clock";
        class = "island center-item center-first";
        # Pango targets the time directly; styling only the outer GTK button is
        # overridden by the clock's internal label in Ironbar 0.19.
        format = ''<span foreground="#${c.subtle}" size="x-large" weight="bold">󰥔</span>  <span foreground="#${c.bright}" font_family="${theme.fonts.monospace}" size="large" weight="heavy">%H:%M</span>'';
        format_popup = "󰃭  %A, %d %B %Y";
        locale = "pl_PL";
        show_week_numbers = false;
      }
    ] ++ lib.optionals voxtypeEnabled [
      {
        type = "script";
        name = "voxtype";
        class = "island center-item voxtype";
        # This is Voxtype's official Waybar JSON stream. Ironbar's watch mode
        # keeps one inotify-backed process instead of polling status on a timer.
        cmd = ''
          voxtype status --follow --format json \
            | ${pkgs.jq}/bin/jq --unbuffered --raw-output '
              if .class == "recording" then
                "<span foreground=\"#${c.accent}\">" + .text + "</span>"
              elif .class == "transcribing" then
                "<span foreground=\"#${c.violet}\">" + .text + "</span>"
              elif .class == "stopped" then
                "<span foreground=\"#${c.muted}\">" + .text + "</span>"
              else
                "<span foreground=\"#${c.subtle}\">" + .text + "</span>"
              end
            '
        '';
        mode = "watch";
        tooltip = "Voxtype\nKliknij, aby rozpocząć lub zakończyć dyktowanie";
        on_click_left = "voxtype record toggle";
      }
    ] ++ [
      {
        type = "label";
        name = "screenshot";
        class = "island center-item center-last";
        label = "󰄀";
        tooltip = "Screenshot\nLewy klik: wybierz okno\nLewy przeciągnij: wybierz obszar\nPrawy: cały ekran\nŚrodkowy: przełącz edycję Satty\nDomyślnie: zapisz PNG i skopiuj do schowka";
        on_click_left = "screenshot-menu select";
        on_click_right = "screenshot-menu full";
        on_click_middle = "screenshot-menu toggle-edit";
      }
    ];

    end = [
      {
        type = "volume";
        name = "volume";
        class = "island status status-first";
        format = "{icon} {percentage}%";
        mute_format = "󰖁 mute";
        max_volume = 100;
        show_sinks = true;
        show_sources = false;
        disable_popup = true;
        on_click_left = "desktop-panel audio";
        on_click_right = "swayosd-client --output-volume=mute-toggle --max-volume=100";
        on_scroll_up = "swayosd-client --output-volume=+5 --max-volume=100";
        on_scroll_down = "swayosd-client --output-volume=-5 --max-volume=100";
        icons = {
          volume = "󰕾";
          muted = "󰖁";
        };
        profiles = {
          low = {
            when = 33.33;
            icons.volume = "󰕿";
          };
          medium = {
            when = 66.66;
            icons.volume = "󰖀";
          };
        };
      }
      {
        type = "network_manager";
        name = "network";
        class = "island status network${lib.optionalString (!laptopEnabled && !bluetoothEnabled) " status-last"}";
        icon_size = 19;
        justify = "center";
        types_whitelist = [ "wifi" "ethernet" ];
        interface_blacklist = [ "lo" ];
        use_default_profiles = false;
        profiles = {
          wired_disconnected = {
            when = {
              type = "wired";
              state = "disconnected";
            };
            icon = "󰈂";
          };
          wired_acquiring = {
            when = {
              type = "wired";
              state = "acquiring";
            };
            icon = "󰈁";
          };
          wired_connected = {
            when = {
              type = "wired";
              state = "connected";
            };
            icon = "󰈀";
          };
          wifi_disconnected = {
            when = {
              type = "wifi";
              state = "disconnected";
            };
            icon = "󰤭";
          };
          wifi_acquiring = {
            when = {
              type = "wifi";
              state = "acquiring";
            };
            icon = "󰤫";
          };
          wifi_connected_none = {
            when = {
              type = "wifi";
              state = "connected";
              signal_strength = 20;
            };
            icon = "";
          };
          wifi_connected_weak = {
            when = {
              type = "wifi";
              state = "connected";
              signal_strength = 40;
            };
            icon = "";
          };
          wifi_connected_ok = {
            when = {
              type = "wifi";
              state = "connected";
              signal_strength = 50;
            };
            icon = "";
          };
          wifi_connected_good = {
            when = {
              type = "wifi";
              state = "connected";
              signal_strength = 80;
            };
            icon = "";
          };
          wifi_connected_excellent = {
            when = {
              type = "wifi";
              state = "connected";
              signal_strength = 100;
            };
            icon = "";
          };
        };
        tooltip = "Sieć\nKliknij, aby otworzyć panel TUI";
        on_click_left = "desktop-panel wifi";
      }
    ] ++ lib.optionals bluetoothEnabled [
      {
        type = "bluetooth";
        name = "bluetooth";
        class = "island status${lib.optionalString (!laptopEnabled) " status-last"}";
        icon_size = 19;
        disable_popup = true;
        tooltip = "Bluetooth\nKliknij, aby otworzyć panel TUI";
        on_click_left = "desktop-panel bluetooth";
        format = {
          not_found = "";
          disabled = "󰂲";
          enabled = "";
          connected = "";
          connected_battery = "";
        };
      }
    ] ++ lib.optionals laptopEnabled [
      {
        type = "brightness";
        name = "brightness";
        class = "island status brightness";
        icon_label = "󰖨";
        justify = "center";
        format = "{percentage}%";
        smooth_scroll_speed = 0.5;
        mode = {
          type = "systemd";
          subsystem = "backlight";
          name = backlightDevice;
        };
        tooltip = "Jasność ekranu\nScroll: zmień o 5%";
      }
      {
        type = "battery";
        name = "battery";
        class = "island status status-last";
        icon_size = 18;
        justify = "center";
        format = "{percentage}%";
        profiles = {
          warning = {
            percent = 30;
          };
          critical = {
            when = {
              percent = 15;
              charging = false;
            };
            format = "{percentage}%";
          };
        };
      }
    ] ++ [
      {
        type = "tray";
        name = "tray";
        icon_size = 17;
        prefer_theme_icons = true;
      }
      {
        type = "inhibit";
        name = "caffeine";
        class = "island caffeine";
        durations = [ "inf" ];
        default_duration = "inf";
        on_click_left = "toggle";
        on_click_right = "toggle";
        format_on = "<span foreground=\"#${c.orange}\">󰅶</span>";
        format_off = "<span foreground=\"#${c.subtle}\">󰾪</span>";
        tooltip = "Caffeine\nKliknij, aby zablokować wygaszanie i automatyczne usypianie";
      }
      {
        type = "notifications";
        name = "notifications";
        class = "island";
        show_count = true;
        on_click_right = "swaync-client -d -sw";
        icons = {
          closed_none = "";
          # Two en-spaces reserve exactly one 18 px badge beside the bell. CSS
          # centres the resulting bell/badge pair as a single 36 px group.
          closed_some = "  ";
          closed_dnd = "󰂛";
          open_none = "󰍡";
          open_some = "󰍡  ";
          open_dnd = "󰂛";
        };
      }
    ];
  };

  metricLua = ''
    local cairo = require("lgi").cairo
    local metrics = {}

    local palette = {
      track = "${c.muted}",
      cpu = { "${c.violet}", "${c.yellow}" },
      memory = { "${c.accent}", "${c.blue}", "${c.green}" },
      network = { "${c.green}", "${c.violet}" },
      disk = { "${c.orange}", "${c.green}", "${c.violet}" },
      gpu = { "${c.blue}", "${c.magenta}", "${c.yellow}" },
    }

    local symbols = {
      cpu = { "󰓅", "" },
      -- Nerd Font archive and compression glyphs keep ZRAM consistent with
      -- the icon-only visual language used by every other metric.
      memory = { "󰓅", "", "" },
      network = { "", "" },
      disk = { "󰓅", "", "" },
      gpu = { "󰓅", "", "" },
    }

    local function rgb(hex)
      return tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
    end

    local function read_line(path)
      local file = io.open(path, "r")
      if not file then return nil end
      local value = file:read("*l")
      file:close()
      return value
    end

    local function read_number(path)
      return tonumber(read_line(path) or "") or 0
    end

    local function shell_paths(pattern)
      local paths = {}
      local command = "for path in " .. pattern
        .. "; do [ -r \"$path\" ] && printf '%s\\n' \"$path\"; done"
      local process = io.popen(command, "r")
      if not process then return paths end
      for path in process:lines() do table.insert(paths, path) end
      process:close()
      return paths
    end

    local function clamp(value)
      value = tonumber(value) or 0
      if value < 0 then return 0 end
      if value > 100 then return 100 end
      return value
    end

    local function maximum_temperature(paths)
      local maximum = 0
      for _, path in ipairs(paths) do
        local value = read_number(path) / 1000
        if value > maximum then maximum = value end
      end
      return maximum
    end

    -- Thermal bars start at the 40°C idle baseline and fill completely at
    -- 100°C, keeping low idle readings visually quiet without changing alarms.
    local function temperature_percentage(temperature)
      local idle_baseline = 40
      local full_scale = 100
      return clamp((temperature - idle_baseline) * 100 / (full_scale - idle_baseline))
    end

    -- 85°C changes the thermal indicator from yellow to red, ahead of the
    -- separate 90°C critical status threshold used by metric popups.
    local thermal_alert_percentage = temperature_percentage(85)

    local cpu_temperature_paths = {}
    for _, name_path in ipairs(shell_paths("/sys/class/hwmon/hwmon*/name")) do
      local name = read_line(name_path)
      if name == "k10temp" or name == "zenpower" then
        local directory = name_path:match("^(.*)/name$")
        for _, path in ipairs(shell_paths(directory .. "/temp*_input")) do
          table.insert(cpu_temperature_paths, path)
        end
      end
    end

    local gpu_path = nil
    local gpu_vram_total = 0
    for _, total_path in ipairs(shell_paths("/sys/class/drm/card[0-9]*/device/mem_info_vram_total")) do
      local device = total_path:match("^(.*)/mem_info_vram_total$")
      if read_line(device .. "/vendor") == "0x1002" then
        local total = read_number(total_path)
        if total > gpu_vram_total then
          gpu_path = device
          gpu_vram_total = total
        end
      end
    end

    local gpu_temperature_paths = {}
    if gpu_path then
      gpu_temperature_paths = shell_paths(gpu_path .. "/hwmon/hwmon*/temp*_input")
    end

    local function cpu_counters()
      local line = read_line("/proc/stat") or ""
      local values = {}
      for value in line:gmatch("%d+") do table.insert(values, tonumber(value)) end
      local total = 0
      for index = 1, math.min(#values, 8) do total = total + values[index] end
      local idle = (values[4] or 0) + (values[5] or 0)
      return total, idle
    end

    local function memory_percent()
      local file = io.open("/proc/meminfo", "r")
      if not file then return 0 end
      local total, available = 0, 0
      for line in file:lines() do
        local key, value = line:match("^(%w+):%s+(%d+)")
        if key == "MemTotal" then total = tonumber(value) or 0 end
        if key == "MemAvailable" then available = tonumber(value) or 0 end
      end
      file:close()
      if total == 0 then return 0 end
      return (total - available) * 100 / total
    end

    local zram_disksize_paths = shell_paths("/sys/block/zram*/disksize")

    local function zram_percentages()
      local logical_total, logical_used, physical_used = 0, 0, 0
      for _, disksize_path in ipairs(zram_disksize_paths) do
        local directory = disksize_path:match("^(.*)/disksize$")
        local disksize = read_number(disksize_path)
        local mm_stat = directory and read_line(directory .. "/mm_stat") or nil
        if disksize > 0 and mm_stat then
          local original, _, physical = mm_stat:match("^(%d+)%s+(%d+)%s+(%d+)")
          logical_total = logical_total + disksize
          logical_used = logical_used + (tonumber(original) or 0)
          physical_used = physical_used + (tonumber(physical) or 0)
        end
      end

      if logical_total == 0 then return nil, nil end
      local usage = logical_used * 100 / logical_total
      local savings = 0
      if logical_used > 0 then
        savings = math.max(0, (logical_used - physical_used) * 100 / logical_used)
      end
      return clamp(usage), clamp(savings)
    end

    local function default_interface()
      local file = io.open("/proc/net/route", "r")
      if not file then return nil end
      for line in file:lines() do
        local interface, destination = line:match("^(%S+)%s+(%S+)")
        if destination == "00000000" then
          file:close()
          return interface
        end
      end
      file:close()
      return nil
    end

    local function disk_bytes()
      local file = io.open("/proc/diskstats", "r")
      if not file then return 0, 0 end
      local read_sectors, written_sectors = 0, 0
      for line in file:lines() do
        local fields = {}
        for value in line:gmatch("%S+") do table.insert(fields, value) end
        local name = fields[3] or ""
        if name:match("^sd[a-z]+$") or name:match("^vd[a-z]+$")
          or name:match("^xvd[a-z]+$") or name:match("^nvme%d+n%d+$")
          or name:match("^mmcblk%d+$") then
          read_sectors = read_sectors + (tonumber(fields[6]) or 0)
          written_sectors = written_sectors + (tonumber(fields[10]) or 0)
        end
      end
      file:close()
      return read_sectors * 512, written_sectors * 512
    end

    local function root_disk_percent()
      local process = io.popen("df -Pk / 2>/dev/null", "r")
      if not process then return 0 end
      local last = nil
      for line in process:lines() do last = line end
      process:close()
      return tonumber((last or ""):match("(%d+)%%%s+/%s*$")) or 0
    end

    local function rounded_rectangle(cr, x, y, width, height, radius)
      radius = math.min(radius, width / 2, height / 2)
      cr:new_sub_path()
      cr:arc(x + width - radius, y + radius, radius, -math.pi / 2, 0)
      cr:arc(x + width - radius, y + height - radius, radius, 0, math.pi / 2)
      cr:arc(x + radius, y + height - radius, radius, math.pi / 2, math.pi)
      cr:arc(x + radius, y + radius, radius, math.pi, math.pi * 1.5)
      cr:close_path()
    end

    function metrics.new(component)
      local state = {
        cpu_total = nil,
        cpu_idle = nil,
        interface = nil,
        rx = nil,
        tx = nil,
        disk_read = nil,
        disk_write = nil,
        time = nil,
        scale = nil,
        scale_time = nil,
        scale_hold_until = 0,
        scale_last_write = nil,
        gpu_values = nil,
        gpu_next_probe = 0,
      }

      local function adaptive_ceiling(rate, floor, maximum, now)
        local previous = state.scale or floor
        local elapsed = state.scale_time and math.max(now - state.scale_time, 0) or 0
        local ceiling = previous

        if rate >= ceiling * 0.80 then
          -- Leave 25% headroom after a sudden transfer spike.
          ceiling = math.min(maximum, math.max(ceiling, rate / 0.75))
          state.scale_hold_until = now + 30
        elseif now > state.scale_hold_until and elapsed > 0 then
          -- After the hold, decay smoothly with a 60-second half-life.
          local decayed = ceiling * math.pow(0.5, elapsed / 60)
          local live_target = rate > 0 and rate / 0.80 or floor
          ceiling = math.max(floor, live_target, decayed)
        end

        state.scale = ceiling
        state.scale_time = now

        local runtime_directory = os.getenv("XDG_RUNTIME_DIR")
        local should_write = not state.scale_last_write
          or now - state.scale_last_write >= 10
          or ceiling > previous
        if runtime_directory and should_write then
          local file = io.open(
            runtime_directory .. "/ironbar-" .. component .. "-scale",
            "w"
          )
          if file then
            file:write(string.format("%.0f\n", ceiling))
            file:close()
            state.scale_last_write = now
          end
        end

        return ceiling
      end

      local function values()
        local now = ironbar:unixtime().secs

        if component == "cpu" then
          local total, idle = cpu_counters()
          local usage = 0
          if state.cpu_total and total > state.cpu_total then
            local delta = total - state.cpu_total
            usage = (delta - (idle - state.cpu_idle)) * 100 / delta
          end
          state.cpu_total, state.cpu_idle = total, idle
          return {
            clamp(usage),
            temperature_percentage(maximum_temperature(cpu_temperature_paths)),
          }
        end

        if component == "memory" then
          local ram = clamp(memory_percent())
          local zram_usage, zram_savings = zram_percentages()
          if zram_usage then return { ram, zram_usage, zram_savings } end
          return { ram }
        end

        if component == "network" then
          local interface = default_interface()
          if not interface then
            adaptive_ceiling(0, 10 * 1024 * 1024, 1024 * 1024 * 1024, now)
            return { 0, 0 }
          end
          local rx = read_number("/sys/class/net/" .. interface .. "/statistics/rx_bytes")
          local tx = read_number("/sys/class/net/" .. interface .. "/statistics/tx_bytes")
          local elapsed = state.time and math.max(now - state.time, 0.001) or 1
          if state.interface ~= interface then state.rx, state.tx = rx, tx end
          local down = state.rx and math.max((rx - state.rx) / elapsed, 0) or 0
          local up = state.tx and math.max((tx - state.tx) / elapsed, 0) or 0
          state.interface, state.rx, state.tx, state.time = interface, rx, tx, now
          local ceiling = adaptive_ceiling(
            math.max(down, up),
            10 * 1024 * 1024,
            1024 * 1024 * 1024,
            now
          )
          return {
            clamp(down / ceiling * 100),
            clamp(up / ceiling * 100),
          }
        end

        if component == "disk" then
          local read_bytes, write_bytes = disk_bytes()
          local elapsed = state.time and math.max(now - state.time, 0.001) or 1
          local read_rate = state.disk_read and math.max((read_bytes - state.disk_read) / elapsed, 0) or 0
          local write_rate = state.disk_write and math.max((write_bytes - state.disk_write) / elapsed, 0) or 0
          state.disk_read, state.disk_write, state.time = read_bytes, write_bytes, now
          local ceiling = adaptive_ceiling(
            math.max(read_rate, write_rate),
            100 * 1024 * 1024,
            8 * 1024 * 1024 * 1024,
            now
          )
          return {
            clamp(root_disk_percent()),
            clamp(read_rate / ceiling * 100),
            clamp(write_rate / ceiling * 100),
          }
        end

        if component == "gpu" and gpu_path then
          local runtime_status = read_line(gpu_path .. "/power/runtime_status")
          if runtime_status and runtime_status ~= "active" then
            state.gpu_values = nil
            state.gpu_next_probe = 0
            return {}, true
          end

          if not state.gpu_values or now >= state.gpu_next_probe then
            local usage = read_number(gpu_path .. "/gpu_busy_percent")
            local used = read_number(gpu_path .. "/mem_info_vram_used")
            local vram = gpu_vram_total > 0 and used * 100 / gpu_vram_total or 0
            local temperature = maximum_temperature(gpu_temperature_paths)
            state.gpu_values = {
              clamp(usage),
              clamp(vram),
              temperature_percentage(temperature),
            }
            state.gpu_next_probe = now + 7
          end

          return state.gpu_values, false
        end

        return { 0 }
      end

      return function(cr, width, height)
        local current, gpu_suspended = values()
        local colors = palette[component] or { "${c.foreground}" }
        local bar_width = 15
        local gap = 3
        local bar_inset = 3
        local bar_height = math.max(height - 2 * bar_inset, 1)
        local track_r, track_g, track_b = rgb(palette.track)
        local base_r, base_g, base_b = rgb("${c.background}")
        local bright_r, bright_g, bright_b = rgb("${c.bright}")
        local outline = {
          { -0.65, 0 },
          { 0.65, 0 },
          { 0, -0.65 },
          { 0, 0.65 },
        }

        if component == "gpu" and gpu_suspended then
          local sleep_r, sleep_g, sleep_b = rgb("${c.subtle}")
          rounded_rectangle(cr, 1, bar_inset, width - 2, bar_height, 4)
          cr:set_source_rgba(track_r, track_g, track_b, 0.12)
          cr:fill()

          local sleep_symbol = "Zz"
          cr:select_font_face(
            "${theme.fonts.monospace}",
            cairo.FontSlant.NORMAL,
            cairo.FontWeight.BOLD
          )
          cr:set_font_size(12)
          local sleep_extents = cr:text_extents(sleep_symbol)
          cr:move_to(
            (width - sleep_extents.width) / 2 - sleep_extents.x_bearing,
            (height - sleep_extents.height) / 2 - sleep_extents.y_bearing
          )
          cr:set_source_rgba(sleep_r, sleep_g, sleep_b, 0.88)
          cr:show_text(sleep_symbol)
          return
        end

        for index, value in ipairs(current) do
          local displayed_value = math.floor(clamp(value))
          local x = (index - 1) * (bar_width + gap)
          rounded_rectangle(cr, x, bar_inset, bar_width, bar_height, 3)
          cr:set_source_rgba(track_r, track_g, track_b, 0.22)
          cr:fill()

          local fill = bar_height * displayed_value / 100
          if fill > 0 then
            fill = math.max(fill, 2)
            local color = colors[index] or colors[#colors]
            local is_thermal_indicator = (component == "cpu" and index == 2)
              or (component == "gpu" and index == 3)
            if is_thermal_indicator and value >= thermal_alert_percentage then
              color = "${c.red}"
            end
            local red, green, blue = rgb(color)
            rounded_rectangle(
              cr,
              x,
              bar_inset + bar_height - fill,
              bar_width,
              fill,
              3
            )
            cr:set_source_rgba(red, green, blue, 0.96)
            cr:fill()
          end

          local symbol = (symbols[component] or {})[index] or "•"
          cr:select_font_face(
            "${theme.fonts.interface}",
            cairo.FontSlant.NORMAL,
            cairo.FontWeight.BOLD
          )
          cr:set_font_size(12)
          local extents = cr:text_extents(symbol)
          local symbol_x = x + (bar_width - extents.width) / 2 - extents.x_bearing
          local symbol_y = bar_inset + (bar_height - extents.height) / 2 - extents.y_bearing
          cr:set_source_rgba(base_r, base_g, base_b, 0.94)
          for _, offset in ipairs(outline) do
            cr:move_to(symbol_x + offset[1], symbol_y + offset[2])
            cr:show_text(symbol)
          end
          cr:move_to(symbol_x, symbol_y)
          cr:set_source_rgba(bright_r, bright_g, bright_b, 1)
          cr:show_text(symbol)
        end
      end
    end

    return metrics
  '';

  metricLoader = component: ''
    local directory = ironbar.config_dir
    if directory:sub(-1) ~= "/" then directory = directory .. "/" end
    local metrics = dofile(directory .. "metrics.lua")
    return metrics.new("${component}")
  '';
in
{
  home.packages = [
    ironbar
    ironbarMetric
  ];

  xdg.configFile = {
    "ironbar/config.json".text = builtins.toJSON ironbarConfig;
    "ironbar/style.css".text = ''
      @define-color base #${c.background};
      @define-color mantle #${c.surface};
      @define-color surface #${c.selection};
      @define-color overlay #${c.muted};
      @define-color text #${c.foreground};
      @define-color bright #${c.bright};
      @define-color subtext #${c.subtle};
      @define-color violet #${c.violet};
      @define-color blue #${c.blue};
      @define-color green #${c.green};
      @define-color olive #${c.olive};
      @define-color yellow #${c.yellow};
      @define-color orange #${c.orange};
      @define-color red #${c.red};
      @define-color accent #${c.accent};
      @define-color magenta #${c.magenta};
      @define-color panel #${s.panel};
      @define-color panel-hover #${s.panelHover};
      @define-color line #${s.border};
      @define-color active #${s.active};
      @define-color info #${s.info};
      @define-color success #${s.success};
      @define-color warning #${s.warning};
      @define-color thermal #${s.thermal};
      @define-color critical #${s.critical};

      * {
        border: none;
        border-radius: 0;
        box-shadow: none;
        font-family: "${theme.fonts.interface}";
        font-size: 11px;
        font-weight: 500;
      }

      .background,
      #bar,
      #start,
      #center,
      #end {
        color: @text;
        background-color: transparent;
      }

      #metric-cpu,
      #docker,
      #caffeine,
      #notifications {
        margin-left: 5px;
      }

      .island {
        min-height: 28px;
        padding: 0 8px;
        color: @text;
        /* 0.62 gives the wallpaper a deliberate glass presence. Raise toward
           0.75 if a future bright wallpaper compromises small-text contrast. */
        background-color: alpha(@panel, 0.62);
        border: 1px solid alpha(@line, 0.62);
        border-radius: 9px;
        box-shadow: 0 2px 6px alpha(@base, 0.42);
      }

      .island:hover {
        color: @bright;
        background-color: alpha(@panel-hover, 0.62);
        border-color: alpha(@active, 0.76);
      }

      #global-menu {
        /* The Nerd Font keyboard glyph connects the system menu to the TOTEM
           identity without turning this compact target into an illustration.
           Its 20 px glyph plus 2 × 6 px padding keeps the Home field compact. */
        min-width: 20px;
        padding: 0 6px;
        color: @text;
        font-size: 20px;
        font-weight: 800;
      }

      #global-menu:hover {
        color: @bright;
        border-color: alpha(@active, 0.90);
      }

      #workspace-island {
        /* Keep the same 5 px breathing room as the following metrics island;
           resource meters themselves intentionally remain one joined group. */
        margin-left: 5px;
        padding: 0 5px;
        background-color: alpha(@panel, 0.62);
        border-color: alpha(@line, 0.72);
      }

      #workspace-island .item {
        /* 22 px circle + 2 × 3 px margins = the island's 28 px content.
           At 11 px CommitMono a tabular digit advances about 6.5 px, leaving
           (22 - 6.5) / 2 = 7.75 px on each horizontal side. */
        min-width: 22px;
        min-height: 22px;
        margin: 3px 1px;
        padding: 0;
        color: alpha(@text, 0.78);
        background: transparent;
        border: none;
        border-radius: 99px;
        box-shadow: none;
        font-family: "${theme.fonts.interface}";
        font-size: 11px;
        font-weight: 800;
        font-feature-settings: "tnum" 1;
      }

      #workspace-island .item.inactive {
        color: alpha(@subtext, 0.68);
        background: transparent;
      }

      #workspace-island .item:not(.inactive):not(.visible):not(.urgent) {
        color: @subtext;
        background: transparent;
        border: none;
        box-shadow: none;
        font-size: 11px;
      }

      #workspace-island .item.visible:not(.focused):not(.urgent) {
        color: @base;
        background: alpha(@olive, 0.62);
        box-shadow: inset 0 0 0 1px alpha(@bright, 0.10);
        font-weight: 800;
      }

      #workspace-island .item.focused {
        min-width: 22px;
        min-height: 22px;
        margin: 3px 1px;
        color: @base;
        background: alpha(@active, 0.62);
        border: none;
        border-radius: 99px;
        box-shadow: inset 0 0 0 1px alpha(@bright, 0.10);
        font-size: 11px;
        font-weight: 900;
      }

      #workspace-island .item label {
        /* A 20 px line box plus 2 px top padding fills the 22 px circle. The
           asymmetric padding moves the glyph's optical centre down by 1 px. */
        min-width: 22px;
        min-height: 20px;
        margin: 0;
        padding: 2px 0 0;
        font-family: "${theme.fonts.monospace}";
        font-weight: 800;
        font-feature-settings: "tnum" 1;
      }

      #workspace-island .item.urgent {
        color: @base;
        background: alpha(@critical, 0.62);
        box-shadow: inset 0 0 0 1px alpha(@bright, 0.16);
        font-size: 11px;
        font-weight: 900;
      }

      #workspace-island .item:not(.focused):not(.visible):not(.urgent):hover {
        color: @bright;
        background: alpha(@surface, 0.62);
        border: none;
        box-shadow: inset 0 0 0 1px alpha(@line, 0.42);
      }

      #workspace-island .item.visible:not(.focused):not(.urgent):hover {
        color: @base;
        background: alpha(@yellow, 0.62);
      }

      #workspace-island .item.focused:not(.urgent):hover {
        color: @base;
        background: alpha(@bright, 0.62);
      }

      #workspace-island .item.urgent:hover {
        color: @base;
        background: alpha(@critical, 0.62);
        box-shadow: inset 0 0 0 2px alpha(@bright, 0.24);
      }

      .metric {
        padding: 0 5px;
        background-color: alpha(@panel, 0.62);
        border-color: alpha(@line, 0.62);
        border-radius: 0;
        box-shadow: none;
      }

      .metric .metric-button {
        min-height: 28px;
        margin: 0;
        padding: 0;
        background: transparent;
        border: none;
        border-radius: 0;
        box-shadow: none;
      }

      .metric .metric-button:hover {
        background: transparent;
      }

      .metric-icon,
      .metric .metric-icon {
        min-width: 22px;
        margin: 0 6px 0 1px;
        font-family: "${theme.fonts.monospace}";
        font-size: 24px;
        font-weight: 800;
      }

      .metric .cairo {
        margin: 0;
        padding: 0;
      }

      #metric-cpu .metric-icon { color: @violet; }
      #metric-memory .metric-icon { color: @accent; }
      #metric-network .metric-icon { color: @green; }
      #metric-disk .metric-icon { color: @orange; }
      #metric-gpu .metric-icon { color: @blue; }

      #metric-gpu .metric-icon {
        min-width: 24px;
        margin-right: 5px;
        font-size: 28px;
      }

      #metric-cpu {
        border-right: none;
        border-radius: 9px 0 0 9px;
      }

      #metric-memory,
      #metric-network,
      #metric-disk,
      #metric-gpu {
        margin-left: 0;
        border-left-width: 2px;
        border-left-style: solid;
      }

      #metric-memory { border-left-color: alpha(@accent, 0.76); }
      #metric-network { border-left-color: alpha(@green, 0.76); }
      #metric-disk { border-left-color: alpha(@orange, 0.76); }
      #metric-gpu { border-left-color: alpha(@blue, 0.86); }

      #metric-memory,
      #metric-network,
      #metric-disk {
        border-right: none;
      }

      #metric-gpu {
        border-right: 1px solid alpha(@line, 0.62);
        border-radius: 0 9px 9px 0;
      }

      #metric-disk.metric-last {
        border-right: 1px solid alpha(@line, 0.62);
        border-radius: 0 9px 9px 0;
      }

      .metric:hover {
        background-color: alpha(@panel-hover, 0.62);
      }

      #docker { color: @text; }
      #docker.offline { color: @subtext; }

      #clock {
        /* Separate the central clock island from the final left-side island
           (Docker when enabled) by the common 5 px panel gap. */
        margin-left: 5px;
        padding: 0 10px;
        color: @bright;
        border-right: none;
        border-radius: 9px 0 0 9px;
        font-family: "${theme.fonts.interface}";
        font-size: 12px;
        font-weight: 700;
      }

      #clock label {
        margin: 0;
        padding: 0;
        color: @bright;
        font-family: "${theme.fonts.monospace}";
        font-size: 12px;
        font-weight: 900;
        font-feature-settings: "tnum" 1;
        letter-spacing: 0.3px;
      }

      #screenshot {
        margin-left: 0;
        padding: 0 9px;
        color: @orange;
        border-left-color: alpha(@line, 0.36);
        border-radius: 0 9px 9px 0;
        font-size: 16px;
      }

      .status {
        margin-left: 0;
        padding: 0 5px;
        border-left-color: alpha(@line, 0.34);
        border-right: none;
        border-radius: 0;
        box-shadow: none;
        font-size: 12.5px;
        font-weight: 600;
      }

      .status.status-last {
        border-right: 1px solid alpha(@line, 0.62);
        border-radius: 0 9px 9px 0;
      }

      #volume {
        min-width: 54px;
        color: @text;
        border-left-color: alpha(@line, 0.62);
        border-radius: 9px 0 0 9px;
      }

      #volume .sink {
        min-width: 54px;
        margin: 0;
        padding: 0;
        font-family: "${theme.fonts.monospace}";
        font-size: 12.5px;
        font-weight: 700;
        font-feature-settings: "tnum" 1;
      }

      #voxtype {
        /* The prior 17 px Nerd Font glyph looked smaller than every nearby
           status icon. The 28 px content height is the maximum that fits this
           30 px bar; a literal twofold 34 px size would be visibly clipped.
           Keep its outer field at 34 px (28 px glyph + 2 × 3 px padding),
           matching the screenshot field (16 px glyph + 2 × 9 px padding). */
        margin-left: 0;
        padding: 0 3px;
        border-left-color: alpha(@line, 0.36);
        border-radius: 0;
        font-family: "${theme.fonts.monospace}";
        font-size: 28px;
        font-weight: 700;
      }

      #voxtype label {
        min-width: 28px;
        min-height: 28px;
        margin: 0;
        padding: 0;
      }

      #network {
        min-width: 38px;
        padding: 0;
        color: @success;
        font-family: "${theme.fonts.interface}";
      }

      #network .item,
      #network button,
      #network .icon,
      #network .text-icon {
        min-width: 38px;
        min-height: 28px;
        margin: 0;
        padding: 0;
        font-family: "${theme.fonts.interface}";
        font-size: 19px;
        font-weight: 500;
      }

      #network.profile-wifi_disconnected,
      #network.profile-wired_disconnected {
        color: @subtext;
      }

      #network.profile-wifi_acquiring,
      #network.profile-wired_acquiring {
        color: @warning;
      }

      #network.profile-wifi_connected_none { color: alpha(@success, 0.38); }
      #network.profile-wifi_connected_weak { color: alpha(@success, 0.52); }
      #network.profile-wifi_connected_ok { color: alpha(@success, 0.68); }
      #network.profile-wifi_connected_good { color: alpha(@success, 0.84); }
      #network.profile-wifi_connected_excellent { color: @success; }

      #bluetooth {
        min-width: 38px;
        padding: 0;
        color: @info;
        font-family: "${theme.fonts.monospace}";
        font-size: 19px;
        font-weight: 800;
      }

      #bluetooth label {
        min-width: 38px;
        min-height: 28px;
        margin: 0;
        padding: 0;
        font-family: "${theme.fonts.monospace}";
        font-size: 19px;
        font-weight: 800;
      }

      #brightness {
        min-width: 54px;
        padding: 0 5px;
        color: @thermal;
      }

      #brightness .icon {
        min-width: 18px;
        margin: 0 -3px 0 2px;
        padding: 0;
        font-family: "${theme.fonts.interface}";
        font-size: 18px;
        font-weight: 600;
      }

      #brightness .label {
        min-width: 31px;
        margin: 0;
        padding: 0;
        font-size: 12.5px;
        font-weight: 700;
      }

      #battery {
        min-width: 54px;
        padding: 0 5px;
        color: @success;
        border-right: 1px solid alpha(@line, 0.62);
        border-radius: 0 9px 9px 0;
      }

      #battery .contents,
      #battery .icon,
      #battery .label {
        margin: 0;
        padding: 0;
      }

      #battery .contents {
        min-width: 54px;
      }

      #battery .icon {
        min-width: 18px;
      }

      #battery .label {
        min-width: 31px;
        font-size: 12.5px;
        font-weight: 700;
        font-feature-settings: "tnum" 1;
      }

      #battery.profile-warning {
        color: @warning;
        background-color: alpha(@orange, 0.62);
      }

      #battery.profile-critical {
        color: @critical;
        background-color: alpha(@red, 0.62);
        border-color: alpha(@critical, 0.76);
      }

      #notifications {
        min-width: 56px;
        padding: 0;
        color: @active;
      }

      #notifications .button {
        min-width: 56px;
        min-height: 28px;
        margin: 0;
        padding: 0;
      }

      #caffeine {
        min-width: 40px;
        padding: 0;
        font-family: "${theme.fonts.monospace}";
        font-size: 20px;
        font-weight: 700;
      }

      #caffeine button,
      #caffeine label {
        min-width: 40px;
        margin: 0;
        padding: 0;
      }

      #notifications label {
        margin: 0;
        padding: 0;
        font-family: "${theme.fonts.monospace}";
        font-size: 18px;
      }

      #tray {
        padding: 0;
        background: transparent;
      }

      #tray .item {
        min-width: 17px;
        min-height: 28px;
        margin-left: 5px;
        padding: 0 7px;
        color: @text;
        background-color: alpha(@panel, 0.62);
        border: 1px solid alpha(@line, 0.62);
        border-radius: 9px;
        box-shadow: 0 2px 6px alpha(@base, 0.42);
      }

      #tray .item > box,
      #tray .item image,
      #tray .item picture {
        min-width: 17px;
        min-height: 17px;
        margin: 0;
        padding: 0;
      }

      #tray .item label {
        margin: 0;
        padding: 0;
      }

      #tray .item:hover {
        color: @bright;
        background-color: alpha(@panel-hover, 0.62);
        border-color: alpha(@active, 0.76);
      }

      #tray .item + .item {
        margin-left: 2px;
      }

      #network .item,
      #network button,
      #brightness .icon,
      #brightness .label {
        background: transparent;
      }

      #notifications .count {
        /* 14 px content + 2 × 1 px padding + 2 × 1 px border = 18 px.
           The 5 px vertical margins centre it exactly in the 28 px button;
           a 10 px right margin centres it beside the reserved 18 px icon. */
        min-width: 14px;
        min-height: 14px;
        margin: 5px 10px 5px 0;
        padding: 1px;
        color: @base;
        background: alpha(@active, 0.62);
        border: 1px solid alpha(@base, 0.92);
        border-radius: 99px;
        box-shadow: none;
        font-family: "${theme.fonts.interface}";
        font-size: 10px;
        font-weight: 900;
        font-feature-settings: "tnum" 1;
      }

      tooltip,
      tooltip.background,
      popover contents,
      .popup {
        color: @text;
        /* One shared glass value keeps popups, hover states and islands at
           62% opacity while preserving their semantic Biscuit colours. */
        background: alpha(@panel, 0.62);
        border: 1px solid alpha(@line, 0.92);
        border-radius: 11px;
        box-shadow: 0 8px 24px alpha(@base, 0.74);
      }

      tooltip label {
        min-width: 210px;
        padding: 9px 11px;
        color: @text;
        font-family: "${theme.fonts.monospace}";
        font-size: 10px;
        font-weight: 500;
      }

      .popup .metric-tooltip {
        min-width: 250px;
        padding: 3px 4px 3px 10px;
        color: @text;
        border-left: 3px solid alpha(@line, 0.92);
        border-radius: 3px;
        font-family: "${theme.fonts.monospace}";
        font-size: 11px;
        font-weight: 500;
      }

      .popup .metric-tooltip-cpu { border-left-color: #${theme.metricPopup.cpu}; }
      .popup .metric-tooltip-memory { border-left-color: #${theme.metricPopup.memory}; }
      .popup .metric-tooltip-network { border-left-color: #${theme.metricPopup.positive}; }
      .popup .metric-tooltip-disk { border-left-color: #${theme.metricPopup.disk}; }
      .popup .metric-tooltip-gpu { border-left-color: #${theme.metricPopup.gpu}; }

      .popup {
        padding: 10px;
      }

      .popup-clock {
        min-width: 240px;
        padding: 12px;
      }

      .popup-clock .calendar-clock {
        padding: 2px 4px 10px;
        color: @bright;
        font-size: 12px;
        font-weight: 700;
      }

      .popup-clock .calendar {
        padding: 4px;
        color: @text;
        background: transparent;
        font-size: 10.5px;
      }

      .popup-clock calendar header {
        padding-bottom: 6px;
        color: @bright;
        background: transparent;
      }

      .popup-clock calendar header button {
        min-width: 24px;
        min-height: 24px;
        color: @subtext;
        border-radius: 99px;
      }

      .popup-clock calendar header button:hover {
        color: @bright;
        background: alpha(@surface, 0.62);
      }

      .popup-clock calendar .day-name {
        color: @subtext;
        font-weight: 700;
      }

      .popup-clock calendar .day-number {
        min-width: 24px;
        min-height: 24px;
        color: @text;
        border-radius: 99px;
      }

      .popup-clock calendar .day-number:hover {
        color: @bright;
        background: alpha(@surface, 0.62);
      }

      .popup-clock calendar .other-month {
        color: alpha(@subtext, 0.32);
      }

      .popup-clock calendar .today {
        color: @base;
        background: alpha(@active, 0.62);
        font-weight: 800;
      }

      button,
      label,
      box {
        background: transparent;
      }
    '';
    "ironbar/metrics.lua".text = metricLua;
    "ironbar/cpu.lua".text = metricLoader "cpu";
    "ironbar/memory.lua".text = metricLoader "memory";
    "ironbar/network.lua".text = metricLoader "network";
    "ironbar/disk.lua".text = metricLoader "disk";
    "ironbar/gpu.lua".text = metricLoader "gpu";
  };

  systemd.user.services.ironbar-metric-popup-refresh = {
    Unit = {
      Description = "Refresh the visible Ironbar metric popup";
      After = [ "ironbar.service" ];
      PartOf = [ "ironbar.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${metricPopupRefresh}/bin/ironbar-metric-popup-refresh";
    };
  };

  systemd.user.services.ironbar = {
    Unit = {
      Description = "Ironbar desktop panel";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${ironbar}/bin/ironbar --config ${homeDirectory}/.config/ironbar/config.json";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [
        "PATH=/etc/profiles/per-user/${username}/bin:${homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin"
        "LC_ALL=pl_PL.UTF-8"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
