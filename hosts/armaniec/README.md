# ASUS Vivobook S 15 ze Snapdragonem

Ten host to ostrożny punkt startowy dla wariantu Vivobook S 15 z procesorem
Snapdragon X Elite. Używa platformy `aarch64-linux`, pełnego profilu
`home/wojtek` importującego `home/base` oraz modułu `x1e-nixos-config` dostosowanego do tego modelu:
własnego kernela, device tree, initrd i firmware. Zapewnia kompletną sesję
Hyprland z Ironbarem i narzędziami użytkownika, ale nie włącza gamingu,
Dockera, nagrywania, VR, metryk AMD ani modułów przeznaczonych dla laptopa ROG.

Kernel to `6.17.0` z gałęzi Linaro ARM64 Laptops, rozszerzony o poprawki X Elite
i pakiety firmware dla Vivobooka. W bazowym systemie są też natywne dla ARM64
Zen Browser oraz Codex (z GNU Make).

Zwykły obraz instalacyjny NixOS ARM64 nie zawiera jeszcze kompletnego stosu
startowego X Elite. Najpierw przygotuj nośnik z forka
`JamiKettunen/x1e-vivobook-nixos-config`, ponieważ zawiera device tree dla
S5507 i potrzebne moduły initrd. Jego instrukcja ostrzega, że
`nixos-generate-config` nie jest na tej platformie wiarygodnym źródłem
konfiguracji sprzętowej.

Na komputerze x86_64 nośnik buduje się z jego outputu `iso` (cross-build może
trwać kilka godzin):

```bash
nix build github:JamiKettunen/x1e-vivobook-nixos-config/vivobook#iso
```

Po pobraniu tej zmiany zaktualizuj nowy input w lockfile:

```bash
nix flake lock --update-input x1e-nixos-config
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

Po pierwszym starcie sprawdź działanie ekranu, Wi-Fi, dźwięku, klawiatury,
touchpada, baterii i usypiania. Dopiero na podstawie tych wyników włącz
`features.laptop` z rzeczywistą nazwą podświetlenia oraz dodaj specyficzne dla
tego wariantu moduły sprzętowe.

Nie dodawaj emulacji x86 do pierwszej instalacji. QEMU przez `binfmt` może
uruchamiać pojedyncze binaria x86_64 po stabilizacji systemu, ale nie emuluje
sterowników ani kernela i jest wyraźnie wolniejszy. FEX jest szybszą emulacją
userspace x86/x86_64 na ARM64, lecz wymaga osobnego pakietu lub overlaya i nie
jest częścią tej deklaratywnej konfiguracji.
