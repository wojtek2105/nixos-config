# Nowy host i użytkownik krok po kroku

Ten przewodnik opisuje utworzenie nowej konfiguracji przez generator hosta oraz
współdzielony profil Home Managera. Nazwa hosta, użytkownika i ścieżka profilu
są parametrami manifestu — nie trzeba ich przepisywać we współdzielonych modułach.

## Założenia

- repozytorium znajduje się w bieżącym katalogu,
- nowy host ma nazwę `nowy-host`,
- nowe konto ma nazwę `nowy-user`,
- konfiguracja sprzętowa jest generowana na docelowym komputerze,
- sekrety, hasła, sieci Wi-Fi i klucze prywatne nie trafiają do Git.

Nazwy w przykładach należy zastąpić własnymi. Nazwa użytkownika powinna być
krótka, zapisana małymi literami i nie zawierać spacji.

## Kolejność całego wdrożenia

1. Zrób kopię danych z docelowego komputera i zdecyduj, czy dysk będzie
   wyczyszczony, szyfrowany albo używany w dual boot.
2. W bieżącym checkoutcie utwórz manifest nowego hosta i wybierz profil użytkownika.
3. Dopasuj manifest funkcji i importy sprzętowe, ale nie kopiuj konfiguracji
   sprzętowej ROG-a.
4. Przenieś dokładnie ten checkout na Live ISO: przez zatwierdzony i wypchnięty
   commit albo jako kopię katalogu roboczego bez sekretów.
5. Na docelowym komputerze przygotuj i zamontuj partycje, a następnie wygeneruj
   jego własny `hardware-configuration.nix`.
6. Wykonaj ewaluację i build nowego outputu. Dopiero po ich powodzeniu uruchom
   `nixos-install`.
7. Przed restartem ustaw hasło nowego konta przez `nixos-enter`; po restarcie
   sprawdź sprzęt i pulpit przed włączaniem kolejnych funkcji.

## 0. Przygotowanie źródła konfiguracji

Najpierw sprawdź stan repozytorium:

```bash
git status --short
git diff --check
```

Zwykły `git clone` na komputerze docelowym zawiera tylko zmiany zatwierdzone i
wypchnięte na serwer. Nie przeniesie niezatwierdzonych ani nieśledzonych plików
z bieżącego katalogu. Są dwa bezpieczne warianty:

- zatwierdź i wypchnij kompletny stan potrzebny do buildu, a następnie sklonuj
  go na Live ISO,
- skopiuj cały katalog roboczy na nośnik lub przez sieć, wykluczając co najmniej
  `.git/`, `.env`, `.env.*`, `result` i `result-*`.

Przed przeniesieniem upewnij się, że w źródle znajdują się wszystkie pliki
wskazywane przez `flake.nix` i importy Nix. Dotyczy to również nowych modułów
oraz trzech plików z `home/<profil>/wallpapers/fallback/`. Nie przenoś haseł,
tokenów, prywatnych kluczy SSH ani profili Wi-Fi.

## 1. Interaktywny manager i wspólny profil Home Managera

Domyślnie nowy użytkownik współdzieli źródła istniejącego profilu, ale zachowuje
oddzielny katalog `/home/<username>` i stan aplikacji. Uruchom manager:

```bash
make host-manager
```

Jeżeli `gum`, `jq` lub Git nie są dostępne, manager sam uruchomi się w
jednorazowym `nix shell`. Narzędzia nie są instalowane do systemu ani dodawane
do flake. Wybierz **Utwórz host od zera**, uzupełnij dane użytkownika i wybierz
architekturę, profil oraz moduły. Później ten sam manager edytuje host, zmienia
moduły on/off, pokazuje diff i — wyłącznie po potwierdzeniu — uruchamia check,
build, test albo switch.

W menu `↑`/`↓` zmienia zaznaczenie, `→` oraz Enter potwierdzają wybór lub
przełączają pozycję, a `←` i Esc cofają o jeden poziom. Pozycje zawierają
przyjazną nazwę, opis i stan, więc nie trzeba znać technicznych kluczy takich
jak `x1e`: jest to obsługa laptopów Snapdragon X Elite i jest dostępna tylko
dla architektury ARM64.

Wynik to `hosts/nowy-host/host.json` z wszystkimi zmiennymi oraz dwa małe pliki
Nix będące stałym mostkiem do wspólnej konfiguracji. JSON jest jedynym miejscem
edycji nazwy hosta, użytkownika, skali, funkcji i modułów. Wspólny profil to
`base`; własne dodatki umieszczaj w `home/individual/<użytkownik>/override.nix`.

```bash
make host-manager
```

### Osobna kopia profilu użytkownika

Jeżeli profil ma się później rozwijać niezależnie, skopiuj go przed utworzeniem
hosta i wskaż jego nazwę w polu **Wspólny profil Home Managera**:

```bash
mkdir -p home/nowy-user
cat > home/nowy-user/default.nix <<'EOF'
{ ... }: { imports = [ ../base/default.nix ]; }
EOF
make host-manager
```

Generator nie modyfikuje ani nie kopiuje profilu automatycznie. Każdy profil
musi zawierać `default.nix` i `theme.nix`; flake przekazuje jego paletę również
do systemowego Tuigreet.

## 2. Konfiguracja sprzętu

Generator celowo nie tworzy ani nie kopiuje `hardware-configuration.nix`.
Dzięki temu nie da się przez przypadek zbudować nowego hosta z UUID-ami dysków
i modułami ROG-a.

Po dodaniu własnego `hardware-configuration.nix` nazwa katalogu automatycznie
staje się:

- nazwą outputu flake: `nixosConfigurations.nowy-host`,
- wartością `networking.hostName`.

Nie trzeba wpisywać `nowy-host` wewnątrz `configuration.nix`.

## 3. Wygenerowanie konfiguracji sprzętu

Pliku z ROG-a nie wolno używać na innym komputerze. Na uruchomionym systemie
docelowym wykonaj z katalogu repozytorium:

```bash
sudo nixos-generate-config --show-hardware-config \
  | sudo tee hosts/nowy-host/hardware-configuration.nix >/dev/null
```

Podczas instalacji z obrazu NixOS, po zamontowaniu systemu pod `/mnt`, użyj:

```bash
sudo nixos-generate-config --root /mnt --show-hardware-config \
  | sudo tee hosts/nowy-host/hardware-configuration.nix >/dev/null
```

Jeżeli wcześniej wykonasz `sudo -i` i całą instalację prowadzisz w powłoce
roota, pomiń oba wystąpienia `sudo` i użyj zwykłego przekierowania `>`.

Przed kontynuacją sprawdź szczególnie:

- UUID systemu plików `/` i `/boot`,
- typ systemu plików,
- `swapDevices`,
- moduły kontrolera dysku i CPU,
- `nixpkgs.hostPlatform`.

Dla komputerów ARM64 ustaw w manifeście hosta `system = "aarch64-linux"`.
Flake przekazuje tę wartość do `nixosSystem`; nie zmieniaj globalnie
architektury innych hostów. Wygenerowany plik sprzętowy powinien również
wykazywać `nixpkgs.hostPlatform = "aarch64-linux"`.

## 4. Dane hosta i moduły

Nie edytuj `default.nix` ani `configuration.nix`: oba są stałymi adapterami
do `host.json`. Wybieraj moduły i funkcje przez `make host-manager`; chroni to
przed zestawami Ollama bez Dockera, ASUS bez AMD GPU, laptopa bez desktopu oraz
X1E poza ARM64. Pozostała historyczna lista poniżej opisuje znaczenie pól
przeniesionych do JSON.

Poniższy szablon pokazuje wszystkie obsługiwane pola manifestu hosta:

```nix
{
  # Główny moduł NixOS tego komputera.
  configuration = ./configuration.nix;

  # Jedyna wymagana systemowa nazwa konta.
  # Flake utworzy użytkownika i skonfiguruje dla niego Home Managera, greetd,
  # grupy, ścieżki profilu, Ironbar oraz katalog zapisu replayów.
  username = "nowy-user";

  # Platforma hosta. Domyślnie jest to x86_64-linux; dla Snapdragonów użyj:
  # system = "aarch64-linux";

  # Opcjonalna przyjazna nazwa widoczna w narzędziach systemowych.
  # Pominięcie pola powoduje użycie wartości `username`.
  userDescription = "Nowy użytkownik";

  # Opcjonalna nazwa katalogu w home/. Domyślnie jest równa `username`.
  # Profil użytkownika importuje wspólną bazę home/base.
  # homeProfile = "nowy-user";

  # Jedna mapa steruje modułami NixOS i odpowiadającymi im elementami pulpitu.
  features = {
    # Metryki AMD GPU, VRAM i temperatury w Ironbarze.
    # Ustaw true tylko dla GPU obsługiwanego przez skrypt AMD w tym repo.
    amdGpuMetrics = false;

    # BlueZ i zasilanie adaptera po starcie; włącz tylko, gdy host ma Bluetooth.
    bluetooth = false;

    # Docker, Compose, lazydocker, lazyssh oraz integracja z pulpitem.
    # Daemon pozostaje uruchamiany ręcznie.
    docker = false;

    # Lokalny Compose Ollama + Open WebUI w ~/Dev/Ollama. Wymaga Dockera;
    # modele i ustawienia GUI pozostają prywatnymi danymi użytkownika.
    ollama = false;

    # Steam, Proton-GE, Gamescope, GameMode i biblioteki 32-bit.
    gaming = false;

    # ALVR, Steam i ADB dla Quest 2 po USB-C; bez otwierania portów LAN.
    vr = false;

    # GPU Screen Recorder, uruchamiany na żądanie, skróty i konfiguracja replay.
    screenRecording = false;

    # vainfo, radeontop i vulkaninfo do doraźnej diagnostyki GPU.
    hardwareDiagnostics = false;

    # Opcjonalny benchmark schedulerów; instaluje się tylko na czas porównań.
    # Nie uruchamia testu ani usługi automatycznie.
    schedulerBenchmark = false;

    # Bateria, jasność i klawisze regulacji ekranu w sesji użytkownika.
    laptop = false;

    # Lokalne dyktowanie Whisper oraz dostęp do grupy input dla hotkeya.
    # Włączenie dodaje też skróty, launcher i wskaźnik Ironbara.
    voxtype = false;

    # Każda większa aplikacja może być przełączana osobno.
    personalApps = {
      discord = false;
      easyeffects = false;
      plexamp = false;
    };
  };

  # Wymagane, gdy features.laptop = true.
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

    # Hyprland, greetd, PipeWire, awaryjny Thunar, fonty i usługi.
    ../../modules/desktop.nix

    # Fish, Codex i GNU Make.
    ../../modules/development-core.nix

    # Grafika AMD i wczesny KMS.
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

`flake.nix` automatycznie dołącza `docker.nix`, `gaming.nix`, `vr.nix`,
`screen-recording.nix`, `hardware-diagnostics.nix` i `scheduler-benchmark.nix`
według mapy `features` z manifestu. Nie należy powtarzać tych importów w
`configuration.nix`.

## 6. Katalog modułów systemowych

| Moduł | Co włącza | Kiedy importować |
|---|---|---|
| `common.nix` | Flakes, ZRAM skalowany do 50% RAM-u, strefę Warszawa, polskie locale, Git, curl, jq, fd i ripgrep | Praktycznie na każdym hoście |
| `desktop.nix` | Greetd/Tuigreet z logowaniem hasłem i uruchamianiem Hyprlanda przez UWSM, PipeWire, awaryjny Thunar, Polkit i fonty | Na hostach graficznych |
| `bluetooth.nix` | BlueZ i zasilanie adaptera po starcie | Gdy `features.bluetooth = true` |
| `development-core.nix` | Fish, Codex i GNU Make | Gdy potrzebne są podstawowe narzędzia deweloperskie bez Dockera |
| `docker.nix` | Docker uruchamiany ręcznie, grupę `docker`, Compose, lazydocker i lazyssh | Gdy `features.docker = true` |
| `ollama.nix` | Pakiet Compose dla lokalnego stosu Ollama + Open WebUI | Gdy `features.ollama = true` i Docker jest włączony |
| `gaming.nix` | Steam, Proton-GE, Gamescope, GameMode oraz grafikę i ALSA 32-bit | Gdy `features.gaming = true` |
| `vr.nix` | ALVR, Steam i ADB dla przewodowego Quest 2; bez usług i otwierania portów | Gdy `features.vr = true` |
| `scheduler-benchmark.nix` | Zachowany harness, stress-ng, SuperTuxKart i schedulery SCX | Doraźnie, gdy `features.schedulerBenchmark = true` |
| `screen-recording.nix` | GPU Screen Recorder i oficjalne UI | Gdy `features.screenRecording = true` |
| `voxtype.nix` | Lokalne dyktowanie Voxtype, model i dostęp do grupy `input` | Gdy `features.voxtype = true` |
| `hardware-amd-gpu.nix` | `amdgpu` w initrd i systemową obsługę grafiki | Tylko dla GPU AMD |
| `hardware-diagnostics.nix` | libva-utils, radeontop i vulkan-tools | Doraźnie, gdy `features.hardwareDiagnostics = true` |
| `hardware-asus-laptop.nix` | Najnowsze jądro, `asus-armoury`, `asusd`, UPower, profile zasilania i ROG Control Center | Tylko dla zgodnych laptopów ASUS |

`hardware-configuration.nix` nie jest modułem współdzielonym. Musi pochodzić z
konkretnej maszyny.

ZRAM z `common.nix` nie zawiera identyfikatora sprzętu ani użytkownika. Jego
logiczna pojemność wynika z fizycznego RAM-u wykrytego na danym urządzeniu, więc
po skopiowaniu konfiguracji nie wymaga ręcznej zmiany.

### Jedno źródło prawdy: `features`

- `docker`, `ollama`, `gaming`, `vr`, `screenRecording`, `hardwareDiagnostics` i
  `schedulerBenchmark` warunkowo importują kompletne moduły systemowe,
- `amdGpuMetrics`, `docker`, `ollama`, `screenRecording`, `laptop` i `personalApps` są
  przekazywane także do Home Managera i sterują wyłącznie pasującym interfejsem,
- `personalApps` rozdziela Discord, Plexamp i EasyEffects, więc wyłączenie jednej
  aplikacji usuwa jej pakiet oraz skrót bez wpływu na pozostałe,
- `laptop` nie oznacza automatycznie ASUS-a: włącza ogólne elementy laptopowe w
  sesji, a moduł ASUS nadal jest niezależnym wyborem sprzętowym.

## 7. Moduły profilu Home Managera

| Plik w `home/<profil>/` | Odpowiedzialność |
|---|---|
| `default.nix` | Punkt wejścia, pakiety użytkownika, Fish, tmux, btop, Git i konfiguracja replay |
| `desktop.nix` | Aplikacje pulpitu, GTK, Foot, Fuzzel, MPV i Yazi |
| `hyprland.nix` oraz `hyprland.lua` | Sesja Hyprlanda, autostart, skróty i reguły okien |
| `ironbar.nix` | Panel, moduły statusu, metryki, popupy i usługa użytkownika |
| `ironbar-metric.nix` | Pobieranie i formatowanie metryk CPU, RAM, sieci, dysku i AMD GPU |
| `neovim.nix` | Codzienny Neovim oraz odizolowany PoC oparty na Kickstart |
| `notifications.nix` | Centrum i wygląd powiadomień SwayNC |
| `osd.nix` | SwayOSD dla głośności i jasności |
| `scripts.nix` | Współdzielone skrypty sesji |
| `theme.nix` | Kolory, fonty, tapety oraz motywy GTK i ikon |
| `zen.nix` | Zen Browser i jego polityki |

Po skopiowaniu katalogu na nową nazwę użytkownika pliki działają bez zmian.
Opcjonalnej adaptacji mogą wymagać jedynie osobiste aplikacje, skróty, tapety,
branding wygaszacza oraz preferencje przeglądarki.

Obecny profil zawiera widoczny napis `WOJTECH` oraz grafikę ASCII w
`home/<profil>/default.nix`. Dla osobnego profilu siostry zmień opis skrótu i
zawartość `xdg.configFile."screensaver/wojtech.txt"`. Identyfikator techniczny
`org.polamaniec.screensaver` może pozostać bez zmian; jeśli go zmieniasz, zrób
to spójnie w `default.nix` oraz regule okna w `hyprland.lua`.

Skrypty produkcji tapet w `tools/` wskazują obecnie katalog `home/base`.
Nie wpływa to na działanie pulpitu siostry, ale przed generowaniem osobnego
zestawu tapet trzeba świadomie zmienić ich katalog docelowy.

## 8. Dodanie hosta i użytkownika do allowlisty Git

Nowe katalogi są celowo ignorowane, dopóki nie zostaną jawnie zatwierdzone.
W `.gitignore` dodaj:

```gitignore
!/hosts/nowy-host/
!/hosts/nowy-host/**

!/home/nowy-user/
!/home/nowy-user/**
```

Drugiej pary nie dodawaj, jeśli używasz profilu użytkownika importującego `home/base` i nie tworzysz
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
nix build path:.#nixosConfigurations.nowy-host.config.system.build.toplevel --no-link
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

### Instalacja od zera z Live ISO

Poniższy wariant zakłada komputer `x86_64`, start Live ISO w trybie UEFI,
systemd-boot, jedną partycję EFI i jedną partycję główną. Przed formatowaniem
wykonaj kopię danych i sprawdź urządzenie po modelu oraz rozmiarze:

```bash
sudo -i
lsblk -e7 -o NAME,SIZE,MODEL,SERIAL,TYPE,FSTYPE,MOUNTPOINTS
test -d /sys/firmware/efi/efivars && echo UEFI || echo BIOS
lspci -nnk | grep -A3 -E 'VGA|3D|Display'
```

Jeśli wynik pokazuje BIOS, docelowy dysk ma pozostać w dual boot, ma używać
LUKS albo komputer nie jest `x86_64`, przerwij ten wariant. Najpierw trzeba
dopasować bootloader, partycje lub parametr architektury; obecny flake zakłada
`x86_64-linux` i UEFI z systemd-boot. Bez konfiguracji podpisanego bootloadera
Secure Boot powinien być wyłączony.

Na pustym dysku utwórz tablicę GPT, partycję EFI około 1 GiB typu EFI System i
partycję główną zajmującą resztę. Możesz użyć `cfdisk` lub `parted`. Dopiero po
ponownym sprawdzeniu nazw sformatuj właściwe partycje. Przykład dla dysku NVMe,
w którym EFI to `p1`, a root to `p2`:

```bash
# UWAGA: te dwie komendy bezpowrotnie kasują zawartość wskazanych partycji.
mkfs.fat -F 32 -n NIXBOOT /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/NIXBOOT /mnt/boot
findmnt -R /mnt
```

Nazwy dla dysku SATA zwykle wyglądają jak `/dev/sda1` i `/dev/sda2`. Nie
wklejaj nazw z przykładu bez potwierdzenia ich przez `lsblk`. Konfiguracja używa
ZRAM-u i nie wymaga partycji swap; hibernacja wymaga osobnego projektu swapu i
resume.

Następnie umieść przygotowane repo w `/mnt/etc/nixos`, przejdź do niego i
wygeneruj konfigurację sprzętową tej maszyny:

```bash
mkdir -p /mnt/etc/nixos
# W tym miejscu sklonuj zatwierdzony commit albo skopiuj przygotowany checkout.
cd /mnt/etc/nixos

nixos-generate-config --root /mnt --show-hardware-config \
  > hosts/nowy-host/hardware-configuration.nix

lsblk -f
sed -n '1,220p' hosts/nowy-host/hardware-configuration.nix
```

Potwierdź UUID-y `/` i `/boot`, platformę, moduły dysku oraz mikrokod CPU.
Następnie wykonaj kontrole i instalację:

```bash
nix flake show path:.
nix flake check path:.
nix build path:.#nixosConfigurations.nowy-host.config.system.build.toplevel --no-link
nixos-install --flake 'path:/mnt/etc/nixos#nowy-host'
```

`nixos-install` poprosi o hasło roota. Konfiguracja nie przechowuje hasła
zwykłego użytkownika, dlatego ustaw je w zainstalowanym systemie jeszcze przed
restartem:

```bash
nixos-enter --root /mnt -c 'passwd nowy-user'
sync
reboot
```

Obecny `modules/desktop.nix` pokazuje ekran Tuigreet po każdym uruchomieniu.
Hasło użytkownika jest wymagane przed rozpoczęciem sesji Hyprlanda, którą
uruchamia UWSM; hasło pozostaje też wymagane do `sudo`.

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

Jeśli ustawisz `features.docker = true`, Docker pozostaje celowo wyłączony po
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
`home/nowy-user/default.nix`. Utwórz profil importujący `home/base`, albo
ustaw istniejący profil użytkownika:

```nix
homeProfile = "wojtek";
```

### Host jest laptopem, ale nie ustawia `backlightDevice`

Przy `features.laptop = true` pole jest wymagane. Znajdź nazwę przez
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
