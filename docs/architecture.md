# Architektura

## Flake

Flake definiuje hosty z katalogu `hosts/`. Sprzęt jest w `hosts/`; moduły
systemowe w `modules/`; profile Home Managera w `home/` są przypięte tylko do
hostów z GUI.

## Warstwy

- `hosts/rog-polamaniec/` — laptop z GUI i klientem Pi.
- `hosts/white-monster/` — bezgłowy serwer Docker + SSH bez profilu Home Managera.
- `modules/` — współdzielone moduły NixOS.
- `home/base/` — pakiety i konfiguracja użytkownika.

## Agenty AI

Pi jest głównym agentem CLI na ROG-u. Korzysta z OpenAI-compatible API vLLM
na White Monsterze, bez lokalnego serwera modeli. Przed uruchomieniem ustaw
rzeczywistą nazwę z `vllm serve --served-model-name` w polu `piModelName` oraz
osiągalny adres w `piApiBaseUrl` w manifeście ROG-a. Jeśli vLLM wymaga klucza,
eksportuj `VLLM_API_KEY` w sesji Pi; sekret nie trafia do Git.

## Zasada zmian

Edytuj pliki repozytorium, nie pliki w `~/.config` ani `/etc`. Sekrety trzymaj
poza Git, w `~/.config/ollama-router/hosts.env`.
