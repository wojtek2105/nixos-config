# Architektura

## Flake

`flake.nix` przypina zależności w `flake.lock` i automatycznie udostępnia każdy
katalog `hosts/<nazwa>/`, który zawiera `default.nix` oraz własny
`hardware-configuration.nix`. Obecnie dostępne są hosty mające oba pliki:

```text
nixosConfigurations.izakomp
nixosConfigurations.rog-polamaniec
nixosConfigurations.white-monster
```

Domyślny `devShell` zapewnia Codex, Git i Neovim do pracy nad konfiguracją.

Profil Home Managera instaluje Agent Manager jako warstwę operacyjną nad
trwałymi sesjami CLI w tmux. Jeden profil Codexa używa `gpt-5.6-terra` z
rozumowaniem `medium` zarówno dla korzenia, jak i workerów. Alternatywny
`crabcode-manager` działa na małym lokalnym Qwenie i domyślnie tworzy przez MCP
workery Crabcode/Ollama. Trudne zadanie eskaluje najpierw do większego modelu na
White Monsterze; ten może utworzyć Codexa, gdy lokalne rozumowanie nie wystarczy.
Przy niedostępnym White Monsterze manager może eskalować do Codexa bezpośrednio.
Sesje pozostają widoczne w TUI; natywne subagenty Codexa są wyłączone, aby nie
tworzyć drugiego, ukrytego drzewa.
Jawna cecha hosta `features.ollamaFarm` rozdziela profile zdalnej farmy od
lokalnego Crabcode. Jej wyłączenie pozostawia tylko loopback Ollamy i opcjonalną
eskalację przez MCP do Codexa; włączenie dodaje nazwane workery hostów oraz
sondę `ollama-farm-status`.

Pulpit korzysta wyłącznie z Ironbara. Kod Waybara, Noctalii i narzędzia do ich
porównywania został usunięty, a historyczne wyniki pozostały w dokumentacji.

Główne wejścia:

- `nixpkgs` z gałęzi `nixos-unstable`,
- `home-manager`,
- `zen-browser`,
- przypięte źródła Biscuit dla nvim, GTK i pulpitu,
- przypięty upstream Kickstart jako odizolowany PoC przyszłej konfiguracji Neovima.

Home Manager działa jako moduł NixOS i korzysta z globalnego zestawu pakietów.
`home/base/` jest wejściem wspólnej bazy sesji Home Managera, a
`home/individual/<nazwa>/override.nix` jest trwałą nakładką dla jednego konta.
Home Manager importuje oba moduły podczas budowania profilu. `hosts/<host>/host.json`
jest manifestem hosta: wybiera nazwę hosta i konta,
profil z `home/<profil>/`, moduły bazowe oraz funkcje. `default.nix` tylko
odczytuje JSON, a `modules/host-base.nix` dołącza wskazane moduły.
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

`boot-splash.nix` jest wspólną warstwą pierwszego kontaktu z systemem: uruchamia
Plymouth jeszcze w initrd, łączy paletę Biscuit ze statyczną maskotką Tux i
ogranicza zwykły strumień logów. Diagnostyka pozostaje dostępna przez `Esc` w
czasie bootu.
Wspólny `modules/common.nix` włącza ZRAM o pojemności 50% fizycznej pamięci;
limit skaluje się automatycznie na każdym hoście i nie zależy od konta
użytkownika ani nie rezerwuje z góry połowy RAM-u. Ten sam moduł ustawia
jednostronicowy odczyt ZRAM, neutralną skłonność do swapowania oraz traktuje
buildy Nix jako pracę tła o najniższej polityce CPU i klasie I/O, aby kompilacja
nie odbierała responsywności aktywnym aplikacjom.

Opcjonalny `modules/gaming.nix` uruchamia `scx_bpfland` z rustowego zestawu SCX.
Scheduler rozpoznaje interaktywny charakter obciążenia zamiast na stałe
blokować CPU w maksymalnym profilu; dotyczy tylko hostów z `features.gaming`.
Opcjonalny `modules/vr.nix` dodaje ALVR, Steam i ADB dla przewodowego Quest 2.
Nie uruchamia demona, nie włącza Avahi i zachowuje zamknięte porty LAN, dopóki
użytkownik świadomie nie przełączy konfiguracji na bezprzewodowy ALVR.

## Układ katalogów

```text
.
├── flake.nix
├── hosts/
│   ├── rog-polamaniec/
│   │   ├── default.nix
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── white-monster/
│       ├── README.md
│       ├── default.nix
│       └── configuration.nix
├── modules/
│   ├── common.nix
│   ├── desktop.nix
│   ├── development-core.nix
│   ├── docker.nix
│   ├── gaming.nix
│   ├── hardware-diagnostics.nix
│   ├── hardware-amd-gpu.nix
│   ├── hardware-asus-laptop.nix
│   ├── scheduler-benchmark.nix
│   ├── screen-recording.nix
│   └── vr.nix
├── tools/
│   └── scheduler-benchmark/
├── home/
│   └── wojtek/
│       ├── clipboard.nix
│       ├── agent-manager.nix
│       ├── default.nix
│       ├── desktop.nix
│       ├── hyprland.lua
│       ├── hyprland.nix
│       ├── ironbar.nix
│       ├── neovim.nix
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
- `home/base/` zawiera przenośne ustawienia wspólnej sesji; profile w
  `home/<użytkownik>/` importują tę bazę.
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
