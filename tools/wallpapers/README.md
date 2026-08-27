# Narzędzia kolekcji tapet

Skrypty uruchamia się z katalogu głównego repozytorium. Wszystkie ścieżki
robocze są wyliczane względem repozytorium, więc żaden etap nie zależy od
bieżącego katalogu powłoki.

## Układ

- `generation/` — generowanie i edycja obrazów przez zewnętrzne API.
- `processing/` — import, QA kadru, mastering, finalizacja i audyt kolekcji.
- `upscale/` — lokalne modele SR, profile GPU oraz staging.
- `flux2/` — lokalne testy generatywnej rekonstrukcji FLUX.2; wyniki nie są
  automatycznie promowane do kolekcji.

## Przepływ kolekcji

```text
RAW / źródło 16:9
        |
        v
generation/seedream-edit.sh
        |
        v
work/import-48/masters (master 32:9)
        |
        v
processing/review-master.sh
        |
        v
work/import-48/accepted (offsety cropów)
        |
        v
processing/finalize-queue.sh
        |
        +--> wallpapers/32x9
        +--> wallpapers/21x9
        +--> wallpapers/16x9
```

`processing/audit-collection.sh` jest tylko kontrolą kolekcji. Finalizacja i
`upscale/collection.sh promote` zapisują pliki aktywne, dlatego należy ich użyć
dopiero po obejrzeniu stagingu.

## Najczęstsze polecenia

```bash
# Stan importu i kontrola 48 pozycji
tools/wallpapers/processing/import-collection.sh status
tools/wallpapers/processing/audit-collection.sh

# Podglądy kandydatów kadru i zapis zaakceptowanych offsetów
tools/wallpapers/processing/preview-crops.sh SLUG
tools/wallpapers/processing/review-master.sh accept SLUG CROP_16_X CROP_21_X

# Finalizacja zaakceptowanej kolejki — zapisuje aktywne formaty
tools/wallpapers/processing/finalize-queue.sh

# Stary, niegeneratywny upscale AnimeSharp na RX 6800S
tools/wallpapers/upscale/install-animesharp-ncnn.sh
REALESRGAN_TILE=96 tools/wallpapers/upscale/run-6800s.sh run
tools/wallpapers/upscale/run-6800s.sh status

# Zachowawczy 4xNomos8kDAT na RX 6800S: najpierw jedna tapeta
tools/wallpapers/upscale/install-nomos8kdat-rocm.sh
tools/wallpapers/upscale/run-nomos-6800s.sh test 01-frieren
tools/wallpapers/upscale/run-nomos-6800s.sh test 02-frieren

# Dopiero po obejrzeniu testów cała kolekcja; model ładuje się jeden raz
tools/wallpapers/upscale/run-nomos-6800s.sh run
tools/wallpapers/upscale/run-nomos-6800s.sh status

# Ten sam pełny Nomos na RX 9070 XT 16 GiB; wspólny instalator/model
tools/wallpapers/upscale/install-nomos8kdat-rocm.sh
tools/wallpapers/upscale/run-nomos-9070xt.sh test 01-frieren
tools/wallpapers/upscale/run-nomos-9070xt.sh batch 1
tools/wallpapers/upscale/run-nomos-9070xt.sh batch 2
tools/wallpapers/upscale/run-nomos-9070xt.sh batch 3

# Generatywny test naprawy detali; instrukcja w flux2/README.md
tools/wallpapers/flux2/install.sh
tools/wallpapers/flux2/run-6800s.sh gpu-info
tools/wallpapers/flux2/run-6800s.sh run
```

AnimeSharp poprawia ostrość linii, ale nie naprawia źle narysowanych oczu.
Jego wynik trafia do `work/import-48/upscaled-32x9-animesharp/`. Polecenie
`promote` jest celowo oddzielne i nie powinno być wykonywane bez porównania
wyników. `Ctrl+C` w launcherze kończy całe drzewo procesów danego przebiegu.

Nomos8kDAT jest lokalnym, niepromptowanym modelem 4× super-resolution. Profil
6800S przetwarza obraz kafelkami, skaluje rezultat z powrotem do dokładnie
5120×1440 i domyślnie miesza 65% rekonstrukcji z 35% oryginału. Domyślny profil
max-quality podaje cały master 5120×1440 do Nomos, wykonuje pełne 4× do
20480×5760, a dopiero potem skaluje do celu i miesza wynik z oryginałem. Kafel
512 ma 32-pikselowe halo; łagodne końcowe wyostrzenie ogranicza artefakty
twarzy. Nomos zawsze czyta surowy master z `work/import-48/masters/`, przed
końcową korektą czerni; ta korekta jest stosowana dopiero przy promocji wyniku.
Profil nie zmienia kadru. Wyniki trafiają do
`work/import-48/upscaled-32x9-nomos8kdat/`; aktywna kolekcja nie jest zmieniana
przez `test` ani `run`. Przy OOM profil automatycznie ponawia bieżącą tapetę z
kaflami 512, 448, 384, a następnie 320. Mechanizm można wyłączyć przez
`NOMOS_AUTO_TILE=0`; siłę efektu reguluje `NOMOS_BLEND` od 0 do 1. DAT nie deklaruje bezpiecznego FP16, dlatego
profil 6800S używa domyślnie BF16; zgodnościowy, wolniejszy fallback to
`NOMOS_DTYPE=float32`.

Pełną kolekcję można wykonać przez trzy noce, po 16 pozycji. Gotowe wyniki są
pomijane, więc przerwany batch można wznowić tym samym poleceniem:

```bash
tools/wallpapers/upscale/run-nomos-6800s.sh batch 1
tools/wallpapers/upscale/run-nomos-6800s.sh batch 2
tools/wallpapers/upscale/run-nomos-6800s.sh batch 3
```

## Katalogi danych

- `home/wojtek/wallpapers/raw/` — materiały źródłowe.
- `home/wojtek/wallpapers/work/import-48/masters/` — mastery przed finalizacją.
- `home/wojtek/wallpapers/work/import-48/accepted/` — decyzje QA i offsety.
- `home/wojtek/wallpapers/work/import-48/upscale-logs/` — logi lokalnego SR.
- `home/wojtek/wallpapers/{16x9,21x9,32x9}/` — aktywna kolekcja używana przez
  konfigurację pulpitu.

Modele i środowiska uruchomieniowe nie trafiają do Git. Instalatory zapisują je
pod `${XDG_DATA_HOME:-$HOME/.local/share}`; katalog `work/` pozostaje stagingiem
i miejscem backupów.
