# Obsługa systemu

## Walidacja i aktywacja

Uruchamiaj z katalogu repozytorium:

```bash
nix flake check path:.
nix build path:.#nixosConfigurations.rog-polamaniec.config.system.build.toplevel --no-link
sudo nixos-rebuild test --flake path:.#rog-polamaniec
sudo nixos-rebuild switch --flake path:.#rog-polamaniec
```

Po zmianach Home Managera aktywacja aktualizuje także pliki `~/.pi/agent/` i
`~/.config/mcp/`. Repozytorium nie uruchamia tych poleceń automatycznie.

## Ollama, LiteLLM i Open WebUI

```bash
cd ~/Dev/Ollama
make init-litellm-env
make vulkan   # albo: make rocm / make cpu
make status
make logs
make pull MODEL=<tag>
make restart-litellm
make down
```

Usługi: Open WebUI `:3000`, SearXNG `:8080`, Ollama `:11434`, LiteLLM `:4000`,
router AUTO `:4100` lokalnie w sieci Compose. Sekret `LITELLM_MASTER_KEY` jest
w `~/.config/ollama-router/hosts.env`.

Ollama: kontekst `65536`, Flash Attention, KV cache `q8_0` i jedno żądanie
równoległe. White Monster (RX 9070 XT) kieruje Qwen3.8 27B MTP na profil
`qwen38-mtp2` z `draft_num_predict=2` i `think=low`; po aktywacji utwórz go na tym hoście
przez `cd ~/Dev/Ollama && make mtp2`. Open WebUI używa LiteLLM i ma web search
przez SearXNG. Nie wpisuj kluczy do Nixa ani Git.

## Pi i MCP

```bash
pi
agent-manager
```

Pi używa LiteLLM `model=auto`, czterech narzędzi bazowych i jednego lazy proxy
MCP. SearXNG i Agent Manager są uruchamiane na żądanie. Konfiguracja:

- `~/.pi/agent/settings.json` — narzędzia i compaction;
- `~/.pi/agent/models.json` — provider LiteLLM, model `auto`;
- `~/.pi/agent/SYSTEM.md` — krótka instrukcja agenta;
- `~/.config/mcp/mcp.json` — adapter MCP.

Na hoście lokalnym bez farmy (izakomp) domyślnym modelem jest
`local-qwen38-off` (Qwen3.8 bez MTP); `local-qwen38-thinking` włącza tryb
rozumowania.

Pi: `contextWindow=65536`, `maxTokens=16384`, compaction
`reserveTokens=20480`, `keepRecentTokens=10000`. Pi pokazuje w transkrypcie
diagnostykę kompaktowania; przy długim zadaniu po zakończeniu etapu użyj
`/compact`, zanim wkleisz duży log lub rozpoczniesz odrębny temat. Duże zadania
zapisuj w `PLAN.md` i `STATUS.md`.

## Autonomiczny Pi

`auto-worker` wykonuje w bieżącym projekcie świeżą sesję Pi co pięć minut;
każda iteracja czyta i aktualizuje `PLAN.md` oraz `STATUS.md`. Jedna blokada
`flock` na katalog projektu uniemożliwia równoległe uruchomienie, `Ctrl+C`
zatrzymuje pętlę po bieżącej iteracji, a sześć kolejnych nieudanych iteracji
kończy ją automatycznie:

```bash
auto-worker --prompt "Ulepsz aplikację Laravel zgodnie z PLAN.md"
```

W Agent Managerze wybierz narzędzie `auto-worker` w formularzu nowej sesji i
wpisz ten sam cel jako prompt. Manager pokaże nadrzędną pętlę i jej log; jej
krótkie procesy Pi celowo nie są osobnymi wierszami, aby nie zaśmiecać panelu.
Worker nie wykonuje deploya, pushowania, instalacji zależności ani zmian
systemowych.

## Modele i routing

Prywatne adresy i tagi modeli ustawiaj w `~/.config/ollama-router/hosts.env`.
Alias `auto` kieruje żądania przez lokalny router do właściwego modelu. Model
wag Q8 wymaga osobnego artefaktu Ollama; `q8_0` w konfiguracji oznacza cache KV.

## Diagnostyka

```bash
docker compose ps
docker compose logs --tail=100 litellm
docker compose logs --tail=100 ollama-vulkan
curl -sS http://127.0.0.1:4000/v1/models
curl -sS http://127.0.0.1:4100/health
systemctl --user --failed
```

Po zmianie zmiennych modeli wykonaj `make restart-litellm`. Po zmianie profilu
Ollama odtwórz wybrany kontener Compose, aby przyjął nowe zmienne środowiskowe.

## Aktualizacje i porządki

```bash
nix-collect-garbage -d
update-agent-manager
```

Nie usuwaj ręcznie `/nix/store`; najpierw sprawdź zależności i bieżącą generację.
