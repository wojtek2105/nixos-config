# Architektura

## Flake

`flake.nix` przypina zależności w `flake.lock` i automatycznie udostępnia każdy
katalog `hosts/<nazwa>/`, który zawiera `default.nix`. Obecnie dostępny jest:

```text
nixosConfigurations.rog-polamaniec
```

Domyślny `devShell` zapewnia Codex, Git i Neovim do pracy nad konfiguracją.

Pulpit korzysta wyłącznie z Ironbara. Kod Waybara i Noctalii został usunięty,
natomiast ich historyczne benchmarki pozostają zapisane w dokumentacji.

Główne wejścia:

- `nixpkgs` z gałęzi `nixos-unstable`,
- `home-manager`,
- `zen-browser`,
- przypięte źródła Biscuit dla nvim, GTK i pulpitu.

Home Manager działa jako moduł NixOS i korzysta z globalnego zestawu pakietów.
Manifest hosta wybiera nazwę konta oraz profil z `home/<profil>/`.

## Układ katalogów

```text
.
├── flake.nix
├── hosts/
│   ├── rog-polamaniec/
│   │   ├── default.nix
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
├── modules/
│   ├── common.nix
│   ├── desktop.nix
│   ├── desktop-shell.nix
│   ├── development-core.nix
│   ├── development.nix
│   ├── gaming.nix
│   ├── hardware-amd-gpu.nix
│   └── hardware-asus-laptop.nix
├── home/
│   └── wojtek/
│       ├── default.nix
│       ├── desktop.nix
│       ├── hyprland.lua
│       ├── hyprland.nix
│       ├── ironbar.nix
│       ├── notifications.nix
│       ├── osd.nix
│       ├── scripts.nix
│       ├── theme.nix
│       ├── ironbar-metric.nix
│       └── zen.nix
└── docs/
```

## Odpowiedzialność warstw

- `hosts/rog-polamaniec/` zawiera manifest, sprzęt i parametry laptopa.
- `modules/` zawiera współdzielone funkcje systemowe.
- `home/wojtek/` zawiera przenośne ustawienia sesji użytkownika.
- `docs/` dokumentuje zachowanie, obsługę i plan rozwoju.

## Zasady

- Źródłem prawdy są pliki repozytorium, w tym deklaratywnie instalowany
  `hyprland.lua`, a nie ręcznie edytowane pliki w katalogu domowym.
- Ustawienia sprzętowe należą do hosta.
- Powtarzalne funkcje należą do małych modułów.
- Sekrety, tokeny i dane logowania nie mogą trafić do repozytorium.
- `result` jest generowanym symlinkiem po buildzie i nie należy go commitować.
