{ inputs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
in
{
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      EnableTrackingProtection = {
        Value = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      ExtensionSettings = {
        "addon@darkreader.org" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          default_area = "navbar";
          private_browsing = true;
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          default_area = "navbar";
          private_browsing = true;
        };
      };
    };

    # Reuse the existing profile so history, sessions and bookmarks stay in
    # place. Home Manager owns only the declarative CSS and preferences below.
    profiles."Default Profile" = {
      id = 0;
      path = "ytjrlmux.Default Profile";
      isDefault = true;

      settings = {
        "browser.theme.content-theme" = 0;
        "browser.theme.toolbar-theme" = 0;
        "layout.css.prefers-color-scheme.content-override" = 0;
        "ui.systemUsesDarkTheme" = 1;
        "zen.urlbar.behavior" = "float";
        "zen.view.compact.enable-at-startup" = false;
      };

      userChrome = ''
        :root {
          --biscuit-base: #${c.background};
          --biscuit-surface: #${c.surface};
          --biscuit-selection: #${c.selection};
          --biscuit-muted: #${c.muted};
          --biscuit-subtle: #${c.subtle};
          --biscuit-text: #${c.foreground};
          --biscuit-bright: #${c.bright};
          --biscuit-accent: #${c.accent};
          --biscuit-yellow: #${c.yellow};

          --zen-colors-primary: var(--biscuit-surface) !important;
          --zen-primary-color: var(--biscuit-accent) !important;
          --zen-main-browser-background: var(--biscuit-base) !important;
          --zen-main-browser-background-toolbar: var(--biscuit-surface) !important;
          --zen-webview-border-radius: 12px !important;
          --toolbar-bgcolor: var(--biscuit-base) !important;
          --toolbar-color: var(--biscuit-text) !important;
          --toolbar-field-background-color: var(--biscuit-surface) !important;
          --toolbar-field-color: var(--biscuit-text) !important;
          --toolbar-field-focus-background-color: var(--biscuit-selection) !important;
          --toolbar-field-focus-color: var(--biscuit-bright) !important;
          --toolbar-field-border-color: color-mix(in srgb, var(--biscuit-muted) 72%, transparent) !important;
          --toolbar-field-focus-border-color: var(--biscuit-accent) !important;
          --lwt-accent-color: var(--biscuit-base) !important;
          --lwt-text-color: var(--biscuit-text) !important;
          --arrowpanel-background: var(--biscuit-surface) !important;
          --arrowpanel-color: var(--biscuit-text) !important;
          --arrowpanel-border-color: var(--biscuit-muted) !important;
          --button-hover-bgcolor: color-mix(in srgb, var(--biscuit-selection) 88%, transparent) !important;
          --button-active-bgcolor: color-mix(in srgb, var(--biscuit-accent) 34%, var(--biscuit-selection)) !important;
          --tab-selected-bgcolor: color-mix(in srgb, var(--biscuit-accent) 30%, var(--biscuit-selection)) !important;
        }

        #navigator-toolbox,
        #zen-main-app-wrapper,
        #zen-appcontent-wrapper,
        #zen-sidebar-splitter,
        #titlebar {
          color: var(--biscuit-text) !important;
          background-color: var(--biscuit-base) !important;
        }

        #navigator-toolbox,
        #titlebar,
        #zen-sidebar-top-buttons,
        #zen-sidebar-foot-buttons {
          font-family: "${theme.fonts.sans}" !important;
          font-size: 12px !important;
        }

        #navigator-toolbox {
          border: none !important;
        }

        #nav-bar {
          color: var(--biscuit-text) !important;
          background: var(--biscuit-base) !important;
          border: none !important;
          box-shadow: none !important;
        }

        #urlbar-container {
          margin-block: 3px !important;
        }

        #urlbar-background {
          background: color-mix(in srgb, var(--biscuit-surface) 96%, transparent) !important;
          border: 1px solid color-mix(in srgb, var(--biscuit-muted) 68%, transparent) !important;
          border-radius: 12px !important;
          box-shadow: 0 3px 12px color-mix(in srgb, var(--biscuit-base) 72%, transparent) !important;
        }

        #urlbar[focused] > #urlbar-background,
        #urlbar[open] > #urlbar-background {
          background: var(--biscuit-selection) !important;
          border-color: var(--biscuit-accent) !important;
          box-shadow: 0 0 0 2px color-mix(in srgb, var(--biscuit-accent) 24%, transparent),
                      0 8px 24px color-mix(in srgb, var(--biscuit-base) 78%, transparent) !important;
        }

        #urlbar-input {
          color: var(--biscuit-bright) !important;
          font-family: "${theme.fonts.sans}" !important;
          font-size: 13px !important;
          font-weight: 500 !important;
        }

        .urlbarView {
          color: var(--biscuit-text) !important;
          background: var(--biscuit-surface) !important;
          border-radius: 0 0 12px 12px !important;
        }

        .urlbarView-row {
          border-radius: 9px !important;
          margin: 2px 6px !important;
        }

        .urlbarView-row:hover,
        .urlbarView-row[selected] {
          color: var(--biscuit-bright) !important;
          background: color-mix(in srgb, var(--biscuit-accent) 28%, var(--biscuit-selection)) !important;
        }

        #nav-bar toolbarbutton,
        #zen-sidebar-top-buttons toolbarbutton,
        #zen-sidebar-foot-buttons toolbarbutton {
          color: var(--biscuit-text) !important;
          border: 1px solid transparent !important;
          border-radius: 10px !important;
          margin: 2px 1px !important;
        }

        #nav-bar toolbarbutton:hover,
        #zen-sidebar-top-buttons toolbarbutton:hover,
        #zen-sidebar-foot-buttons toolbarbutton:hover {
          color: var(--biscuit-bright) !important;
          background: var(--biscuit-selection) !important;
          border-color: color-mix(in srgb, var(--biscuit-muted) 56%, transparent) !important;
        }

        #titlebar,
        #zen-tabs-wrapper {
          background: var(--biscuit-base) !important;
        }

        .tabbrowser-tab .tab-background {
          background: transparent !important;
          border: 1px solid transparent !important;
          border-radius: 10px !important;
          margin-block: 2px !important;
          box-shadow: none !important;
        }

        .tabbrowser-tab:hover .tab-background {
          background: color-mix(in srgb, var(--biscuit-selection) 78%, transparent) !important;
          border-color: color-mix(in srgb, var(--biscuit-muted) 44%, transparent) !important;
        }

        .tabbrowser-tab[selected] .tab-background {
          background: color-mix(in srgb, var(--biscuit-accent) 28%, var(--biscuit-selection)) !important;
          border-color: color-mix(in srgb, var(--biscuit-accent) 78%, var(--biscuit-muted)) !important;
          box-shadow: 0 3px 10px color-mix(in srgb, var(--biscuit-base) 62%, transparent) !important;
        }

        .tabbrowser-tab .tab-label {
          color: var(--biscuit-text) !important;
          font-family: "${theme.fonts.sans}" !important;
          font-size: 12px !important;
          font-weight: 500 !important;
        }

        .tabbrowser-tab[selected] .tab-label {
          color: var(--biscuit-bright) !important;
          font-weight: 700 !important;
        }

        .tab-close-button {
          border-radius: 8px !important;
        }

        #zen-sidebar-top-buttons,
        #zen-sidebar-foot-buttons {
          background: color-mix(in srgb, var(--biscuit-surface) 86%, transparent) !important;
          border: 1px solid color-mix(in srgb, var(--biscuit-muted) 46%, transparent) !important;
          border-radius: 12px !important;
          padding: 3px !important;
          margin: 4px !important;
        }

        menupopup,
        panelmultiview,
        .panel-arrowcontent {
          color: var(--biscuit-text) !important;
          background: var(--biscuit-surface) !important;
          border-color: var(--biscuit-muted) !important;
          border-radius: 13px !important;
        }

        menu,
        menuitem,
        .subviewbutton {
          color: var(--biscuit-text) !important;
          border-radius: 9px !important;
          margin: 2px 4px !important;
        }

        menu:hover,
        menuitem:hover,
        .subviewbutton:hover {
          color: var(--biscuit-bright) !important;
          background: var(--biscuit-selection) !important;
        }

        #statuspanel-label {
          color: var(--biscuit-text) !important;
          background: var(--biscuit-surface) !important;
          border: 1px solid var(--biscuit-muted) !important;
          border-radius: 0 10px 0 0 !important;
          padding: 5px 9px !important;
        }
      '';

      userContent = ''
        @-moz-document url("about:home"), url("about:newtab"), url("about:privatebrowsing") {
          :root {
            --newtab-background-color: #${c.background} !important;
            --newtab-background-color-secondary: #${c.surface} !important;
            --newtab-text-primary-color: #${c.bright} !important;
            --newtab-text-secondary-color: #${c.foreground} !important;
            --newtab-primary-action-background: #${c.accent} !important;
            --newtab-primary-element-hover-color: #${c.selection} !important;
          }

          body {
            color: #${c.foreground} !important;
            background: radial-gradient(circle at 50% -20%, #${c.selection} 0%, #${c.surface} 28%, #${c.background} 66%) !important;
            font-family: "${theme.fonts.sans}" !important;
          }

          .search-handoff-button,
          .search-wrapper input {
            color: #${c.bright} !important;
            background: color-mix(in srgb, #${c.surface} 96%, transparent) !important;
            border: 1px solid #${c.muted} !important;
            border-radius: 14px !important;
            box-shadow: 0 8px 24px color-mix(in srgb, #${c.background} 72%, transparent) !important;
          }

          .top-site-outer .tile,
          .card-outer {
            background: #${c.surface} !important;
            border: 1px solid color-mix(in srgb, #${c.muted} 62%, transparent) !important;
            border-radius: 14px !important;
            box-shadow: 0 6px 18px color-mix(in srgb, #${c.background} 68%, transparent) !important;
          }

          .top-site-outer:hover .tile,
          .card-outer:hover {
            background: #${c.selection} !important;
            border-color: #${c.accent} !important;
          }
        }

        @-moz-document url-prefix("about:preferences"), url-prefix("about:addons"), url-prefix("about:logins") {
          :root {
            --in-content-page-background: #${c.background} !important;
            --in-content-page-color: #${c.foreground} !important;
            --in-content-text-color: #${c.foreground} !important;
            --in-content-deemphasized-text: #${c.subtle} !important;
            --in-content-box-background: #${c.surface} !important;
            --in-content-box-border-color: #${c.muted} !important;
            --in-content-border-color: #${c.muted} !important;
            --in-content-primary-button-background: #${c.accent} !important;
            --in-content-primary-button-background-hover: #${c.magenta} !important;
            --in-content-focus-outline-color: #${c.yellow} !important;
            --in-content-link-color: #${c.yellow} !important;
          }

          body {
            font-family: "${theme.fonts.sans}" !important;
          }
        }
      '';
    };
  };
}
