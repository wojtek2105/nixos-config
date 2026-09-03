# White Monster

Ten host używa profilu `home/wojtek`, który importuje przenośną bazę desktopową `home/base`: środowisko
Hyprland, aplikacje, gaming, Docker, VR i nagrywanie ekranu. Nie importuje
modułu `hardware-asus-laptop.nix`, usług `asusd`, ROG Control Center, obsługi
baterii, pokrywy, podświetlenia matrycy ani automatyki eDP. Moduł
`hardware-amd-gpu.nix` przygotowuje KMS dla Radeona RX 9070 XT, a host używa
najnowszego jądra z przypiętego nixpkgs.

Host pozostaje celowo niewidoczny w `nixosConfigurations`, dopóki nie ma jego
własnego `hardware-configuration.nix`. Na White Monsterze, z repozytorium jako
bieżącym katalogiem, wygeneruj go poleceniem:

```bash
sudo nixos-generate-config --show-hardware-config \
  | sudo tee hosts/white-monster/hardware-configuration.nix >/dev/null
```

Podczas instalacji z obrazu NixOS, po zamontowaniu docelowego systemu pod
`/mnt`, użyj zamiast tego:

```bash
sudo nixos-generate-config --root /mnt --show-hardware-config \
  | sudo tee hosts/white-monster/hardware-configuration.nix >/dev/null
```

Nie kopiuj pliku z `rog-polamaniec`: zawiera identyfikatory dysków i moduły
sprzętowe laptopa. Po dodaniu właściwego pliku output pojawi się automatycznie
jako `nixosConfigurations.white-monster`.
