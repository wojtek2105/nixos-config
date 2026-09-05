# Architektura

## Flake

Flake definiuje host `rog-polamaniec`. Sprzęt jest w `hosts/`; moduły systemowe
w `modules/`; profil Home Managera w `home/`.

## Warstwy

- `hosts/rog-polamaniec/` — host, sprzęt i wybór funkcji.
- `modules/` — współdzielone moduły NixOS.
- `home/base/` — pakiety i konfiguracja użytkownika.
- `home/ollama.nix` — Docker Compose: Ollama, LiteLLM, Open WebUI, SearXNG.
- `services/auto-ai-router/` — lokalny router AUTO.

## Agenty AI

Pi jest głównym agentem CLI. Używa LiteLLM `http://127.0.0.1:4000/v1`, modelu
`auto` i Qwena 3.8. Pi ma `read`, `write`, `edit`, `bash` oraz jeden lazy proxy
MCP dla SearXNG i Agent Managera. Codex jest tylko jawną eskalacją.

Ollama używa kontekstu 65 536 tokenów, pojedynczego żądania równoległego i KV
cache `q8_0`. White Monster z RX 9070 XT używa profilu `qwen38-mtp2`, który
ustawia `draft_num_predict=2` dla Qwen3.8 27B MTP.
Pi ma limit odpowiedzi 4096 tokenów oraz compaction `reserveTokens=8192`,
`keepRecentTokens=6000`.
Kompaktowanie zaczyna się około 32k tokenów, aby streszczenie i ponowiona
odpowiedź miały bezpieczny zapas.

## Zasada zmian

Edytuj pliki repozytorium, nie pliki w `~/.config` ani `/etc`. Sekrety trzymaj
poza Git, w `~/.config/ollama-router/hosts.env`.
