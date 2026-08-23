# Repository Guidelines

## Project Structure & Module Organization

This repository defines NixOS systems through a flake. `flake.nix` declares each machine under `nixosConfigurations`, while `flake.lock` pins the `nixpkgs` revision. Put machine-specific settings in `hosts/<name>/configuration.nix`; generated hardware settings belong in `hosts/<name>/hardware-configuration.nix`. Reusable concerns live in `modules/`: `common.nix` provides baseline packages and locale settings, while `desktop.nix`, `development.nix`, and `gaming.nix` group optional capabilities. The checked-in host is currently `laptop`. Keep secrets and machine credentials out of Nix files and Git.

## Build, Test, and Development Commands

- `nix flake check` evaluates all flake outputs and catches syntax or module errors.
- `nix build .#nixosConfigurations.laptop.config.system.build.toplevel` builds the laptop configuration without activating it; inspect the resulting `result` symlink.
- `sudo nixos-rebuild test --flake .#laptop` activates a build until reboot, making it the preferred manual verification step.
- `sudo nixos-rebuild switch --flake .#laptop` installs and activates a configuration after validation.
- `nix flake update` refreshes locked inputs; review `flake.lock` changes carefully.

Run commands from the repository root. Replace `laptop` with the relevant flake output when adding another host.

## Coding Style & Naming Conventions

Use two-space indentation and conventional Nix formatting. Prefer small, declarative modules over duplicating options in host files. Name modules and host directories with lowercase, descriptive words. Format function arguments and attribute sets consistently, and group package lists with `with pkgs; [ ... ]`. No formatter is configured, so avoid unrelated formatting churn; use `nixfmt` if available.

## Testing Guidelines

There is no separate automated test suite or coverage target. Treat successful flake evaluation and a full system build as required checks. For changes affecting boot, networking, graphics, or hardware, use `nixos-rebuild test` before `switch` and confirm the affected service manually.

## Commit & Pull Request Guidelines

Repository history is unavailable in this checkout. Use short, imperative commit subjects such as `Enable Bluetooth on laptop` and keep unrelated changes separate. Pull requests should explain the motivation, identify affected hosts/modules, list validation commands and results, and note operational risks. Include screenshots only for visible desktop changes; never commit secrets or generated `result` links.
