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

## PoC Neovima z Kickstart

`nvim-kickstart` korzysta z osobnego `NVIM_APPNAME`, więc nie modyfikuje
zwykłego `~/.config/nvim` ani jego pluginów. Przy pierwszym uruchomieniu tworzy
zapisywalny katalog `~/.config/nvim-kickstart` z wersji Kickstart przypiętej w
`flake.lock`. Kolejne aktualizacje inputu nie nadpisują tego katalogu, aby nie
niszczyć lokalnych zmian przygotowywanych do przyszłego repozytorium.

Po pierwszym starcie sprawdź `:checkhealth`. Pełne usunięcie PoC wymaga usunięcia
osobnych katalogów `nvim-kickstart` z `~/.config`, `~/.local/share`,
`~/.local/state` i `~/.cache`; zwykły profil Neovima pozostaje wtedy nietknięty.

## Zespół Codexa w Agent Managerze

Uruchom panel z terminala:

```bash
agent-manager
```

Przy pierwszym zadaniu utwórz sesję narzędziem `codex-manager`. Jest to lekki
kierownik na `gpt-5.6-luna` z poziomem rozumowania `medium`, wystarczającym do
podziału pracy, koordynacji i odbioru wyników. Kierownik tworzy workerów przez
MCP, zawsze wybierając narzędzie `codex`; ten wpis uruchamia `codex-worker` na
mocniejszym `gpt-5.6-terra` z poziomem `high`. Ten podział rezerwuje większy
budżet rozumowania dla ograniczonych zadań wykonawczych, bez mnożenia kosztu
sesji zarządzającej. Domyślny bezpiecznik instrukcji ogranicza zespół do czterech
workerów, o ile zadanie jawnie nie wymaga większej liczby.

Najważniejsze operacje w panelu:

- `n` tworzy sesję; dla korzenia wybierz `codex-manager`,
- `Enter` otwiera zaznaczoną sesję, a `Ctrl+Q` wraca do panelu,
- `Space` wysyła wiadomość bez przełączania sesji,
- `Ctrl+R` otwiera przegląd zmian workera,
- `x` zatrzymuje sesję z zachowaniem rekordu, a `v` ją wznawia,
- `q` zamyka tylko panel; sesje nadal działają w prywatnym serwerze tmux.

Po aktywacji sprawdź ręcznie, że manager widzi serwer MCP, tworzy workera jako
`codex`, czeka na jego wynik i pokazuje jego status oraz diff w panelu. Logowanie
Codexa i limity konta są współdzielone z normalnym CLI; konfiguracja nie zapisuje
żadnych tokenów ani danych uwierzytelniających w repozytorium.

Wersja Agent Managera jest przypięta razem z oficjalnym hashem, aby build i
rollback były powtarzalne. Aktualizacja do najnowszego taga sprowadza się do:

```bash
update-agent-manager
```

Polecenie należy uruchomić z katalogu repozytorium. Odczytuje `releases/latest`,
pobiera archiwum i oficjalne `checksums.txt`, weryfikuje SHA-256, aktualizuje
wersję oraz hash w module i pokazuje diff. Nie buduje ani nie aktywuje systemu;
po przejrzeniu zmian należy użyć zwykłych poleceń walidacji z początku dokumentu.

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

## Historia schowka

Stan Rustowego watchera Stash i rozmiar historii można sprawdzić bez zmiany
danych:

```bash
systemctl --user status stash-clipboard.service
stash db stats
```

`Super+Shift+V` powinno pokazać tekst oraz opisy zapisanych obrazów, skopiować
wybrany wpis z powrotem do schowka i wkleić go do aktywnego okna.

## Minimalna kontrola po aktywacji

1. Otworzyć Foot przez `Super+Enter`.
2. Sprawdzić launcher, aktywny panel i powiadomienia. Otworzyć Wleave przez
   `Super+Escape` i zamknąć je przez `Esc`.
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
    animację od 5. do 10. minuty, blokadę po 10 minutach i DPMS sekundę później
    na dowolnym zasilaniu oraz
    suspend po 30 minutach wyłącznie na baterii. Na zasilaczu automatyczny
    suspend nie może wystąpić; po włączeniu Caffeine cała sekwencja ma pozostać
    zablokowana. Podczas wygaszacza sprawdzić w `pgrep -af tte`, że na baterii
    używa `--frame-rate 60`, a po podłączeniu zasilacza kolejny efekt wraca do
    pełnej częstotliwości monitora.
13. Na laptopie sprawdzić `display-power-refresh status`, odłączyć zasilacz i
    potwierdzić przez `hyprctl monitors`, że matryca przeszła na 60 Hz. Po
    ponownym podłączeniu zasilacza ma automatycznie wrócić do najwyższego trybu
    tej samej rozdzielczości, obecnie 120 Hz.
14. Po docelowym `switch` i restarcie potwierdzić jednosekundowe menu
    systemd-boot; `nixos-rebuild test` nie instaluje tej zmiany na następny boot.
15. Po restarcie sprawdzić aktywny `scx_bpfland`, uruchomić `gamemoded -t`, a
    następnie porównać tę samą grę z `gamemoderun %command%` i bez niego;
    obserwować przede wszystkim płynność i 1% low, nie tylko średni FPS.
