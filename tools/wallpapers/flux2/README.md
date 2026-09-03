# FLUX.2 Klein — test na RX 6800S

Ten pipeline generuje pojedynczego kandydata i nigdy nie podmienia aktywnych
tapet. Używa oficjalnego obrazu AMD ROCm 7.2.4 oraz FLUX.2 Klein 4B z
sekwencyjnym offloadem do 32 GiB RAM. Runner odnajduje RX 6800S po adresie PCI
`0000:03:00.0`, zamiast zakładać numer `renderD*`. Zmienne `FLUX2_GPU_PCI` i
`FLUX2_RENDER_NODE` pozwalają jawnie zmienić wybór. Ustawienie
`HSA_OVERRIDE_GFX_VERSION=10.3.0` jest eksperymentalnym obejściem gfx1031, a nie
gwarancją obsługi tej karty przez ROCm.
Kontener dostaje całe `/dev/dri`, ponieważ KFD potrzebuje pełnej topologii DRM;
`ROCR_VISIBLE_DEVICES=0` i `HIP_VISIBLE_DEVICES=0` ograniczają obliczenia do
pierwszego agenta ROCm. `gpu-info` musi potwierdzić, że jest nim RX 6800S, zanim
zostanie pobrany checkpoint modelu.

## Instalacja

Model ma otwarte wagi na licencji Apache-2.0. `HF_TOKEN` nie jest wymagany;
opcjonalny token tylko do odczytu może ograniczyć throttling pobierania. Docker
jest w tej konfiguracji uruchamiany ręcznie.

```bash
sudo systemctl start docker
tools/wallpapers/flux2/install.sh
tools/wallpapers/flux2/run-6800s.sh gpu-info
tools/wallpapers/flux2/run-6800s.sh run
tools/wallpapers/flux2/run-6800s.sh status
```

Instalator tworzy overlay Pythona bez pakietów `torch`, `triton` i `nvidia-*`.
PyTorch pochodzi wyłącznie z obrazu AMD ROCm. Każda instalacja powstaje najpierw
w katalogu `python.next`, przechodzi test `torch.version.hip`, a dopiero potem
atomowo zastępuje poprzedni overlay. Ponowne uruchomienie instalatora naprawia
również wcześniejsze środowisko z omyłkowo pobranym PyTorch CUDA i usuwa te
zbędne koła po udanej weryfikacji.

Pierwszy przebieg pobiera model do
`${XDG_DATA_HOME:-$HOME/.local/share}/wallpaper-flux2-klein/hf-cache`. Wynik
domyślny to
`home/base/wallpapers/work/import-48/flux2-klein-tests/01-frieren-klein4b.png`.

Oficjalna karta modelu podaje około 13 GiB VRAM, dlatego 8-gigabajtowy RX 6800S
jest profilem eksperymentalnym nawet z offloadem. Domyślne 1024×288 zachowuje
dokładne 32:9 i ogranicza aktywacje do około 0,29 MP. Profil gfx1030 używa FP16;
BF16 pozostaje opcją dla nowszego GPU przez `FLUX2_DTYPE=bfloat16`. Po zaakceptowaniu wynik
można skalować do 5120×1440. Test 2560×720 uruchamiaj dopiero po udanym małym
przebiegu:

```bash
FLUX2_WIDTH=2560 FLUX2_HEIGHT=720 tools/wallpapers/flux2/run-6800s.sh run
```

Jeśli wystąpi OOM, nie zwiększaj rozdzielczości; ten model jest docelowo lepiej
dopasowany do 16 GiB VRAM w White Monsterze. Zmienne `FLUX2_WIDTH`,
`FLUX2_HEIGHT`, `FLUX2_STEPS`, `FLUX2_SEED` i `FLUX2_PROMPT_FILE` pozwalają
wykonać kontrolowane warianty. `FLUX2_OVERWRITE=1` jest wymagane do świadomego
zastąpienia istniejącego kandydata.

`Ctrl+C` zatrzymuje kontener o unikalnej nazwie, więc proces ROCm nie pozostaje
w tle ani nie może zostać pomylony z równoległym testem.
Niepełny plik `.part` jest wtedy usuwany, a gotowy PNG pojawia się atomowo
dopiero po pełnym zapisie.
Instalator przypina sprawdzony commit Diffusers, zamiast pobierać zmienny `main`.
Pozostałe biblioteki są izolowane w katalogu runtime. Instalator i test pobierają duże dane; katalog środowiska można później usunąć
niezależnie od repozytorium.
