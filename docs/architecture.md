# Architektura

## Flake

Flake definiuje hosty z katalogu `hosts/`. Sprzęt jest w `hosts/`; moduły
systemowe w `modules/`; profile Home Managera w `home/` są przypięte tylko do
hostów z GUI.

## Warstwy

- `hosts/rog-polamaniec/` — laptop z GUI i klientem Pi.
- `hosts/armaniec/` — etapowy laptop ARM64 z GUI i natywnym Codexem, bez
  lokalnego AI i pakietów binarnych dostępnych tylko na x86_64.
- `modules/` — współdzielone moduły NixOS.
- `home/base/` — pakiety i konfiguracja użytkownika.

## Agenty AI

Pi jest głównym agentem CLI na ROG-u. Korzysta z lokalnej lub wskazanej w
manifeście Ollamy, zależnie od konfiguracji hosta.

Opcjonalna funkcja hosta `godot` dostarcza silnik i lokalny bridge MCP. Bridge
jest globalnie wyłączony; użytkownik może dopuścić go osobno w konkretnym
projekcie poleceniem Pi, bez rozszerzania uprawnień pozostałych sesji.

## Zasada zmian

Edytuj pliki repozytorium, nie pliki w `~/.config` ani `/etc`. Sekrety trzymaj
poza Git, w `~/.config/ollama-router/hosts.env`.
