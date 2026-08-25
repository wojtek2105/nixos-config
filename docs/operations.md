# Obsługa systemu

Wszystkie polecenia należy uruchamiać z katalogu repozytorium.

## Walidacja

Ewaluacja wszystkich outputów flake:

```bash
nix flake check path:.
```

Pełny build laptopa bez aktywowania:

```bash
nix build path:.#nixosConfigurations.rog-polamaniec.config.system.build.toplevel
```

Użycie `path:.` uwzględnia wszystkie pliki robocze i działa również bez metadanych
Git. W zwykłym checkoutcie można używać także `.#...`.

## Aktywacja

Preferowana pierwsza próba, ważna do restartu:

```bash
sudo nixos-rebuild test --flake path:.#rog-polamaniec
```

Po ręcznym sprawdzeniu pulpitu, sieci, dźwięku i nagrywania:

```bash
sudo nixos-rebuild switch --flake path:.#rog-polamaniec
```

## Generacje i garbage collection

Lista zachowanych generacji systemu:

```bash
make generations
```

Usunięcie starszych generacji oraz nieosiągalnych ścieżek z `/nix/store`, z
pozostawieniem czterech ostatnich generacji do bieżącej:

```bash
make gc KEEP=4
```

Parametr `KEEP` musi być dodatnią liczbą całkowitą. Jeśli aktywna jest starsza
generacja po rollbacku, Nix zachowuje również generacje nowsze od niej. GC nie
usuwa ścieżek nadal używanych przez inne profile lub pozostałe korzenie GC.
Usuniętych generacji nie można już wybrać podczas bootowania ani użyć do
rollbacku.

## Aktualizacja zależności

```bash
nix flake update
nix flake check path:.
nix build path:.#nixosConfigurations.rog-polamaniec.config.system.build.toplevel
```

Zmiany `flake.lock` należy przejrzeć przed aktywacją.

## Diagnostyka Hyprlanda

```bash
hyprctl configerrors
hyprctl version
hyprctl monitors
```

Centrum skrótów jest dostępne pod `Super+F1`. Poszczególne sekcje można
sprawdzić również z terminala, np. przez `shortcut-menu capture` albo
`shortcut-menu all`.

## Diagnostyka usług użytkownika

```bash
systemctl --user status hypridle.service
journalctl --user -u hypridle.service -b
systemd-inhibit --list
hyprctl clients -j | jq -r '.[] | select(.inhibitingIdle == true) | [.class, .title] | @tsv'
pgrep -a gsr-ui
gsr-ui-cli --help
```

Bezpośrednio po zalogowaniu `pgrep -a gsr-ui` nie powinno nic zwrócić. Użycie
`Alt+Z`, `Super+G`, `Super+Shift+R` albo `Super+R` uruchamia UI na żądanie.

Natychmiastowe przejście do następnej tapety bez czekania na timer:

```bash
systemctl --user start rotate-wallpaper.service
```

Pierwsza tapeta w nowej sesji powinna rozwinąć się okręgiem od środka. Kolejne
wywołania przeplatają `wave`, `grow`, `wipe` i `outer`, zmieniając kierunek,
punkt startu oraz geometrię fali bez zwykłego `fade`. Rotator odczytuje
geometrię każdego aktywnego wyjścia z `hyprctl monitors -j`: 16:9 wybiera
`wallpapers/16x9`, około 3440:1440 wybiera `wallpapers/21x9`, a 32:9 wybiera
`wallpapers/32x9`. Każdy monitor otrzymuje ten sam indeks sceny i własną pełną
częstotliwość przejścia.

Stan przenośnego, kompresowanego swapu po aktywacji:

```bash
zramctl
swapon --show
```

W sekcji pamięci Ironbara trzy słupki oznaczają kolejno użycie RAM, zapełnienie
ZRAM (ikona archiwum ``) i faktyczną oszczędność pamięci dzięki kompresji
(ikona kompresji ``). Najechanie pokazuje również rozmiar logiczny i fizyczny,
współczynnik oraz algorytm kompresji; wartości powinny odpowiadać licznikom
widocznym w `zramctl`.

Źródło zasilania wykryte bez zależności od nazw urządzeń oraz wynikowy limit
FPS wygaszacza:

```bash
power-source-state
screensaver-refresh-rate
```

Na baterii drugie polecenie zwraca najwyżej `60`; na zasilaniu zewnętrznym
zwraca pełną częstotliwość aktywnego monitora.

## Gry i responsywność pod obciążeniem

Stan schedulera SCX po restarcie do nowej generacji:

```bash
systemctl status scx.service
cat /sys/kernel/sched_ext/state
journalctl -u scx.service -b
```

Usługa powinna uruchamiać `scx_bpfland`, a stan kernela powinien wynosić
`enabled`. Jeżeli scheduler użytkowy zakończy się błędem, mechanizm `sched_ext`
oddaje zadania standardowemu schedulerowi kernela; log usługi pozostaje źródłem
przyczyny. Moduł używa wyłącznie rustowego wariantu pakietu SCX i jest aktywny
tylko na hostach z `features.gaming = true`.

GameMode działa na żądanie. Jego integrację można sprawdzić przez:

```bash
gamemoded -t
```

Dla gry bez natywnej integracji należy wpisać w jej opcjach uruchamiania Steam:

```text
gamemoderun %command%
```

Pełna instrukcja dla Steam, Proton, Gamescope i diagnostyki znajduje się w
[tutorialu GameMode](gaming.md).

Podczas działania gry GameMode nada jej priorytet `nice -10` i najwyższy
priorytet I/O, przełączy governor CPU oraz profil platformy na `performance`
i zablokuje wygaszacz. Zmiany są ograniczone czasem życia klienta GameMode;
po wyjściu z ostatniej gry daemon przywraca poprzedni stan. Konfiguracja nie
włącza podkręcania ani ręcznego poziomu wydajności GPU.

Buildy Nix działają z polityką CPU i klasą I/O `idle`. Dzięki temu pulpit i gra
zachowują pierwszeństwo przy jednoczesnym obciążeniu, ale build może wtedy trwać
dłużej, a pod stałym pełnym obciążeniem nawet okresowo czekać. Ustawienia ZRAM
można potwierdzić poleceniem:

```bash
sysctl vm.swappiness vm.page-cluster
```

Oczekiwane wartości to odpowiednio `100` i `0`.

## Minimalna kontrola po aktywacji

1. Otworzyć Foot przez `Super+Enter`.
2. Sprawdzić launcher, aktywny panel i powiadomienia. Otworzyć Wleave przez
   `Super+Escape`, zamknąć je przez `Esc` i ponownie otworzyć przejściowym
   aliasem `Super+Shift+E`.
3. Otworzyć aplikację GTK3 i GTK4, potwierdzając ciemny motyw.
4. Przetestować historię schowka przez `Super+Shift+V`.
5. Sprawdzić głośność, mikrofon, Bluetooth i klawisze multimedialne.
6. Potwierdzić brak `gsr-ui` po logowaniu, włączyć replay pierwszym skrótem,
   zapisać klip i sprawdzić trzy ścieżki audio.
7. Najechać na każdą grupę metryk, przytrzymać kursor i następnie go odsunąć,
   przejść kursorem z wyspy do samego popupu, a następnie odsunąć go poza oba
   obszary; szczegóły nie mogą migać ani zamknąć się podczas przejścia i powinny
   zniknąć po około 180 ms od faktycznego opuszczenia; pozostawienie kursora nad
   metryką przez co najmniej kilka sekund nie może tworzyć cyklu pokaż–schowaj,
   a bieżące wartości powinny zmieniać się w popupie co około 2 sekundy;
   sprawdzić wyśrodkowanie cyfr pulpitów oraz osobne miejsce dzwonka i licznika
   przy co najmniej jednym powiadomieniu.
8. Sprawdzić `Print`, `Super+Shift+S` oraz zapis i kopiowanie z Satty.
9. Otworzyć `about:policies` w Zen i potwierdzić Dark Reader oraz Bitwarden na
   pasku narzędzi i w prywatnym oknie.
10. Po zamknięciu i ponownym uruchomieniu Zen sprawdzić Biscuit w interfejsie,
    nowej karcie oraz `about:preferences`; profil powinien zachować historię,
    zakładki i poprzednią sesję, ale nie wybrane karty powinny pozostać
    niezaładowane. Przy otwartym Zen `Super+B` ma fokusować jego ostatnio używane
    okno także z innego pulpitu, a po pełnym zamknięciu uruchomić nowy proces.
11. W Yazi sprawdzić `f`, `g c` w repozytorium oraz `Ctrl+D` po zaznaczeniu
    jednego pliku i wskazaniu drugiego.
12. Najpierw uruchomić wygaszacz przez `Super+Ctrl+S`, potwierdzić, że pozostaje
    widoczny, a następnie zamyka się po klawiszu, ruchu albo kliknięciu myszy.
    Przy wyłączonym Caffeine potwierdzić jego automatyczny start po 5 minutach,
    blokadę po 6 minutach i DPMS po 10 minutach na dowolnym zasilaniu oraz
    suspend po 30 minutach wyłącznie na baterii. Na zasilaczu automatyczny
    suspend nie może wystąpić; po włączeniu Caffeine cała sekwencja ma pozostać
    zablokowana. Podczas wygaszacza sprawdzić w `pgrep -af tte`, że na baterii
    używa `--frame-rate 60`, a po podłączeniu zasilacza kolejny efekt wraca do
    pełnej częstotliwości monitora.
13. Po docelowym `switch` i restarcie potwierdzić jednosekundowe menu
    systemd-boot; `nixos-rebuild test` nie instaluje tej zmiany na następny boot.
14. Po restarcie sprawdzić aktywny `scx_bpfland`, uruchomić `gamemoded -t`, a
    następnie porównać tę samą grę z `gamemoderun %command%` i bez niego;
    obserwować przede wszystkim płynność i 1% low, nie tylko średni FPS.
