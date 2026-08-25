# Architektura

## Flake

`flake.nix` przypina zależności w `flake.lock` i automatycznie udostępnia każdy
katalog `hosts/<nazwa>/`, który zawiera `default.nix`. Obecnie dostępny jest:

```text
nixosConfigurations.rog-polamaniec
```

Domyślny `devShell` zapewnia Codex, Git i Neovim do pracy nad konfiguracją.

Pulpit korzysta wyłącznie z Ironbara. Kod Waybara, Noctalii i narzędzia do ich
porównywania został usunięty, a historyczne wyniki pozostały w dokumentacji.

Główne wejścia:

- `nixpkgs` z gałęzi `nixos-unstable`,
- `home-manager`,
- `zen-browser`,
- przypięte źródła Biscuit dla nvim, GTK i pulpitu.

Home Manager działa jako moduł NixOS i korzysta z globalnego zestawu pakietów.
Manifest hosta wybiera nazwę konta oraz profil z `home/<profil>/`.
Flake odczytuje `theme.nix` z wybranego profilu i przekazuje jego paletę także
modułom NixOS. Dzięki temu konsola oraz Tuigreet używają tych samych kolorów co
sesja Home Managera bez wiązania modułu systemowego z nazwą konta lub profilu.
Ta sama mapa `features` warunkowo dołącza moduły NixOS i jest rzutowana na
ustawienia sesji Home Managera. Wyłączenie Dockera, gamingu lub nagrywania usuwa
więc również ich pakiety, zamiast jedynie ukrywać widget albo skrót.
Manifest odrzuca nieznane nazwy i wartości inne niż logiczne, dzięki czemu
literówka nie może po cichu wyłączyć funkcji. Btop dostaje obsługę ROCm wyłącznie
na hostach z włączonymi metrykami AMD GPU.
Opcjonalny harness schedulerów pozostaje osobnym outputem flake oraz modułem
`scheduler-benchmark.nix` sterowanym przez `features.schedulerBenchmark`.
Domyślne `false` nie dodaje jego narzędzi do closure hosta i nie uruchamia usług.
Wspólny `modules/common.nix` włącza ZRAM o pojemności 50% fizycznej pamięci;
limit skaluje się automatycznie na każdym hoście i nie zależy od konta
użytkownika ani nie rezerwuje z góry połowy RAM-u. Ten sam moduł ustawia
jednostronicowy odczyt ZRAM, neutralną skłonność do swapowania oraz traktuje
buildy Nix jako pracę tła o najniższej polityce CPU i klasie I/O, aby kompilacja
nie odbierała responsywności aktywnym aplikacjom.

Opcjonalny `modules/gaming.nix` uruchamia `scx_bpfland` z rustowego zestawu SCX.
Scheduler rozpoznaje interaktywny charakter obciążenia zamiast na stałe
blokować CPU w maksymalnym profilu; dotyczy tylko hostów z `features.gaming`.

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
│   ├── development-core.nix
│   ├── development.nix
│   ├── docker.nix
│   ├── gaming.nix
│   ├── hardware-diagnostics.nix
│   ├── hardware-amd-gpu.nix
│   ├── hardware-asus-laptop.nix
│   ├── scheduler-benchmark.nix
│   └── screen-recording.nix
├── tools/
│   └── scheduler-benchmark/
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
- Manifest hosta jest jedynym źródłem prawdy dla opcjonalnych możliwości;
  moduły systemowe i elementy pulpitu nie mają niezależnych przełączników.
- Sekrety, tokeny i dane logowania nie mogą trafić do repozytorium.
- `result` jest generowanym symlinkiem po buildzie i nie należy go commitować.
