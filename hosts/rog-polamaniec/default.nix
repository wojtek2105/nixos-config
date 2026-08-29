{
  # Główny moduł NixOS tego hosta. Importuje m.in. konfigurację sprzętu
  # oraz wybrane moduły współdzielone z katalogu modules/.
  configuration = ./configuration.nix;

  # Systemowa nazwa konta. Flake automatycznie użyje profilu home/<username>.
  # Po skopiowaniu hosta i profilu Home Managera wystarczy zmienić tę wartość.
  username = "wojtek";

  # Opcjonalna, przyjazna nazwa wyświetlana przez system.
  userDescription = "Polamaniec";

  # Skala interfejsu Hyprlanda dla tego hosta.
  uiScale = 2;

  # Domyślnie profil Home Managera ma taką samą nazwę jak `username`.
  # Aby użyć istniejącego profilu bez kopiowania, można odkomentować np.:
  # homeProfile = "wojtek";

  # Jedna mapa możliwości steruje zarówno modułami NixOS, jak i odpowiadającą
  # im integracją Home Managera. Wyłączenie funkcji usuwa więc także pakiety,
  # zamiast jedynie ukrywać jej elementy pulpitu.
  features = {
    # Pokazuje w Ironbarze metryki rdzenia GPU, VRAM-u i temperatury AMD.
    # Nie instaluje sterownika — konfiguracja sprzętu pozostaje w module hosta.
    amdGpuMetrics = true;

    # Instaluje ręcznie uruchamiany Docker, Compose, lazydocker i lazyssh oraz
    # dodaje status i panel Dockera do pulpitu. Daemon nie startuje przy boot.
    docker = true;

    # Instaluje Steam, Proton-GE, Gamescope i GameMode wraz z potrzebnymi
    # bibliotekami grafiki i dźwięku 32-bit oraz uruchamia scheduler SCX
    # nastawiony na responsywny pulpit i stabilne czasy klatek.
    gaming = true;

    # Instaluje ALVR, Steam i ADB dla Quest 2 po USB-C. Jest to przewodowy
    # transport ALVR, nie Meta Quest Link; nie otwiera portów ani nie uruchamia
    # procesu w tle. Tryb deweloperski i USB debugging w goglach są wymagane.
    vr = true;

    # Instaluje GPU Screen Recorder i dodaje skróty replay. UI uruchamia się
    # dopiero przy pierwszym użyciu, więc nie zajmuje pamięci po zalogowaniu.
    screenRecording = true;

    # Narzędzia vainfo, radeontop i vulkaninfo są potrzebne tylko przy ręcznej
    # diagnostyce GPU. Btop i Ironbar pokrywają codzienny monitoring.
    hardwareDiagnostics = false;

    # Opcjonalny harness porównujący EEVDF, bpfland, LAVD i Flash. Włączenie
    # instaluje narzędzia testowe, ale nie uruchamia usługi ani benchmarku.
    # Na co dzień pozostaje false; bez instalacji można użyć aplikacji flake.
    schedulerBenchmark = false;

    # Dodaje elementy laptopowe: baterię, jasność i klawisze regulacji ekranu.
    laptop = true;

    # Każdą większą aplikację można wyłączyć niezależnie bez zmiany profilu.
    personalApps = {
      discord = true;
      easyeffects = true;
      plexamp = true;
    };
  };

  # Nazwa urządzenia podświetlenia w /sys/class/backlight. Sprawdzisz ją przez:
  #   brightnessctl --list
  # Wartość jest używana tylko wtedy, gdy `features.laptop = true`.
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
