# Nowy host i użytkownik krok po kroku

Ten przewodnik opisuje utworzenie nowej konfiguracji przez skopiowanie hosta
`rog-polamaniec` oraz profilu `home/wojtek`. Po wykonaniu opisanych zmian nazwa
hosta i użytkownika nie jest zaszyta we współdzielonych modułach.

## Założenia

- repozytorium znajduje się w bieżącym katalogu,
- nowy host ma nazwę `nowy-host`,
- nowe konto ma nazwę `nowy-user`,
- konfiguracja sprzętowa jest generowana na docelowym komputerze,
- sekrety, hasła, sieci Wi-Fi i klucze prywatne nie trafiają do Git.

Nazwy w przykładach należy zastąpić własnymi. Nazwa użytkownika powinna być
krótka, zapisana małymi literami i nie zawierać spacji.

## 1. Wybór sposobu użycia profilu Home Managera

Są dwa poprawne warianty.

### Osobna kopia profilu użytkownika

Ten wariant pozwala później niezależnie zmieniać ustawienia obu kont:

```bash
cp -a home/wojtek home/nowy-user
```

W plikach skopiowanego katalogu nie trzeba zmieniać `wojtek` na nową nazwę.
Nazwa konta i katalog domowy zostaną przekazane przez manifest hosta.

### Współdzielenie istniejącego profilu

Nie kopiuj katalogu `home/wojtek`. W manifeście nowego hosta ustaw:

```nix
username = "nowy-user";
homeProfile = "wojtek";
```

Powstanie oddzielne konto `/home/nowy-user`, ale jego konfiguracja będzie
budowana ze źródeł w `home/wojtek`. Stan programów i pliki użytkowników nadal
pozostają oddzielne.

## 2. Skopiowanie hosta

```bash
cp -a hosts/rog-polamaniec hosts/nowy-host
```

Nazwa katalogu automatycznie staje się:

- nazwą outputu flake: `nixosConfigurations.nowy-host`,
- wartością `networking.hostName`.

Nie trzeba wpisywać `nowy-host` wewnątrz `configuration.nix`.

## 3. Wygenerowanie konfiguracji sprzętu

Pliku z ROG-a nie wolno używać na innym komputerze. Na uruchomionym systemie
docelowym wykonaj z katalogu repozytorium:

```bash
sudo nixos-generate-config --show-hardware-config \
  > hosts/nowy-host/hardware-configuration.nix
```

Podczas instalacji z obrazu NixOS, po zamontowaniu systemu pod `/mnt`, użyj:

```bash
sudo nixos-generate-config --root /mnt --show-hardware-config \
  > hosts/nowy-host/hardware-configuration.nix
```

Przed kontynuacją sprawdź szczególnie:

- UUID systemu plików `/` i `/boot`,
- typ systemu plików,
- `swapDevices`,
- moduły kontrolera dysku i CPU,
- `nixpkgs.hostPlatform`.

## 4. Konfiguracja `hosts/nowy-host/default.nix`

Poniższy szablon pokazuje wszystkie obsługiwane pola manifestu hosta:

```nix
{
  # Główny moduł NixOS tego komputera.
  configuration = ./configuration.nix;

  # Jedyna wymagana systemowa nazwa konta.
  # Flake utworzy użytkownika i skonfiguruje dla niego Home Managera, greetd,
  # grupy, ścieżki profilu, Ironbar oraz katalog zapisu replayów.
  username = "nowy-user";

  # Opcjonalna przyjazna nazwa widoczna w narzędziach systemowych.
  # Pominięcie pola powoduje użycie wartości `username`.
  userDescription = "Nowy użytkownik";

  # Opcjonalna nazwa katalogu w home/. Domyślnie jest równa `username`.
  # Ustaw "wojtek", aby użyć home/wojtek bez kopiowania profilu.
  # homeProfile = "wojtek";

  desktopFeatures = {
    # Metryki AMD GPU, VRAM i temperatury w Ironbarze.
    # Ustaw true tylko dla GPU obsługiwanego przez skrypt AMD w tym repo.
    amdGpu = false;

    # Status Dockera w Ironbarze, lazydocker i panel terminalowy.
    # Nie uruchamia demona; systemowy Docker pochodzi z modules/development.nix.
    docker = false;

    # Autostart i skróty GPU Screen Recorder oraz konfiguracja replay.
    # Pakiety systemowe pochodzą z modules/gaming.nix.
    gaming = false;

    # Bateria, jasność i klawisze regulacji ekranu w sesji użytkownika.
    laptop = false;

    # Prywatne aplikacje i skróty, obecnie m.in. Discord, Plexamp i EasyEffects.
    personalApps = false;
  };

  # Wymagane, gdy desktopFeatures.laptop = true.
  # Nazwy urządzeń pokaże `brightnessctl --list` albo `ls /sys/class/backlight`.
  backlightDevice = "amdgpu_bl2";

  # Każde z poniższych pól jest opcjonalnym nadpisaniem wartości z flake.nix.
  replayConfig = {
    # focused_monitor: automatycznie wybiera aktywny monitor przy starcie replay.
    # screen: pierwszy monitor znaleziony przez GPU Screen Recorder.
    # Można też podać stałą nazwę z `gpu-screen-recorder --list-monitors`,
    # np. "eDP-1", "DP-1" albo "HDMI-A-1".
    captureSource = "focused_monitor";

    # Liczba klatek na sekundę.
    fps = 60;

    # Długość bufora ShadowPlay/replay w sekundach.
    seconds = 120;

    # Kodek obrazu obsługiwany przez GPU Screen Recorder.
    # Typowe wartości: "h264", "hevc", "av1".
    videoCodec = "hevc";

    # Docelowy bitrate obrazu w kb/s używany przy jakości custom.
    videoBitrate = 25000;

    # Kodek dźwięku, np. "opus", "aac" albo "flac".
    audioCodec = "opus";
  };
}
```

Domyślne wartości `replayConfig` są już zdefiniowane w `flake.nix`. Jeśli nie
chcesz ich zmieniać, wystarczy pozostawić wyłącznie potrzebne nadpisanie albo
usunąć cały blok.

### Wykrywanie monitora i podświetlenia

Polecane polecenia należy uruchamiać w działającej sesji graficznej:

```bash
hyprctl monitors
hyprctl monitors -j | jq -r '.[].name'
gpu-screen-recorder --list-monitors
brightnessctl --list
ls /sys/class/backlight
```

`focused_monitor` wybiera monitor przy uruchamianiu bufora. Nagranie nie
przeskakuje później między ekranami, gdy zmieni się aktywny monitor.

## 5. Dostosowanie `configuration.nix`

Minimalny, komentowany szablon oparty na ROG-u:

```nix
{ hostName, pkgs, userDescription, username, ... }:

{
  imports = [
    # Zawsze własny, wygenerowany plik docelowego komputera.
    ./hardware-configuration.nix

    # Podstawowe narzędzia, locale, strefa czasowa i obsługa flakes.
    ../../modules/common.nix

    # Hyprland, greetd, PipeWire, Bluetooth, Thunar, fonty i usługi pulpitu.
    ../../modules/desktop.nix

    # Opcjonalny program desktop-benchmark. Nie jest wymagany przez pulpit.
    ../../modules/desktop-shell.nix

    # Fish, Codex, Docker, Compose, lazydocker i lazyssh.
    # Jeśli Docker nie jest potrzebny, można zamiast tego importować tylko:
    # ../../modules/development-core.nix
    ../../modules/development.nix

    # Steam, Gamescope, GameMode, Proton-GE i GPU Screen Recorder.
    # Usuń, jeśli desktopFeatures.gaming = false i host nie służy do grania.
    ../../modules/gaming.nix

    # Grafika AMD, biblioteki 32-bit, wczesny KMS i narzędzia diagnostyczne.
    # Usuń dla Intel/NVIDIA; odpowiedni moduł trzeba wtedy przygotować osobno.
    ../../modules/hardware-amd-gpu.nix

    # Tylko laptopy ASUS obsługiwane przez asusctl/asusd.
    # Ładuje asus-armoury, ustawia najnowsze jądro i ROG Control Center.
    ../../modules/hardware-asus-laptop.nix
  ];

  # Zakłada start UEFI przez systemd-boot. Dla GRUB/BIOS trzeba zmienić tę sekcję.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Wartość pochodzi automatycznie z nazwy katalogu hosts/<host>/.
  networking.hostName = hostName;
  networking.networkmanager.enable = true;

  # Na laptopie zamknięcie pokrywy nic nie robi na baterii, zasilaczu i stacji.
  # Na desktopie cały blok można usunąć.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # Ustawienia regionalne można skopiować bez zmian lub dostosować do kraju.
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pl_PL.UTF-8";
    LC_IDENTIFICATION = "pl_PL.UTF-8";
    LC_MEASUREMENT = "pl_PL.UTF-8";
    LC_MONETARY = "pl_PL.UTF-8";
    LC_NAME = "pl_PL.UTF-8";
    LC_NUMERIC = "pl_PL.UTF-8";
    LC_PAPER = "pl_PL.UTF-8";
    LC_TELEPHONE = "pl_PL.UTF-8";
    LC_TIME = "pl_PL.UTF-8";
  };

  services.xserver.xkb = {
    layout = "pl";
    variant = "";
  };
  console.keyMap = "pl2";

  # Nazwa i opis są przekazywane z default.nix.
  users.users.${username} = {
    isNormalUser = true;
    description = userDescription;
    extraGroups = [
      "networkmanager"
      "wheel" # Na NixOS grupa wheel daje uprawnienia przez sudo.
    ];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;

  # Ustaw raz przy tworzeniu hosta. Nie podnoś później razem z wersją NixOS.
  system.stateVersion = "26.05";
}
```

## 6. Katalog modułów systemowych

| Moduł | Co włącza | Kiedy importować |
|---|---|---|
| `common.nix` | Flakes, strefę Warszawa, polskie locale, Git, curl, jq, fd i ripgrep | Praktycznie na każdym hoście |
| `desktop.nix` | Hyprland/UWSM, automatyczną sesję greetd dla wybranego użytkownika, PipeWire, Bluetooth, Thunar, Polkit i fonty | Na hostach graficznych |
| `desktop-shell.nix` | Wyłącznie polecenie `desktop-benchmark` | Opcjonalnie do pomiarów pulpitu |
| `development-core.nix` | Fish, Codex i GNU Make | Gdy potrzebne są podstawowe narzędzia deweloperskie bez Dockera |
| `development.nix` | Importuje `development-core`, dodaje Docker uruchamiany ręcznie, grupę `docker`, Compose, lazydocker i lazyssh | Na hostach deweloperskich z Dockerem |
| `gaming.nix` | Steam, Proton-GE, Gamescope, GameMode i GPU Screen Recorder UI | Na komputerach gamingowych |
| `hardware-amd-gpu.nix` | `amdgpu` w initrd, grafikę 32-bitową, libva-utils, radeontop i vulkan-tools | Tylko dla GPU AMD |
| `hardware-asus-laptop.nix` | Najnowsze jądro, `asus-armoury`, `asusd`, UPower, profile zasilania i ROG Control Center | Tylko dla zgodnych laptopów ASUS |

`hardware-configuration.nix` nie jest modułem współdzielonym. Musi pochodzić z
konkretnej maszyny.

### Zależności między importami i `desktopFeatures`

- import `development.nix` włącza systemowego Dockera; flaga `docker` włącza
  tylko jego elementy w sesji użytkownika,
- import `gaming.nix` dostarcza GSR i gry; flaga `gaming` dodaje autostart,
  skróty i konfigurację replay,
- import `hardware-amd-gpu.nix` konfiguruje systemową grafikę AMD; flaga
  `amdGpu` pokazuje jej metryki w Ironbarze,
- flaga `laptop` nie oznacza automatycznie ASUS-a: włącza ogólne elementy
  laptopowe w sesji, a moduł ASUS jest niezależnym wyborem sprzętowym.

## 7. Moduły profilu Home Managera

| Plik w `home/<profil>/` | Odpowiedzialność |
|---|---|
| `default.nix` | Punkt wejścia, pakiety użytkownika, Fish, tmux, Neovim, btop, Git i konfiguracja replay |
| `desktop.nix` | Aplikacje pulpitu, GTK, Foot, Fuzzel i MPV |
| `hyprland.nix` oraz `hyprland.lua` | Sesja Hyprlanda, autostart, skróty i reguły okien |
| `ironbar.nix` | Panel, moduły statusu, metryki, popupy i usługa użytkownika |
| `ironbar-metric.nix` | Pobieranie i formatowanie metryk CPU, RAM, sieci, dysku i AMD GPU |
| `notifications.nix` | Centrum i wygląd powiadomień SwayNC |
| `osd.nix` | SwayOSD dla głośności i jasności |
| `scripts.nix` | Współdzielone skrypty sesji |
| `theme.nix` | Kolory, fonty, tapety oraz motywy GTK i ikon |
| `zen.nix` | Zen Browser i jego polityki |

Po skopiowaniu katalogu na nową nazwę użytkownika pliki działają bez zmian.
Opcjonalnej adaptacji mogą wymagać jedynie osobiste aplikacje, skróty, tapety,
branding wygaszacza oraz preferencje przeglądarki.

## 8. Dodanie hosta i użytkownika do allowlisty Git

Nowe katalogi są celowo ignorowane, dopóki nie zostaną jawnie zatwierdzone.
W `.gitignore` dodaj:

```gitignore
!/hosts/nowy-host/
!/hosts/nowy-host/**

!/home/nowy-user/
!/home/nowy-user/**
```

Drugiej pary nie dodawaj, jeśli używasz `homeProfile = "wojtek"` i nie tworzysz
`home/nowy-user`.

Następnie:

```bash
git add .gitignore hosts/nowy-host
git add home/nowy-user # tylko dla osobnej kopii profilu
```

Flake oparty na Git nie widzi nieśledzonych plików. Przed `git add` do testów
używaj odwołania `path:.`.

## 9. Sprawdzenie konfiguracji

```bash
# Powinien pokazać nixosConfigurations.nowy-host.
nix flake show path:.

# Ewaluacja wszystkich outputów.
nix flake check path:.

# Pełny build bez aktywowania systemu.
nix build path:.#nixosConfigurations.nowy-host.config.system.build.toplevel
```

Po dodaniu wszystkich plików do Git można używać krótszego `.#...` zamiast
`path:.#...`.

## 10. Aktywacja lub instalacja

Na działającym NixOS najpierw użyj trybu tymczasowego:

```bash
sudo nixos-rebuild test --flake path:.#nowy-host
```

Sprawdź logowanie, sieć, dźwięk, grafikę, jasność, uśpienie i panel. Dopiero
potem zapisz konfigurację:

```bash
sudo nixos-rebuild switch --flake path:.#nowy-host
```

Podczas świeżej instalacji, gdy partycje są już przygotowane i zamontowane pod
`/mnt`, a repo znajduje się np. w `/mnt/etc/nixos`:

```bash
sudo nixos-install --flake path:/mnt/etc/nixos#nowy-host
```

Konfiguracja nie przechowuje hasła. Ustaw je lokalnie dla nowego konta:

```bash
sudo passwd nowy-user
```

## 11. Kontrola po uruchomieniu

```bash
hostnamectl hostname
id nowy-user
systemctl status greetd
systemctl --user status ironbar
hyprctl monitors
brightnessctl --list
gpu-screen-recorder --list-monitors
```

Jeśli importujesz `development.nix`, Docker pozostaje celowo wyłączony po
starcie. Uruchamiaj go ręcznie:

```bash
sudo systemctl start docker
```

## Najczęstsze błędy

### Flake nie udostępnia `nixosConfigurations.nowy-host`

Sprawdź, czy istnieje `hosts/nowy-host/default.nix` i czy katalog nie jest
pomijany przez Git. Przed dodaniem do indeksu użyj `path:.`.

### Brakuje profilu Home Managera

Jeśli `username = "nowy-user"`, flake domyślnie szuka
`home/nowy-user/default.nix`. Skopiuj profil albo ustaw:

```nix
homeProfile = "wojtek";
```

### Host jest laptopem, ale nie ustawia `backlightDevice`

Przy `desktopFeatures.laptop = true` pole jest wymagane. Znajdź nazwę przez
`brightnessctl --list` i wpisz ją w manifeście hosta.

### Hyprland nie widzi GPU

Nie kopiuj w ciemno modułu AMD na Intel/NVIDIA. Sprawdź sprzęt:

```bash
lspci -nnk | rg -A3 'VGA|3D|Display'
```

Następnie dobierz właściwy moduł sterownika.

### Moduł ASUS powoduje błędy

Usuń `hardware-asus-laptop.nix` na sprzęcie innego producenta. Producenta i
model pokażą:

```bash
cat /sys/class/dmi/id/sys_vendor
cat /sys/class/dmi/id/product_name
```
