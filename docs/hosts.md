# Hosty

## `rog-polamaniec`

Główny laptop i host AUTO. Używa GPU AMD, Docker Compose, Ollamy, LiteLLM,
Open WebUI, SearXNG, Agent Managera i Pi. Profil Home Managera: `base`.

## Pozostałe manifesty

`hosts/armaniec/` i `hosts/white-monster/` zawierają opisy hostów używanych jako
zewnętrzne endpointy. Ich adresy i modele są prywatną konfiguracją w
`~/.config/ollama-router/hosts.env`.

## Nowy host

Skopiuj manifest, wygeneruj własny `hardware-configuration.nix`, wybierz moduły
sprzętowe i osobny profil użytkownika. Nie kopiuj konfiguracji sprzętu między
maszynami. Szczegóły: [new-host.md](new-host.md).
