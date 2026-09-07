# Hosty

## `rog-polamaniec`

Główny laptop i klient Pi. Nie uruchamia Dockera, Ollamy, LiteLLM, Open WebUI
ani routera AUTO. Pi łączy się bezpośrednio z API vLLM na White Monsterze;
adres i nazwa modelu są w `hosts/rog-polamaniec/host.json`.

## `white-monster`

Bezgłowy serwer AI bez Home Managera i GUI. NixOS udostępnia Docker z Compose,
SSH oraz sam sterownik AMD wymagany przez vLLM w kontenerze. Open WebUI i vLLM
instaluj jako własny stos Docker po SSH; modele i dane kontenerów pozostają poza
Nix store i Git.

## Pozostałe manifesty

`hosts/armaniec/` i `hosts/white-monster/` zawierają opisy hostów używanych jako
zewnętrzne endpointy. Ich adresy i modele są prywatną konfiguracją w
`~/.config/ollama-router/hosts.env`.

## Nowy host

Skopiuj manifest, wygeneruj własny `hardware-configuration.nix`, wybierz moduły
sprzętowe i osobny profil użytkownika. Nie kopiuj konfiguracji sprzętu między
maszynami. Szczegóły: [new-host.md](new-host.md).
