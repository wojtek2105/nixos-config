{ inputs, pkgs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
  waybarMetric = import ./waybar-metric.nix { inherit inputs pkgs; };

  metric = {
    component,
    icon,
    interval,
    width,
  }: {
    type = "custom";
    name = "metric-${component}";
    class = "island metric metric-${component}";
    tooltip = "#metric_${component}_tooltip";
    on_mouse_enter =
      ''${pkgs.ironbar}/bin/ironbar var set metric_${component}_tooltip "$(${waybarMetric}/bin/waybar-metric ${component} tooltip)"'';
    on_click_left = "desktop-panel metrics";
    bar = [
      {
        type = "label";
        class = "metric-icon";
        label = icon;
      }
      {
        type = "cairo";
        path = "/home/wojtek/.config/ironbar/${component}.lua";
        frequency = interval;
        inherit width;
        height = 20;
      }
    ];
  };

  ironbarConfig = {
    name = "main";
    ironvar_defaults = {
      metric_cpu_tooltip = "  PROCESOR\nNajedź, aby pobrać szczegóły";
      metric_memory_tooltip = "  PAMIĘĆ\nNajedź, aby pobrać szczegóły";
      metric_network_tooltip = "󰓅  SIEĆ\nNajedź, aby pobrać szczegóły";
      metric_disk_tooltip = "󰋊  DYSK\nNajedź, aby pobrać szczegóły";
      metric_gpu_tooltip = "󰢮  GRAFIKA\nNajedź, aby pobrać szczegóły";
    };
    position = "top";
    anchor_to_edges = true;
    height = 30;
    layer = "top";
    popup_gap = 6;
    popup_autohide = true;
    margin = {
      top = 4;
      bottom = 0;
      left = 6;
      right = 6;
    };

    start = [
      {
        type = "workspaces";
        name = "workspace-island";
        class = "island";
        favorites = [ "1" "2" "3" "4" "5" ];
        all_monitors = false;
        sort = "index";
        name_map = {
          "1" = "●";
          "2" = "●";
          "3" = "●";
          "4" = "●";
          "5" = "●";
        };
      }
      (metric {
        component = "cpu";
        icon = "";
        interval = 2000;
        width = 13;
      })
      (metric {
        component = "memory";
        icon = "";
        interval = 3000;
        width = 5;
      })
      (metric {
        component = "network";
        icon = "󰓅";
        interval = 2000;
        width = 13;
      })
      (metric {
        component = "disk";
        icon = "󰋊";
        interval = 15000;
        width = 21;
      })
      (metric {
        component = "gpu";
        icon = "󰢮";
        interval = 2000;
        width = 21;
      })
      {
        type = "script";
        name = "docker";
        class = "island docker";
        cmd = "docker-status label";
        mode = "poll";
        interval = 10000;
        tooltip = "{{poll:15000:docker-status tooltip}}";
        on_click_left = "desktop-panel docker";
      }
    ];

    center = [
      {
        type = "clock";
        name = "clock";
        class = "island";
        format = "󰥔  %H:%M";
        locale = "pl_PL";
        disable_popup = true;
        tooltip = "{{poll:60000:date '+%A, %d.%m.%Y'}}";
      }
      {
        type = "label";
        name = "screenshot";
        class = "island";
        label = "󰄀";
        tooltip = "Screenshot\nLewy: obszar i edycja\nPrawy: cały ekran";
        on_click_left = "screenshot-menu area";
        on_click_right = "screenshot-menu full";
      }
    ];

    end = [
      {
        type = "tray";
        name = "tray";
        class = "island";
        icon_size = 13;
        prefer_theme_icons = true;
      }
      {
        type = "volume";
        name = "volume";
        class = "island";
        format = "{icon}  {percentage}%";
        mute_format = "󰝟  mute";
        max_volume = 100;
        show_sinks = true;
        show_sources = false;
        disable_popup = true;
        on_click_left = "desktop-panel audio";
        on_click_right = "swayosd-client --output-volume=mute-toggle --max-volume=100";
        on_scroll_up = "swayosd-client --output-volume=+5 --max-volume=100";
        on_scroll_down = "swayosd-client --output-volume=-5 --max-volume=100";
        icons = {
          volume = "";
          muted = "󰝟";
        };
        profiles = {
          low = {
            when = 33.33;
            icons.volume = "";
          };
          medium = {
            when = 66.66;
            icons.volume = "";
          };
        };
      }
      {
        type = "network_manager";
        name = "network";
        class = "island network";
        icon_size = 13;
        types_whitelist = [ "wifi" "ethernet" ];
        interface_blacklist = [ "lo" ];
        tooltip = "Sieć\nKliknij, aby otworzyć panel TUI";
        on_click_left = "desktop-panel wifi";
      }
      {
        type = "bluetooth";
        name = "bluetooth";
        class = "island";
        icon_size = 13;
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
      {
        type = "brightness";
        name = "brightness";
        class = "island brightness";
        format = "{percentage}%";
        smooth_scroll_speed = 0.5;
        mode = {
          type = "systemd";
          subsystem = "backlight";
          name = "amdgpu_bl2";
        };
        tooltip = "Jasność ekranu\nScroll: zmień o 5%";
      }
      {
        type = "battery";
        name = "battery";
        class = "island";
        icon_size = 13;
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
      {
        type = "notifications";
        name = "notifications";
        class = "island";
        show_count = true;
        on_click_right = "swaync-client -d -sw";
        icons = {
          closed_none = "";
          closed_some = "󱅫";
          closed_dnd = "󰂛";
          open_none = "󰍡";
          open_some = "󱥁";
          open_dnd = "󰂛";
        };
      }
    ];
  };

  metricLua = ''
    local metrics = {}

    local palette = {
      track = "${c.selection}",
      cpu = { "${c.violet}", "${c.yellow}" },
      memory = { "${c.accent}" },
      network = { "${c.green}", "${c.violet}" },
      disk = { "${c.orange}", "${c.green}", "${c.violet}" },
      gpu = { "${c.blue}", "${c.magenta}", "${c.yellow}" },
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

    local function logarithmic_percent(rate, ceiling)
      if rate <= 0 then return 0 end
      return clamp(math.log(rate + 1) / math.log(ceiling + 1) * 100)
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
      }

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
          return { clamp(usage), clamp(maximum_temperature(cpu_temperature_paths)) }
        end

        if component == "memory" then
          return { clamp(memory_percent()) }
        end

        if component == "network" then
          local interface = default_interface()
          if not interface then return { 0, 0 } end
          local rx = read_number("/sys/class/net/" .. interface .. "/statistics/rx_bytes")
          local tx = read_number("/sys/class/net/" .. interface .. "/statistics/tx_bytes")
          local elapsed = state.time and math.max(now - state.time, 0.001) or 1
          if state.interface ~= interface then state.rx, state.tx = rx, tx end
          local down = state.rx and math.max((rx - state.rx) / elapsed, 0) or 0
          local up = state.tx and math.max((tx - state.tx) / elapsed, 0) or 0
          state.interface, state.rx, state.tx, state.time = interface, rx, tx, now
          return {
            logarithmic_percent(down, 100 * 1024 * 1024),
            logarithmic_percent(up, 100 * 1024 * 1024),
          }
        end

        if component == "disk" then
          local read_bytes, write_bytes = disk_bytes()
          local elapsed = state.time and math.max(now - state.time, 0.001) or 1
          local read_rate = state.disk_read and math.max((read_bytes - state.disk_read) / elapsed, 0) or 0
          local write_rate = state.disk_write and math.max((write_bytes - state.disk_write) / elapsed, 0) or 0
          state.disk_read, state.disk_write, state.time = read_bytes, write_bytes, now
          return {
            clamp(root_disk_percent()),
            logarithmic_percent(read_rate, 1024 * 1024 * 1024),
            logarithmic_percent(write_rate, 1024 * 1024 * 1024),
          }
        end

        if component == "gpu" and gpu_path then
          local usage = read_number(gpu_path .. "/gpu_busy_percent")
          local used = read_number(gpu_path .. "/mem_info_vram_used")
          local vram = gpu_vram_total > 0 and used * 100 / gpu_vram_total or 0
          local temperature = maximum_temperature(gpu_temperature_paths)
          return { clamp(usage), clamp(vram), clamp(temperature) }
        end

        return { 0 }
      end

      return function(cr, width, height)
        local current = values()
        local colors = palette[component] or { "${c.foreground}" }
        local bar_width = 5
        local gap = 3
        local bar_height = height - 4
        local track_r, track_g, track_b = rgb(palette.track)

        for index, value in ipairs(current) do
          local x = (index - 1) * (bar_width + gap)
          rounded_rectangle(cr, x, 2, bar_width, bar_height, 2.5)
          cr:set_source_rgba(track_r, track_g, track_b, 0.72)
          cr:fill()

          local fill = bar_height * clamp(value) / 100
          if fill > 0 then
            fill = math.max(fill, 2)
            local red, green, blue = rgb(colors[index] or colors[#colors])
            rounded_rectangle(cr, x, 2 + bar_height - fill, bar_width, fill, 2.5)
            cr:set_source_rgba(red, green, blue, 1)
            cr:fill()
          end
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
    pkgs.ironbar
    waybarMetric
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
      @define-color yellow #${c.yellow};
      @define-color orange #${c.orange};
      @define-color red #${c.red};
      @define-color accent #${c.accent};
      @define-color magenta #${c.magenta};

      * {
        border: none;
        border-radius: 0;
        box-shadow: none;
        font-family: "${theme.fonts.interface}";
        font-size: 10.5px;
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

      #start > * + *,
      #center > * + *,
      #end > * + * {
        margin-left: 4px;
      }

      .island {
        min-height: 28px;
        padding: 0 8px;
        color: @text;
        background-color: alpha(@base, 0.96);
        border: 1px solid alpha(@overlay, 0.56);
        border-radius: 9px;
        box-shadow: 0 3px 8px alpha(@base, 0.50);
      }

      .island:hover {
        color: @bright;
        background-color: alpha(@surface, 0.98);
        border-color: alpha(@accent, 0.68);
      }

      #workspace-island {
        padding: 0 3px;
      }

      #workspace-island .item {
        min-width: 18px;
        min-height: 20px;
        margin: 4px 1px;
        padding: 0 2px;
        color: alpha(@subtext, 0.46);
        background: transparent;
        border: 1px solid transparent;
        border-radius: 8px;
        font-size: 9px;
      }

      #workspace-island .item:not(.inactive) {
        color: @blue;
        background: alpha(@blue, 0.22);
        border-color: alpha(@blue, 0.72);
        font-size: 10px;
      }

      #workspace-island .item.visible {
        color: @bright;
        border-color: alpha(@violet, 0.88);
      }

      #workspace-island .item.focused {
        min-width: 27px;
        color: @bright;
        background: alpha(@accent, 0.56);
        border-color: alpha(@accent, 0.94);
        box-shadow: inset 0 -2px alpha(@bright, 0.18);
        font-size: 11px;
      }

      #workspace-island .item.urgent {
        color: @bright;
        background: alpha(@red, 0.72);
        border-color: alpha(@red, 0.9);
      }

      .metric {
        padding: 0 6px;
        background-color: alpha(@base, 0.96);
      }

      .metric .metric-icon {
        margin-right: 5px;
        color: @bright;
        font-family: "${theme.fonts.monospace}";
        font-size: 11px;
        font-weight: 700;
      }

      .metric .cairo {
        margin: 0;
        padding: 0;
      }

      #metric-cpu { border-color: alpha(@violet, 0.58); }
      #metric-memory { border-color: alpha(@accent, 0.58); }
      #metric-network { border-color: alpha(@green, 0.58); }
      #metric-disk { border-color: alpha(@orange, 0.58); }
      #metric-gpu { border-color: alpha(@blue, 0.68); }

      #docker { color: @blue; }
      #clock { color: @bright; font-weight: 600; }
      #screenshot { color: @orange; font-size: 12px; }
      #volume { color: @violet; }
      #network { color: @green; }
      #bluetooth { color: @blue; }
      #brightness { color: @yellow; }
      #battery { color: @yellow; }
      #battery.profile-warning { border-color: alpha(@yellow, 0.75); }
      #battery.profile-critical { color: @red; border-color: alpha(@red, 0.86); }
      #notifications { color: @accent; }

      #tray {
        padding: 0 5px;
      }

      #tray .item {
        padding: 0 3px;
        background: transparent;
      }

      #network .item,
      #network button,
      #brightness .icon,
      #brightness .label {
        background: transparent;
      }

      #notifications .count {
        min-width: 10px;
        min-height: 10px;
        padding: 1px;
        color: @bright;
        background: @accent;
        border-radius: 99px;
        font-size: 7px;
        font-weight: 700;
      }

      tooltip,
      tooltip.background,
      popover contents,
      .popup {
        color: @text;
        background: alpha(@base, 0.99);
        border: 1px solid alpha(@accent, 0.62);
        border-radius: 10px;
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

      .popup {
        padding: 10px;
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

  systemd.user.services.ironbar = {
    Unit = {
      Description = "Ironbar desktop panel";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Conflicts = [ "waybar.service" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStartPre = [
        "-${pkgs.procps}/bin/pkill -x waybar"
        "-${pkgs.procps}/bin/pkill -x .waybar-wrapped"
      ];
      ExecStart = "${pkgs.ironbar}/bin/ironbar --config /home/wojtek/.config/ironbar/config.json";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [
        "PATH=/etc/profiles/per-user/wojtek/bin:/home/wojtek/.nix-profile/bin:/run/current-system/sw/bin"
        "LC_ALL=pl_PL.UTF-8"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
