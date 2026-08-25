# NixOS configuration

Deklaratywna konfiguracja NixOS dla hosta `rog-polamaniec`, oparta na flakes,
Home Managerze i Hyprlandzie.

Repozytorium źródłowe: `https://github.com/wojtek2105/nixos-config.git`.

## Szybki start

```bash
nix flake check path:.
nix build path:.#nixosConfigurations.rog-polamaniec.config.system.build.toplevel
sudo nixos-rebuild test --flake path:.#rog-polamaniec
```

Output `rog-polamaniec` używa wyłącznie Ironbara:

```bash
make test
```

Historyczne wyniki porównania Ironbara, Waybara i Noctalii oraz uruchamiany na
żądanie benchmark schedulerów znajdują się w
[docs/benchmarks.md](docs/benchmarks.md). Narzędzia pomiarowe nie trafiają do
aktywnej konfiguracji systemu.

Po sprawdzeniu konfiguracji:

```bash
sudo nixos-rebuild switch --flake path:.#rog-polamaniec
```

Pełna dokumentacja i plan rozwoju znajdują się w [docs/](docs/README.md).
Instrukcja skopiowania konfiguracji na nowy komputer i konto znajduje się w
[docs/new-host.md](docs/new-host.md).
