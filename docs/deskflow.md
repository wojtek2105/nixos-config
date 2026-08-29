# Deskflow

Deskflow udostępnia klawiaturę i mysz z `rog-polamaniec` na `white-monster` po
LAN-ie. Nie przesyła obrazu — obraz z White Monster jest odbierany osobno przez
kartę przechwytującą HDMI.

## Role hostów

- `rog-polamaniec` działa jako serwer i posiada fizyczną klawiaturę oraz mysz,
- `white-monster` działa jako klient i otrzymuje zdarzenia wejściowe.

Usługa startuje w graficznej sesji użytkownika. Deskflow używa portu TCP `24800`,
który jest otwarty tylko na serwerze.

## Przełączanie sterowania

Ponieważ White Monster nie jest drugim ekranem Hyprlanda, nie trzeba przesuwać
myszy do krawędzi obrazu. Na `rog-polamaniec` używaj:

| Skrót | Działanie |
| --- | --- |
| `Ctrl+Alt+F12` | sterowanie White Monster |
| `Ctrl+Alt+F11` | powrót do Rog Polamaniec |

Skróty są obsługiwane przez serwer Deskflow, więc nie używają lokalnych bindów
`Super` Hyprlanda. Deskflow musi mieć aktywną sesję graficzną na obu hostach;
brak przesyłanego obrazu nie oznacza braku sesji Wayland na White Monster.

## Sieć i bezpieczeństwo

Połączenie powinno działać w zaufanej sieci LAN albo przez prywatną sieć VPN.
Deskflow korzysta z uwierzytelniania odciskami kluczy — przy pierwszym
połączeniu zaakceptuj właściwy fingerprint klienta i serwera.
