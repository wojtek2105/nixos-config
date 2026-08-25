-include .env

HOST ?= rog-polamaniec
FLAKE ?= path:.
KEEP ?= 4
SYSTEM_PROFILE ?= /nix/var/nix/profiles/system

.PHONY: help check build test rollback boot switch generations gc

help:
	@printf '%s\n' \
		'make check     - sprawdź wszystkie wyjścia flake' \
		'make build     - zbuduj system bez aktywacji' \
		'make test      - aktywuj konfigurację do restartu' \
		'make rollback  - wróć na żywo do systemu uruchomionego przy bootowaniu' \
		'make boot      - ustaw konfigurację na następny start' \
		'make switch    - aktywuj i ustaw konfigurację jako domyślną' \
		'make generations       - pokaż zachowane generacje systemu' \
		'make gc KEEP=4         - zachowaj 4 ostatnie generacje i zwolnij miejsce'

check:
	nix flake check $(FLAKE)

build:
	nix build $(FLAKE)\#nixosConfigurations.$(HOST).config.system.build.toplevel --no-link

test:
	sudo nixos-rebuild test --flake $(FLAKE)\#$(HOST)
	ironbar --config "$(HOME)/.config/ironbar/config.json" --theme "$(HOME)/.config/ironbar/style.css" --validate-config
	systemctl --user daemon-reload
	systemctl --user restart ironbar.service

rollback:
	sudo /run/booted-system/bin/switch-to-configuration test

boot:
	sudo nixos-rebuild boot --flake $(FLAKE)\#$(HOST)

switch:
	sudo nixos-rebuild switch --flake $(FLAKE)\#$(HOST)

generations:
	sudo nix-env --profile $(SYSTEM_PROFILE) --list-generations

gc:
	@case '$(KEEP)' in ''|*[!0-9]*) printf 'KEEP musi być dodatnią liczbą całkowitą.\n' >&2; exit 2;; esac
	@test '$(KEEP)' -ge 1 || { printf 'KEEP musi być większe lub równe 1.\n' >&2; exit 2; }
	sudo nix-env --profile $(SYSTEM_PROFILE) --delete-generations +$(KEEP)
	sudo nix-store --gc
	sudo nix-env --profile $(SYSTEM_PROFILE) --list-generations
