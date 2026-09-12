# ASUS Vivobook S 15 ze Snapdragonem

Ten host to ostrożny punkt startowy dla wariantu Vivobook S 15 z procesorem
Snapdragon X Elite. Używa platformy `aarch64-linux`, pełnego profilu
`home/wojtek` importującego `home/base` oraz modułu `x1e-nixos-config`
dostosowanego do tego modelu: własnego kernela, device tree, initrd i firmware.
Zapewnia sesję Hyprland z Ironbarem, Zen Browserem, terminalem, Gitem, Vimem,
GNU Make i natywnym Codexem. Skala pulpitu wynosi `2`, odpowiednio dla
wbudowanego ekranu 2880×1620; po pierwszym starcie można ją skorygować w
`host.json`, jeśli rzeczywisty wariant panelu wymaga innej wartości.

Pierwszy etap celowo nie włącza Dockera, lokalnych modeli AI, Agent Managera,
Pi, Godota, gamingu, nagrywania, VR, metryk AMD ani modułów przeznaczonych dla
laptopa ROG. Codex pochodzi z Nixpkgs i działa natywnie na ARM64; Agent Manager
i Pi są pomijane, ponieważ ich przypięte paczki upstream są obecnie tylko dla
`x86_64-linux`.

Kernel to `6.17.0` z gałęzi Linaro ARM64 Laptops, rozszerzony o poprawki X Elite
i pakiety firmware dla Vivobooka. W bazowym systemie są też natywne dla ARM64
Zen Browser oraz Codex (z GNU Make).

Zwykły obraz instalacyjny NixOS ARM64 nie zawiera jeszcze kompletnego stosu
startowego X Elite. Najpierw przygotuj nośnik z forka
`JamiKettunen/x1e-vivobook-nixos-config`, ponieważ zawiera device tree dla
S5507 i potrzebne moduły initrd. Jego instrukcja ostrzega, że
`nixos-generate-config` nie jest na tej platformie wiarygodnym źródłem
konfiguracji sprzętowej.

Jeśli zachowujesz Windows, przed zmianą partycji zapisz klucz odzyskiwania i
wyłącz szyfrowanie urządzenia/BitLocker. Zmniejsz partycję Windows z poziomu
Windows, nie formatuj istniejącej partycji EFI, a przed uruchomieniem własnego
kernela wyłącz Secure Boot w UEFI.

Na komputerze x86_64 nośnik buduje się z jego outputu `iso` (cross-build może
trwać kilka godzin):

```bash
nix build github:JamiKettunen/x1e-vivobook-nixos-config/vivobook#iso
```

`hardware-configuration.nix` celowo nie jest wersjonowany ani zastąpiony
szablonem. Po zamontowaniu partycji pod `/mnt` utwórz go ręcznie dla własnych
UUID-ów, na przykład:

```bash
{ lib, ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/TWOJ-UUID-ROOT";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/TWOJ-UUID-EFI";
    fsType = "vfat";
  };
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
```

Sprawdź w nim `nixpkgs.hostPlatform = "aarch64-linux"`, partycje oraz UUID-y.
Dopiero wtedy flake wystawi output `armaniec`; chroni to przed instalacją z
dyskami lub ustawieniami sprzętu skopiowanymi z innego hosta.

Po sklonowaniu repozytorium na instalatorze i dodaniu pliku sprzętowego najpierw
zbuduj system bez instalowania go:

```bash
nix flake check path:.
nix build path:.#nixosConfigurations.armaniec.config.system.build.toplevel --no-link
```

Gdy oba polecenia zakończą się poprawnie i jeszcze raz sprawdzisz UUID-y oraz
punkty montowania, zainstaluj system do `/mnt`:

```bash
sudo nixos-install --root /mnt --no-channel-copy --flake path:.#armaniec
```

Instalator poprosi o hasło roota. Przed restartem ustaw też hasło zwykłego
użytkownika, ponieważ nie jest ono zapisane w repozytorium:

```bash
sudo nixos-enter --root /mnt -c 'passwd wojtek'
```

Na tej platformie samo skopiowanie systemd-boot na partycję EFI może nie dodać
działającego wpisu firmware. Jeśli po instalacji nie pojawi się wpis NixOS,
uruchom ponownie nośnik, wybierz EFI Shell, wykonaj `map -r -b`, przejdź na
partycję `FS*` zawierającą `EFI\\systemd\\systemd-bootaa64.efi`, a następnie:

```text
bcfg boot add 0 EFI\systemd\systemd-bootaa64.efi "NixOS"
bcfg boot dump
reset
```

Numer `FS*` jest zależny od bieżącego układu dysków; nie kopiuj numeru z
cudzego komputera. Pełna procedura EFI jest utrzymywana w instrukcji
[`x1e-vivobook-nixos-config`](https://github.com/JamiKettunen/x1e-vivobook-nixos-config).

Po pierwszym starcie sprawdź działanie ekranu, Wi-Fi, dźwięku, klawiatury,
touchpada, baterii i usypiania. Dopiero na podstawie tych wyników włącz
`features.laptop` z rzeczywistą nazwą podświetlenia oraz dodaj specyficzne dla
tego wariantu moduły sprzętowe.

Nie dodawaj emulacji x86 do pierwszej instalacji. QEMU przez `binfmt` może
uruchamiać pojedyncze binaria x86_64 po stabilizacji systemu, ale nie emuluje
sterowników ani kernela i jest wyraźnie wolniejszy. FEX jest szybszą emulacją
userspace x86/x86_64 na ARM64, lecz wymaga osobnego pakietu lub overlaya i nie
jest częścią tej deklaratywnej konfiguracji.
