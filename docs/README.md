# Dokumentacja konfiguracji

Ten katalog opisuje stan konfiguracji, sposób jej obsługi oraz plan rozbudowy.

## Spis treści

- [Architektura](architecture.md) — struktura flake, moduły i przepływ opcji.
- [Obsługa systemu](operations.md) — sprawdzanie, budowanie, aktywacja i diagnostyka.
- [Pulpit](desktop.md) — Hyprland, aplikacje, dark mode i usługi sesji.
- [Skróty klawiszowe](keybindings.md) — kompletna mapa skrótów.
- [Replay](replay.md) — konfiguracja bufora GPU Screen Recorder.
- [Hosty](hosts.md) — laptop oraz dodawanie osobnego PC.
- [Plan rozbudowy](roadmap.md) — kolejne etapy rozwoju konfiguracji.
- [Źródła](sources.md) — upstreamy i dokumentacja techniczna.

Dokumentacja opisuje konfigurację deklaratywną z plików Nix oraz śledzonego
`home/wojtek/hyprland.lua`. Ręczne zmiany w `~/.config` mogą zostać nadpisane
przez Home Manager i nie powinny być traktowane jako źródło prawdy.
