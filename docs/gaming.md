# GameMode w Steam

Ten host włącza Steam, Proton-GE, Gamescope i GameMode przez
`features.gaming = true`. Scheduler `scx_bpfland` działa stale dla całego
systemu. GameMode nie zmienia schedulera ani jego trybu: na czas życia gry
podnosi profil wydajności oraz priorytety procesu, a po zakończeniu ostatniego
klienta przywraca poprzedni stan.

## Co robi obecna konfiguracja

Po aktywowaniu GameMode dla gry moduł `modules/gaming.nix`:

- ustawia governor CPU na `performance`,
- nadaje grze `nice -10`,
- ustawia najwyższy skonfigurowany priorytet I/O (`ioprio = 0`),
- blokuje wygaszacz na czas działania klienta,
- pozostawia `scx_bpfland` jako aktywny scheduler,
- nie podkręca GPU i nie wymusza ręcznego poziomu wydajności karty.

Na hoście ASUS `modules/hardware-asus-laptop.nix` dodaje do GameMode hooki
`asusctl`: pierwsza uruchomiona gra przełącza profil laptopa na `Performance`,
a zamknięcie ostatniej przywraca `Balanced` przy zasilaczu albo `Quiet` na
baterii. Nie zmienia to ustawień Hyprlanda ani czułości myszy/trackballa.

Daemon jest aktywowany na żądanie przez D-Bus. Nie trzeba uruchamiać ani włączać
go ręcznie. Po pierwszym aktywowaniu konfiguracji należy ponownie zalogować się
do sesji, aby procesy użytkownika otrzymały członkostwo w grupie `gamemode`.

## Jednorazowa kontrola instalacji

Po ponownym zalogowaniu uruchom w terminalu:

```bash
gamemoded -t
```

Test powinien zakończyć się bez błędu. Nie trzeba wykonywać go przed każdym
uruchomieniem gry.

## Dodanie GameMode do gry Steam

1. Otwórz bibliotekę Steam.
2. Kliknij grę prawym przyciskiem i wybierz **Właściwości**.
3. W sekcji **Ogólne** znajdź pole **Opcje uruchamiania**.
4. Wpisz dokładnie:

   ```text
   gamemoderun %command%
   ```

5. Zamknij okno właściwości i uruchom grę normalnym przyciskiem **Graj**.

Steam zastępuje dosłowny token `%command%` właściwym poleceniem gry. Działa to
tak samo dla gry natywnej i dla Proton/Proton-GE; nie należy ręcznie wpisywać
ścieżki do pliku EXE ani zastępować `%command%` nazwą procesu.

Niektóre gry mają natywną integrację z GameMode i same zgłaszają klienta.
W pozostałych przypadkach powyższy wrapper jest najprostszym, jednoznacznym
sposobem aktywacji.

## Łączenie z innymi opcjami

Zmienne środowiskowe umieszcza się przed `gamemoderun`, a argumenty samej gry
po `%command%`. Przykłady:

```text
PROTON_LOG=1 gamemoderun %command%
```

```text
gamemoderun %command% -novid
```

Nie dodawaj `%command%` drugi raz. Jeśli gra przestanie się uruchamiać, najpierw
wróć do samego `gamemoderun %command%`, a dopiero później dokładaj po jednym
parametrze.

## GameMode z Gamescope

Gamescope nie jest wymagany do działania GameMode. Warto go użyć dopiero wtedy,
gdy potrzebujesz osobnego limitu FPS, skalowania albo kontrolowanego okna
fullscreen. Najprostszy wariant uruchamia grę w pełnoekranowym Gamescope i
aktywuje GameMode dla właściwego polecenia gry:

```text
gamescope -f -- gamemoderun %command%
```

Przykład ze sztywnym wyjściem `2560x1600` i limitem `120 Hz` dla wbudowanego
panelu obecnego laptopa:

```text
gamescope -W 2560 -H 1600 -w 2560 -h 1600 -r 120 -f -- gamemoderun %command%
```

Na innym monitorze dopasuj szerokość, wysokość i odświeżanie; nie kopiuj tego
przykładu bez sprawdzenia `hyprctl monitors`. Jeżeli gra działa poprawnie bez
Gamescope, samo `gamemoderun %command%` ma mniej warstw i jest preferowanym
ustawieniem.

## Sprawdzenie podczas działania gry

Pozostaw grę uruchomioną i w drugim terminalu wykonaj:

```bash
gamemoded -s
```

Oczekiwany komunikat informuje, że GameMode jest aktywny. Po zamknięciu gry
polecenie powinno ponownie pokazać stan nieaktywny. Bardziej szczegółowe logi:

```bash
systemctl --user status gamemoded.service
journalctl --user -u gamemoded.service -b --no-pager
```

Na ASUS-ie aktywny profil można równolegle potwierdzić przez:

```bash
asusctl profile get
```

Aktywny GameMode nie oznacza automatycznie wyższego średniego FPS. Jego zadaniem
jest przede wszystkim niedopuszczenie do oszczędnego profilu CPU podczas gry,
nadanie procesowi właściwych priorytetów i ograniczenie zakłóceń. Efekt należy
oceniać w tej samej scenie gry, zwracając uwagę również na frametime i `1% low`.

## Typowe problemy

- **GameMode jest nieaktywny:** upewnij się, że opcja zawiera dokładnie
  `gamemoderun %command%`, uruchom `gamemoded -t` i sprawdź log użytkownika.
- **Gra nie startuje:** usuń dodatkowe zmienne i wrappery, zostawiając najpierw
  samo `gamemoderun %command%`.
- **Problem pojawia się tylko z Gamescope:** wróć do samego GameMode. Gamescope
  jest opcjonalną warstwą i nie powinien blokować optymalizacji gry.
- **Po zmianie NixOS brakuje uprawnień do `renice`:** wyloguj się całkowicie
  i zaloguj ponownie albo uruchom ponownie system, aby odświeżyć grupy konta.

Źródłem składni `gamemoderun %command%` i sposobu działania klienta jest
[oficjalna dokumentacja GameMode](https://github.com/FeralInteractive/gamemode).
