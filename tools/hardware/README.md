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
