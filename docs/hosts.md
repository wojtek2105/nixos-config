# Hosty

## `rog-polamaniec`

Główny laptop i klient Pi. Uruchamia w Dockerze wyłącznie Ollamę ROCm z
Qwen2.5-Coder 7B Q6_K i kontekstem 16k, bez LiteLLM, Open WebUI ani lokalnego
kontenera SearXNG. MCP SearXNG korzysta z instancji na White Monsterze. API
Ollamy jest dostępne w zaufanej sieci LAN na porcie `11434`; obsługa kontenera jest w
`~/Dev/Ollama` po aktywacji konfiguracji. Funkcja `godot` instaluje Godot 4 oraz
bridge MCP, który pozostaje wyłączony do jawnego włączenia w projekcie przez Pi.

## `izakomp`

Desktop Izy ma ten sam profil Pi, adapter MCP, queue picker, Agent Manager i
opcjonalny bridge Godot co ROG. Pi łączy się bezpośrednio wyłącznie z lokalną
Ollamą pod `http://127.0.0.1:11434/v1`, używając `qwen38-27b:latest`; lazy MCP
SearXNG korzysta z lokalnej instancji pod `http://127.0.0.1:8080`. Powłoką
logowania jest Bash z ble.sh i Starshipem.

## `white-monster`

Bezgłowy serwer AI bez Home Managera i GUI. NixOS udostępnia Docker z Compose,
SSH oraz sam sterownik AMD wymagany przez vLLM w kontenerze. Open WebUI i vLLM
instaluj jako własny stos Docker po SSH; modele i dane kontenerów pozostają poza
Nix store i Git.

## `armaniec`

ASUS Vivobook S 15 ze Snapdragonem X Elite, przygotowany jako pierwszy etap
instalacji ARM64. Ma GUI Hyprland, Zen Browser, Codex, Git, Vim i GNU Make, ale
bez Dockera, lokalnego AI, Agent Managera, Pi, Godota i funkcji gamingowych.
Host pojawi się w outputach flake dopiero po dodaniu lokalnie wygenerowanego
`hosts/armaniec/hardware-configuration.nix`. Procedura instalacji i ograniczenia
sprzętowe są opisane w [README hosta](../hosts/armaniec/README.md).

## Nowy host

Skopiuj manifest, wygeneruj własny `hardware-configuration.nix`, wybierz moduły
sprzętowe i osobny profil użytkownika. Nie kopiuj konfiguracji sprzętu między
maszynami. Szczegóły: [new-host.md](new-host.md).
