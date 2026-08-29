# Dokumentacja konfiguracji

Ten katalog opisuje stan konfiguracji, sposób jej obsługi oraz plan rozbudowy.

## Spis treści

- [Architektura](architecture.md) — struktura flake, moduły i przepływ opcji.
- [Obsługa systemu](operations.md) — sprawdzanie, budowanie, aktywacja i diagnostyka.
- [Pulpit](desktop.md) — Hyprland, aplikacje, dark mode i usługi sesji.
- [Granie i GameMode](gaming.md) — ustawienie opcji uruchamiania Steam,
  weryfikacja GameMode oraz wariant z Gamescope.
- [Quest 2 i PCVR](vr.md) — ALVR, SteamVR i przewodowe połączenie przez USB-C.
- [Benchmarki](benchmarks.md) — historyczne wyniki pulpitu oraz powtarzalne
  porównanie EEVDF, bpfland, LAVD i Flash dla CPU, z opcjonalną diagnostyką GPU.
- [Wyniki benchmarków](benchmark-results/README.md) — katalog raportów Markdown,
  CSV, metadanych i pełnych logów z kolejnych sesji.
- [Skróty klawiszowe](keybindings.md) — kompletna mapa skrótów.
- [Deskflow](deskflow.md) — współdzielenie klawiatury i myszy z White Monster
  bez przesyłania obrazu.
- [Replay](replay.md) — konfiguracja bufora GPU Screen Recorder.
- [Host](hosts.md) — konfiguracja laptopa ROG.
- [Nowy host i użytkownik](new-host.md) — kompletna instrukcja kopiowania,
  adaptacji sprzętu, profilu Home Managera i instalacji.
- [Plan rozbudowy](roadmap.md) — kolejne etapy rozwoju konfiguracji.
- [Źródła](sources.md) — upstreamy i dokumentacja techniczna.

Dokumentacja opisuje konfigurację deklaratywną z plików Nix oraz śledzonego
`home/wojtek/hyprland.lua`. Ręczne zmiany w `~/.config` mogą zostać nadpisane
przez Home Manager i nie powinny być traktowane jako źródło prawdy.
