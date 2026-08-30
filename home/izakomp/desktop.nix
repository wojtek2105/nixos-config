{ config, desktopFeatures, inputs, lib, pkgs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
  personalApps = desktopFeatures.personalApps or { };
  easyeffectsEnabled = personalApps.easyeffects or false;
  plexampEnabled = personalApps.plexamp or false;

  yazi-file-manager = pkgs.writeShellApplication {
    name = "yazi-file-manager";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.foot
      config.programs.neovim.finalPackage
      config.programs.yazi.finalPackage
    ];
    text = ''
      target="''${1:-$HOME}"
      if [[ ! -d "$target" ]]; then
        target="$(dirname -- "$target")"
      fi

      # Do not depend on whether the graphical session imported shell startup
      # variables before launching Foot/Yazi.
      export EDITOR=nvim
      export VISUAL=nvim

      exec foot \
        --app-id=org.polamaniec.yazi \
        --title=Yazi \
        --override=main.pad=6x6 \
        -e yazi "$target"
    '';
  };
  usb-capture-viewer = pkgs.writeShellApplication {
    name = "usb-capture-viewer";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.mpv
      pkgs.v4l-utils
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${../../tools/hardware/usb-capture-viewer.sh} "$@"
    '';
  };
in
{
  home.packages =
    [
      pkgs.swayimg
      yazi-file-manager
      usb-capture-viewer
    ]
    ++ lib.optionals easyeffectsEnabled [ pkgs.easyeffects ]
    ++ lib.optionals plexampEnabled [ pkgs.plexamp ];

  # Ironbar provides native, event-driven network and Bluetooth widgets. Hide
  # the legacy XDG tray applets while keeping NetworkManager and BlueZ intact.
  services.network-manager-applet.enable = false;
  services.blueman-applet.enable = false;

  xdg.configFile = {
    "autostart/nm-applet.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=NetworkManager Applet
      Hidden=true
    '';
    "autostart/blueman.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Blueman Applet
      Hidden=true
    '';
  };

  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      thumbfast
      uosc
    ];
    config = {
      osc = false;
      osd-bar = false;
      border = false;
      force-window = "immediate";
      hwdec = "auto-safe";
      vo = "gpu-next";
      gpu-api = "vulkan";
      keep-open = true;
      image-display-duration = "inf";
      save-position-on-quit = true;
      alang = "pl,pol,en,eng";
      slang = "pl,pol,en,eng";
      sub-auto = "fuzzy";
      osd-font = theme.fonts.sans;
      volume-max = 100;
    };
    scriptOpts.uosc = {
      autoload = true;
      animation_duration = 100;
      border_radius = 10;
      color = builtins.concatStringsSep "," [
        "foreground=${c.foreground}"
        "foreground_text=${c.background}"
        "background=${c.background}"
        "background_text=${c.foreground}"
        "window_border=${c.accent}"
        "curtain=${c.surface}"
        "success=${c.green}"
        "error=${c.red}"
        "match=${c.orange}"
        "heatmap=${c.magenta}"
      ];
      languages = "pl,slang,en";
      top_bar_flash_on = "video,audio,image";
    };
  };

  programs.yazi = {
    enable = true;
    package = pkgs.yazi.override {
      _7zz = pkgs._7zz-rar;
    };
    enableFishIntegration = true;
    shellWrapperName = "y";
    extraPackages = with pkgs; [
      udisks2
      util-linux
      wl-clipboard
    ];

    settings = {
      opener = {
        edit = [
          {
            run = "${config.programs.neovim.finalPackage}/bin/nvim %s";
            block = true;
            for = "unix";
            desc = "Edytuj w Neovim";
          }
        ];
        image = [
          {
            run = "${pkgs.swayimg}/bin/swayimg %s";
            orphan = true;
            for = "unix";
            desc = "Pokaż w Swayimg";
          }
        ];
      };
      open.prepend_rules = [
        {
          mime = "image/*";
          use = "image";
        }
      ];
      mgr = {
        ratio = [ 1 4 4 ];
        sort_by = "natural";
        sort_sensitive = false;
        sort_reverse = false;
        sort_dir_first = true;
        sort_translit = true;
        linemode = "size";
        show_hidden = false;
        show_symlink = true;
        scrolloff = 5;
      };
      preview = {
        wrap = "yes";
        tab_size = 2;
        max_width = 1600;
        max_height = 1600;
        image_delay = 20;
        image_filter = "triangle";
        image_quality = 80;
      };
      plugin.prepend_fetchers = [
        {
          url = "*";
          run = "git";
          group = "git";
        }
        {
          url = "*/";
          run = "git";
          group = "git";
        }
      ];
    };

    plugins = {
      chmod = pkgs.yaziPlugins.chmod;
      diff = pkgs.yaziPlugins.diff;
      full-border = {
        package = pkgs.yaziPlugins.full-border;
        setup = true;
        settings.type = lib.generators.mkLuaInline "ui.Border.ROUNDED";
      };
      git = {
        package = pkgs.yaziPlugins.git;
        setup = true;
        settings.order = 1500;
      };
      jump-to-char = pkgs.yaziPlugins.jump-to-char;
      mount = pkgs.yaziPlugins.mount;
      smart-enter = pkgs.yaziPlugins.smart-enter;
      smart-filter = pkgs.yaziPlugins.smart-filter;
      smart-paste = pkgs.yaziPlugins.smart-paste;
      toggle-pane = pkgs.yaziPlugins.toggle-pane;
      vcs-files = pkgs.yaziPlugins.vcs-files;
      zoom = pkgs.yaziPlugins.zoom;
    };

    keymap.mgr.prepend_keymap = [
      {
        on = [ "<Enter>" ];
        run = "plugin smart-enter";
        desc = "Otwórz plik albo wejdź do katalogu";
      }
      {
        on = [ "f" ];
        run = "plugin jump-to-char";
        desc = "Skocz do pliku według pierwszego znaku";
      }
      {
        on = [ "F" ];
        run = "plugin smart-filter";
        desc = "Inteligentne filtrowanie";
      }
      {
        on = [ "p" ];
        run = "plugin smart-paste";
        desc = "Wklej do wskazanego katalogu";
      }
      {
        on = [ "g" "c" ];
        run = "plugin vcs-files";
        desc = "Pokaż pliki zmienione w Git";
      }
      {
        on = [ "<C-d>" ];
        run = "plugin diff";
        desc = "Porównaj zaznaczony plik ze wskazanym";
      }
      {
        on = [ "M" ];
        run = "plugin mount";
        desc = "Montowanie i odłączanie nośników";
      }
      {
        on = [ "c" "m" ];
        run = "plugin chmod";
        desc = "Zmień uprawnienia";
      }
      {
        on = [ "T" ];
        run = "plugin toggle-pane min-preview";
        desc = "Pokaż lub ukryj podgląd";
      }
      {
        on = [ "t" "p" ];
        run = "plugin toggle-pane max-preview";
        desc = "Zmaksymalizuj lub przywróć podgląd";
      }
      {
        on = [ "+" ];
        run = "plugin zoom 1";
        desc = "Powiększ podgląd obrazu";
      }
      {
        on = [ "-" ];
        run = "plugin zoom -1";
        desc = "Pomniejsz podgląd obrazu";
      }
      {
        on = [ "c" "l" ];
        run = "link";
        desc = "Utwórz dowiązanie bezwzględne";
      }
      {
        on = [ "c" "L" ];
        run = "link --relative";
        desc = "Utwórz dowiązanie względne";
      }
    ];

    theme = {
      app.overall = {
        fg = "#${c.foreground}";
        bg = "#${c.background}";
      };
      mgr = {
        cwd = {
          fg = "#${c.bright}";
          bold = true;
        };
        find_keyword = {
          fg = "#${c.yellow}";
          bold = true;
          italic = true;
          underline = true;
        };
        find_position = {
          fg = "#${c.accent}";
          bg = "reset";
          bold = true;
        };
        symlink_target = {
          fg = "#${c.violet}";
          italic = true;
        };
        marker_copied = {
          fg = "#${c.green}";
          bg = "#${c.green}";
        };
        marker_cut = {
          fg = "#${c.red}";
          bg = "#${c.red}";
        };
        marker_marked = {
          fg = "#${c.accent}";
          bg = "#${c.accent}";
        };
        marker_selected = {
          fg = "#${c.yellow}";
          bg = "#${c.yellow}";
        };
        marker_symbol = "│";
        count_copied = {
          fg = "#${c.background}";
          bg = "#${c.green}";
          bold = true;
        };
        count_cut = {
          fg = "#${c.bright}";
          bg = "#${c.red}";
          bold = true;
        };
        count_selected = {
          fg = "#${c.background}";
          bg = "#${c.yellow}";
          bold = true;
        };
        border_symbol = "│";
        border_style.fg = "#${c.muted}";
      };
      tabs = {
        active = {
          fg = "#${c.bright}";
          bg = "#${c.accent}";
          bold = true;
        };
        inactive = {
          fg = "#${c.subtle}";
          bg = "#${c.surface}";
        };
        sep_inner = {
          open = "";
          close = "";
        };
        sep_outer = {
          open = "";
          close = "";
        };
      };
      mode = {
        normal_main = {
          fg = "#${c.background}";
          bg = "#${c.accent}";
          bold = true;
        };
        normal_alt = {
          fg = "#${c.accent}";
          bg = "#${c.surface}";
        };
        select_main = {
          fg = "#${c.background}";
          bg = "#${c.yellow}";
          bold = true;
        };
        select_alt = {
          fg = "#${c.yellow}";
          bg = "#${c.surface}";
        };
        unset_main = {
          fg = "#${c.bright}";
          bg = "#${c.red}";
          bold = true;
        };
        unset_alt = {
          fg = "#${c.red}";
          bg = "#${c.surface}";
        };
      };
      indicator = {
        parent.reversed = true;
        current = {
          fg = "#${c.bright}";
          bg = "#${c.selection}";
          bold = true;
        };
        preview = {
          fg = "#${c.yellow}";
          underline = true;
        };
        padding = {
          open = "";
          close = "";
        };
      };
      status = {
        overall = {
          fg = "#${c.foreground}";
          bg = "#${c.background}";
        };
        sep_left = {
          open = "";
          close = "";
        };
        sep_right = {
          open = "";
          close = "";
        };
        perm_sep.fg = "#${c.muted}";
        perm_type.fg = "#${c.green}";
        perm_read.fg = "#${c.yellow}";
        perm_write.fg = "#${c.red}";
        perm_exec.fg = "#${c.violet}";
        progress_label = {
          fg = "#${c.bright}";
          bold = true;
        };
        progress_normal = {
          fg = "#${c.green}";
          bg = "#${c.surface}";
        };
        progress_error = {
          fg = "#${c.bright}";
          bg = "#${c.red}";
        };
      };
      which = {
        border.fg = "#${c.accent}";
        cols = 3;
        mask.bg = "#${c.surface}";
        cand = {
          fg = "#${c.yellow}";
          bold = true;
        };
        rest.fg = "#${c.subtle}";
        desc.fg = "#${c.foreground}";
        separator = "    ";
        separator_style.fg = "#${c.muted}";
      };
      confirm = {
        border.fg = "#${c.accent}";
        title = {
          fg = "#${c.bright}";
          bold = true;
        };
        body.fg = "#${c.foreground}";
        list.fg = "#${c.subtle}";
        btn_yes = {
          fg = "#${c.background}";
          bg = "#${c.green}";
          bold = true;
        };
        btn_no = {
          fg = "#${c.bright}";
          bg = "#${c.red}";
          bold = true;
        };
      };
      spot = {
        border.fg = "#${c.accent}";
        title = {
          fg = "#${c.bright}";
          bold = true;
        };
        tbl_col.fg = "#${c.violet}";
        tbl_cell = {
          fg = "#${c.bright}";
          bg = "#${c.selection}";
        };
      };
      notify = {
        title_info.fg = "#${c.green}";
        title_warn.fg = "#${c.yellow}";
        title_error = {
          fg = "#${c.red}";
          bold = true;
        };
      };
      pick = {
        border.fg = "#${c.accent}";
        active = {
          fg = "#${c.yellow}";
          bold = true;
        };
        inactive.fg = "#${c.subtle}";
      };
      input = {
        border.fg = "#${c.accent}";
        title = {
          fg = "#${c.bright}";
          bold = true;
        };
        value.fg = "#${c.foreground}";
        selected = {
          fg = "#${c.bright}";
          bg = "#${c.selection}";
        };
      };
      cmp = {
        border.fg = "#${c.accent}";
        active = {
          fg = "#${c.bright}";
          bg = "#${c.selection}";
          bold = true;
        };
        inactive.fg = "#${c.subtle}";
      };
      tasks = {
        border.fg = "#${c.accent}";
        title = {
          fg = "#${c.bright}";
          bold = true;
        };
        hovered = {
          fg = "#${c.yellow}";
          bg = "#${c.selection}";
          bold = true;
        };
      };
      help = {
        border.fg = "#${c.accent}";
        chord = {
          fg = "#${c.yellow}";
          bold = true;
        };
        action.fg = "#${c.foreground}";
        hovered = {
          fg = "#${c.bright}";
          bg = "#${c.selection}";
          bold = true;
        };
      };
      filetype.rules = [
        {
          mime = "**/image/*";
          fg = "#${c.yellow}";
        }
        {
          mime = "**/{audio,video}/*";
          fg = "#${c.magenta}";
        }
        {
          mime = "**/application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
          fg = "#${c.orange}";
        }
        {
          mime = "**/application/{pdf,doc,rtf}";
          fg = "#${c.violet}";
        }
        {
          mime = "vfs/{absent,stale}";
          fg = "#${c.muted}";
        }
        {
          url = "*";
          is = "orphan";
          bg = "#${c.red}";
        }
        {
          url = "*";
          is = "exec";
          fg = "#${c.green}";
          bold = true;
        }
        {
          url = "*/";
          fg = "#${c.accent}";
          bold = true;
        }
      ];
      git = {
        unknown.fg = "#${c.muted}";
        ignored.fg = "#${c.muted}";
        untracked = {
          fg = "#${c.magenta}";
          bold = true;
        };
        unstaged = {
          fg = "#${c.yellow}";
          bold = true;
        };
        staged = {
          fg = "#${c.green}";
          bold = true;
        };
        added = {
          fg = "#${c.green}";
          bold = true;
        };
        deleted = {
          fg = "#${c.red}";
          bold = true;
        };
        updated = {
          fg = "#${c.orange}";
          bold = true;
        };
        clean.fg = "#${c.subtle}";
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/avif" = [ "swayimg.desktop" ];
      "image/bmp" = [ "swayimg.desktop" ];
      "image/gif" = [ "swayimg.desktop" ];
      "image/heic" = [ "swayimg.desktop" ];
      "image/heif" = [ "swayimg.desktop" ];
      "image/jpeg" = [ "swayimg.desktop" ];
      "image/jxl" = [ "swayimg.desktop" ];
      "image/png" = [ "swayimg.desktop" ];
      "image/svg+xml" = [ "swayimg.desktop" ];
      "image/tiff" = [ "swayimg.desktop" ];
      "image/webp" = [ "swayimg.desktop" ];
      "image/x-exr" = [ "swayimg.desktop" ];
      "inode/directory" = [ "org.polamaniec.Yazi.desktop" ];
      "video/mp4" = [ "mpv.desktop" ];
      "video/mpeg" = [ "mpv.desktop" ];
      "video/ogg" = [ "mpv.desktop" ];
      "video/quicktime" = [ "mpv.desktop" ];
      "video/webm" = [ "mpv.desktop" ];
      "video/x-matroska" = [ "mpv.desktop" ];
      "video/x-msvideo" = [ "mpv.desktop" ];
    };
  };

  programs.foot = {
    enable = true;
    settings = {
      main = {
        term = "foot";
        font = "${theme.fonts.monospace}:size=12";
        pad = "12x12";
        dpi-aware = "yes";
      };
      bell = {
        system = "no";
        urgent = "yes";
      };
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
        line-height = 34;
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

  # Register the graphical Yazi launcher. Foot ships three desktop entries in
  # one package, so keep only the regular terminal visible in application menus.
  xdg.desktopEntries = {
    "org.polamaniec.Yazi" = {
      name = "Yazi";
      genericName = "Menedżer plików";
      comment = "Szybki terminalowy menedżer plików";
      exec = "yazi-file-manager %F";
      icon = "system-file-manager";
      terminal = false;
      startupNotify = false;
      categories = [
        "System"
        "FileTools"
        "FileManager"
      ];
      mimeType = [ "inode/directory" ];
      settings.Keywords = "files;folders;explorer;yazi;pliki;katalogi;";
    };
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
