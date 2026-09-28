# White Monster

Minimalny, przenośny NixOS dla komputerów AMD64 uruchamiany z pendrive'a UEFI.
System używa przewodowego Ethernetu; NetworkManager ignoruje interfejsy Wi-Fi.

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
- GRUB instalowany w przenośnej ścieżce UEFI

Nie są włączone VR, Bluetooth, Docker, Ollama, nagrywanie ekranu, zdalne
sterowanie myszą, Gamescope, GameMode ani Lutris.

## Układ nośnika

Konfiguracja oczekuje partycji EFI FAT32 z etykietą `NIXBOOT` oraz partycji
głównej ext4 z etykietą `WHITE_MONSTER`. Instalacja usuwa całą obecną zawartość
wybranego urządzenia, dlatego przed partycjonowaniem trzeba ponownie sprawdzić
jego model, numer seryjny i ścieżkę przez `lsblk`.
