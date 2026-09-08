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

## White Monster: Docker i SSH

Po aktywacji konfiguracji zaloguj się na serwer i zainstaluj własny stos
Compose z Open WebUI oraz vLLM. NixOS nie tworzy kontenerów, nie pobiera modeli
i nie przechowuje ich danych ani sekretów.

```bash
ssh wojtek@white-monster
docker compose version
```

W Compose wystaw Open WebUI oraz API vLLM na portach potrzebnych w zaufanej
sieci LAN. Następnie ustaw ten adres i dokładną nazwę serwowanego modelu w
`hosts/rog-polamaniec/host.json`, aby Pi na ROG-u korzystał z White Monstera.

## Pi i MCP

```bash
pi
agent-manager
```

Pi używa API vLLM na White Monsterze, czterech narzędzi bazowych i jednego lazy
proxy MCP. Agent Manager jest uruchamiany na żądanie. Konfiguracja:

- `~/.pi/agent/settings.json` — narzędzia i compaction;
- `~/.pi/agent/models.json` — provider OpenAI-compatible vLLM i wybrany model;
- `~/.pi/agent/SYSTEM.md` — krótka instrukcja agenta;
- `~/.config/mcp/mcp.json` — adapter MCP.

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

## Diagnostyka

```bash
ssh wojtek@white-monster docker ps
ssh wojtek@white-monster docker compose --project-directory /sciezka/do/stosu ps
curl -sS http://white-monster:8000/v1/models
systemctl --user --failed
```

## Aktualizacje i porządki

```bash
nix-collect-garbage -d
update-agent-manager
```

Nie usuwaj ręcznie `/nix/store`; najpierw sprawdź zależności i bieżącą generację.
