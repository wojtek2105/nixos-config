# White Monster

White Monster jest bezgłowym serwerem bez Home Managera i GUI. Konfiguracja
systemowa włącza tylko wspólną bazę, Docker z Compose oraz SSH. Open WebUI i
vLLM instaluj ręcznie jako kontenery Docker; żaden model ani stos AI nie jest
deklarowany ani uruchamiany przez NixOS. Włączony pozostaje wyłącznie sterownik
AMD potrzebny, aby kontener vLLM miał dostęp do GPU; nie uruchamia on GUI.

Host ma własny `hardware-configuration.nix` i jest dostępny jako
`nixosConfigurations.white-monster`. Jeśli przy ponownej instalacji zmienią się
dyski lub sprzęt, wygeneruj go na White Monsterze, z repozytorium jako bieżącym
katalogiem:

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
sprzętowe laptopa.
