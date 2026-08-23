# Hosty

## ROG Polamaniec

Obecnie repozytorium zawiera jeden gotowy do aktywacji host:

- output flake: `rog-polamaniec`,
- hostname: `rog-polamaniec`,
- konfiguracja: `hosts/rog-polamaniec/configuration.nix`,
- sprzęt: `hosts/rog-polamaniec/hardware-configuration.nix`,
- dodatkowe funkcje: Docker, gaming, aplikacje osobiste i profil laptopa,
- dodatkowy moduł: `modules/hardware-amd-rog.nix`.

Laptop to ASUS ROG Zephyrus G14 GA402RK. Moduł sprzętowy używa najnowszego
jądra z przypiętego `nixpkgs`, ładuje sterownik `asus-armoury` oraz uruchamia
`asusd`; polecenie `asusctl` i ROG Control Center są dostępne deklaratywnie.

To jedyny host wystawiony przez flake i jedyny katalog w `hosts/`, który jest
przeznaczony do wersjonowania. Pozostałe, lokalnie tworzone katalogi hostów są
ignorowane przez Git. Sekrety, hasła, profile Wi-Fi i klucze SSH pozostają poza
repozytorium.
