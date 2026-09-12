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

## Kali Linux VM na ROG-u

`features.kaliVm = true` w manifeście ROG-a instaluje KVM/QEMU, libvirt z
UEFI oraz Virt-Manager. Nie pobiera obrazu Kali ani nie tworzy maszyny
wirtualnej automatycznie. Po aktywacji pobierz oficjalne ISO instalatora Kali,
uruchom `virt-manager` i utwórz VM z lokalnego ISO. Wybierz firmware UEFI,
wirtualny dysk qcow2 i domyślną sieć NAT. Po pierwszej aktywacji wyloguj się i
zaloguj ponownie, aby członkostwo w grupie `libvirtd` było widoczne w sesji.

`virtui-manager` jest klawiaturowym TUI dla tych samych VM libvirt; uruchom go
w Foot poleceniem `virtui-manager`. Virt-Manager pozostaje awaryjnym edytorem
sprzętu i konsolą graficzną. Oba programy zarządzają jedną pulą VM, więc nie
twórz osobnego QEMU ani Quickemu dla tej samej maszyny.

NAT pozwala VM inicjować połączenia i skany do urządzeń LAN, ale nie daje jej
własnego adresu w LAN ani ruchu warstwy 2. To bezpieczny domyślny wariant dla
autoryzowanych rekonesansów i prostych skanów; do testów wymagających własnego
adresu LAN trzeba osobno skonfigurować most sieciowy, co na Wi-Fi może nie być
obsługiwane przez punkt dostępowy.

## ROG: Ollama z Qwen2.5-Coder 7B Q6_K

Po aktywacji uruchom Dockera oraz pobierz model. Stos zawiera tylko Ollamę
ROCm — bez Open WebUI, SearXNG i LiteLLM.

```bash
sudo systemctl start docker
cd ~/Dev/Ollama
make up
make pull
curl http://127.0.0.1:11434/api/tags
```

API jest otwarte na zaufaną sieć LAN pod portem `11434` i nie ma
uwierzytelniania. Zatrzymanie kontenera: `cd ~/Dev/Ollama && make down`.

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

ROG uruchamia SearXNG MCP lokalnie na żądanie, a wyszukiwanie przekazuje do
adresu `searxngUrl` z `hosts/rog-polamaniec/host.json`, wskazującego instancję
na White Monsterze. Ten serwer musi udostępniać port `8080` w zaufanej sieci LAN.

Funkcja hosta `godot` instaluje Godot 4 i lokalny serwer `godot-mcp`. Serwer jest
zadeklarowany w Pi, ale domyślnie zablokowany, ponieważ może modyfikować i
uruchamiać projekt. Włączaj go jawnie tylko w katalogu właściwego projektu:

```text
/mcp enable godot
/reload
```

Wyłączenie dla projektu działa analogicznie przez `/mcp disable godot` i
`/reload`. Stan przełącznika trafia do projektowego `.pi/mcp.json`; konfiguracja
globalna pozostaje wyłączona.

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
