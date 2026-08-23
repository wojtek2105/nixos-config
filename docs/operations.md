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

Lista skrótów jest dostępna również pod `Super+F1`.

## Diagnostyka usług użytkownika

```bash
systemctl --user status hypridle.service
journalctl --user -u hypridle.service -b
pgrep -a gsr-ui
gsr-ui-cli --help
```

Natychmiastowe przejście do następnej tapety bez czekania na timer:

```bash
systemctl --user start rotate-wallpaper.service
```

## Minimalna kontrola po aktywacji

1. Otworzyć Foot przez `Super+Enter`.
2. Sprawdzić launcher, aktywny panel i powiadomienia.
3. Otworzyć aplikację GTK3 i GTK4, potwierdzając ciemny motyw.
4. Przetestować historię schowka przez `Super+Shift+V`.
5. Sprawdzić głośność, mikrofon, Bluetooth i klawisze multimedialne.
6. Włączyć replay, zapisać klip i sprawdzić trzy ścieżki audio.
7. Rozwinąć monitoring zasobów oraz centrum powiadomień w aktywnym panelu.
8. Sprawdzić `Print`, `Super+Shift+S` oraz zapis i kopiowanie z Satty.
9. Otworzyć `about:policies` w Zen i potwierdzić Dark Reader oraz Bitwarden na
   pasku narzędzi i w prywatnym oknie.
10. Po zamknięciu i ponownym uruchomieniu Zen sprawdzić Biscuit w interfejsie,
    nowej karcie oraz `about:preferences`; profil powinien zachować historię,
    zakładki i poprzednią sesję.
