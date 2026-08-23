# Architektura

## Flake

`flake.nix` przypina zależności w `flake.lock` i udostępnia jeden aktywny output
sprzętowy:

```text
nixosConfigurations.rog-polamaniec
```

`nixosModules.simple` udostępnia lekką bazę przyszłych hostów, a domyślny
`devShell` zapewnia Codex, Git i Neovim do ich przygotowania.

Pulpit korzysta wyłącznie z Ironbara. Kod Waybara i Noctalii został usunięty,
natomiast ich historyczne benchmarki pozostają zapisane w dokumentacji.

Główne wejścia:

- `nixpkgs` z gałęzi `nixos-unstable`,
- `home-manager`,
- `zen-browser`,
- przypięte źródła Biscuit dla nvim, GTK i pulpitu.

Home Manager działa jako moduł NixOS. Użytkownik `wojtek` korzysta z globalnego
zestawu pakietów.

## Układ katalogów

```text
.
├── flake.nix
├── hosts/
│   ├── rog-polamaniec/
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── simple/
│       ├── configuration.nix
│       └── README.md
├── modules/
│   ├── common.nix
│   ├── desktop.nix
│   ├── desktop-shell.nix
│   ├── development-core.nix
│   ├── development.nix
│   ├── gaming.nix
│   └── hardware-amd-rog.nix
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

- `hosts/<nazwa>/` zawiera sprzęt i parametry konkretnej maszyny.
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
