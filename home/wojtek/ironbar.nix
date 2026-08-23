{ desktopFeatures, inputs, lib, pkgs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
  s = theme.semantic;
  ironbarMetric = import ./ironbar-metric.nix { inherit inputs pkgs; };
  amdGpuEnabled = desktopFeatures.amdGpu or false;
  dockerEnabled = desktopFeatures.docker or false;
  laptopEnabled = desktopFeatures.laptop or false;

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
    tooltip = "{{poll:10000:${ironbarMetric}/bin/ironbar-metric ${component} tooltip_plain}}";
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
        height = 23;
      }
    ];
  };

  ironbarConfig = {
    name = "main";
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
        icon = "";
        interval = 3000;
        width = 15;
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
        interval = 10000;
        tooltip = "{{poll:15000:docker-status tooltip}}";
        on_click_left = "desktop-panel docker";
      }
    ];

    center = [
      {
        type = "clock";
        name = "clock";
        class = "island center-item center-first";
        format = "󰥔  %H:%M";
        format_popup = "󰃭  %A, %d %B %Y";
        locale = "pl_PL";
        show_week_numbers = false;
      }
      {
        type = "label";
        name = "screenshot";
        class = "island center-item center-last";
        label = "󰄀";
        tooltip = "Screenshot\nLewy klik: wybierz okno\nLewy przeciągnij: wybierz obszar\nPrawy: cały ekran\nKażdy tryb otwiera edycję";
        on_click_left = "screenshot-menu select";
        on_click_right = "screenshot-menu full";
      }
    ];

    end = [
      {
        type = "volume";
        name = "volume";
        class = "island status status-first";
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
        class = "island status network";
        icon_size = 18;
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
            icon = "";
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
      {
        type = "bluetooth";
        name = "bluetooth";
        class = "island status${lib.optionalString (!laptopEnabled) " status-last"}";
        icon_size = 18;
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
        icon_label = "";
        justify = "center";
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
        class = "island status status-last";
        icon_size = 17;
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
        icon_size = 15;
        prefer_theme_icons = true;
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
    local cairo = require("lgi").cairo
    local metrics = {}

    local palette = {
      track = "${c.muted}",
      cpu = { "${c.violet}", "${c.yellow}" },
      memory = { "${c.accent}" },
      network = { "${c.green}", "${c.violet}" },
      disk = { "${c.orange}", "${c.green}", "${c.violet}" },
      gpu = { "${c.blue}", "${c.magenta}", "${c.yellow}" },
    }

    local symbols = {
      cpu = { "󰓅", "" },
      memory = { "󰓅" },
      network = { "", "" },
      disk = { "󰓅", "", "" },
      gpu = { "󰓅", "󰍛", "" },
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

    local function throughput_percent(rate, knee, ceiling, knee_percent)
      if rate <= 0 then return 0 end
      if rate < knee then
        return clamp(rate / knee * knee_percent)
      end
      if rate >= ceiling then return 100 end
      local progress = math.log(rate / knee) / math.log(ceiling / knee)
      return clamp(knee_percent + progress * (100 - knee_percent))
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
            throughput_percent(down, 1024 * 1024, 100 * 1024 * 1024, 20),
            throughput_percent(up, 1024 * 1024, 100 * 1024 * 1024, 20),
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
            throughput_percent(read_rate, 10 * 1024 * 1024, 1024 * 1024 * 1024, 20),
            throughput_percent(write_rate, 10 * 1024 * 1024, 1024 * 1024 * 1024, 20),
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
        local bar_width = 15
        local gap = 3
        local bar_height = height - 2
        local track_r, track_g, track_b = rgb(palette.track)
        local base_r, base_g, base_b = rgb("${c.background}")
        local bright_r, bright_g, bright_b = rgb("${c.bright}")
        local outline = {
          { -1, 0 },
          { 1, 0 },
          { 0, -1 },
          { 0, 1 },
        }

        for index, value in ipairs(current) do
          local x = (index - 1) * (bar_width + gap)
          rounded_rectangle(cr, x, 1, bar_width, bar_height, 3)
          cr:set_source_rgba(track_r, track_g, track_b, 0.22)
          cr:fill()

          local fill = bar_height * clamp(value) / 100
          if fill > 0 then
            fill = math.max(fill, 2)
            local red, green, blue = rgb(colors[index] or colors[#colors])
            rounded_rectangle(
              cr,
              x,
              1 + bar_height - fill,
              bar_width,
              fill,
              3
            )
            cr:set_source_rgba(red, green, blue, 0.96)
            cr:fill()
          end

          local symbol = (symbols[component] or {})[index] or "•"
          cr:select_font_face(
            "${theme.fonts.monospace}",
            cairo.FontSlant.NORMAL,
            cairo.FontWeight.BOLD
          )
          cr:set_font_size(12)
          local extents = cr:text_extents(symbol)
          local symbol_x = x + (bar_width - extents.width) / 2 - extents.x_bearing
          local symbol_y = 1 + (bar_height - extents.height) / 2 - extents.y_bearing
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
    pkgs.ironbar
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
      #notifications {
        margin-left: 5px;
      }

      .island {
        min-height: 28px;
        padding: 0 8px;
        color: @text;
        background-color: alpha(@panel, 0.95);
        border: 1px solid alpha(@line, 0.62);
        border-radius: 9px;
        box-shadow: 0 2px 6px alpha(@base, 0.42);
      }

      .island:hover {
        color: @bright;
        background-color: alpha(@panel-hover, 0.98);
        border-color: alpha(@active, 0.76);
      }

      #workspace-island {
        padding: 0 5px;
        background-color: alpha(@panel, 0.97);
        border-color: alpha(@line, 0.72);
      }

      #workspace-island .item {
        min-width: 20px;
        min-height: 22px;
        margin: 3px 1px;
        padding: 0;
        color: alpha(@subtext, 0.46);
        background: transparent;
        border: none;
        border-radius: 99px;
        box-shadow: none;
        font-family: "${theme.fonts.monospace}";
        font-size: 10px;
        font-weight: 700;
      }

      #workspace-island .item:not(.inactive) {
        color: @subtext;
        background: transparent;
        border: none;
        box-shadow: none;
        font-size: 10px;
      }

      #workspace-island .item.visible {
        color: @bright;
      }

      #workspace-island .item.focused {
        min-width: 22px;
        min-height: 22px;
        margin: 3px 1px;
        color: @base;
        background: @active;
        border: none;
        border-radius: 99px;
        box-shadow: 0 0 0 1px alpha(@bright, 0.12);
        font-size: 11px;
        font-weight: 800;
      }

      #workspace-island .item.urgent {
        color: @base;
        background: @critical;
        font-size: 11px;
      }

      #workspace-island .item:hover {
        color: @bright;
        background: transparent;
        border: none;
      }

      #workspace-island .item.focused:hover {
        color: @base;
        background: @bright;
      }

      .metric {
        padding: 0 5px;
        background-color: alpha(@panel, 0.95);
        border-color: alpha(@line, 0.62);
        border-radius: 0;
        box-shadow: none;
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
        background-color: alpha(@panel-hover, 0.98);
      }

      #docker { color: @text; }
      #docker.offline { color: @subtext; }

      #clock {
        padding: 0 10px;
        color: @bright;
        border-right: none;
        border-radius: 9px 0 0 9px;
        font-size: 11.5px;
        font-weight: 700;
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
        padding: 0 7px;
        border-left-color: alpha(@line, 0.34);
        border-right: none;
        border-radius: 0;
        box-shadow: none;
        font-size: 11.5px;
        font-weight: 600;
      }

      .status.status-last {
        border-right: 1px solid alpha(@line, 0.62);
        border-radius: 0 9px 9px 0;
      }

      #volume {
        min-width: 58px;
        color: @text;
        border-left-color: alpha(@line, 0.62);
        border-radius: 9px 0 0 9px;
      }

      #network {
        min-width: 32px;
        padding: 0 6px;
        color: @success;
      }

      #network .item,
      #network .icon,
      #network .text-icon {
        min-width: 20px;
        margin: 0;
        padding: 0;
        font-family: "${theme.fonts.monospace}";
        font-size: 18px;
        font-weight: 800;
      }

      #bluetooth {
        min-width: 32px;
        padding: 0 6px;
        color: @info;
        font-family: "${theme.fonts.monospace}";
        font-size: 18px;
        font-weight: 800;
      }

      #bluetooth label {
        min-width: 20px;
        margin: 0;
        padding: 0;
        font-family: "${theme.fonts.monospace}";
        font-size: 18px;
        font-weight: 800;
      }

      #brightness {
        min-width: 64px;
        padding: 0 7px;
        color: @thermal;
      }

      #brightness .icon {
        min-width: 20px;
        margin: 0 5px 0 0;
        padding: 0;
        font-family: "${theme.fonts.monospace}";
        font-size: 18px;
        font-weight: 800;
      }

      #brightness .label {
        min-width: 38px;
        margin: 0;
        padding: 0;
        font-size: 11.5px;
        font-weight: 700;
      }

      #battery {
        min-width: 58px;
        color: @success;
        border-right: 1px solid alpha(@line, 0.62);
        border-radius: 0 9px 9px 0;
      }

      #battery.profile-warning {
        color: @warning;
        background-color: alpha(@orange, 0.13);
      }

      #battery.profile-critical {
        color: @critical;
        background-color: alpha(@red, 0.18);
        border-color: alpha(@critical, 0.76);
      }

      #notifications { color: @active; }

      #notifications label {
        font-size: 16px;
      }

      #tray {
        padding: 0;
        background: transparent;
      }

      #tray .item {
        min-width: 22px;
        min-height: 28px;
        margin-left: 5px;
        padding: 0 4px;
        color: @text;
        background-color: alpha(@panel, 0.95);
        border: 1px solid alpha(@line, 0.62);
        border-radius: 9px;
        box-shadow: 0 2px 6px alpha(@base, 0.42);
      }

      #tray .item:hover {
        color: @bright;
        background-color: alpha(@panel-hover, 0.98);
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
        min-width: 10px;
        min-height: 10px;
        padding: 1px;
        color: @bright;
        background: @active;
        border-radius: 99px;
        font-size: 7px;
        font-weight: 700;
      }

      tooltip,
      tooltip.background,
      popover contents,
      .popup {
        color: @text;
        background: alpha(@panel, 0.99);
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
        background: alpha(@surface, 0.70);
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
        background: alpha(@surface, 0.90);
      }

      .popup-clock calendar .other-month {
        color: alpha(@subtext, 0.32);
      }

      .popup-clock calendar .today {
        color: @base;
        background: @active;
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

  systemd.user.services.ironbar = {
    Unit = {
      Description = "Ironbar desktop panel";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
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
