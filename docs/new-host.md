# Nowy host lub użytkownik

## 1. Skopiuj manifest

Utwórz `hosts/<host>/default.nix`, `configuration.nix` i własny
`hardware-configuration.nix`. Nie kopiuj pliku sprzętowego z innej maszyny.
Wybierz istniejący profil Home Managera albo utwórz `home/<profil>/`.

## 2. Wygeneruj sprzęt

Na uruchomionym NixOS:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/<host>/hardware-configuration.nix
```

Sprawdź GPU, dyski, sieć, monitor i urządzenie podświetlenia. Ustaw te fakty
w manifeście hosta, nie w module współdzielonym.

## 3. Dodaj hosta do flake

Dodaj host do `flake.nix` oraz do allowlisty użytkowników, jeśli jest używana.
Zachowaj poprawne `username`, `homeProfile` i funkcje sprzętowe.

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

Sprawdź logowanie, sieć, Wayland, dźwięk, GPU, podświetlenie, Docker i wybrane
usługi użytkownika. Dla profilu AI utwórz poza Git:

```bash
mkdir -p ~/.config/ollama-router
chmod 700 ~/.config/ollama-router
```

W `hosts.env` wpisz adresy endpointów i `LITELLM_MASTER_KEY`; nie commituj tego
pliku. Sekrety, dane modeli i dane kontenerów pozostają poza repozytorium.

## Typowe błędy

- Brak hosta w `flake.nix`: nazwa w komendzie musi odpowiadać outputowi flake.
- Brak profilu: `homeProfile` musi wskazywać istniejący moduł.
- Brak podświetlenia: ustaw właściwy `backlightDevice` dla danego laptopa.
- Błąd GPU: sprawdź moduł GPU i urządzenia `/dev/dri` oraz `/dev/kfd`.
- Błąd AI: sprawdź `hosts.env`, `make status` i logi LiteLLM/Ollamy.
