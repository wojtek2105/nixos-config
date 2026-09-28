# White Monster

Minimalny NixOS dla docelowego komputera White Monster z architekturą AMD64.
Instalator uruchamia się z osobnego pendrive'a, a system trafia na dysk
komputera. NetworkManager ignoruje interfejsy Wi-Fi.

## Aplikacje

- Firefox
- Steam z Proton GE
- Codex, GNU Make i Python 3 z `modules/development-core.nix`
- Git, curl, fd, jq i ripgrep z `modules/common.nix`
- podstawowe aplikacje Plasma: Dolphin, Konsole i Ustawienia systemowe

## Moduły i usługi

- Plasma 6 na Waylandzie z SDDM
- PipeWire z obsługą ALSA i PulseAudio
- Mesa/AMDGPU z bibliotekami 32-bitowymi dla Steam
- firmware i mikrokod AMD
- NetworkManager tylko do sieci przewodowej
- ZRAM i podstawowe narzędzia z `modules/common.nix`
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
