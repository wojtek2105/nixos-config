# Narzędzia sprzętowe

## Podgląd rejestratora USB-C

`usb-capture-viewer.sh` wybiera wejście V4L2 podłączone przez USB, preferując
urządzenia opisane jako HDMI/capture/grabber, i otwiera je w MPV z profilem
niskiego opóźnienia. Domyślnie żąda 1920×1080 przy 60 Hz. Wejście audio jest
automatycznie dobierane z tej samej fizycznej karty USB, więc launcher nie
wybierze mikrofonu laptopa.

Po otwarciu obrazu terminal stale pokazuje FPS zgłaszany przez rejestrator
(`input`), FPS dekodowany przez MPV (`decoded`) i odświeżanie ekranu
(`display`). Jeżeli bezpośrednio uruchomiony skrypt nie ma jeszcze `v4l2-ctl`,
przekazuje żądane 1080p60 i MJPEG bezpośrednio do MPV/FFmpeg zamiast
pozostawiać karcie wolniejszy format domyślny.

Te same wartości są stale widoczne w prawym górnym rogu obrazu MPV. `DROP`
pokazuje liczbę klatek zgubionych przez dekoder i wyjście wideo. Klawisz `o`
przełącza poziom OSD i pozwala ukryć lub ponownie pokazać nakładkę.

Po aktywacji konfiguracji Home Manager skrypt jest dostępny w `PATH` jako:

```bash
usb-capture-viewer
```

Można go też uruchomić bezpośrednio z repozytorium:

```bash
tools/hardware/usb-capture-viewer.sh
```

Wymuszenie urządzenia lub trybu:

```bash
CAPTURE_DEVICE=/dev/video2 usb-capture-viewer
CAPTURE_RESOLUTION=3840x2160 CAPTURE_FPS=30 usb-capture-viewer
CAPTURE_PIXEL_FORMAT=mjpeg CAPTURE_FPS=60 usb-capture-viewer
```

Surowy YUY2 z używanej karty nie przekazuje wiarygodnej informacji o zakresie
kolorów. Launcher dlatego domyślnie interpretuje obraz jako `full` (0–255) w
Rec.709 — zapobiega to zbyt ciemnym czerniom i cieniom. Jeżeli inne źródło
wygląda wyprane (szare czernie), przełącz wyłącznie zakres:

```bash
CAPTURE_COLOR_LEVELS=limited usb-capture-viewer
```

Do diagnostyki można też użyć `CAPTURE_COLOR_LEVELS=auto`; standardowe wartości
to `auto`, `limited` i `full`. `CAPTURE_COLOR_MATRIX` domyślnie ma wartość
`bt.709`, właściwą dla 1080p HD.

Argument ścieżki ma pierwszeństwo przed zmienną środowiskową, np.
`usb-capture-viewer /dev/video4`. Automatyczny dźwięk można wyłączyć albo
zastąpić ręcznym wejściem ALSA:

```bash
CAPTURE_AUDIO=0 usb-capture-viewer
CAPTURE_AUDIO_DEVICE=hw:3,0 usb-capture-viewer
CAPTURE_AUDIO_DELAY=-0.10 usb-capture-viewer
```

`CAPTURE_AUDIO_DELAY` pozwala skorygować synchronizację: wartość dodatnia
opóźnia dźwięk, a ujemna opóźnia obraz względem dźwięku.

## Gotowe presety

Skrypty uruchamiane bezpośrednio z `tools/hardware/` zachowują przekazane
zmienne środowiskowe, więc każdy parametr można jednorazowo nadpisać.

| Skrypt | Zastosowanie | Tryb |
| --- | --- | --- |
| `usb-capture-game-quality.sh` | gry PC, priorytet jakości | 1080p60, YUY2, Rec.709 Full |
| `usb-capture-game-16x10.sh` | ekran 16:10 bez rozciągania | 1080p60, YUY2, centralny kadr 1728×1080 |
| `usb-capture-game-low-bandwidth.sh` | gdy surowe YUY2 obciąża magistralę USB | 1080p60, MJPEG, Rec.709 Full |
| `usb-capture-console-limited.sh` | konsola ustawiona na HDMI Limited | 1080p60, YUY2, Rec.709 Limited |
| `usb-capture-4k30-quality.sh` | gry SDR w 4K | 2160p30, MJPEG, Rec.709 Full |

Przykład:

```bash
tools/hardware/usb-capture-game-quality.sh
```

Presety dotyczą SDR. Przed użyciem `usb-capture-4k30-quality.sh` wyłącz HDR w
źródle — karta oraz podgląd nie wykonują mapowania tonów HDR.

`usb-capture-game-16x10.sh` nie zmienia trybu karty: odbiera pełne 1080p16:9 i
wycina symetrycznie 96 px po obu bokach. Zachowuje proporcje gry i wypełnia
ekran 16:10; elementy przy samych krawędziach źródła nie będą widoczne.
