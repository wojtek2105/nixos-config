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

  # Every regular PNG below an aspect directory joins the rotation after the
  # next activation. Sort by filename rather than subdirectory so grouping by
  # universe cannot desynchronize the shared scene index across aspect families.
  wallpapers = let
    wallpapersIn = directory:
      let
        collectPngs = current:
          let
            entries = builtins.readDir current;
          in
          lib.concatMap
            (name:
              let
                entryType = entries.${name};
                path = current + "/${name}";
              in
              if entryType == "directory" then
                collectPngs path
              else
                lib.optional
                  (entryType == "regular" && builtins.match ".*[.]png" name != null)
                  path)
            (builtins.attrNames entries);

        byFilename = left: right:
          let
            leftName = builtins.baseNameOf (toString left);
            rightName = builtins.baseNameOf (toString right);
          in
          if leftName == rightName then
            toString left < toString right
          else
            leftName < rightName;
      in
      builtins.sort byFilename (collectPngs directory);

  in {
    aspect16x9 = wallpapersIn ./wallpapers/16x9;
    aspect21x9 = wallpapersIn ./wallpapers/21x9;
    aspect32x9 = wallpapersIn ./wallpapers/32x9;
  };

  gtkTheme = "biscuit-dark";
  gtkThemeSource = "${inputs.biscuit-gtk}/biscuit-dark";
  iconTheme = "papirus-biscuit-dark";
  iconThemeSource = "${inputs.biscuit-gtk}/papirus-biscuit-dark";
}
