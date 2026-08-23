# Replay

GPU Screen Recorder UI zapewnia pełnoekranową nakładkę podobną do ShadowPlay.
Nakładka startuje ukryta razem z Hyprlandem. Bufor jest domyślnie wyłączony i nie
koduje obrazu, dopóki użytkownik go nie uruchomi.

## Sterowanie

| Skrót | Akcja |
| --- | --- |
| `Alt+Z` | Pokaż lub ukryj oficjalną nakładkę |
| `Super+G` | Alternatywny skrót nakładki |
| `Super+Shift+R` | Włącz lub wyłącz bufor |
| `Super+R` | Zapisz ostatnie 120 sekund |

Proces nakładki można sprawdzić poleceniami:

```bash
pgrep -a gsr-ui
gsr-ui-cli --help
```

## Profil laptopa

- natywna rozdzielczość ekranu `2560x1600`,
- źródło obrazu `eDP-2`, zgodne z nazwą matrycy zgłaszaną przez GSR,
- 60 FPS,
- bufor 120 sekund w RAM,
- HEVC/H.265,
- CBR 25 Mb/s,
- kontener MP4,
- kodek audio Opus.

Dwuminutowy bufor zajmuje około 385 MB RAM. HEVC 25 Mb/s jest dobrany do
dynamicznych gier w natywnej rozdzielczości laptopa.

## Audio

Klip zawiera trzy ścieżki w tej kolejności:

1. miks dźwięku systemowego i mikrofonu,
2. sam dźwięk systemowy,
3. sam mikrofon.

Pliki są zapisywane w `~/Videos/Replays`.

## Implementacja deklaratywna

- pakiet: `modules/gaming.nix`,
- profil laptopa: `hosts/laptop/configuration.nix`,
- autostart i skróty: `home/wojtek/hyprland.nix`,
- konfiguracja nakładki: `home/wojtek/default.nix`.

Plik `~/.config/gpu-screen-recorder/config_ui` jest generowany przez Home Manager.
Oficjalne globalne skróty UI są wyłączone, aby nakładka nie przechwytywała całej
klawiatury i nie kolidowała ze zrzutami ekranu Hyprlanda. Te same akcje wywołuje
Hyprland przez `gsr-ui-cli`.

Sama nakładka działa przez XWayland i upstream ostrzega, że nie wszystkie jej
elementy są idealnie obsługiwane na Waylandzie. Nie oznacza to braku obsługi
nagrywania: silnik GSR przechwytuje monitor bezpośrednio i sprzętowo koduje obraz.
Jednorazowe ostrzeżenie Wayland jest oznaczone jako przeczytane deklaratywnie.

Nakładka jest jedynym kontrolerem nagrywania — nie działa obok niej druga usługa
GPU Screen Recordera.
