# NixOS configuration

Deklaratywna konfiguracja NixOS dla hosta `rog-polamaniec` oraz baza kolejnych
komputerów, oparta na flakes, Home Managerze i Hyprlandzie.

Repozytorium źródłowe: `https://gitea.wardyn.dev/wojtek/nix-config.git`.

## Szybki start

```bash
nix flake check path:.
nix build path:.#nixosConfigurations.rog-polamaniec.config.system.build.toplevel
sudo nixos-rebuild test --flake path:.#rog-polamaniec
```

Output `rog-polamaniec` używa wyłącznie Ironbara. Historyczne wyniki Waybara i
Noctalii pozostają w dokumentacji do porównań:

```bash
make test
make benchmark SECONDS=120
```

Po sprawdzeniu konfiguracji:

```bash
sudo nixos-rebuild switch --flake path:.#rog-polamaniec
```

Na nowej maszynie `nix develop` udostępnia Codex, Git i Neovim jeszcze przed
utworzeniem osobnego outputu. Sprzętowo neutralny punkt startowy znajduje się w
[`hosts/simple/`](hosts/simple/README.md).

Pełna dokumentacja i plan rozwoju znajdują się w [docs/](docs/README.md).
