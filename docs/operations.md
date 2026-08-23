# Obsługa systemu

Wszystkie polecenia należy uruchamiać z katalogu repozytorium.

## Walidacja

Ewaluacja wszystkich outputów flake:

```bash
nix flake check path:.
```

Pełny build laptopa bez aktywowania:

```bash
nix build path:.#nixosConfigurations.laptop.config.system.build.toplevel
```

Użycie `path:.` uwzględnia wszystkie pliki robocze i działa również bez metadanych
Git. W zwykłym checkoutcie można używać także `.#...`.

## Aktywacja

Preferowana pierwsza próba, ważna do restartu:

```bash
sudo nixos-rebuild test --flake path:.#laptop
```

Po ręcznym sprawdzeniu pulpitu, sieci, dźwięku i nagrywania:

```bash
sudo nixos-rebuild switch --flake path:.#laptop
```

## Aktualizacja zależności

```bash
nix flake update
nix flake check path:.
nix build path:.#nixosConfigurations.laptop.config.system.build.toplevel
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

## Minimalna kontrola po aktywacji

1. Otworzyć Foot przez `Super+Enter`.
2. Sprawdzić launcher, Waybar i powiadomienia.
3. Otworzyć aplikację GTK3 i GTK4, potwierdzając ciemny motyw.
4. Przetestować historię schowka przez `Super+Shift+V`.
5. Sprawdzić głośność, mikrofon, Bluetooth i klawisze multimedialne.
6. Włączyć replay, zapisać klip i sprawdzić trzy ścieżki audio.
7. Rozwinąć monitoring zasobów oraz centrum powiadomień w Waybarze.
8. Sprawdzić `Print`, `Super+Shift+S` oraz zapis i kopiowanie z Satty.
9. Otworzyć `about:policies` w Zen i potwierdzić Dark Reader oraz Bitwarden na
   pasku narzędzi i w prywatnym oknie.
