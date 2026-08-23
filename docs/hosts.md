# Hosty

## Laptop

Obecnie repozytorium zawiera jeden host:

- output flake: `laptop`,
- hostname: `polamaniec`,
- konfiguracja: `hosts/laptop/configuration.nix`,
- sprzęt: `hosts/laptop/hardware-configuration.nix`,
- dodatkowy moduł: `modules/hardware-amd-rog.nix`.

Parametry sprzętowe należą do hosta. Ustawienia pulpitu użytkownika pozostają
wspólne.

## Dodanie PC

1. Utworzyć katalog `hosts/pc/`.
2. Dodać wygenerowany `hardware-configuration.nix`.
3. Utworzyć `configuration.nix` z właściwymi modułami i hostname.
4. Dodać `nixosConfigurations.pc` w `flake.nix`.
5. Przekazać użytkownika Home Manager tak samo jak dla laptopa.
6. Wykonać check i build outputu PC przed aktywacją.

Przykład walidacji przyszłego hosta:

```bash
nix flake check path:.
nix build path:.#nixosConfigurations.pc.config.system.build.toplevel
sudo nixos-rebuild test --flake path:.#pc
```

Moduły zależne od AMD ROG nie powinny być importowane na PC bez zgodnego sprzętu.
Konfigurację monitorów, zasilania oraz GPU należy utrzymywać osobno dla każdego
hosta.
