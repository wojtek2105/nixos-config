-include .env

HOST ?= rog-polamaniec
FLAKE ?= path:.
KEEP ?= 4
SYSTEM_PROFILE ?= /nix/var/nix/profiles/system

.DEFAULT_GOAL := help

.PHONY: help check build test rollback boot switch generations gc host-manager new-host

help: ## 📖 Pokaż dostępne polecenia
	@awk 'BEGIN { FS = ":.*## " } /^[a-zA-Z0-9][a-zA-Z0-9_.-]*:.*## / && $$1 != "help" { printf "\033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

host-manager: ## 🧭 Interaktywnie twórz i edytuj hosty oraz moduły
	bash ./tools/host-manager.sh

new-host: host-manager ## 🆕 Uruchom kreator nowego hosta

check: ## 🔎 Sprawdź wszystkie wyjścia flake
	nix flake check $(FLAKE)

build: ## 🔨 Zbuduj system bez aktywacji
	nix build $(FLAKE)\#nixosConfigurations.$(HOST).config.system.build.toplevel --no-link

test: ## 🧪 Aktywuj konfigurację do restartu
	sudo nixos-rebuild test --flake $(FLAKE)\#$(HOST)
	ironbar --config "$(HOME)/.config/ironbar/config.json" --theme "$(HOME)/.config/ironbar/style.css" --validate-config
	systemctl --user daemon-reload
	systemctl --user restart ironbar.service

rollback: ## ↩️ Wróć na żywo do systemu uruchomionego przy bootowaniu
	sudo /run/booted-system/bin/switch-to-configuration test

boot: ## 💾 Ustaw konfigurację na następny start
	sudo nixos-rebuild boot --flake $(FLAKE)\#$(HOST)

switch: ## ✨ Aktywuj i ustaw konfigurację jako domyślną
	sudo nixos-rebuild switch --flake $(FLAKE)\#$(HOST)

generations: ## 🗂️ Pokaż zachowane generacje systemu
	sudo nix-env --profile $(SYSTEM_PROFILE) --list-generations

gc: ## 🧹 Zachowaj ostatnie KEEP generacje i zwolnij miejsce
	@case '$(KEEP)' in ''|*[!0-9]*) printf 'KEEP musi być dodatnią liczbą całkowitą.\n' >&2; exit 2;; esac
	@test '$(KEEP)' -ge 1 || { printf 'KEEP musi być większe lub równe 1.\n' >&2; exit 2; }
	sudo nix-env --profile $(SYSTEM_PROFILE) --delete-generations +$(KEEP)
	sudo nix-store --gc
	sudo nix-env --profile $(SYSTEM_PROFILE) --list-generations
