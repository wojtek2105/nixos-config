{ inputs }:

let
  colors = {
    background = "1A1515";
    surface = "2D2424";
    selection = "453636";
    muted = "725A5A";
    subtle = "9C8181";
    foreground = "DCC9BC";
    bright = "FFE9C7";
    red = "CF223E";
    orange = "F07342";
    yellow = "E39C45";
    olive = "959A6B";
    green = "768F80";
    violet = "756D94";
    blue = "614F76";
    magenta = "7B3D79";
    accent = "AE3F82";
  };
in
{
  name = "Biscuit de Mar Dark";

  fonts = {
    interface = "CommitMono Nerd Font Propo";
    monospace = "CommitMono Nerd Font Mono";
    sans = "Inter";
  };

  inherit colors;

  metricPopup = {
    label = colors.subtle;
    value = colors.bright;
    secondary = colors.foreground;
    cpu = colors.violet;
    memory = colors.accent;
    positive = colors.green;
    upload = colors.violet;
    disk = colors.orange;
    gpu = colors.blue;
    vram = colors.magenta;
    thermal = colors.yellow;
    warning = colors.orange;
    critical = colors.red;
  };

  semantic = {
    panel = colors.surface;
    panelHover = colors.selection;
    border = colors.muted;
    active = colors.accent;
    info = colors.violet;
    success = colors.green;
    warning = colors.orange;
    thermal = colors.yellow;
    critical = colors.red;
  };

  # Lists are synchronized by index: every position names the same scene in
  # three aspect families. Hyprland selects the family matching the monitor,
  # while the shared index keeps the same scene on mixed-aspect displays.
  wallpapers = {
    aspect16x9 = [
      ./wallpapers/16x9/14-blood-certificate-domain.png
    ];
    aspect21x9 = [
      ./wallpapers/21x9/14-blood-certificate-domain.png
    ];
    aspect32x9 = [
      ./wallpapers/32x9/14-blood-certificate-domain.png
    ];
  };
  gtkTheme = "biscuit-dark";
  gtkThemeSource = "${inputs.biscuit-gtk}/biscuit-dark";
  iconTheme = "papirus-biscuit-dark";
  iconThemeSource = "${inputs.biscuit-gtk}/papirus-biscuit-dark";
}
