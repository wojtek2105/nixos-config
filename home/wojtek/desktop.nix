{ inputs, pkgs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
in
{
  home.packages = with pkgs; [
    bluetui
    easyeffects
    plexamp
    wiremix
  ];

  programs.foot = {
    enable = true;
    settings = {
      main = {
        term = "foot";
        font = "${theme.fonts.monospace}:size=12";
        pad = "12x12";
        dpi-aware = "yes";
      };
      bell.system = "no";
      cursor.style = "beam";
      "colors-dark" = {
        alpha = 0.94;
        foreground = c.foreground;
        background = c.background;
        selection-foreground = c.foreground;
        selection-background = c.selection;
        cursor = "${c.background} ${c.bright}";
        regular0 = c.background;
        regular1 = c.orange;
        regular2 = c.green;
        regular3 = c.olive;
        regular4 = c.blue;
        regular5 = c.magenta;
        regular6 = c.violet;
        regular7 = c.foreground;
        bright0 = c.muted;
        bright1 = c.orange;
        bright2 = c.green;
        bright3 = c.olive;
        bright4 = c.blue;
        bright5 = c.magenta;
        bright6 = c.violet;
        bright7 = c.bright;
      };
    };
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "${theme.fonts.sans} Medium,${theme.fonts.interface}:size=12";
        terminal = "foot";
        layer = "overlay";
        dpi-aware = "no";
        use-bold = true;
        width = 46;
        lines = 9;
        line-height = 28;
        letter-spacing = 0.5;
        horizontal-pad = 22;
        vertical-pad = 16;
        inner-pad = 12;
        icon-theme = theme.iconTheme;
      };
      colors = {
        background = "${c.background}fa";
        text = "${c.foreground}ff";
        prompt = "${c.yellow}ff";
        placeholder = "${c.subtle}ff";
        input = "${c.bright}ff";
        match = "${c.orange}ff";
        selection = "${c.selection}ff";
        selection-text = "${c.bright}ff";
        selection-match = "${c.yellow}ff";
        counter = "${c.subtle}ff";
        border = "${c.accent}ff";
      };
      border = {
        width = 2;
        radius = 14;
        selection-radius = 10;
      };
    };
  };

  # Foot ships three desktop entries in one package. Keep the regular terminal
  # visible and hide the implementation-oriented server/client launchers.
  xdg.desktopEntries = {
    foot-server = {
      name = "Foot Server";
      exec = "foot --server";
      icon = "foot";
      noDisplay = true;
    };
    footclient = {
      name = "Foot Client";
      exec = "footclient";
      icon = "foot";
      noDisplay = true;
    };
  };

  gtk = {
    enable = true;
    theme.name = theme.gtkTheme;
    font = {
      name = theme.fonts.sans;
      size = 11;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    iconTheme = {
      name = theme.iconTheme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Amber";
      package = pkgs.bibata-cursors;
      size = 24;
    };
  };

  # Qt applications use the same GTK theme, icons and font instead of growing
  # a separate, visually inconsistent desktop stack.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = theme.gtkTheme;
  };

  home.file = {
    ".themes/${theme.gtkTheme}".source = theme.gtkThemeSource;
    ".icons/${theme.iconTheme}".source = theme.iconThemeSource;
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    hyprcursor.enable = true;
    name = "Bibata-Modern-Amber";
    package = pkgs.bibata-cursors;
    size = 24;
  };
}
