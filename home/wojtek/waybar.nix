{ inputs, pkgs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
  waybarMetric = import ./waybar-metric.nix { inherit inputs pkgs; };

  metric = component: interval: {
    exec = "${waybarMetric}/bin/waybar-metric ${component}";
    inherit interval;
    return-type = "json";
    format = "{text}";
    escape = false;
    tooltip = true;
    min-length = 3;
    align = 0.5;
    justify = "center";
    on-click = "waybar-panel metrics";
  };
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 4;
      margin-top = 4;
      margin-left = 6;
      margin-right = 6;

      modules-left = [
        "hyprland/workspaces"
        "custom/cpu"
        "custom/memory"
        "custom/network-usage"
        "custom/disk"
        "custom/gpu"
        "custom/temperature"
        "custom/docker"
      ];
      modules-center = [
        "clock"
        "custom/screenshot"
      ];
      modules-right = [
        "tray"
        "pulseaudio"
        "network"
        "bluetooth"
        "backlight"
        "battery"
        "custom/notifications"
      ];

      "hyprland/workspaces" = {
        format = "{icon}";
        on-click = "activate";
        persistent-workspaces."*" = 5;
        format-icons = {
          active = "●";
          default = "●";
          empty = "○";
          persistent = "○";
          urgent = "!";
        };
      };

      clock = {
        format = "󰥔 {:%H:%M}";
        format-alt = "󰃭 {:%a, %d.%m}";
        tooltip = false;
        locale = "pl_PL.UTF-8";
      };

      "custom/cpu" = metric "cpu" 2;
      "custom/memory" = metric "memory" 3;
      "custom/network-usage" = metric "network" 2;
      "custom/disk" = metric "disk" 15;
      "custom/gpu" = metric "gpu" 2;
      "custom/temperature" = metric "temperature" 3;

      "custom/docker" = {
        exec = "docker-status";
        interval = 10;
        return-type = "json";
        format = "{}";
        tooltip = true;
        on-click = "waybar-panel docker";
      };

      "custom/screenshot" = {
        format = "󰄀";
        tooltip-format = "Screenshot\nLewy: obszar i edycja\nPrawy: cały ekran";
        on-click = "screenshot-menu area";
        on-click-right = "screenshot-menu full";
      };

      tray = {
        icon-size = 13;
        spacing = 4;
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟 mute";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "waybar-panel audio";
        on-click-right = "swayosd-client --output-volume=mute-toggle --max-volume=100";
        on-scroll-up = "swayosd-client --output-volume=+5 --max-volume=100";
        on-scroll-down = "swayosd-client --output-volume=-5 --max-volume=100";
      };

      network = {
        format-wifi = " {signalStrength}%";
        format-ethernet = "󰈀 LAN";
        format-disconnected = "󰖪 off";
        tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
        on-click = "waybar-panel wifi";
      };

      bluetooth = {
        format = "";
        format-connected = " {num_connections}";
        format-disabled = "󰂲";
        on-click = "waybar-panel bluetooth";
      };

      backlight = {
        device = "amdgpu_bl2";
        format = "{icon} {percent}%";
        format-icons = [
          "󰃞"
          "󰃟"
          "󰃠"
        ];
        scroll-step = 5;
        on-scroll-up = "swayosd-client --brightness=+5 --device=amdgpu_bl2";
        on-scroll-down = "swayosd-client --brightness=-5 --device=amdgpu_bl2";
      };

      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-plugged = "󰚥 {capacity}%";
        format-icons = [
          "󰁺"
          "󰁻"
          "󰁼"
          "󰁽"
          "󰁾"
          "󰁿"
          "󰂀"
          "󰂁"
          "󰂂"
          "󰁹"
        ];
      };

      "custom/notifications" = {
        tooltip = false;
        format = "{icon}";
        format-icons = {
          notification = "󱅫";
          none = "";
          dnd-notification = "󰂛";
          dnd-none = "󰂛";
          inhibited-notification = "󰂛";
          inhibited-none = "󰂛";
          dnd-inhibited-notification = "󰂛";
          dnd-inhibited-none = "󰂛";
        };
        return-type = "json";
        exec-if = "which swaync-client";
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
      };
    };

    style = ''
      @define-color base #${c.background};
      @define-color mantle #${c.surface};
      @define-color surface #${c.selection};
      @define-color overlay #${c.muted};
      @define-color text #${c.foreground};
      @define-color bright #${c.bright};
      @define-color subtext #${c.subtle};
      @define-color blue #${c.violet};
      @define-color sapphire #${c.blue};
      @define-color green #${c.green};
      @define-color yellow #${c.yellow};
      @define-color peach #${c.orange};
      @define-color red #${c.red};
      @define-color mauve #${c.accent};
      @define-color accent #${c.accent};
      @define-color pink #${c.magenta};

      * {
        border: none;
        border-radius: 0;
        min-height: 0;
        font-family: "${theme.fonts.interface}";
        font-size: 10.5px;
        font-weight: 500;
      }

      window#waybar {
        background: transparent;
        color: @text;
      }

      .modules-left,
      .modules-center,
      .modules-right {
        min-height: 30px;
      }

      #workspaces,
      #clock,
      #tray,
      #custom-cpu,
      #custom-memory,
      #custom-network-usage,
      #custom-disk,
      #custom-gpu,
      #custom-temperature,
      #custom-docker,
      #custom-screenshot,
      #pulseaudio,
      #network,
      #bluetooth,
      #backlight,
      #battery,
      #custom-notifications {
        min-height: 28px;
        padding: 0 8px;
        background: alpha(@base, 0.95);
        border: 1px solid alpha(@muted, 0.48);
        border-radius: 9px;
        box-shadow: 0 3px 9px alpha(@base, 0.58);
        transition: background-color 140ms ease, border-color 140ms ease, color 140ms ease;
      }

      #clock:hover,
      #tray:hover,
      #custom-cpu:hover,
      #custom-memory:hover,
      #custom-network-usage:hover,
      #custom-disk:hover,
      #custom-gpu:hover,
      #custom-temperature:hover,
      #custom-docker:hover,
      #custom-screenshot:hover,
      #pulseaudio:hover,
      #network:hover,
      #bluetooth:hover,
      #backlight:hover,
      #battery:hover,
      #custom-notifications:hover {
        background: alpha(@surface, 0.98);
        border-color: alpha(@accent, 0.68);
      }

      #workspaces {
        padding: 0 3px;
      }

      #workspaces button {
        min-width: 16px;
        min-height: 20px;
        margin: 4px 1px;
        padding: 0 2px;
        font-size: 8.5px;
        color: alpha(@subtext, 0.72);
        background: transparent;
        border: 1px solid transparent;
        border-radius: 8px;
        box-shadow: none;
        transition: background-color 160ms ease, border-color 160ms ease, color 160ms ease;
      }

      #workspaces button.empty {
        color: alpha(@overlay, 0.66);
      }

      #workspaces button:hover {
        color: @bright;
        background: alpha(@surface, 0.82);
        border-color: alpha(@muted, 0.54);
      }

      #workspaces button.active {
        min-width: 25px;
        color: @bright;
        background: alpha(@mauve, 0.72);
        border-color: alpha(@bright, 0.22);
        box-shadow: 0 2px 6px alpha(@base, 0.48);
      }

      #workspaces button.urgent {
        color: @bright;
        background: alpha(@red, 0.72);
        border-color: alpha(@red, 0.88);
      }

      #battery.critical:not(.charging) {
        color: @red;
        border-color: alpha(@red, 0.72);
      }

      #clock {
        color: @bright;
        font-weight: 600;
      }

      #custom-cpu,
      #custom-memory,
      #custom-network-usage,
      #custom-disk,
      #custom-gpu,
      #custom-temperature {
        min-width: 31px;
        padding: 0 5px;
        font-size: 11px;
        background: alpha(@surface, 0.94);
        border-color: alpha(@overlay, 0.66);
      }

      #custom-cpu { color: @blue; }
      #custom-memory { color: @mauve; }
      #custom-network-usage { color: @green; }
      #custom-disk { color: @peach; }
      #custom-gpu { color: @sapphire; }
      #custom-temperature { color: @yellow; }

      #custom-cpu.warning,
      #custom-memory.warning,
      #custom-disk.warning,
      #custom-gpu.warning,
      #custom-temperature.warning {
        border-color: alpha(@yellow, 0.72);
      }

      #custom-cpu.critical,
      #custom-memory.critical,
      #custom-disk.critical,
      #custom-gpu.critical,
      #custom-temperature.critical {
        color: @red;
        border-color: alpha(@red, 0.82);
      }

      #custom-docker {
        color: @blue;
      }

      #custom-docker.warning {
        color: @yellow;
        border-color: alpha(@yellow, 0.52);
      }

      #custom-docker.critical {
        color: @red;
        border-color: alpha(@red, 0.68);
      }

      #custom-docker.offline {
        color: @overlay;
      }

      #custom-screenshot {
        color: @peach;
        padding: 0 8px;
      }

      #pulseaudio {
        color: @blue;
      }

      #pulseaudio.muted {
        color: @overlay;
      }

      #network {
        color: @green;
      }

      #network.disconnected {
        color: @red;
      }

      #bluetooth {
        color: @sapphire;
      }

      #bluetooth.disabled,
      #bluetooth.off {
        color: @overlay;
      }

      #backlight {
        color: @yellow;
      }

      #battery {
        color: @yellow;
      }

      #battery.charging,
      #battery.plugged {
        color: @green;
      }

      #custom-notifications {
        color: @accent;
        padding: 0 8px;
      }

      #custom-notifications.notification {
        color: @yellow;
        border-color: alpha(@yellow, 0.62);
      }

      tooltip {
        color: @text;
        background: alpha(@base, 0.99);
        border: 1px solid alpha(@accent, 0.60);
        border-radius: 10px;
        box-shadow: 0 6px 18px alpha(@base, 0.72);
      }

      tooltip label {
        color: @text;
        padding: 8px 10px;
      }
    '';
  };

}
