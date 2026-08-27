# Źródła

Preferowane są oficjalne repozytoria GitHub i dokumentacja pierwotna.

## GitHub

- [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) — pakiety i moduły NixOS.
- [sched-ext/scx](https://github.com/sched-ext/scx) — schedulery BPF/Rust dla
  mechanizmu `sched_ext`, w tym interaktywny `scx_bpfland`.
- [Dokumentacja scx_bpfland](https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_bpfland) — uzasadnienie wyboru schedulera dla interaktywnego pulpitu, gier i multimediów pod obciążeniem.
- [Dokumentacja scx_lavd](https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_lavd) — algorytm Latency-criticality Aware Virtual Deadline i profile zasilania.
- [Wydanie SCX 1.1.2](https://github.com/sched-ext/scx/releases/tag/v1.1.2) — przypięte źródło LAVD używane wyłącznie przez opcjonalny harness benchmarkowy.
- [Dokumentacja scx_flash](https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_flash) — scheduler EDF nastawiony na sprawiedliwość i przewidywalne opóźnienia.
- [Regresja scx_lavd 1.1.3](https://github.com/sched-ext/scx/issues/3750) — powód niewłączania LAVD przy obecnie przypiętej wersji SCX.
- [stress-ng](https://github.com/ColinIanKing/stress-ng) — kontrolowane obciążenie CPU używane podczas pomiaru responsywności pulpitu i wątku renderującego.
- [SuperTuxKart](https://github.com/supertuxkart/stk-code) — rzeczywisty silnik gry i wbudowany deterministyczny benchmark replayu dla profili gaming CPU i GPU.
- [FeralInteractive/gamemode](https://github.com/FeralInteractive/gamemode) —
  optymalizacje uruchamiane na żądanie dla procesu gry.
- [ALVR](https://github.com/alvr-org/ALVR) — otwarty streamer i sterownik
  SteamVR używany do połączenia Quest 2 z Linuksem.
- [ALVR: połączenie przewodowe](https://github.com/alvr-org/ALVR/wiki/ALVR-wired-setup-%28ALVR-over-USB%29) — wymagania trybu natywnego przez ADB i awaryjne przekierowanie portów.
- [ALVR: instalacja](https://github.com/alvr-org/ALVR/wiki/Installation-guide) — instalacja klienta, streamera oraz rejestracja sterownika SteamVR.
- [ALVR: diagnostyka Linuksa](https://github.com/alvr-org/ALVR/wiki/Linux-troubleshooting) — aktualne obejście uruchamiania SteamVR przez `vrmonitor.sh`.
- [ValveSoftware/gamescope](https://github.com/ValveSoftware/gamescope) —
  składnia zagnieżdżonego mikrokompozytora, skalowania i limitu odświeżania.
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
- [nvim-lua/kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) — oficjalny,
  edukacyjny punkt wyjścia dla przyszłej osobistej konfiguracji Neovima.
- [Biscuit-Theme/gtk](https://github.com/Biscuit-Theme/gtk) — oficjalny motyw GTK i wariant ikon Papirus.
- [OldJobobo/omarchy-biscuit-de-mar-dark-theme](https://github.com/OldJobobo/omarchy-biscuit-de-mar-dark-theme) — przypięta tapeta, motyw btop i referencja integracji całego pulpitu.
- [basecamp/omarchy](https://github.com/basecamp/omarchy) — inspiracja dla logicznych skrótów i referencyjny mechanizm wygaszacza TTE.
- [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) — CommitMono Nerd Font i ikony terminalowe.
- [fish-shell/fish-shell](https://github.com/fish-shell/fish-shell) — domyślna powłoka interaktywna.
- [IlanCosman/tide](https://github.com/IlanCosman/tide) — prompt Fish ze statusem Git i czasem poleceń.
- [tmux/tmux](https://github.com/tmux/tmux) — multiplekser i trwałe sesje terminalowe.
- [Pakiet Foot w nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/fo/foot/package.nix) — deklaratywny pakiet lekkiego terminala Wayland.
- [Wiremix](https://github.com/tsowell/wiremix) — interfejs TUI do urządzeń i strumieni PipeWire.
- [wlctl](https://github.com/aashish-thapa/wlctl) — lekki interfejs TUI w Rust
  do Wi-Fi zarządzanego przez NetworkManager.
- [Lazygit](https://github.com/jesseduffield/lazygit) — interfejs TUI do Git.
- [Lazydocker](https://github.com/jesseduffield/lazydocker) — interfejs TUI do kontenerów Docker.
- [Oficjalne pluginy Yazi](https://github.com/yazi-rs/plugins) — źródło przypiętych rozszerzeń menedżera plików.
- [Yazi vcs-files](https://github.com/yazi-rs/plugins/tree/main/vcs-files.yazi) — lista plików zmienionych w repozytorium.
- [Yazi jump-to-char](https://github.com/yazi-rs/plugins/tree/main/jump-to-char.yazi) — szybki skok po pierwszym znaku nazwy.
- [Yazi diff](https://github.com/yazi-rs/plugins/tree/main/diff.yazi) — porównywanie zaznaczonego i wskazanego pliku.
- [LazySSH](https://github.com/Adembc/lazyssh) — interfejs TUI do zapisanych hostów SSH.
- [ChrisBuilds/terminaltexteffects](https://github.com/ChrisBuilds/terminaltexteffects) — animacje wygaszacza.

## Oficjalne źródła poza GitHubem

- [Meta Horizon Link](https://developers.meta.com/horizon/documentation/unity/unity-development-overview/) — oficjalne ograniczenie Link do systemu Windows.
- [NixOS: VR](https://wiki.nixos.org/wiki/VR/en) — zachowanie SteamVR na NixOS,
  ograniczenia `CAP_SYS_NICE` i ryzyka obejść ingerujących w bubblewrap lub jądro.
- [SuperTuxKart: Performance Testing](https://supertuxkart.net/Performance_testing) — opis deterministycznego replayu, jego powtarzalności i metryk Steady/Mostly Steady/Typical FPS.
- [OpenBenchmarking: SuperTuxKart](https://openbenchmarking.org/test/pts/supertuxkart) — zweryfikowany replay testowy STK 1.5 i historyczna referencja ustawień Low/Ultimate dla Vulkan; bieżący profil GPU używa natywnego OpenGL Ultimate, aby wymagać pełnej ścieżki shaderowej.
- [SuperTuxKart: Vulkan uruchamia fixed pipeline](https://github.com/supertuxkart/stk-code/issues/4815) — upstreamowe zgłoszenie regresji uzasadniające użycie shaderowego OpenGL w bieżącym profilu GPU.
- [Mesa: zmienna `DRI_PRIME`](https://docs.mesa3d.org/envvars.html#envvar-DRI_PRIME) — wybór konkretnego GPU OpenGL/Vulkan i składnia ukrywająca pozostałe urządzenia.
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
