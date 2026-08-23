# NixOS configuration

Deklaratywna konfiguracja NixOS dla laptopa `polamaniec`, oparta na flakes,
Home Managerze i Hyprlandzie.

Repozytorium źródłowe: `https://gitea.wardyn.dev/wojtek/nix-config.git`.

## Szybki start

```bash
nix flake check path:.
nix build path:.#nixosConfigurations.laptop.config.system.build.toplevel
sudo nixos-rebuild test --flake path:.#laptop
```

Po sprawdzeniu konfiguracji:

```bash
sudo nixos-rebuild switch --flake path:.#laptop
```

Pełna dokumentacja i plan rozwoju znajdują się w [docs/](docs/README.md).
