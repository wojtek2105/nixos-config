# Hosty

## ROG Polamaniec

Obecnie repozytorium zawiera jeden gotowy do aktywacji host:

- output flake: `rog-polamaniec`,
- hostname: `rog-polamaniec`,
- konfiguracja: `hosts/rog-polamaniec/configuration.nix`,
- sprzęt: `hosts/rog-polamaniec/hardware-configuration.nix`,
- dodatkowe funkcje: Docker, gaming, aplikacje osobiste i profil laptopa,
- dodatkowy moduł: `modules/hardware-amd-rog.nix`.

Laptop to ASUS ROG Zephyrus G14 GA402RK. Moduł sprzętowy używa najnowszego
jądra z przypiętego `nixpkgs`, ładuje sterownik `asus-armoury` oraz uruchamia
`asusd`; polecenie `asusctl` i ROG Control Center są dostępne deklaratywnie.

## Profil simple

`hosts/simple/configuration.nix` jest współdzielonym profilem, a nie hostem do
bezpośredniej aktywacji. Zawiera pulpit Hyprland z Ironbarem, Zen Browser, Foot,
Codex, Git, Neovim i podstawowe narzędzia. Nie zawiera ustawień ASUS ROG,
baterii i jasności laptopa, metryk AMD, Steam, GPU Screen Recorder, Dockera,
Discorda, Plexampa ani EasyEffects.

Profil nie ma `hardware-configuration.nix`, bootloadera, hostname ani
`system.stateVersion`, ponieważ te wartości muszą pochodzić z rzeczywistego
komputera. Szczegółowa procedura znajduje się w
[`hosts/simple/README.md`](../hosts/simple/README.md).

## Planowane hosty

Pierwszym hostem opartym na profilu `simple` będzie PC `bialy-monster`.
Konfiguracja nie jest jeszcze wystawiona jako output flake, ponieważ jej moduł
sprzętowy trzeba wygenerować na tym komputerze. Tę samą procedurę można później
powtórzyć dla komputera siostry i kolejnych maszyn, nadając każdej osobny katalog
i output.

## Dodanie komputera

Po sklonowaniu repozytorium na nowej maszynie uruchom `nix develop`, aby dostać
Codex, Git i Neovim bez aktywowania całej konfiguracji. Następnie:

1. utwórz katalog, na przykład `hosts/bialy-monster/`;
2. wygeneruj w nim `hardware-configuration.nix`;
3. utwórz `configuration.nix`, który importuje profil `simple` i wygenerowany
   moduł sprzętowy;
4. ustaw hostname, bootloader i zachowaj `system.stateVersion` właściwe dla
   pierwszej instalacji tego hosta;
5. dodaj nowy `mkHost` do `nixosConfigurations` w `flake.nix`;
6. wykonaj check, pełny build i `nixos-rebuild test` przed `switch`.

Przykładowa konfiguracja PC:

```nix
{ ... }:

{
  imports = [
    ../simple/configuration.nix
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "bialy-monster";
  system.stateVersion = "26.05"; # zachowaj wartość z instalacji
}
```

Odpowiadający wpis we flake:

```nix
bialy-monster = mkHost {
  configuration = ./hosts/bialy-monster/configuration.nix;
};
```

Walidacja nowego hosta:

```bash
nix flake check path:.
nix build path:.#nixosConfigurations.bialy-monster.config.system.build.toplevel
sudo nixos-rebuild test --flake path:.#bialy-monster
```

Sekrety, hasła, profile Wi-Fi i klucze SSH pozostają poza repozytorium.
