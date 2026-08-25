---
name: manage-nixos-config
description: Maintain and evolve this repository's NixOS flake and Home Manager desktop configuration. Use for changes involving Nix modules, host manifests, Home Manager profiles, Hyprland, Ironbar, Yazi, packages, documentation, cleanup, or adapting the complete configuration to another device or user. Preserve portable host/profile boundaries and leave every Nix evaluation, build, test, activation, service restart, and manual verification to the user.
---

# Manage NixOS Config

Maintain this flake as a portable, declarative system while keeping validation and activation under the user's control.

## Start safely

1. Work from the repository root.
2. Read the root `AGENTS.md` and the relevant files before editing.
3. Inspect `git status` and preserve all unrelated or pre-existing changes.
4. Use `rg` or `rg --files` for discovery and `apply_patch` for edits.
5. Treat repository files as the source of truth. Do not hand-edit generated files under `~/.config` or `/etc`.

For a diagnosis or review request, remain read-only. Implement only when the user asks for a change.

## Keep responsibilities separated

- Put generated hardware facts only in `hosts/<host>/hardware-configuration.nix`.
- Put host imports and machine-specific NixOS settings in `hosts/<host>/configuration.nix`.
- Put the host manifest in `hosts/<host>/default.nix`: `username`, optional `homeProfile`, `desktopFeatures`, `backlightDevice`, replay settings, and other hardware choices.
- Put reusable system capabilities in small files under `modules/`.
- Put user-session behavior in `home/<profile>/`; pass values through module arguments instead of importing a host directly.
- Keep Biscuit colors, fonts, icons, and semantic roles centralized in `home/<profile>/theme.nix`.
- Update `docs/` when behavior, shortcuts, architecture, installation, or operational expectations change.
- Keep secrets, tokens, credentials, machine identities, generated `result` links, and mutable runtime state out of Git.

Prefer the smallest responsible module and avoid unrelated formatting churn.

## Comment configurable behavior

Make configurable parts self-explanatory at the point of use.

- Add a nearby comment for every non-obvious knob the user is expected to tune: describe its purpose, unit or accepted values, visible/performance impact, and safe default.
- For hardware-derived values, include the exact read-only discovery command when practical. Examples include backlight devices, monitor names, GPU nodes, audio sources, and network interfaces.
- Explain why a workaround, threshold, timer, scaling factor, polling interval, or package override exists. Record the invariant that must survive future refactors.
- Explain capability flags in host manifests, including what they enable and what they deliberately do not install or start.
- Keep comments concise and adjacent to the setting. Do not narrate obvious Nix syntax or repeat the option name.
- Match the language already used by the file: write user-facing host guidance and documentation in Polish; preserve the established language of implementation comments in mixed technical modules.
- Update or remove a comment in the same patch when behavior changes. Never leave stale operational guidance.

## Maintain useful documentation

Document behavior, decisions, and user actions rather than restating source code.

- Keep `README.md` as a short entry point with build commands and links.
- Use `docs/architecture.md` for module ownership, data flow, and repository layout.
- Use `docs/desktop.md` for components, appearance, runtime behavior, and design decisions.
- Use `docs/keybindings.md` for every user-facing shortcut and important application-local keymap.
- Use `docs/operations.md` for activation, rollback, recovery, and diagnostics.
- Use `docs/new-host.md` for the complete device/account adaptation path.
- Preserve historical performance results in `docs/benchmarks.md`; do not mix removed benchmark tooling back into the live configuration.
- Keep `home/<profile>/wallpapers/README.md` accurate for collection-wide technical facts, `CONCEPTS.md` for artistic direction and the scene list, and `INVENTORY.md` for verified per-file details and planned regeneration briefs.
- Update `docs/README.md` when adding a standalone document.
- Keep commands copy-pasteable, examples consistent with the current flake outputs, and warnings next to risky actions.
- For a visible change, describe the intended hierarchy, spacing, alignment, colors, states, and interaction so a later screenshot can be judged against a concrete target.

## Follow the system vision

Build a desktop that feels snappy and modern while remaining as visually polished as practical.

Prioritize in this order:

1. Correctness, portability, and recoverability.
2. Perceived latency, fast startup, and low idle CPU, memory, GPU, disk, and wakeup activity.
3. Complete daily-driver functionality.
4. Biscuit visual coherence, readable hierarchy, and restrained animation.

Apply these preferences:

- Prefer event-driven native components over polling loops. When polling is unavoidable, use one shared collector, an explicit interval, adaptive behavior where useful, and no hardware wakeups merely to draw idle UI.
- Prefer on-demand tools over permanent daemons when no background behavior is required.
- Prefer maintained, modern Rust implementations and forks when they offer equal or better feature coverage, Wayland integration, startup time, and resource behavior. Ironbar and Yazi are representative choices.
- Also accept focused C or C++ software when it is measurably leaner or more mature. Never assume a language alone proves performance.
- Avoid replacing a small component with a heavyweight desktop shell, web runtime, or broad framework unless the missing functionality clearly justifies the permanent cost.
- Favor attractive keyboard-first TUI applications in Foot for administration and focused workflows. Keep a GUI fallback when it materially improves discoverability, drag-and-drop, complex previews, or recovery.
- Reuse an already selected backend instead of starting competing applets or services. Prefer native integration with NetworkManager, BlueZ, PipeWire, UDisks, systemd, and Hyprland.
- Keep hot paths simple, cache expensive work, debounce bursty events, and avoid subprocess fan-out from frequently refreshed widgets.
- Centralize the Biscuit palette and semantic roles. Use pink for active focus, violet for information, green for healthy state, yellow/orange for attention, and red for urgent or destructive state unless the existing component defines a more specific mapping.
- Aim for balanced padding, centered icons, consistent field sizes, readable line height, clear contrast, and dense-but-not-cramped layouts. Use animation to communicate change, not as constant background work.
- Treat wallpapers as part of the system identity. Keep them dark, OLED-friendly, and consistent with Biscuit. Build each scene in layers: first use Seedream Pro with a short prompt to create a complete native `2560x1440` core; inspect it before every paid follow-up; then add one technical mechanism and at most two or three short labels per focused image-to-image edit. If generated lettering remains inaccurate, repair it deterministically during mastering instead of repainting the illustration. Finally use Seedream Lite to outpaint only the natural left-side environment to a native `5120x1440` master while preserving the accepted core. Derive 21:9 UWQHD `3440x1440` from the right side and retain the accepted Pro core for 16:9 WQHD `2560x1440`. Never stretch an axis or add padding. Keep prompts short enough that character, composition, OLED direction, technical story, crossover, typography, palette and negative constraints do not compete in one request. Do not describe percentage-based zones: models tend to turn those instructions into a visible diptych seam.
- Make 16:9, 21:9 and 32:9 three windows onto one continuous world. Foreground, midground and background must preserve perspective, material scale, terrain and architecture through the far-left edge. The same practical lights produce weaker bounced light, ambient occlusion and contact shadows in wider left-side scenery. Never fill width with a black veil, gradient mask, blur, vertical tonal boundary, repeated tile, pasted rectangle or giant occluding object.
- Use DevSecOps easter eggs only when they form one technically correct causal subflow inside the scene: an input, ordered processing, a success result and a meaningful failure or recovery path. Never squeeze an entire SDLC or platform into one image. Limit the visible story to four transitions, at most three major technical props, one tracked payload and two to five short physical labels; give every named tool its actual role. Main characters must visibly react to the incident and resolution instead of posing beside an ignored diagram. Good scopes include conflict/red test → short branch into `main` → canary feature flag → flag-off rollback, or HTTP → API Gateway/reverse proxy → application with cache/database → response. Never treat a logo or technology name as an easter egg by itself. Each wallpaper still gets exactly one small diegetic cross-world object. Text belongs only on real terminal panes, device labels, ports, contracts, books, cassettes or engravings. Floating words, unexplained numbers, arbitrary ports, logo walls, fake-code wallpaper and rebus-like labels are rejection conditions. Simplify the same flow before compromising the universe, composition or OLED quality.
- When the user points to real infrastructure documentation, inspect its non-secret README and configuration before assigning roles in wallpaper stories. Reflect the actual responsibility boundaries and never copy addresses, credentials, secret values or operationally identifying detail into prompts. A startpage such as Glance may provide links and simple status tiles but is not an observability pipeline; Prometheus/Grafana performs monitoring and correlation. Split a long real stack across multiple wallpapers when it cannot meet the visual-density budget—for example media acquisition (Overseerr → Sonarr/Radarr → Prowlarr → qBittorrent) and media playback (library → Bazarr → Plex → Tautulli).
- Give every wallpaper exactly one additional personal or cross-world easter egg in a different diegetic form: for example a secondary-monitor wallpaper, phone lockscreen, sticker, figurine, charm, sketch, hostname, backup label, reflection or tool engraving. It may reference another character or scene in the collection, but must remain visually subordinate to the hero metaphor and technically meaningful support layer. Track the planned form in `wallpapers/CONCEPTS.md` and record it in `INVENTORY.md` only after it is genuinely visible in an accepted image.
- Give each wallpaper an original narrative tied to engineering or security work. Document its filename, mood, technical metaphor, inspiration boundary, and scene role in `wallpapers/CONCEPTS.md`; record verified visible details separately from future high-resolution additions in `wallpapers/INVENTORY.md` whenever adding or replacing an image.
- Require every declared universe to be recognizable within seconds through its original character design, default wardrobe language, camera grammar, rendering, environment, gameplay systems and emotional tone. Preserve six distinct visual languages: six Frieren anime scenes (01–06), four *The Witcher 3* game-cinematic scenes (07–10), three authentic Palworld 3D anime-game scenes (11–13), three authentic V Rising stylized-isometric scenes (14–16), three authentic Valheim low-poly painterly scenes (17–19), and three Chainsaw Man anime/manga scenes (20–22). Never homogenize them into one generic anime, photoreal movie or concept-art style.
- Depict Frieren, Fern, Stark, Ciri, Yennefer, Geralt, Makima, Denji and Power as the actual canonical characters with their recognizable default wardrobe language and equipment, not lookalikes or provocative redesigns. Preserve game versions of the Witcher characters rather than television likenesses. Palworld scenes need a real Palbox, recognizable canonical Pals performing plausible work specializations and an overbuilt survival base. V Rising scenes need isometric domain construction, Castle Heart, blood essence, servants and coffins. Valheim scenes need low-poly painterly geometry, survival craft, weather and procedural landscape rather than a realistic Viking film.
- Avoid giant text, watermarks, large bright regions, generic neon-city clichés, copied characters, real credentials, plausible secrets, and UI-like detail that competes with active windows.
- For OLED, target roughly 35–50% genuinely emitted-off `#000000` pixels distributed through organic negative space, arch cavities, foliage gaps, deep water, unlit rooms and material occlusion across every aspect zone. Never satisfy this with one empty sky, pasted rectangle, gradient mask or crushed background plane. Build the transition out of black with physically coherent global illumination, soft ambient occlusion, contact shadows and material-aware bounced light so wider scenery retains depth on an OLED panel. Keep average picture level low with small Biscuit highlights and no broad white, gray, blue or neon surfaces.

Before proposing a replacement, compare maintenance, Nixpkgs availability, Wayland support, feature parity, startup behavior, resident idle cost, event model, theming, accessibility, and portability. Distinguish evidence from inference. Let the user run side-by-side tests and benchmarks before removing a proven fallback.

## Preserve portability

Design every change so the full configuration remains easy to clone for another device or account.

- Never introduce a new hard-coded `/home/<user>` path, username, host name, monitor name, GPU path, backlight device, or machine-specific identifier in shared modules.
- Derive the home directory from `username` or Home Manager configuration. Pass host facts through `specialArgs`, `extraSpecialArgs`, or explicit module options.
- Keep optional desktop integrations behind `desktopFeatures` or another explicit host capability.
- For a new user, either copy `home/<profile>/` to a new profile or set `homeProfile` in the host manifest to reuse an existing profile. Do not silently bind reusable code to `wojtek`.
- For a new machine, copy a host manifest as a starting point, generate a fresh `hardware-configuration.nix`, and select only the hardware modules that match that device.
- Treat `backlightDevice`, replay capture source, monitor layout, GPU modules, ASUS support, gaming, Docker, laptop widgets, and personal applications as host choices.
- Do not copy hardware configuration between machines.
- Do not change `system.stateVersion` or `home.stateVersion` as part of an ordinary upgrade.
- Do not edit `flake.lock` or refresh inputs unless the user explicitly requests an update.
- If the target architecture differs from the current flake's `x86_64-linux`, first make the system architecture a host parameter instead of adding another global hard-coded value.
- When derived wallpaper variants are present, select the 16:9, 21:9, or 32:9 collection from an explicit host display capability or reliable monitor-mode derivation; never hard-code one aspect family globally for every device.

When adding a host or account, follow `docs/new-host.md` and update it if the real process changes.

## Respect user-owned validation

Treat the following as a persistent project rule: the user runs every evaluation, build, test, activation, restart, and visual check. Do not run them unless the user explicitly revokes this rule in the current request.

Do not run:

- `nix eval`, `nix flake check`, `nix build`, `nix develop`, or `nix flake update`;
- `make check`, `make build`, `make test`, `make boot`, or `make switch`;
- `nixos-rebuild`, Home Manager activation, or a generated `switch-to-configuration`;
- system or user service restarts, reloads, starts, stops, or enables;
- GUI launchers, manual desktop tests, Ironbar restarts, or configuration activation;
- benchmarks or performance measurements.

Allow only read-only inspection and non-runtime hygiene such as `rg`, `sed`, `git status`, `git diff`, and `git diff --check`. Do not call a static check a successful system test.

## Hand off verification

Finish each implementation with:

1. A concise summary of changed behavior and important files.
2. An explicit statement that no build, evaluation, activation, or runtime test was run.
3. Exact commands the user may run, selected to match the risk:
   - `nix flake check path:.`
   - `nix build path:.#nixosConfigurations.<host>.config.system.build.toplevel --no-link`
   - `sudo nixos-rebuild test --flake path:.#<host>` for temporary activation
   - `sudo nixos-rebuild switch --flake path:.#<host>` only after the user accepts the tested result
4. A short manual checklist for the changed subsystem.

For visual desktop work, ask the user for a screenshot or concrete feedback after they activate it. Use that feedback for the next edit; never infer that a successful build proves the UI looks or behaves correctly.
