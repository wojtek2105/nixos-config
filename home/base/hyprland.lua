-- Declarative Hyprland Lua configuration, installed by Home Manager.

local mod = "SUPER"
local terminal = "foot"
local file_manager = "yazi-file-manager"
local menu = "fuzzel"

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = @UI_SCALE@,
})

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.config({
  input = {
    kb_layout = "pl",
    -- Voxtype may reserve Caps Lock for its separate evdev hotkey listener.
    kb_options = "@KEYBOARD_OPTIONS@",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
    },
  },
  xwayland = {
    force_zero_scaling = true,
  },
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    resize_on_border = true,
    layout = "dwindle",
    col = {
      active_border = {
        colors = { "rgba(@ACTIVE_BORDER@ff)", "rgba(@ACTIVE_BORDER_ALT@ff)" },
        angle = 45,
      },
      inactive_border = "rgba(@INACTIVE_BORDER@aa)",
    },
  },
  decoration = {
    rounding = 12,
    rounding_power = 2,
    active_opacity = 1.0,
    inactive_opacity = 0.96,
    fullscreen_opacity = 1.0,
    blur = {
      enabled = true,
      size = 8,
      passes = 3,
      vibrancy = 0.2,
    },
    shadow = {
      enabled = true,
      range = 18,
      render_power = 3,
      color = "rgba(@SHADOW@99)",
    },
  },
  animations = {
    enabled = true,
  },
  dwindle = {
    preserve_split = true,
  },
  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
    focus_on_activate = false,
  },
})

hl.curve("easeOutQuint", {
  type = "bezier",
  points = { { 0.23, 1 }, { 0.32, 1 } },
})
hl.curve("easeInOutCubic", {
  type = "bezier",
  points = { { 0.65, 0.05 }, { 0.36, 1 } },
})

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "easeInOutCubic", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })

hl.on("hyprland.start", function()
  -- UWSM is the sole session manager. Export Hyprland's Wayland and IPC
  -- variables and notify its compositor unit that startup completed.
  hl.exec_cmd("@UWSM_FINALIZE@")
  hl.exec_cmd("@POLKIT_AGENT@")
end)

local function bind_exec(keys, command, options)
  hl.bind(keys, hl.dsp.exec_cmd(command), options)
end

bind_exec(mod .. " + RETURN", terminal)
bind_exec(mod .. " + E", file_manager)
bind_exec(mod .. " + ALT + E", "thunar")
bind_exec(mod .. " + B", "zen-run-or-raise")
bind_exec(mod .. " + SPACE", menu)
bind_exec(mod .. " + D", "global-menu")
bind_exec(mod .. " + N", "swaync-client -t -sw")
bind_exec(mod .. " + L", "hyprlock")
bind_exec(mod .. " + F1", "shortcut-menu")
bind_exec(mod .. " + ESCAPE", "power-menu")
@BIND_PERSONAL_APPS@

@BIND_SCREEN_RECORDING@
bind_exec(mod .. " + SHIFT + V", "clipboard-history")

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + S", hl.dsp.layout("togglesplit"))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
  hl.bind(mod .. " + " .. direction, hl.dsp.focus({ direction = direction }))
  hl.bind(mod .. " + SHIFT + " .. direction, hl.dsp.window.move({ direction = direction }))
end

hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))

for workspace = 1, 10 do
  local key = workspace % 10
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

bind_exec("Print", "screenshot-menu select")
bind_exec("SHIFT + Print", "screenshot-menu window")
bind_exec("CTRL + Print", "screenshot-menu full")
bind_exec(mod .. " + SHIFT + S", "screenshot-menu")
bind_exec(mod .. " + CTRL + S", "screensaver")

bind_exec("XF86AudioRaiseVolume", "swayosd-client --output-volume=+5 --max-volume=100", { locked = true, repeating = true })
bind_exec("XF86AudioLowerVolume", "swayosd-client --output-volume=-5 --max-volume=100", { locked = true, repeating = true })
bind_exec("XF86AudioMute", "swayosd-client --output-volume=mute-toggle --max-volume=100", { locked = true, repeating = true })
@BIND_LAPTOP@
bind_exec("XF86AudioPlay", "playerctl play-pause", { locked = true })
bind_exec("XF86AudioNext", "playerctl next", { locked = true })
bind_exec("XF86AudioPrev", "playerctl previous", { locked = true })

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.window_rule({
  name = "center-tui-utilities",
  match = { class = "^(desktop-metrics|desktop-audio|desktop-wifi|desktop-bluetooth|desktop-docker)$" },
  float = true,
  center = true,
})
hl.window_rule({
  name = "float-steam-dialogs",
  match = {
    class = "^steam$",
    title = "^(Friends List|Steam Settings|Special Offers)$",
  },
  float = true,
})
hl.window_rule({
  name = "immediate-games",
  match = { class = "^steam_app_.*$" },
  immediate = true,
})
hl.window_rule({
  name = "screensaver",
  match = { class = "^org.polamaniec.screensaver$" },
  float = true,
  fullscreen = true,
  -- Foot owns input while the saver is visible and closes itself after the
  -- first keyboard or pointer report. Hypridle must not kill it on the resume
  -- event generated while the fullscreen window itself is being mapped.
})
