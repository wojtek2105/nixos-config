# Architektura

## Flake

`flake.nix` przypina zależności w `flake.lock` i udostępnia trzy nazwy wariantów tego
samego hosta:

```text
nixosConfigurations.laptop
nixosConfigurations.laptop-ironbar
nixosConfigurations.laptop-waybar
```

Pierwszy jest stabilnym wariantem Ironbar, drugi jego zgodnym aliasem testowym,
a trzeci zachowuje Waybara jako wariant awaryjny i porównawczy. Wszystkie
korzystają z tych samych modułów systemowych, Home Managera i parametrów
sprzętowych, więc benchmark panelu pozostaje porównywalny.

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
│   └── laptop/
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── modules/
│   ├── common.nix
│   ├── desktop.nix
│   ├── desktop-shell.nix
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
│       ├── waybar-metric.nix
│       ├── waybar.nix
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
