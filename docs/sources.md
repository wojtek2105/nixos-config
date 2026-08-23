# Źródła

Preferowane są oficjalne repozytoria GitHub i dokumentacja pierwotna.

## GitHub

- [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) — pakiety i moduły NixOS.
- [Moduł NixOS dla GPU Screen Recordera](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/gpu-screen-recorder.nix) — integracja, pakiet UI i wymagane wrappery capabilities.
- [Pakiet GPU Screen Recorder UI w nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/gp/gpu-screen-recorder-ui/package.nix) — sposób budowania oficjalnego upstreamu.
- [nix-community/home-manager](https://github.com/nix-community/home-manager) — konfiguracja użytkownika.
- [0xc000022070/zen-browser-flake](https://github.com/0xc000022070/zen-browser-flake) — pakiet i moduł Home Manager dla Zen Browser.
- [Mozilla policy-templates](https://github.com/mozilla/policy-templates) — źródło składni `ExtensionSettings`, przypinania ikon i dostępu rozszerzeń w oknach prywatnych.
- [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland) — compositor i dispatchery.
- [Oficjalny przykład konfiguracji Lua Hyprlanda](https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua) — struktura `hl.config`, bindy, animacje i reguły.
- [hyprwm/Hyprland Wiki](https://github.com/hyprwm/hyprland-wiki) — dokumentacja Hyprlanda.
- [Grim](https://gitlab.freedesktop.org/emersion/grim) — bezpośrednie przechwytywanie obrazu pod Waylandem.
- [Slurp](https://gitlab.freedesktop.org/emersion/slurp) — lekki wybór geometrii obszaru ekranu.
- [Satty](https://github.com/gabm/Satty) — edycja, adnotacje, zapis i kopiowanie screenshotów.
- [Fuzzel](https://codeberg.org/dnkl/fuzzel) — lekki launcher oraz menu wyboru pod Waylandem.
- [JakeStanger/ironbar](https://github.com/JakeStanger/ironbar) — panel GTK4
  napisany w Rust, natywne moduły i osadzane wykresy Cairo/LuaJIT.
- [mpv-player/mpv](https://github.com/mpv-player/mpv) — lekki odtwarzacz obrazów
  i wideo.
- [tomasklaen/uosc](https://github.com/tomasklaen/uosc) — nowoczesny interfejs MPV.
- [po5/thumbfast](https://github.com/po5/thumbfast) — miniatury osi czasu MPV.
- [SwayNotificationCenter](https://github.com/ErikReider/SwayNotificationCenter) — centrum i historia powiadomień.
- [SwayOSD](https://github.com/ErikReider/SwayOSD) — lekkie OSD głośności, mikrofonu i jasności.
- [Awww](https://github.com/LGFae/awww) — lekki daemon tapet, skalowanie i animowane przejścia.
- [Biscuit-Theme/biscuit](https://github.com/Biscuit-Theme/biscuit) — oficjalna paleta Biscuit de Mar Dark.
- [Biscuit-Theme/nvim](https://github.com/Biscuit-Theme/nvim) — oficjalny motyw Biscuit dla Neovim.
- [Biscuit-Theme/gtk](https://github.com/Biscuit-Theme/gtk) — oficjalny motyw GTK i wariant ikon Papirus.
- [OldJobobo/omarchy-biscuit-de-mar-dark-theme](https://github.com/OldJobobo/omarchy-biscuit-de-mar-dark-theme) — przypięta tapeta, motyw btop i referencja integracji całego pulpitu.
- [basecamp/omarchy](https://github.com/basecamp/omarchy) — inspiracja dla logicznych skrótów i referencyjny mechanizm wygaszacza TTE.
- [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) — CommitMono Nerd Font i ikony terminalowe.
- [fish-shell/fish-shell](https://github.com/fish-shell/fish-shell) — domyślna powłoka interaktywna.
- [IlanCosman/tide](https://github.com/IlanCosman/tide) — prompt Fish ze statusem Git i czasem poleceń.
- [tmux/tmux](https://github.com/tmux/tmux) — multiplekser i trwałe sesje terminalowe.
- [Pakiet Foot w nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/fo/foot/package.nix) — deklaratywny pakiet lekkiego terminala Wayland.
- [Wiremix](https://github.com/tsowell/wiremix) — interfejs TUI do urządzeń i strumieni PipeWire.
- [Lazygit](https://github.com/jesseduffield/lazygit) — interfejs TUI do Git.
- [Lazydocker](https://github.com/jesseduffield/lazydocker) — interfejs TUI do kontenerów Docker.
- [LazySSH](https://github.com/Adembc/lazyssh) — interfejs TUI do zapisanych hostów SSH.
- [ChrisBuilds/terminaltexteffects](https://github.com/ChrisBuilds/terminaltexteffects) — animacje wygaszacza.

## Oficjalne źródła poza GitHubem

- [Zen: live editing](https://docs.zen-browser.app/guides/live-editing) — oficjalna dokumentacja obsługi `userChrome.css` i `userContent.css`.
- [Dark Reader dla Firefoksa](https://addons.mozilla.org/firefox/addon/darkreader/) — deklaratywnie instalowany oficjalny dodatek AMO.
- [Bitwarden dla Firefoksa](https://addons.mozilla.org/firefox/addon/bitwarden-password-manager/) — deklaratywnie instalowany oficjalny dodatek AMO.
- [GPU Screen Recorder](https://git.dec05eba.com/gpu-screen-recorder/about/) — oficjalny upstream CLI.
- [GPU Screen Recorder UI](https://git.dec05eba.com/gpu-screen-recorder-ui/about/) — oficjalna nakładka ShadowPlay.
- [Foot](https://codeberg.org/dnkl/foot) — oficjalny upstream terminala Wayland.

GPU Screen Recorder nie ma oficjalnego repozytorium kodu na GitHubie. Dlatego dla
integracji z NixOS podane są wyżej konkretne pliki z GitHuba `NixOS/nixpkgs`, a dla
zachowania źródła prawdy o samym recorderze — repozytoria autora. Nieoficjalne
mirrory GitHub nie są używane jako źródła.
