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
# Test kontrolny jest domyślnie BF16 i trafia do oddzielnego stagingu.
tools/wallpapers/upscale/run-nomos-9070xt.sh test 01-frieren
# Dowolny obraz, także 16:9, podaj pełną ścieżką; oryginał jest montowany tylko do odczytu.
tools/wallpapers/upscale/run-nomos-9070xt.sh file /pełna/ścieżka/do/tapety-16x9.png
# FP32: uruchomi się tylko przy co najmniej 14 GiB wolnego VRAM; zaczyna od tile 256.
tools/wallpapers/upscale/run-nomos-9070xt.sh file-fp32 /pełna/ścieżka/do/tapety-16x9.png
# Po czystym teście BF16 dla wybranej listy; każdy wynik zostaje w stagingu.
tools/wallpapers/upscale/run-nomos-9070xt.sh slugs 01-frieren 02-frieren
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
twarzy. Nomos czyta master z `work/import-48/masters/`, przed końcową korektą
czerni dla 44 scen; cztery historyczne mastery bez surowego źródła są
zachowanym fallbackiem po tej korekcie. Dla pozostałych scen korekta czerni
jest stosowana dopiero przy promocji wyniku.
Profil nie zmienia kadru. Wyniki trafiają do
`work/import-48/upscaled-32x9-nomos8kdat/`; aktywna kolekcja nie jest zmieniana
przez `test` ani `run`. Przy OOM profil automatycznie ponawia bieżącą tapetę z
kaflami 512, 448, 384, a następnie 320. Mechanizm można wyłączyć przez
`NOMOS_AUTO_TILE=0`; siłę efektu reguluje `NOMOS_BLEND` od 0 do 1. DAT nie deklaruje bezpiecznego FP16, dlatego
profil 6800S używa domyślnie BF16; zgodnościowy, wolniejszy fallback to
`NOMOS_DTYPE=float32`. Profil RX 9070 XT używa domyślnie BF16 we wszystkich
trybach: model w FP32 potrzebuje około 11 GiB VRAM jeszcze przed aktywacjami,
więc na 16 GiB nie zostawia bezpiecznego miejsca na inferencję. BF16 jest
bezpiecznym formatem tego checkpointu i nie zmienia zauważalnie jakości obrazu.
FP32 można wymusić wyłącznie przy dużym zapasie wolnego VRAM przez
`NOMOS_DTYPE=float32`.

Tryb `file-fp32 /pełna/ścieżka.png` jest gotowym profilem najwyższej precyzji:
używa `NOMOS_DTYPE=float32` i bezpiecznego `NOMOS_TILE=256`. Przed załadowaniem
modelu sprawdza co najmniej 14 GiB wolnego VRAM i kończy się jasnym komunikatem,
zamiast wpadać w OOM. Wynik trafia do oddzielnego stagingu `fp32-file`.

Na RX 9070 XT domyślny `NOMOS_TILE=512` zostawia miejsce na wagi modelu i
aktywacje 4×; większe 832 może próbować zaalokować ponad 8 GiB na jeden kafel.
Jeśli 512 nadal zgłosi OOM, runner automatycznie ponowi plik z 448, 384 i 320.

Każdy tensor zwrócony przez Nomos jest sprawdzany pod kątem `NaN` i `Inf`
zanim zostanie przekonwertowany do PNG. Błąd przerywa tylko daną tapetę,
zapisuje współrzędne kafla w logu i nie tworzy wyniku stagingowego ani nie
dotyka aktywnej kolekcji. Nie należy maskować błędu przez `nan_to_num`, bo
ukryłoby to artefakt jako czarne albo białe piksele.

Gdy szerokość lub wysokość nie dzieli się przez `NOMOS_TILE`, runner odbija
obraz tylko w roboczym buforze do pełnej siatki kafli. Dodaje też odbite halo
na wszystkich czterech brzegach: każdy kafel, również lewy-górny narożnik,
dostaje identyczny kontekst 32 px. Nomos nie dostaje wtedy wąskiego ani
pozbawionego kontekstu kafla brzegowego podatnego na artefakty, a gotowy obraz
jest przycinany dokładnie do pierwotnego wymiaru.

ROCm może zwrócić wizualnie uszkodzony, lecz liczbowo skończony pierwszy wynik
Nomos po zimnym starcie. Domyślne `NOMOS_WARMUP=1` wykonuje i odrzuca dokładnie
taki pierwszy kafel przed właściwym renderem; nie miesza ani nie zachowuje
oryginału. Ustaw `NOMOS_WARMUP=0` tylko do diagnostyki.

Tryb `file /pełna/ścieżka.png` działa także dla 16:9 i innych proporcji. Zachowuje
docelowe `2560×1440`: bez rozciągania skaluje do wysokości 1440 i odcina nadmiar
wyłącznie z lewej strony, więc kompozycja po prawej zostaje nienaruszona. Wynik
zapisuje wyłącznie do
`work/import-48/upscaled-32x9-nomos8kdat-bf16-file/external/`, z hashem źródła
w nazwie. Nie wymaga wpisu w `collection.json` i montuje katalog wejściowy do
kontenera tylko do odczytu. `NOMOS_FILE_TARGET_WIDTH` i
`NOMOS_FILE_TARGET_HEIGHT` pozwalają jawnie zmienić docelowy format; źródło
węższe niż wybrana proporcja zostanie odrzucone zamiast rozciągnięte.

Domyślnie `NOMOS_BLACK_PRESERVE_THRESHOLD=0`: piksele, które w źródle są
dokładnie `#000000`, są po rekonstrukcji, blendzie i wyostrzeniu ponownie
zapisywane jako `#000000`. Dzięki temu duże naturalne obszary OLED-off przechodzą
przez Nomos bez podniesienia czerni. Wartość 1–255 rozszerza ochronę na near-black,
ale może utworzyć zbyt twardą granicę, więc pozostaw bezpieczne domyślne `0`.

Dla niezależnego porównania z Numosem AnimeSharp działa przez NCNN/Vulkan
z osobnym stagingiem. Na RX 9070 XT przetworzysz tę samą listę jednym
workerem:

```bash
tools/wallpapers/upscale/run-9070xt.sh slugs 01-frieren 02-frieren
```

`run-9070xt.sh` nie zmienia aktywnej kolekcji; `promote` pozostaje ręcznym
krokiem dopiero po obejrzeniu odpowiedniego stagingu.

Pełną kolekcję można wykonać przez trzy noce, po 16 pozycji. Gotowe wyniki są
pomijane, więc przerwany batch można wznowić tym samym poleceniem:

```bash
tools/wallpapers/upscale/run-nomos-6800s.sh batch 1
tools/wallpapers/upscale/run-nomos-6800s.sh batch 2
tools/wallpapers/upscale/run-nomos-6800s.sh batch 3
```

## Katalogi danych

- `home/base/wallpapers/raw/16x9/` — materiały źródłowe; JPEG-i są
  wersjonowane jako wejście do upscale'u i outpaintu 32:9, a pozostałe formaty
  RAW pozostają lokalne.
- `home/base/wallpapers/work/import-48/masters/` — mastery przed finalizacją.
- `home/base/wallpapers/work/import-48/accepted/` — decyzje QA i offsety.
- `home/base/wallpapers/work/import-48/upscale-logs/` — logi lokalnego SR.
- `home/base/wallpapers/{16x9,21x9,32x9}/` — aktywna kolekcja używana przez
  konfigurację pulpitu.

Modele i środowiska uruchomieniowe nie trafiają do Git. Instalatory zapisują je
pod `${XDG_DATA_HOME:-$HOME/.local/share}`; katalog `work/` pozostaje stagingiem
i miejscem backupów.
