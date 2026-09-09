# Hosty

## `rog-polamaniec`

Główny laptop i klient Pi. Uruchamia w Dockerze wyłącznie Ollamę ROCm z
Qwen2.5-Coder 7B Q6_K i kontekstem 16k, bez LiteLLM, Open WebUI ani lokalnego
kontenera SearXNG. MCP SearXNG korzysta z instancji na White Monsterze. API
Ollamy jest dostępne w zaufanej sieci LAN na porcie `11434`; obsługa kontenera jest w
`~/Dev/Ollama` po aktywacji konfiguracji.

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
