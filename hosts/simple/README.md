# Profil `simple`

Ten katalog jest sprzętowo neutralnym punktem startowym dla kolejnych hostów.
Zapewnia Hyprland, Ironbar, Zen Browser, terminal Foot, Codex, Git, Neovim i
podstawowe narzędzia systemowe. Nie włącza Steam, Dockera, GPU Screen Recorder,
aplikacji osobistych ani ustawień ASUS ROG i laptopa.

Profil nie jest samodzielnym hostem i celowo nie zawiera zmyślonego
`hardware-configuration.nix`. Na nowej maszynie:

1. utwórz `hosts/<nazwa>/configuration.nix`, który importuje
   `../simple/configuration.nix` i `./hardware-configuration.nix`;
2. wygeneruj sprzęt poleceniem
   `sudo nixos-generate-config --show-hardware-config > hosts/<nazwa>/hardware-configuration.nix`;
3. ustaw `networking.hostName`, bootloader i właściwe `system.stateVersion`;
4. dodaj host przez `mkHost` w `flake.nix` i włącz tylko potrzebne
   `desktopFeatures`;
5. wykonaj check, build i dopiero potem `nixos-rebuild test`.

Zaraz po sklonowaniu repozytorium `nix develop` udostępnia Codex, Git i Neovim,
więc konfigurację nowej maszyny można wygodnie dokończyć przed jej aktywacją.
