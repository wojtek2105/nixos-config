# Narzędzia sprzętowe

## Podgląd rejestratora USB-C

`usb-capture-viewer.sh` wybiera wejście V4L2 podłączone przez USB, preferując
urządzenia opisane jako HDMI/capture/grabber, i otwiera je w MPV z profilem
niskiego opóźnienia. Domyślnie żąda 1920×1080 przy 60 Hz. Wejście audio jest
automatycznie dobierane z tej samej fizycznej karty USB, więc launcher nie
wybierze mikrofonu laptopa.

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
