# Quest 2 i PCVR po USB-C

Host z `features.vr = true` dostaje ALVR, Steam oraz `adb`. Konfiguracja jest
przeznaczona dla Meta Quest 2 podłączonego kablem USB-C i nie uruchamia żadnej
stałej usługi. Porty ALVR 9943/9944 pozostają zamknięte, ponieważ przewodowy
transport korzysta z połączenia ADB.

Moduł instaluje również WayVR. Jest to ręcznie uruchamiana nakładka SteamVR,
która pokazuje ekrany pulpitu w goglach. Zastępuje wbudowany `Desktop View`,
który na Waylandzie może wyświetlać czarny obraz albo sam kursor.

## Pulpit w goglach przez ALVR i WayVR

Po aktywacji konfiguracji uruchom ALVR i połącz Quest, a następnie uruchom
SteamVR z dashboardu ALVR. Na komputerze, w zwykłym terminalu użytkownika,
uruchom:

```bash
wayvr --wait
```

WayVR musi być uruchomiony ręcznie po połączeniu ALVR; nie jest usługą systemową
i nie startuje automatycznie ze SteamVR. Przy pierwszym uruchomieniu pojawi się
prośba o udostępnienie ekranów — wybierz ekran pulpitu zgodnie z kolejnością
podaną w powiadomieniu lub terminalu. W goglach otwórz panel WayVR przez
dwukrotne naciśnięcie `B` albo `Y` na lewym kontrolerze.

Podstawowe sterowanie:

- niebieski laser — lewy klik;
- pomarańczowy laser — prawy klik;
- uchwyt i joystick — przesuwanie ekranu;
- uchwyt, klik i joystick — zmiana rozmiaru ekranu.

Jeśli obraz lub kursor działa nieprawidłowo, w WayVR wybierz `Settings`,
następnie `Clear PipeWire tokens` i `Restart software`, po czym ponownie uruchom
`wayvr --wait`. Log nakładki znajduje się w `/tmp/wayvr.log`.

## Co naprawdę działa na Linuksie

Meta Horizon Link, wcześniej Oculus/Quest Link, jest oficjalnie obsługiwany
wyłącznie na Windows. Na Linuksie kabel USB służy więc ALVR do utworzenia tunelu
ADB. Obraz nadal koduje GPU komputera i dekoduje Quest, ale pakiety płyną kablem
zamiast przez Wi-Fi. Nie jest to sterownik ani protokół Meta Link.

Od ALVR 20.12 tryb przewodowy jest wbudowany w dashboard. Nie trzeba uruchamiać
ręcznie `adb forward`, o ile bieżący ALVR poprawnie wykrywa gogle. Quest wymaga
włączonego trybu deweloperskiego oraz debugowania USB. Kabel USB 3.x o pełnej
obsłudze danych jest zalecany; kabel tylko do ładowania nie zadziała.

## Pierwsze uruchomienie

1. W aplikacji Meta na telefonie włącz tryb deweloperski dla Quest 2.
2. Zainstaluj klienta ALVR na goglach z Meta Quest Store/App Lab albo przyciskiem
   instalacji APK w dashboardzie. Wersja klienta musi pasować do streamera.
3. Zainstaluj SteamVR z biblioteki Steam i uruchom go raz, po czym zamknij.
4. Podłącz Quest przewodem USB-C, załóż gogle i zaakceptuj komunikat
   `Allow USB debugging?`; warto zaznaczyć zapamiętanie tego komputera.
5. Sprawdź autoryzację bez `sudo`:

   ```bash
   adb devices -l
   ```

   Stan urządzenia powinien być `device`, a nie `unauthorized`.
6. Uruchom `ALVR Dashboard`, otwórz ekran urządzeń i włącz `Wired Connection`.
   Przy pierwszym połączeniu zaakceptuj Quest na liście zaufanych urządzeń.
7. Jeżeli klient pochodzi ze sklepu Meta, ustaw zgodny `Wired Client Type`;
   dla klienta instalowanego launcherem wybierz wariant `GitHub`.
8. Uruchom SteamVR z dashboardu ALVR.

Aktualny workaround upstreamu dla SteamVR na Linuksie to wpisanie w
`SteamVR → Properties → Launch Options`:

```text
~/.local/share/Steam/steamapps/common/SteamVR/bin/vrmonitor.sh %command%
```

Jeżeli biblioteka Steam jest w innym miejscu, użyj odpowiadającej jej ścieżki
do `steamapps/common/SteamVR/bin/vrmonitor.sh`.

## Diagnostyka kabla

```bash
lsusb
adb kill-server
adb start-server
adb devices -l
```

Po zmianie reguł systemowych odłącz i podłącz kabel ponownie. Nie uruchamiaj ADB
przez `sudo`, bo utworzy oddzielny serwer i klucze roota. Jeżeli urządzenie jest
`unauthorized`, usuń zgodę debugowania w ustawieniach deweloperskich Quest,
podłącz ponownie i zaakceptuj nowy odcisk klucza.

ALVR zawiera stary awaryjny wariant z ręcznym przekierowaniem portów, ale dla
obecnej wersji powinien być zbędny:

```bash
adb forward tcp:9943 tcp:9943
adb forward tcp:9944 tcp:9944
```

Przekierowania znikają po rozłączeniu lub restarcie ADB. Używaj ich wyłącznie,
gdy wbudowany tryb przewodowy nie działa.

## Sieć lokalna

Moduł nie włącza Avahi, ponieważ przewodowy ALVR go nie potrzebuje, i nie
otwiera portów firewalla. Jeśli później przejdziesz na ALVR przez Wi-Fi, ustaw
w `modules/vr.nix` `programs.alvr.openFirewall = true`; otworzy to TCP i UDP
9943/9944 w zarządzanym przez NixOS firewallu. Nie wystawiaj tych portów do
Internetu i nie zostawiaj streamera uruchomionego bez potrzeby.

## Ograniczenia

- zgodność SteamVR na Linuksie i ALVR jest słabsza niż oficjalnego stosu Meta na
  Windows; aktualizacje SteamVR mogą wymagać obejścia z `vrmonitor.sh`,
- Steam działa na NixOS w izolowanym środowisku bubblewrap, dlatego asynchroniczna
  reprojekcja wymagająca `CAP_SYS_NICE` może być niedostępna; moduł świadomie nie
  osłabia zabezpieczeń bubblewrap ani nie łata jądra,
- aplikacje wymagające natywnego runtime Meta/Oculus PC mogą nie działać,
- jakość i opóźnienie zależą od enkodera GPU, ustawień ALVR oraz kabla, nie tylko
  od nominalnego standardu USB,
- `features.vr` nie instaluje SteamVR automatycznie z powodów licencyjnych i
  operacyjnych — robi się to z biblioteki Steam.
