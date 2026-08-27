{ config, desktopFeatures, inputs, lib, pkgs, replayConfig, username, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
  scripts = import ./scripts.nix { inherit pkgs; };
  amdGpuEnabled = desktopFeatures.amdGpu or false;
  dockerEnabled = desktopFeatures.docker or false;
  screenRecordingEnabled = desktopFeatures.screenRecording or false;
  personalApps = desktopFeatures.personalApps or { };
  discordEnabled = personalApps.discord or false;
  easyeffectsEnabled = personalApps.easyeffects or false;
  plexampEnabled = personalApps.plexamp or false;
  btopPackage =
    if amdGpuEnabled then
      pkgs.btop.override { rocmSupport = true; }
    else
      pkgs.btop;

  # Keep the searchable help menu aligned with every user-facing binding.
  # Host-specific entries follow the same desktopFeatures flags as Hyprland.
  shortcut = key: description: { inherit key description; };
  renderShortcuts = shortcuts:
    lib.concatMapStringsSep "\n"
      (item: "entry ${lib.escapeShellArg item.key} ${lib.escapeShellArg item.description}")
      shortcuts;

  systemShortcuts = [
    (shortcut "Super+Enter" "Uruchom terminal Foot")
    (shortcut "Super+Space" "Otwórz launcher aplikacji Fuzzel")
    (shortcut "Super+B" "Pokaż istniejące okno Zen albo uruchom przeglądarkę")
    (shortcut "Super+E" "Uruchom Yazi w osobnym oknie Foot")
    (shortcut "Super+Alt+E" "Uruchom awaryjny menedżer plików Thunar")
    (shortcut "Super+N" "Pokaż lub ukryj centrum powiadomień SwayNC")
    (shortcut "Super+L" "Zablokuj sesję przez Hyprlock")
    (shortcut "Super+Escape" "Otwórz menu zasilania Wleave")
    (shortcut "Super+Shift+V" "Wybierz wpis historii schowka i wklej go")
    (shortcut "Super+F1" "Otwórz to centrum skrótów")
  ]
  ++ lib.optionals plexampEnabled [
    (shortcut "Super+M" "Uruchom odtwarzacz Plexamp")
  ]
  ++ lib.optionals easyeffectsEnabled [
    (shortcut "Super+Shift+A" "Uruchom efekty dźwięku EasyEffects")
  ];

  windowShortcuts = [
    (shortcut "Super+Q / Super+C" "Zamknij aktywne okno")
    (shortcut "Super+T" "Przełącz aktywne okno między floating i tiling")
    (shortcut "Super+F" "Przełącz maksymalizację z widocznymi panelami")
    (shortcut "Super+Shift+F" "Przełącz pełny ekran bez paneli")
    (shortcut "Super+P" "Przełącz pseudotile aktywnego okna")
    (shortcut "Super+S" "Zmień kierunek następnego podziału dwindle")
    (shortcut "Super+strzałki" "Przenieś fokus między oknami")
    (shortcut "Super+Shift+strzałki" "Przenieś aktywne okno")
    (shortcut "Super+LPM" "Przeciągnij aktywne okno")
    (shortcut "Super+PPM" "Zmień rozmiar aktywnego okna")
    (shortcut "Super+Tab" "Przejdź do następnego używanego pulpitu")
    (shortcut "Super+Shift+Tab" "Przejdź do poprzedniego używanego pulpitu")
    (shortcut "Super+1…0" "Przejdź do pulpitu 1–10")
    (shortcut "Super+Shift+1…0" "Przenieś okno na pulpit 1–10")
  ];

  captureShortcuts = [
    (shortcut "Print" "Wybierz okno lub obszar i otwórz edytor Satty")
    (shortcut "Shift+Print" "Przechwyć aktywne okno i otwórz Satty")
    (shortcut "Ctrl+Print" "Przechwyć cały ekran i otwórz Satty")
    (shortcut "Super+Shift+S" "Otwórz menu trybu zrzutu ekranu")
    (shortcut "Super+Ctrl+S" "Uruchom animowany wygaszacz WOJTECH")
    (shortcut "Satty: Enter" "Zapisz PNG, skopiuj do schowka i zamknij edytor")
    (shortcut "Satty: Esc" "Anuluj edycję i zamknij bez zapisu")
    (shortcut "Satty: PPM" "Zapisz, skopiuj i zamknij edytor")
  ]
  ++ lib.optionals screenRecordingEnabled [
    (shortcut "Alt+Z" "Pokaż lub ukryj nakładkę GPU Screen Recorder")
    (shortcut "Super+G" "Pokaż lub ukryj nakładkę GSR (alias)")
    (shortcut "Super+Shift+R" "Włącz lub wyłącz bufor replay")
    (shortcut "Super+R" "Zapisz ostatnie ${toString replayConfig.seconds} s replay")
  ];

  mediaShortcuts = [
    (shortcut "Głośniej / ciszej" "Zmień głośność wyjścia o 5% i pokaż OSD")
    (shortcut "Wycisz głośniki" "Przełącz wyciszenie wyjścia i pokaż OSD")
    (shortcut "Wycisz mikrofon" "Przełącz wyciszenie mikrofonu i pokaż OSD")
    (shortcut "Play/Pause" "Wstrzymaj lub wznów odtwarzanie przez Playerctl")
    (shortcut "Następny / poprzedni" "Zmień utwór przez Playerctl")
  ]
  ++ lib.optionals (desktopFeatures.laptop or false) [
    (shortcut "Jaśniej / ciemniej" "Zmień jasność ekranu o 5% i pokaż OSD")
  ];

  yaziShortcuts = [
    (shortcut "Enter" "Otwórz plik albo wejdź do katalogu")
    (shortcut "h / l lub ← / →" "Przejdź do katalogu nadrzędnego / podrzędnego")
    (shortcut "j / k lub ↓ / ↑" "Wybierz następny / poprzedni plik")
    (shortcut "H / L" "Wróć / przejdź dalej w historii katalogów")
    (shortcut "Spacja" "Zaznacz plik i przejdź do następnego")
    (shortcut "v / V" "Rozpocznij zaznaczanie / odznaczanie zakresu")
    (shortcut "y / x" "Skopiuj / wytnij zaznaczone pliki")
    (shortcut "p" "Wklej do wskazanego lub bieżącego katalogu")
    (shortcut "d / D" "Przenieś do kosza / usuń bezpowrotnie")
    (shortcut "a" "Utwórz plik; zakończ nazwę /, aby utworzyć katalog")
    (shortcut "r" "Zmień nazwę; przy wielu plikach użyj Neovim")
    (shortcut "." "Pokaż lub ukryj pliki ukryte")
    (shortcut "f" "Skocz do pliku zaczynającego się od wybranego znaku")
    (shortcut "F" "Filtruj ciągle i automatycznie wejdź w jednoznaczny wynik")
    (shortcut "s / S" "Szukaj nazw przez fd / treści przez ripgrep")
    (shortcut "z / Z" "Skocz przez fzf / historię katalogów Zoxide")
    (shortcut "g c" "Pokaż pliki zmienione w bieżącym repozytorium Git")
    (shortcut "Ctrl+D" "Porównaj zaznaczony plik ze wskazanym i skopiuj patch")
    (shortcut "Tab" "Pokaż szczegółowe informacje o pliku")
    (shortcut "w" "Pokaż menedżer zadań Yazi")
    (shortcut "M" "Zamontuj, odmontuj lub wysuń nośnik")
    (shortcut "c m" "Zmień uprawnienia zaznaczonych plików")
    (shortcut "c l / c L" "Utwórz dowiązanie bezwzględne / względne")
    (shortcut "T" "Pokaż lub ukryj panel podglądu")
    (shortcut "t p" "Zmaksymalizuj lub przywróć panel podglądu")
    (shortcut "+ / -" "Powiększ lub pomniejsz podgląd obrazu")
    (shortcut "t t" "Otwórz nową kartę w bieżącym katalogu")
    (shortcut "[ / ]" "Przejdź do poprzedniej / następnej karty")
    (shortcut "1…9" "Przejdź bezpośrednio do wybranej karty")
    (shortcut "q" "Zamknij Yazi; wrapper y może przejąć bieżący katalog")
    (shortcut "F1 / ~" "Otwórz pełną, kontekstową pomoc Yazi")
  ];

  tmuxShortcuts = [
    (shortcut "Ctrl+B" "Prefiks tmux; naciśnij go przed kolejnym klawiszem")
    (shortcut "Ctrl+B, c" "Utwórz nowe okno")
    (shortcut "Ctrl+B, n / p" "Przejdź do następnego / poprzedniego okna")
    (shortcut "Ctrl+B, 0…9" "Przejdź do okna o podanym numerze")
    (shortcut "Ctrl+B, ," "Zmień nazwę bieżącego okna")
    (shortcut "Ctrl+B, &" "Zamknij bieżące okno z potwierdzeniem")
    (shortcut "Ctrl+B, %" "Podziel panel pionowo na lewą i prawą część")
    (shortcut "Ctrl+B, \"" "Podziel panel poziomo na górną i dolną część")
    (shortcut "Ctrl+B, strzałki" "Przenieś fokus do sąsiedniego panelu")
    (shortcut "Ctrl+B, Ctrl+strzałki" "Zmień rozmiar bieżącego panelu")
    (shortcut "Ctrl+B, z" "Powiększ lub przywróć bieżący panel")
    (shortcut "Ctrl+B, x" "Zamknij bieżący panel z potwierdzeniem")
    (shortcut "Ctrl+B, [" "Wejdź do trybu kopiowania z klawiszami Vi")
    (shortcut "Ctrl+B, d" "Odłącz klienta od sesji")
    (shortcut "Ctrl+B, s" "Pokaż i wybierz sesję")
    (shortcut "Ctrl+B, w" "Pokaż drzewo okien i paneli")
    (shortcut "Ctrl+B, ?" "Pokaż pełną listę aktywnych skrótów tmux")
    (shortcut "Mysz" "Wybieraj okna i panele, przewijaj oraz zmieniaj podział")
  ];

  neovimShortcuts = [
    (shortcut "i / a" "Wejdź w tryb Insert przed / za kursorem")
    (shortcut "Esc" "Wróć do trybu Normal")
    (shortcut "h j k l" "Przesuń kursor w lewo, dół, górę i prawo")
    (shortcut "w / b / e" "Skocz do następnego / poprzedniego słowa / końca słowa")
    (shortcut "0 / ^ / $" "Skocz na początek / pierwszy znak / koniec wiersza")
    (shortcut "gg / G" "Skocz na początek / koniec pliku")
    (shortcut "Ctrl+D / Ctrl+U" "Przewiń o pół ekranu w dół / górę")
    (shortcut "v / V / Ctrl+V" "Zaznacz znaki / wiersze / blok kolumnowy")
    (shortcut "y / d / c" "Kopiuj / usuń / zmień według następnego ruchu")
    (shortcut "yy / dd / cc" "Kopiuj / usuń / zmień cały wiersz")
    (shortcut "p / P" "Wklej za / przed kursorem")
    (shortcut "u / Ctrl+R" "Cofnij / ponów zmianę")
    (shortcut "." "Powtórz ostatnią zmianę")
    (shortcut "/tekst" "Wyszukaj tekst do przodu")
    (shortcut "n / N" "Przejdź do następnego / poprzedniego wyniku")
    (shortcut ":w / :q / :wq" "Zapisz / zamknij / zapisz i zamknij")
    (shortcut ":e plik" "Otwórz plik w bieżącym buforze")
    (shortcut ":sp / :vsp" "Podziel okno poziomo / pionowo")
    (shortcut "Ctrl+W, h/j/k/l" "Przenieś fokus między oknami Neovim")
    (shortcut "Ctrl+W, q / o" "Zamknij okno / pozostaw tylko bieżące")
    (shortcut ":tabnew / gt / gT" "Utwórz kartę / przejdź dalej / wróć")
    (shortcut ":terminal" "Otwórz terminal w buforze")
    (shortcut ":help temat" "Otwórz dokumentację wybranego polecenia")
    (shortcut ":map" "Pokaż aktywne mapowania klawiszy")
  ];

  powerShortcuts = [
    (shortcut "l" "Zablokuj sesję")
    (shortcut "u" "Uśpij komputer")
    (shortcut "e" "Wyloguj użytkownika")
    (shortcut "r" "Uruchom komputer ponownie")
    (shortcut "s" "Wyłącz komputer")
    (shortcut "Esc" "Zamknij menu zasilania bez wykonywania akcji")
  ];

  tideDefaults = pkgs.runCommand "tide-declarative-defaults.fish" { } ''
    # Global variables live only in the current shell. Universal variables
    # would rewrite fish_variables every time an interactive shell starts.
    sed -E 's/^(tide_[^ ]+)(.*)$/set -g \1\2/' \
      ${pkgs.fishPlugins.tide}/share/fish/vendor_functions.d/tide/configure/icons.fish \
      ${pkgs.fishPlugins.tide}/share/fish/vendor_functions.d/tide/configure/configs/rainbow.fish \
      > "$out"
  '';

  power-menu = pkgs.writeShellApplication {
    name = "power-menu";
    runtimeInputs = with pkgs; [
      hyprland
      jq
      wleave
    ];
    text = ''
      monitor_row="$({
        hyprctl monitors -j \
          | jq -r '
              (map(select(.focused == true)) + .)[0]
              | if . == null then
                  empty
                else
                  [
                    ((.width / (.scale // 1)) | floor),
                    ((.height / (.scale // 1)) | floor)
                  ]
                  | @tsv
                end
            '
      } 2>/dev/null || true)"

      logical_width=1280
      logical_height=800
      if IFS=$'\t' read -r detected_width detected_height <<< "$monitor_row" \
        && [[ "$detected_width" =~ ^[0-9]+$ ]] \
        && [[ "$detected_height" =~ ^[0-9]+$ ]] \
        && (( detected_width >= 800 && detected_height >= 480 )); then
        logical_width="$detected_width"
        logical_height="$detected_height"
      fi

      # Keep one calm, centered row: use 84% x 32% on smaller outputs and cap
      # it at 1240 x 320 logical pixels so large monitors do not create tiles.
      panel_width=$((logical_width * 84 / 100))
      panel_height=$((logical_height * 32 / 100))
      (( panel_width > 1240 )) && panel_width=1240
      (( panel_height > 320 )) && panel_height=320
      margin_x=$(((logical_width - panel_width) / 2))
      margin_y=$(((logical_height - panel_height) / 2))

      # Wleave 0.7.x lets the compositor choose the output and does not accept
      # wlogout's --no-span/--primary-monitor flags; either flag aborts startup.
      exec wleave \
        --buttons-per-row 5 \
        --column-spacing 16 \
        --margin-left "$margin_x" \
        --margin-right "$margin_x" \
        --margin-top "$margin_y" \
        --margin-bottom "$margin_y"
    '';
  };

  screenshot-menu = pkgs.writeShellApplication {
    name = "screenshot-menu";
    runtimeInputs = with pkgs; [
      coreutils
      fuzzel
      grim
      hyprland
      jq
      libnotify
      satty
      slurp
      swayosd
      wl-clipboard
    ];
    text = ''
      osd_success() {
        swayosd-client \
          --custom-message='Screenshot zapisany i skopiowany' \
          --custom-icon=camera-photo-symbolic \
          >/dev/null 2>&1 || true
      }

      wait_for_selection_overlay() {
        # Slurp exits before the compositor has necessarily removed its
        # dimming layer. Waiting a few frames keeps that layer out of Grim.
        sleep 0.12
      }

      screenshot_dir="''${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
      mkdir -p "$screenshot_dir"

      mode="''${1:-}"
      if [[ -z "$mode" ]]; then
        mode="$({
          printf '%s\n' \
            '󰆞  Obszar' \
            '󰖯  Aktywne okno' \
            '󰍹  Cały ekran'
        } | fuzzel --dmenu --only-match --minimal-lines \
          --prompt 'Zrzut ekranu  ›  ' --width 36 --lines 3)" || exit 0
      fi

      case "$mode" in
        select) target=select ;;
        area|'󰆞  Obszar') target=area ;;
        window|'󰖯  Aktywne okno') target=active ;;
        full|'󰍹  Cały ekran') target=screen ;;
        *) exit 0 ;;
      esac

      # Give Fuzzel enough time to unmap before resolving the active window.
      sleep 0.2

      output="$screenshot_dir/$(date +%F_%H-%M-%S).png"
      temporary="$(mktemp --tmpdir screenshot.XXXXXX.png)"
      cleanup() {
        rm -f "$temporary"
      }
      trap cleanup EXIT

      if [[ "$target" == screen ]]; then
        if ! grim "$temporary"; then
          notify-send --urgency=critical "Screenshot" "Nie udało się przechwycić ekranu."
          exit 1
        fi
      elif [[ "$target" == select ]]; then
        # A short click picks a predefined window; dragging creates any region.
        # Deliberately omit -r so both interactions remain available.
        geometry="$({
          hyprctl clients -j | jq --raw-output '
            .[]
            | select(
                .mapped == true and
                .hidden == false and
                .size[0] > 0 and
                .size[1] > 0
              )
            | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
          '
        } | slurp \
          -b '#${c.background}cc' \
          -B '#${c.surface}66' \
          -c '#${c.accent}ff' \
          -s '#${c.selection}88' \
          -w 2)" || exit 0
        [[ -n "$geometry" ]] || exit 0
        wait_for_selection_overlay

        if ! grim -g "$geometry" "$temporary"; then
          notify-send --urgency=critical "Screenshot" "Nie udało się przechwycić wybranego okna lub obszaru."
          exit 1
        fi
      elif [[ "$target" == area ]]; then
        geometry="$(slurp \
          -b '#${c.background}cc' \
          -c '#${c.accent}ff' \
          -s '#${c.selection}88' \
          -w 2)" || exit 0
        [[ -n "$geometry" ]] || exit 0
        wait_for_selection_overlay

        if ! grim -g "$geometry" "$temporary"; then
          notify-send --urgency=critical "Screenshot" "Nie udało się przechwycić obszaru."
          exit 1
        fi
      else
        geometry="$(hyprctl activewindow -j | jq --raw-output --exit-status '
          select(.address != null and .address != "")
          | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
        ')" || {
          notify-send --urgency=critical "Screenshot" "Nie znaleziono aktywnego okna."
          exit 1
        }

        if ! grim -g "$geometry" "$temporary"; then
          notify-send --urgency=critical "Screenshot" "Nie udało się przechwycić aktywnego okna."
          exit 1
        fi
      fi

      satty \
        --filename "$temporary" \
        --output-filename "$output" \
        --fullscreen current-screen \
        --initial-tool pointer \
        --font-family '${theme.fonts.sans}' \
        --copy-command wl-copy \
        --actions-on-enter save-to-clipboard \
        --actions-on-enter save-to-file \
        --actions-on-enter exit \
        --actions-on-escape exit \
        --actions-on-right-click save-to-clipboard \
        --actions-on-right-click save-to-file \
        --actions-on-right-click exit \
        --disable-notifications \
        --no-window-decoration \
        --title 'Edytuj screenshot' \
        --app-id org.polamaniec.screenshot

      if [[ -s "$output" ]]; then
        wl-copy --type image/png < "$output"
        osd_success
      fi
    '';
  };

  gsr-control = pkgs.writeShellApplication {
    name = "gsr-control";
    runtimeInputs = with pkgs; [
      coreutils
      gpu-screen-recorder-ui
      libnotify
      procps
      util-linux
    ];
    text = ''
      action="''${1:-}"
      case "$action" in
        replay-save|toggle-replay|toggle-show) ;;
        *)
          printf 'Użycie: gsr-control {toggle-show|toggle-replay|replay-save}\n' >&2
          exit 2
          ;;
      esac

      # Serialize a cold start so two shortcuts cannot launch competing UIs.
      lock_file="''${XDG_RUNTIME_DIR:?}/gsr-control.lock"
      exec 9>"$lock_file"
      flock 9

      if ! pgrep -x gsr-ui >/dev/null; then
        gsr-ui launch-hide >/dev/null 2>&1 &

        started=false
        for _ in {1..80}; do
          if pgrep -x gsr-ui >/dev/null; then
            # The process appears before its control socket is always ready.
            sleep 0.35
            started=true
            break
          fi
          sleep 0.05
        done

        if [[ "$started" != true ]]; then
          notify-send --urgency=critical \
            "GPU Screen Recorder" \
            "Nie udało się uruchomić nakładki."
          exit 1
        fi
      fi

      if ! gsr-ui-cli "$action"; then
        notify-send --urgency=critical \
          "GPU Screen Recorder" \
          "Nakładka działa, ale nie przyjęła akcji: $action."
        exit 1
      fi
    '';
  };

  shortcut-menu = pkgs.writeShellApplication {
    name = "shortcut-menu";
    runtimeInputs = [ pkgs.fuzzel ];
    text = ''
      entry() {
        printf '%-29s  %s\n' "$1" "$2"
      }

      show_system() {
        ${renderShortcuts systemShortcuts}
      }

      show_windows() {
        ${renderShortcuts windowShortcuts}
      }

      show_capture() {
        ${renderShortcuts captureShortcuts}
      }

      show_media() {
        ${renderShortcuts mediaShortcuts}
      }

      show_yazi() {
        ${renderShortcuts yaziShortcuts}
      }

      show_tmux() {
        ${renderShortcuts tmuxShortcuts}
      }

      show_neovim() {
        ${renderShortcuts neovimShortcuts}
      }

      show_power() {
        ${renderShortcuts powerShortcuts}
      }

      heading() {
        printf '── %s ──\n' "$1"
      }

      show_all() {
        heading "SYSTEM I APLIKACJE"
        show_system
        heading "OKNA I PULPITY"
        show_windows
        heading "ZRZUTY, SCHOWEK I NAGRYWANIE"
        show_capture
        heading "MULTIMEDIA I LAPTOP"
        show_media
        heading "YAZI"
        show_yazi
        heading "TMUX"
        show_tmux
        heading "NEOVIM"
        show_neovim
        heading "MENU ZASILANIA"
        show_power
      }

      show_list() {
        local title="$1"
        local renderer="$2"

        # Sixteen 34 px rows leave room for the prompt and padding on the
        # laptop's 800 px logical display; longer sections remain scrollable.
        "$renderer" | fuzzel \
          --dmenu \
          --only-match \
          --minimal-lines \
          --prompt "$title  ›  " \
          --width 92 \
          --lines 16 \
          >/dev/null
      }

      show_category() {
        case "$1" in
          system) show_list "System i aplikacje" show_system ;;
          windows) show_list "Okna i pulpity" show_windows ;;
          capture) show_list "Zrzuty, schowek i nagrywanie" show_capture ;;
          media) show_list "Multimedia i laptop" show_media ;;
          yazi) show_list "Yazi" show_yazi ;;
          tmux) show_list "tmux" show_tmux ;;
          nvim|neovim) show_list "Neovim" show_neovim ;;
          power) show_list "Menu zasilania" show_power ;;
          all) show_list "Wszystkie skróty" show_all ;;
          *)
            printf 'Użycie: shortcut-menu [system|windows|capture|media|yazi|tmux|nvim|power|all]\n' >&2
            return 2
            ;;
        esac
      }

      if [[ -n "''${1:-}" ]]; then
        show_category "$1" || status=$?
        exit "''${status:-0}"
      fi

      while true; do
        category="$({
          printf '%s\n' \
            '󰣇  System i aplikacje' \
            '󰖲  Okna i pulpity' \
            '󰄀  Zrzuty, schowek i nagrywanie' \
            '󰋋  Multimedia i laptop' \
            '󰇥  Yazi' \
            '  tmux' \
            '  Neovim' \
            '󰐥  Menu zasilania' \
            '󰈙  Wszystkie skróty'
        } | fuzzel \
          --dmenu \
          --only-match \
          --minimal-lines \
          --prompt 'Pomoc  ›  ' \
          --width 46 \
          --lines 9)" || exit 0

        case "$category" in
          *"System i aplikacje") section=system ;;
          *"Okna i pulpity") section=windows ;;
          *"Zrzuty, schowek i nagrywanie") section=capture ;;
          *"Multimedia i laptop") section=media ;;
          *"Yazi") section=yazi ;;
          *"tmux") section=tmux ;;
          *"Neovim") section=nvim ;;
          *"Menu zasilania") section=power ;;
          *"Wszystkie skróty") section=all ;;
          *) continue ;;
        esac

        show_category "$section" || true
        exit 0
      done
    '';
  };

  docker-status = pkgs.writeShellApplication {
    name = "docker-status";
    runtimeInputs = with pkgs; [
      coreutils
      docker-client
      gnused
      jq
      systemd
    ];
    text = ''
      output_mode="''${1:-json}"

      output() {
        case "$output_mode" in
          json)
            jq --null-input --compact-output \
              --arg text "$1" \
              --arg tooltip "$2" \
              --arg class "$3" \
              '{text: $text, tooltip: $tooltip, class: $class}'
            ;;
          label)
            printf '%s\n' "$1"
            ;;
          tooltip)
            printf '%s\n' "$2" | sed -E 's/<[^>]+>//g'
            ;;
          *)
            printf 'Użycie: docker-status [json|label|tooltip]\n' >&2
            exit 2
            ;;
        esac
      }

      if ! systemctl is-active --quiet docker.service; then
        output "  –" $'<b>Docker</b>\nDaemon jest zatrzymany. Uruchom go ręcznie: sudo systemctl start docker.' "offline"
        exit 0
      fi

      if ! timeout 2 docker info >/dev/null 2>&1; then
        output "  !" $'<b>Docker</b>\nDaemon działa, ale użytkownik nie ma dostępu.' "critical"
        exit 0
      fi

      mapfile -t container_ids < <(docker container ls --all --quiet)
      total="''${#container_ids[@]}"
      if (( total == 0 )); then
        output "  0" $'<b>Docker</b>\nBrak kontenerów.' "ok"
        exit 0
      fi

      inspect_json="$(docker inspect "''${container_ids[@]}")"
      running="$(jq '[.[] | select(.State.Running == true)] | length' <<< "$inspect_json")"
      stopped=$((total - running))
      unhealthy="$(jq '[.[] | select(.State.Health.Status? == "unhealthy")] | length' <<< "$inspect_json")"
      failed="$(jq '[.[] | select(
        (.State.Restarting == true) or
        (.State.Status == "dead") or
        (.State.Status == "exited" and .State.ExitCode != 0)
      )] | length' <<< "$inspect_json")"

      if (( unhealthy > 0 || failed > 0 )); then
        class="critical"
      elif (( stopped > 0 )); then
        class="warning"
      else
        class="ok"
      fi

      tooltip="<b>Docker</b>"$'\n'
      tooltip+="Aktywne: $running   •   Zatrzymane: $stopped"
      (( unhealthy > 0 )) && tooltip+="   •   Unhealthy: $unhealthy"
      (( failed > 0 )) && tooltip+="   •   Błędy: $failed"

      if (( running > 0 )); then
        mapfile -t running_ids < <(docker container ls --quiet)
        stats="$(timeout 4 docker stats --no-stream --format '{{json .}}' "''${running_ids[@]}" 2>/dev/null \
          | jq --raw-input --slurp '
              split("\n")
              | map(select(length > 0) | fromjson)
              | map("\(.Name)   CPU \(.CPUPerc)   RAM \(.MemUsage)")
              | join("\n")
            ')"
        [[ -n "$stats" ]] && tooltip+=$'\n\n<b>Zużycie kontenerów</b>\n'"$stats"
      fi

      problems="$(jq --raw-output '
        .[]
        | select(
            (.State.Restarting == true) or
            (.State.Health.Status? == "unhealthy") or
            (.State.Status == "dead") or
            (.State.Status == "exited" and .State.ExitCode != 0)
          )
        | "\(.Name | ltrimstr("/"))   \(.State.Status)   exit=\(.State.ExitCode)"
      ' <<< "$inspect_json")"
      [[ -n "$problems" ]] && tooltip+=$'\n\n<b>Problemy</b>\n'"$problems"

      output "  $running/$total" "$tooltip" "$class"
    '';
  };

  desktop-panel = pkgs.writeShellApplication {
    name = "desktop-panel";
    runtimeInputs = [
      inputs.wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.bluetui
      btopPackage
      pkgs.foot
      pkgs.util-linux
      pkgs.wiremix
    ] ++ lib.optionals dockerEnabled [ pkgs.lazydocker ];
    text = ''
      panel="''${1:-}"
      lock_file="''${XDG_RUNTIME_DIR:?}/desktop-panel.lock"

      exec 9>"$lock_file"
      flock --nonblock 9 || exit 0

      case "$panel" in
        metrics)
          exec foot --app-id=desktop-metrics --title=Zasoby \
            --window-size-chars=96x28 btop
          ;;
        audio)
          exec foot --app-id=desktop-audio --title=Dźwięk \
            --window-size-chars=100x30 wiremix
          ;;
        wifi)
          exec foot --app-id=desktop-wifi --title=Wi-Fi \
            --window-size-chars=92x28 wlctl
          ;;
        bluetooth)
          exec foot --app-id=desktop-bluetooth --title=Bluetooth \
            --window-size-chars=86x26 bluetui
          ;;
        ${lib.optionalString dockerEnabled ''
          docker)
            exec foot --app-id=desktop-docker --title=Docker \
              --window-size-chars=110x32 lazydocker
            ;;
        ''}
        *)
          printf 'Użycie: desktop-panel {metrics|audio|wifi|bluetooth${lib.optionalString dockerEnabled "|docker"}}\n' >&2
          exit 2
          ;;
      esac
    '';
  };

  screensaver-run = pkgs.writeShellApplication {
    name = "screensaver-run";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      scripts.screensaver-refresh-rate
      terminaltexteffects
    ];
    text = ''
      cleanup() {
        printf '\033[?1003l\033[?1006l\033[?25h'
        jobs -pr | xargs -r kill 2>/dev/null || true
      }
      trap cleanup EXIT INT TERM HUP

      # Ask Foot to report every pointer movement using SGR mouse sequences.
      # The foreground read below can then dismiss the saver on either keyboard
      # or pointer activity without relying on Hypridle's synthetic resume event
      # emitted while this fullscreen window is being mapped.
      printf '\033]11;#${c.background}\007\033[2J\033[H\033[?25l\033[?1003h\033[?1006h'

      wait_for_terminal_resize() {
        local deadline=$((SECONDS + 2))
        while (( SECONDS < deadline )) && [[ "$(stty size 2>/dev/null)" == "24 80" ]]; do
          sleep 0.02
        done
      }

      wait_for_terminal_resize

      # TTE expresses most motion as distance or delay per rendered frame.
      # Normalize it to wall-clock time so a higher refresh rate is smoother,
      # not faster. The selected rate is refreshed between effects so plugging
      # or unplugging external power takes effect without restarting the saver.
      animation_speed() {
        awk -v value="$1" -v fps="$refresh_rate" \
          'BEGIN { printf "%.4f", value * 60 / fps }'
      }

      animation_frames() {
        awk -v value="$1" -v fps="$refresh_rate" \
          'BEGIN {
            frames = value * fps / 60
            if (frames < 1) frames = 1
            printf "%d", frames + 0.5
          }'
      }

      effects=(
        beams
        binarypath
        blackhole
        bouncyballs
        bubbles
        burn
        colorshift
        crumble
        decrypt
        errorcorrect
        expand
        fireworks
        highlight
        laseretch
        matrix
        middleout
        orbittingvolley
        overflow
        pour
        print
        rain
        randomsequence
        rings
        scattered
        slice
        slide
        smoke
        spotlights
        spray
        swarm
        sweep
        synthgrid
        thunderstorm
        unstable
        vhstape
        waves
        wipe
      )

      while true; do
        mapfile -t shuffled_effects < <(printf '%s\n' "''${effects[@]}" | shuf)

        for effect in "''${shuffled_effects[@]}"; do
          refresh_rate="$(screensaver-refresh-rate)"
          effect_args=()
          case "$effect" in
          bouncyballs)
            effect_args=(
              --ball-delay "$(animation_frames 4)"
              --movement-speed "$(animation_speed 0.45)"
              --ball-colors ${c.orange} ${c.yellow} ${c.accent}
              --final-gradient-stops ${c.accent} ${c.orange} ${c.bright}
            )
            ;;
          rain)
            effect_args=(
              --movement-speed "$(animation_speed 0.33)-$(animation_speed 0.57)"
              --rain-colors ${c.violet} ${c.blue} ${c.accent}
              --final-gradient-stops ${c.violet} ${c.accent} ${c.bright}
            )
            ;;
          rings)
            effect_args=(
              --spin-duration "$(animation_frames 200)"
              --spin-speed "$(animation_speed 0.25)-$(animation_speed 1.0)"
              --disperse-duration "$(animation_frames 200)"
              --ring-colors ${c.accent} ${c.orange} ${c.yellow}
              --final-gradient-stops ${c.accent} ${c.orange} ${c.bright}
            )
            ;;
          scattered)
            effect_args=(
              --movement-speed "$(animation_speed 0.5)"
              --final-gradient-frames "$(animation_frames 9)"
              --final-gradient-stops ${c.violet} ${c.accent} ${c.bright}
            )
            ;;
          slide)
            effect_args=(
              --movement-speed "$(animation_speed 0.8)"
              --gap "$(animation_frames 2)"
              --final-gradient-frames "$(animation_frames 6)"
              --final-gradient-stops ${c.orange} ${c.accent} ${c.bright}
            )
            ;;
          wipe)
            effect_args=(
              --wipe-delay "$(animation_frames 1)"
              --final-gradient-frames "$(animation_frames 3)"
              --final-gradient-stops ${c.violet} ${c.accent} ${c.orange} ${c.bright}
            )
            ;;
          esac

          tte --input-file "''${XDG_CONFIG_HOME:-$HOME/.config}/screensaver/wojtech.txt" \
            --frame-rate "$refresh_rate" \
            --canvas-width 0 \
            --canvas-height 0 \
            --anchor-canvas c \
            --anchor-text c \
            --reuse-canvas \
            --no-eol \
            --no-restore-cursor \
            "$effect" "''${effect_args[@]}" &
          effect_pid=$!

          while kill -0 "$effect_pid" 2>/dev/null; do
            if read -r -n 1 -t 0.2; then
              exit 0
            fi
          done
          wait "$effect_pid" || true
        done
      done
    '';
  };

  screensaver = pkgs.writeShellApplication {
    name = "screensaver";
    runtimeInputs = with pkgs; [
      foot
      procps
      screensaver-run
    ];
    text = ''
      pgrep -f '[o]rg.polamaniec.screensaver' >/dev/null && exit 0

      exec foot \
        --app-id=org.polamaniec.screensaver \
        --override=main.font='${theme.fonts.monospace}:size=16' \
        --override=main.pad=0x0 \
        --override=colors.background=${c.background} \
        -e screensaver-run org.polamaniec.screensaver
    '';
  };
in

{
  imports = [
    inputs.zen-browser.homeModules.twilight
    ./agent-manager.nix
    ./clipboard.nix
    ./desktop.nix
    ./hyprland.nix
    ./ironbar.nix
    ./neovim.nix
    ./notifications.nix
    ./osd.nix
    ./zen.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";

    packages =
      (with pkgs; [
        playerctl
        power-menu
        screenshot-menu
        screensaver
        shortcut-menu
        desktop-panel
        wl-clipboard
      ])
      ++ [ scripts.zen-run-or-raise ]
      ++ lib.optionals discordEnabled [ pkgs.discord ]
      ++ lib.optionals screenRecordingEnabled [ gsr-control ]
      ++ lib.optionals dockerEnabled [ docker-status ];

    sessionVariables = {
      BROWSER = "zen-twilight";
      EDITOR = "nvim";
      TERMINAL = "foot";
      VISUAL = "nvim";
      NIXOS_OZONE_WL = "1";
    };
  };

  programs.home-manager.enable = true;

  programs.btop = {
    enable = true;
    package = btopPackage;
    settings = {
      color_theme = "biscuit";
      theme_background = false;
      truecolor = true;
      rounded_corners = true;
      vim_keys = true;
      show_gpu_info = "Auto";
      shown_gpus = "amd";
    };
  };

  # btop writes this file itself on exit; the declarative profile is canonical.
  xdg.configFile."btop/btop.conf".force = true;
  xdg.configFile."btop/themes/biscuit.theme".source =
    "${inputs.biscuit-desktop}/btop.theme";

  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "tide";
        src = pkgs.fishPlugins.tide.src;
      }
    ];
    interactiveShellInit = ''
      set -g fish_greeting

      set -g _tide_color_dark_blue ${c.violet}
      set -g _tide_color_dark_green ${c.green}
      set -g _tide_color_gold ${c.yellow}
      set -g _tide_color_green ${c.green}
      set -g _tide_color_light_blue ${c.blue}
      source ${tideDefaults}

      set -g tide_left_prompt_items pwd git newline character
      set -g tide_right_prompt_items status cmd_duration jobs nix_shell time
      set -g tide_cmd_duration_threshold 1000
      set -g tide_cmd_duration_icon '󱎫'
      set -g tide_git_icon ''
      set -g tide_prompt_add_newline_before true
      set -g tide_time_format '%H:%M'

      # Biscuit de Mar Dark powerline palette.
      set -g tide_pwd_bg_color ${c.accent}
      set -g tide_pwd_color_anchors ${c.bright}
      set -g tide_pwd_color_dirs ${c.bright}
      set -g tide_pwd_color_truncated_dirs ${c.subtle}
      set -g tide_git_bg_color ${c.green}
      set -g tide_git_bg_color_unstable ${c.yellow}
      set -g tide_git_bg_color_urgent ${c.orange}
      set -g tide_git_color_branch ${c.background}
      set -g tide_git_color_conflicted ${c.background}
      set -g tide_git_color_dirty ${c.background}
      set -g tide_git_color_operation ${c.background}
      set -g tide_git_color_staged ${c.background}
      set -g tide_git_color_stash ${c.background}
      set -g tide_git_color_untracked ${c.background}
      set -g tide_git_color_upstream ${c.background}
      set -g tide_status_bg_color ${c.surface}
      set -g tide_status_bg_color_failure ${c.red}
      set -g tide_status_color ${c.green}
      set -g tide_status_color_failure ${c.bright}
      set -g tide_cmd_duration_bg_color ${c.yellow}
      set -g tide_cmd_duration_color ${c.background}
      set -g tide_jobs_bg_color ${c.selection}
      set -g tide_jobs_color ${c.foreground}
      set -g tide_nix_shell_bg_color ${c.violet}
      set -g tide_nix_shell_color ${c.bright}
      set -g tide_time_bg_color ${c.selection}
      set -g tide_time_color ${c.foreground}
      set -g tide_prompt_color_frame_and_connection ${c.muted}
      set -g tide_prompt_color_separator_same_color ${c.subtle}
    '';
  };

  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    escapeTime = 0;
    historyLimit = 100000;
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
    extraConfig = ''
      set -g default-shell ${pkgs.fish}/bin/fish
      set -g focus-events on
      set -g renumber-windows on
      set -g status-position top
      set -g status-style 'bg=#${c.background},fg=#${c.foreground}'
      set -g window-status-current-style 'bg=#${c.accent},fg=#${c.bright},bold'
      set -as terminal-features ',foot:RGB'
      set -g allow-passthrough on
    '';
  };

  programs.lazygit = {
    enable = true;
    settings.gui = {
      border = "rounded";
      nerdFontsVersion = "3";
      theme = {
        activeBorderColor = [ "#${c.accent}" "bold" ];
        inactiveBorderColor = [ "#${c.muted}" ];
        searchingActiveBorderColor = [ "#${c.yellow}" "bold" ];
        optionsTextColor = [ "#${c.violet}" ];
        selectedLineBgColor = [ "#${c.selection}" ];
        selectedRangeBgColor = [ "#${c.surface}" ];
        cherryPickedCommitBgColor = [ "#${c.violet}" ];
        cherryPickedCommitFgColor = [ "#${c.bright}" ];
        unstagedChangesColor = [ "#${c.orange}" ];
        defaultFgColor = [ "#${c.foreground}" ];
      };
    };
  };

  xdg.configFile."gpu-screen-recorder/config_ui" = lib.mkIf screenRecordingEnabled {
    text = ''
      main.wayland_warning_shown true
      main.hotkeys_enable_option disable_hotkeys
      replay.record_options.record_area_option ${replayConfig.captureSource}
      replay.record_options.fps ${toString replayConfig.fps}
      replay.record_options.video_bitrate ${toString replayConfig.videoBitrate}
      replay.record_options.video_quality custom
      replay.record_options.codec ${replayConfig.videoCodec}
      replay.record_options.audio_codec ${replayConfig.audioCodec}
      replay.record_options.framerate_mode cfr
      replay.record_options.advanced_view true
      replay.record_options.audio_track_item false [add_audio_track]
      replay.record_options.audio_track_item false default_output
      replay.record_options.audio_track_item false default_input
      replay.record_options.audio_track_item false [add_audio_track]
      replay.record_options.audio_track_item false default_output
      replay.record_options.audio_track_item false [add_audio_track]
      replay.record_options.audio_track_item false default_input
      replay.turn_on_replay_automatically_mode dont_turn_on_automatically
      replay.restart_replay_on_save false
      replay.save_directory ${config.home.homeDirectory}/Videos/Replays
      replay.container mp4
      replay.time ${toString replayConfig.seconds}
      replay.replay_storage ram
    '';
  };

  xdg.configFile."screensaver/wojtech.txt".text = ''
     ▄█     █▄   ▄██████▄       ▄█       ███        ▄████████  ▄████████    ▄█    █▄
    ███     ███ ███    ███     ███   ▀█████████▄   ███    ███ ███    ███   ███    ███
    ███     ███ ███    ███     ███      ▀███▀▀██   ███    █▀  ███    █▀    ███    ███
    ███     ███ ███    ███     ███       ███   ▀  ▄███▄▄▄     ███         ▄███▄▄▄▄███▄▄
    ███     ███ ███    ███     ███       ███     ▀▀███▀▀▀     ███        ▀▀███▀▀▀▀███▀
    ███     ███ ███    ███     ███       ███       ███    █▄  ███    █▄    ███    ███
    ███ ▄█▄ ███ ███    ███     ███       ███       ███    ███ ███    ███   ███    ███
     ▀███▀███▀   ▀██████▀  █▄ ▄███      ▄████▀     ██████████ ████████▀    ███    █▀
                           ▀▀▀▀▀▀
  '';

  # Wleave stays on-demand: service mode saves a small amount of launch time,
  # but would add an unnecessary resident GTK process to the idle session.
  programs.wleave = {
    enable = true;
    settings = {
      "button-layout" = "grid";
      "buttons-per-row" = "1/1";
      "column-spacing" = "16px";
      "row-spacing" = "16px";
      "margin-left" = "8%";
      "margin-right" = "8%";
      "margin-top" = "34%";
      "margin-bottom" = "34%";
      "close-on-lost-focus" = true;
      "show-keybinds" = true;
      "no-version-info" = true;
      "delay-command-ms" = 100;
      buttons = [
        {
          label = "lock";
          action = "${pkgs.hyprlock}/bin/hyprlock";
          text = "Zablokuj";
          keybind = "l";
          icon = "${pkgs.wleave}/share/wleave/icons/lock.svg";
        }
        {
          label = "suspend";
          action = "${pkgs.systemd}/bin/systemctl suspend";
          text = "Uśpij";
          keybind = "u";
          icon = "${pkgs.wleave}/share/wleave/icons/suspend.svg";
        }
        {
          label = "logout";
          action = "${pkgs.uwsm}/bin/uwsm stop";
          text = "Wyloguj";
          keybind = "e";
          icon = "${pkgs.wleave}/share/wleave/icons/logout.svg";
        }
        {
          label = "reboot";
          action = "${pkgs.systemd}/bin/systemctl reboot";
          text = "Uruchom ponownie";
          keybind = "r";
          icon = "${pkgs.wleave}/share/wleave/icons/reboot.svg";
        }
        {
          label = "shutdown";
          action = "${pkgs.systemd}/bin/systemctl poweroff";
          text = "Wyłącz";
          keybind = "s";
          icon = "${pkgs.wleave}/share/wleave/icons/shutdown.svg";
        }
      ];
    };
    style = ''
      * {
        font-family: "${theme.fonts.interface}";
      }

      window {
        background-color: alpha(#${c.background}, 0.92);
      }

      button {
        color: #${c.foreground};
        background-color: alpha(#${c.surface}, 0.98);
        border: 2px solid alpha(#${c.muted}, 0.68);
        border-radius: 20px;
        margin: 0;
        padding: 18px 14px;
        box-shadow: 0 10px 32px alpha(#${c.background}, 0.76);
        outline-style: none;
        transition: 150ms ease-in-out;
      }

      button image {
        -gtk-icon-size: 68px;
      }

      button label.action-name {
        color: #${c.foreground};
        font-size: 16px;
        font-weight: 700;
      }

      button label.keybind {
        color: #${c.subtle};
        font-family: "${theme.fonts.monospace}";
        font-size: 13px;
        font-weight: 700;
        opacity: 0.78;
      }

      button:hover,
      button:focus,
      button:active {
        background-color: #${c.selection};
      }

      button:hover label.action-name,
      button:focus label.action-name,
      button:active label.action-name {
        color: #${c.bright};
      }

      button:hover label.keybind,
      button:focus label.keybind,
      button:active label.keybind {
        opacity: 1;
      }

      #lock {
        color: #${c.violet};
      }

      #lock:hover,
      #lock:focus,
      #lock:active {
        border-color: #${c.violet};
        box-shadow: inset 0 -4px #${c.violet};
      }

      #lock label.keybind {
        color: #${c.violet};
      }

      #suspend {
        color: #${c.green};
      }

      #suspend:hover,
      #suspend:focus,
      #suspend:active {
        border-color: #${c.green};
        box-shadow: inset 0 -4px #${c.green};
      }

      #suspend label.keybind {
        color: #${c.green};
      }

      #logout {
        color: #${c.accent};
      }

      #logout:hover,
      #logout:focus,
      #logout:active {
        border-color: #${c.accent};
        box-shadow: inset 0 -4px #${c.accent};
      }

      #logout label.keybind {
        color: #${c.accent};
      }

      #reboot {
        color: #${c.orange};
      }

      #reboot:hover,
      #reboot:focus,
      #reboot:active {
        border-color: #${c.orange};
        box-shadow: inset 0 -4px #${c.orange};
      }

      #reboot label.keybind {
        color: #${c.orange};
      }

      #shutdown {
        color: #${c.red};
      }

      #shutdown:hover,
      #shutdown:focus,
      #shutdown:active {
        border-color: #${c.red};
        box-shadow: inset 0 -4px #${c.red};
      }

      #shutdown label.keybind {
        color: #${c.red};
      }
    '';
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
