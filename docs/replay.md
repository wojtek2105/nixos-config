# Replay

GPU Screen Recorder UI zapewnia pełnoekranową nakładkę podobną do ShadowPlay.
Nakładka nie zajmuje pamięci po zalogowaniu: pierwszy skrót uruchamia ją ukrytą,
czeka na gotowość i dopiero wykonuje wybraną akcję. Bufor jest domyślnie
wyłączony i nie koduje obrazu, dopóki użytkownik go nie uruchomi.

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
- źródło obrazu `focused_monitor`, wybierające monitor aktywny przy starcie bufora,
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

- pakiet: `modules/screen-recording.nix`,
- profil laptopa: `hosts/rog-polamaniec/configuration.nix`,
- kontroler uruchamiania na żądanie: `gsr-control` w `home/wojtek/default.nix`,
- skróty: `home/wojtek/hyprland.nix`,
- konfiguracja nakładki: `home/wojtek/default.nix`.

Plik `~/.config/gpu-screen-recorder/config_ui` jest generowany przez Home Manager.
Oficjalne globalne skróty UI są wyłączone, aby nakładka nie przechwytywała całej
klawiatury i nie kolidowała ze zrzutami ekranu Hyprlanda. Te same akcje wywołuje
Hyprland przez `gsr-control`, który po uruchomieniu UI deleguje je do
`gsr-ui-cli`. Blokada w katalogu runtime zapobiega uruchomieniu dwóch nakładek,
gdy kilka skrótów zostanie użytych podczas zimnego startu.

Sama nakładka działa przez XWayland i upstream ostrzega, że nie wszystkie jej
elementy są idealnie obsługiwane na Waylandzie. Nie oznacza to braku obsługi
nagrywania: silnik GSR przechwytuje monitor bezpośrednio i sprzętowo koduje obraz.
Jednorazowe ostrzeżenie Wayland jest oznaczone jako przeczytane deklaratywnie.

Nakładka jest jedynym kontrolerem nagrywania — nie działa obok niej druga usługa
GPU Screen Recordera.
