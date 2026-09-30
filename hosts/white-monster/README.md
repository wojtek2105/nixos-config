# White Monster

Minimalny NixOS dla docelowego komputera White Monster z architekturą AMD64.
Instalator uruchamia się z osobnego pendrive'a, a system trafia na dysk
komputera. NetworkManager ignoruje interfejsy Wi-Fi.

## Aplikacje

- Zen Twilight
- Discord
- Steam z Proton GE
- GPU Screen Recorder z nakładką i buforem replay
- Codex, GNU Make i Python 3 z `modules/development-core.nix`
- Git, curl, fd, jq i ripgrep z `modules/common.nix`
- Foot, Yazi, Thunar, MPV i Swayimg z profilu `home/wojtek`

## Moduły i usługi

- Hyprland uruchamiany przez UWSM
- Greetd z Tuigreet, Ironbar, Fuzzel, SwayNC i SwayOSD
- profil Home Managera `wojtek` z motywem Biscuit
- Plymouth z motywem Biscuit i cichym startem systemu
- animowany wygaszacz `WOJTECH` sterowany przez Hypridle
- PipeWire z obsługą ALSA i PulseAudio
- Mesa/AMDGPU z bibliotekami 32-bitowymi dla Steam
- firmware i mikrokod AMD
- NetworkManager tylko do sieci przewodowej
- ZRAM i podstawowe narzędzia z `modules/common.nix`
- responsywny scheduler CPU `scx_bpfland` bez pełnego stosu gamingowego
- nakładka GPU Screen Recorder uruchamiana na żądanie
- moduł developerski z powiadomieniami terminalowymi Codexa
- systemd-boot na partycji EFI docelowego komputera

Nie są włączone VR, Bluetooth, Docker, Ollama, nagrywanie ekranu, zdalne
sterowanie myszą, Gamescope, GameMode ani Lutris.

## Instalacja

Pendrive zawiera zwykły instalator NixOS x86_64. Po uruchomieniu go na White
Monster należy zamontować docelowy system pod `/mnt`, sklonować repozytorium i
wygenerować fakty sprzętowe tej maszyny:

```bash
sudo nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
  hosts/white-monster/hardware-configuration.nix
sudo nixos-install --flake path:.#white-monster
```

Host celowo nie jest widoczny w outputach flake, dopóki nie powstanie jego
własny `hardware-configuration.nix`.
