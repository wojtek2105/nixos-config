# Repository Guidelines

## Project Structure & Module Organization

This repository defines one NixOS system through a flake. `flake.nix` declares `rog-polamaniec` under `nixosConfigurations`, while `flake.lock` pins the `nixpkgs` revision. Machine-specific settings live in `hosts/rog-polamaniec/configuration.nix`; generated hardware settings belong in `hosts/rog-polamaniec/hardware-configuration.nix`. Reusable concerns live in `modules/`: `common.nix` provides baseline packages and locale settings, while small modules such as `desktop.nix`, `docker.nix`, `gaming.nix`, and `screen-recording.nix` group optional capabilities. Keep secrets and machine credentials out of Nix files and Git.

## Build, Test, and Development Commands

- `nix flake check` evaluates all flake outputs and catches syntax or module errors.
- `nix build .#nixosConfigurations.rog-polamaniec.config.system.build.toplevel` builds the laptop configuration without activating it; inspect the resulting `result` symlink.
- `sudo nixos-rebuild test --flake .#rog-polamaniec` activates a build until reboot, making it the preferred manual verification step.
- `sudo nixos-rebuild switch --flake .#rog-polamaniec` installs and activates a configuration after validation.
- `nix flake update` refreshes locked inputs; review `flake.lock` changes carefully.

Run commands from the repository root.

The user owns all build and test execution. Do not run validation commands such
as `nix flake check`, `nix build`, or `nixos-rebuild`; after making changes,
only report the commands the user may run and wait for their validation.

## Coding Style & Naming Conventions

Use two-space indentation and conventional Nix formatting. Prefer small, declarative modules over duplicating options in the host file. Name modules with lowercase, descriptive words. Format function arguments and attribute sets consistently, and group package lists with `with pkgs; [ ... ]`. No formatter is configured, so avoid unrelated formatting churn; use `nixfmt` if available.

## Testing Guidelines

There is no separate automated test suite or coverage target. Treat successful flake evaluation and a full system build as required checks. For changes affecting boot, networking, graphics, or hardware, use `nixos-rebuild test` before `switch` and confirm the affected service manually.

## Commit & Pull Request Guidelines

Repository history is unavailable in this checkout. Use short, imperative commit subjects such as `Enable Bluetooth on ROG laptop` and keep unrelated changes separate. Pull requests should explain the motivation, identify affected hosts/modules, list validation commands and results, and note operational risks. Include screenshots only for visible desktop changes; never commit secrets or generated `result` links.

## Lean Repository and Documentation

Keep the repository and agent context small. Documentation is an **AS IS**
reference: describe only active behavior, current paths, commands, and required
decisions. Remove obsolete migrations, historical alternatives, duplicated
explanations, and inactive configurations instead of appending more text.
Preserve benchmarks and asset inventories only when they are intentionally used
as historical data. Prefer a short source-of-truth file over repeating the same
details in several Markdown files.
