{
  # Główny moduł NixOS tego hosta. Importuje m.in. konfigurację sprzętu
  # oraz wybrane moduły współdzielone z katalogu modules/.
  configuration = ./configuration.nix;

  # Systemowa nazwa konta. Flake automatycznie użyje profilu home/<username>.
  # Po skopiowaniu hosta i profilu Home Managera wystarczy zmienić tę wartość.
  username = "wojtek";

  # Opcjonalna, przyjazna nazwa wyświetlana przez system.
  userDescription = "Polamaniec";

  # Domyślnie profil Home Managera ma taką samą nazwę jak `username`.
  # Aby użyć istniejącego profilu bez kopiowania, można odkomentować np.:
  # homeProfile = "wojtek";

  # Funkcje interfejsu użytkownika zależne od możliwości danego komputera.
  # `true` włącza daną integrację w konfiguracji Home Managera użytkownika.
  desktopFeatures = {
    # Pokazuje w Ironbarze metryki rdzenia GPU, VRAM-u i temperatury AMD.
    # Nie instaluje sterownika — konfiguracja sprzętu pozostaje w module hosta.
    amdGpu = true;

    # Dodaje do pulpitu status Dockera, panel lazydocker i powiązane skróty.
    # Nie uruchamia automatycznie demona Docker.
    docker = true;

    # Włącza integrację GPU Screen Recorder: replay, autostart UI i skróty.
    # Pakiety oraz ustawienia systemowe do gier nadal zapewnia modules/gaming.nix.
    gaming = true;

    # Dodaje elementy laptopowe: baterię, jasność i klawisze regulacji ekranu.
    laptop = true;

    # Włącza prywatne aplikacje i skróty, np. Discord, Plexamp i EasyEffects.
    personalApps = true;
  };

  # Nazwa urządzenia podświetlenia w /sys/class/backlight. Sprawdzisz ją przez:
  #   brightnessctl --list
  # Wartość jest używana tylko wtedy, gdy `desktopFeatures.laptop = true`.
  backlightDevice = "amdgpu_bl2";

  # Źródło obrazu dla replay GPU Screen Recorder.
  # "focused_monitor" automatycznie wybiera monitor aktywny w Hyprlandzie
  # w chwili uruchamiania replay. Nie przełącza nagrania między monitorami
  # już w trakcie działania bufora.
  #
  # Aby na stałe przypisać konkretny monitor, jego nazwę pokaże:
  #   hyprctl monitors -j | jq -r '.[].name'
  # Można też użyć `hyprctl monitors` i odczytać nazwę po słowie "Monitor".
  # Wtedy wpisz dokładną nazwę, np. "eDP-2" albo "DP-1". Wartość "screen"
  # oznacza pierwszy monitor wykryty przez GPU Screen Recorder.
  replayConfig.captureSource = "focused_monitor";
}
