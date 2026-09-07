# Nowy host lub użytkownik

## 1. Skopiuj manifest

Utwórz `hosts/<host>/default.nix`, `configuration.nix` i własny
`hardware-configuration.nix`. Nie kopiuj pliku sprzętowego z innej maszyny.
Dla GUI wybierz istniejący profil Home Managera albo utwórz `home/<profil>/`;
dla serwera ustaw `homeProfile` i `homeOverlay` na `null`.

## 2. Wygeneruj sprzęt

Na uruchomionym NixOS:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/<host>/hardware-configuration.nix
```

Sprawdź GPU, dyski, sieć, monitor i urządzenie podświetlenia. Ustaw te fakty
w manifeście hosta, nie w module współdzielonym.

## 3. Dodaj hosta do flake

Dodaj host do `flake.nix` oraz do allowlisty użytkowników, jeśli jest używana.
Zachowaj poprawne `username`, opcjonalny `homeProfile` i funkcje sprzętowe.

## 4. Sprawdź i aktywuj

```bash
nix flake check path:.
nix build path:.#nixosConfigurations.<host>.config.system.build.toplevel --no-link
sudo nixos-rebuild test --flake path:.#<host>
sudo nixos-rebuild switch --flake path:.#<host>
```

Na świeżej instalacji użyj `nixos-install --flake .#<host>` dopiero po
sprawdzeniu właściwych urządzeń i partycji.

## 5. Po aktywacji

Sprawdź logowanie, sieć oraz wybrane funkcje hosta. Dla serwera Docker sprawdź
SSH, grupę `docker` i własny stos Compose. Sekrety, dane modeli i dane
kontenerów pozostają poza repozytorium.

## Typowe błędy

- Brak hosta w `flake.nix`: nazwa w komendzie musi odpowiadać outputowi flake.
- Brak profilu: `homeProfile` musi wskazywać istniejący moduł.
- Brak podświetlenia: ustaw właściwy `backlightDevice` dla danego laptopa.
- Błąd GPU: sprawdź moduł GPU i urządzenia `/dev/dri` oraz `/dev/kfd`.
- Błąd AI: sprawdź logi własnego stosu Compose oraz adres i nazwę modelu
  skonfigurowane dla klienta.
