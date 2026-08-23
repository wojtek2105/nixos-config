HOST ?= laptop
FLAKE ?= path:.

.PHONY: help check build test rollback boot switch

help:
	@printf '%s\n' \
		'make check     - sprawdź wszystkie wyjścia flake' \
		'make build     - zbuduj system bez aktywacji' \
		'make test      - aktywuj konfigurację do restartu' \
		'make rollback  - wróć na żywo do systemu uruchomionego przy bootowaniu' \
		'make boot      - ustaw konfigurację na następny start' \
		'make switch    - aktywuj i ustaw konfigurację jako domyślną'

check:
	nix flake check $(FLAKE)

build:
	nix build $(FLAKE)\#nixosConfigurations.$(HOST).config.system.build.toplevel --no-link

test:
	sudo nixos-rebuild test --flake $(FLAKE)\#$(HOST)

rollback:
	sudo /run/booted-system/bin/switch-to-configuration test

boot:
	sudo nixos-rebuild boot --flake $(FLAKE)\#$(HOST)

switch:
	sudo nixos-rebuild switch --flake $(FLAKE)\#$(HOST)
