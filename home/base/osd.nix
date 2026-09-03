{ inputs, pkgs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;

  biscuitStyle = pkgs.writeText "swayosd-biscuit.css" ''
    window#osd {
      color: #${c.foreground};
      background: alpha(#${c.background}, 0.96);
      border: 1px solid alpha(#${c.accent}, 0.72);
      border-radius: 16px;
      box-shadow: 0 8px 24px alpha(#${c.background}, 0.72);
    }

    window#osd #container {
      min-width: 260px;
      margin: 12px 16px;
    }

    window#osd image,
    window#osd label {
      color: #${c.bright};
    }

    window#osd label {
      font-family: "${theme.fonts.interface}";
      font-size: 12px;
      font-weight: 600;
    }

    window#osd progressbar:disabled,
    window#osd image:disabled {
      opacity: 0.48;
    }

    window#osd progressbar,
    window#osd segmentedprogress {
      min-height: 8px;
      background: transparent;
      border: none;
      border-radius: 99px;
    }

    window#osd trough,
    window#osd segment {
      min-height: inherit;
      background: #${c.selection};
      border: none;
      border-radius: inherit;
    }

    window#osd progress,
    window#osd segment.active {
      min-height: inherit;
      background: #${c.accent};
      border: none;
      border-radius: inherit;
    }

    window#osd segment {
      margin-left: 7px;
    }

    window#osd segment:first-child {
      margin-left: 0;
    }
  '';
in
{
  services.swayosd = {
    enable = true;
    # Center OSD feedback; 0.5 is the vertical midpoint, while 0.85 positioned
    # volume and brightness feedback near the bottom edge.
    topMargin = 0.5;
    stylePath = biscuitStyle;
  };

  xdg.configFile."swayosd/config.toml".text = ''
    [server]
    min_brightness = 5
    max_volume = 100
    show_percentage = true
  '';
}
