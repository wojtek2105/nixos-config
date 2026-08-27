# Hosty

## ROG Polamaniec

Obecnie repozytorium zawiera jeden gotowy do aktywacji host:

- output flake: `rog-polamaniec`,
- hostname: `rog-polamaniec`,
- konfiguracja: `hosts/rog-polamaniec/configuration.nix`,
- sprzęt: `hosts/rog-polamaniec/hardware-configuration.nix`,
- dodatkowe funkcje: Docker, gaming, nagrywanie, aplikacje osobiste i profil laptopa,
- diagnostyka GPU na żądanie jest wyłączona w manifeście, bo codzienne metryki
  zapewniają Ironbar i btop,
- opcjonalny benchmark schedulerów jest wyłączony, więc stress-ng,
  SuperTuxKart i schedulery testowe nie trafiają z jego powodu do codziennego
  closure,
- moduł GPU: `modules/hardware-amd-gpu.nix`,
- moduł laptopa: `modules/hardware-asus-laptop.nix`.

Laptop to ASUS ROG Zephyrus G14 GA402RK. Moduł AMD zapewnia grafikę i wczesne
ładowanie `amdgpu`. Niezależny moduł ASUS używa najnowszego jądra z przypiętego
`nixpkgs`, ładuje `asus-armoury` oraz uruchamia `asusd`; polecenie `asusctl`
i ROG Control Center są dostępne deklaratywnie.

Flake automatycznie wystawia katalogi `hosts/<nazwa>/` zawierające `default.nix`
i własny `hardware-configuration.nix`.
Allowlista w `.gitignore` decyduje, które hosty i profile użytkowników mogą być
wersjonowane. Sekrety, hasła, profile Wi-Fi i klucze SSH pozostają poza repo.

## White Monster

`hosts/white-monster/` jest przygotowany dla desktopa z Radeonem RX 9070 XT.
Współdzieli profil `home/wojtek`, pulpit, tapety, aplikacje, Docker, gaming,
nagrywanie i przewodowy ALVR, ale ma `features.laptop = false` i nie importuje
modułu ASUS-a ani ustawień pokrywy. Do czasu wygenerowania na tym komputerze
jego własnego `hardware-configuration.nix` host pozostaje bezpiecznie pominięty
przez flake; dokładna komenda znajduje się w `hosts/white-monster/README.md`.

## Nowy host i użytkownik

1. Skopiuj katalog istniejącego hosta do `hosts/<nowy-host>/` i wygeneruj dla
   niego właściwy `hardware-configuration.nix`.
2. W jego `default.nix` zmień `username`, mapę `features` oraz — na laptopie —
   `backlightDevice`. Nazwa hosta wynika automatycznie z nazwy katalogu.
3. Aby skopiować również profil użytkownika, skopiuj `home/wojtek/` do
   `home/<username>/`. Plików wewnątrz nie trzeba zmieniać.
4. Alternatywnie nie kopiuj profilu i ustaw `homeProfile = "wojtek"`; nowe konto
   użyje wtedy istniejącej konfiguracji Home Managera.
5. Dodaj nowy host i użytkownika do allowlist w `.gitignore`, a następnie do
   indeksu Git, ponieważ flake oparty na repo nie widzi plików nieśledzonych.
