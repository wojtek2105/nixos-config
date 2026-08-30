# Tapety Biscuit OLED

Zaakceptowane obrazy znajdują się wyłącznie pod katalogami `16x9/`, `21x9/`
i `32x9/`. Skanowanie jest rekurencyjne, a kolejność rotacji wynika z nazw
plików z pominięciem nazw podkatalogów. Dzięki temu warianty można grupować
według uniwersum bez rozjechania wspólnego indeksu scen między proporcjami.
Kolekcja `16x9/` używa podkatalogów `frieren/`, `chainsaw-man/`,
`solo-leveling/`, `valheim/`, `vrising/`, `palworld/` i `demon-slayer/`.
Zawartość katalogów proporcji jest archiwum wynikowym: porządki w zapleczu nie
mogą usuwać, zmieniać nazw ani nadpisywać tych plików. Czarne obrazy w
`fallback/` zapewniają bezpieczny stan konfiguracji.

Surowe obrazy wejściowe są oddzielone od wyników w `raw/16x9/`. Oryginalne
pliki `.jpg` i `.jpeg` w tym katalogu są wersjonowane jako wejście do upscale'u
i późniejszego outpaintu 32:9; pozostałe formaty RAW pozostają lokalne.
Importowana seria jest opisana przez `collection.json`; katalog
`work/import-48/` zawiera wyłącznie odtwarzalne mastery, znaczniki etapów i
robocze kopie. Surowy master 32:9 spoza kolekcji znajduje się w `raw/32x9/` i
nie trafia do rotacji ani do Git.

Ostatnia seria obejmuje 18 nowych scen: po trzy z `Frieren`, `Chainsaw Man`,
`Solo Leveling`, `Valheim`, `V Rising` i `Palworld`. Storyboard znajduje się
w [CONCEPTS.md](CONCEPTS.md), stan w [INVENTORY.md](INVENTORY.md), a komplet
36 promptów w `prompts/final-18/`.

## Archiwalny pipeline scen 18 (Pro → Lite)

Każda scena zużywa dokładnie dwa prompty i dwa wywołania modelu:

1. `*.pro.txt` tworzy kompletny rdzeń `2560×1440`. Domyślnie używamy Seedream
   5.0 Pro. Jeżeli filtr odrzuci prompt, uruchamiamy bez zmian ten sam plik
   w Seedream 5.0 Lite, nadal w `2560×1440`.
2. Po ręcznej akceptacji rdzenia `*.lite.txt` rozszerza obraz wyłącznie w lewo
   do `5120×1440`, zachowując zaakceptowany rdzeń po prawej.
3. Dla każdego mastera zapisujemy osobne poziome przesunięcie kadru 16:9 i
   21:9. Dzięki temu postać, twarz i główny punkt sceny nie są ślepo cięte
   według jednej geometrii dla całej kolekcji.
4. `tools/wallpapers/processing/finalize-imported.sh` tworzy z mastera wybrany kadr 16:9
   `2560×1440`, wybrany kadr 21:9 `3440×1440` i pełne 32:9 `5120×1440`.

Rdzeń Pro:

```bash
env SEEDREAM_MODEL=dola-seedream-5-0-pro-260628 \
  SEEDREAM_WALLPAPER_SIZE=2560x1440 \
  ./tools/wallpapers/generation/seedream-generate.sh \
  home/wojtek/wallpapers/prompts/final-18/01-frieren-grimoire-vault.pro.txt \
  /tmp/01-frieren-grimoire-vault-core.png
```

Fallback Lite po odrzuceniu przez filtr zmienia tylko model:

```bash
env SEEDREAM_MODEL=seedream-5-0-lite-260128 \
  SEEDREAM_WALLPAPER_SIZE=2560x1440 \
  ./tools/wallpapers/generation/seedream-generate.sh \
  home/wojtek/wallpapers/prompts/final-18/01-frieren-grimoire-vault.pro.txt \
  /tmp/01-frieren-grimoire-vault-core-lite.png
```

Outpaint zaakceptowanego rdzenia:

```bash
env SEEDREAM_MODEL=seedream-5-0-lite-260128 \
  SEEDREAM_WALLPAPER_SIZE=5120x1440 \
  ./tools/wallpapers/generation/seedream-edit.sh \
  /tmp/01-frieren-grimoire-vault-core.png \
  home/wojtek/wallpapers/prompts/final-18/01-frieren-grimoire-vault.lite.txt \
  /tmp/01-frieren-grimoire-vault-master.png
```

## Import kolekcji 48 RAW-ów (aktywny pipeline)

`collection.json` zawiera 48 kanonicznych scen. Źródła wejściowe są w
`raw/16x9/`, mastery w `work/import-48/masters/`, a znaczniki etapów w
`generated/`, `accepted/` i `finalized/`. Potok uruchamia się kolejno:

```bash
bash tools/wallpapers/processing/import-collection.sh generate
bash tools/wallpapers/processing/review-master.sh accept SLUG CROP_16_X CROP_21_X
bash tools/wallpapers/processing/finalize-queue.sh
```

Worker generatora pracuje scenami po kolei i zapisuje tylko mastery oraz
znaczniki w `work/import-48/`; nie nadpisuje gotowych pozycji. Worker QA
porównuje master z RAW-em, zapisując plan `accepted/SLUG.json` z osobnym
`crop16X` i `crop21X`. Worker crop/mastering bierze zatwierdzony plan i zapisuje
trzy finalne warianty w katalogach `16x9/`, `21x9/` i `32x9/`. Końcowy worker
audytu sprawdza komplet 48 nazw i wymiary:

```bash
bash tools/wallpapers/processing/audit-collection.sh
```

## Lokalny upscale 32:9

Do nocnego przebiegu służy `tools/wallpapers/upscale/collection.sh`. Skrypt
przetwarza istniejące mastery `32x9/` w skali 4× zgodnej z modelem
`realesrgan-x4plus-anime` (NCNN-owa wersja checkpointu
`RealESRGAN_x4plus_anime_6B`, dla ilustracji), a następnie zmniejsza wynik
Lanczosem do `5120×1440`. Wyniki pośrednie zapisuje w
`work/import-48/upscaled-32x9/`; tryb `promote` tworzy kopię zapasową w
`pre-upscale-32x9/` i dopiero wtedy odświeża rotowane pliki oraz cropy.

Oficjalny pakiet `realesrgan-ncnn-vulkan` zawiera binarkę i modele dla Linuxa.
Na NixOS podaj ścieżki jawnie (binarka jest uruchamiana przez systemowy loader):

```bash
mkdir -p "$HOME/.local/share/realesrgan-ncnn-vulkan"
curl -L --fail \
  -o /tmp/realesrgan-ncnn-vulkan.zip \
  https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip
unzip -o /tmp/realesrgan-ncnn-vulkan.zip \
  -d "$HOME/.local/share/realesrgan-ncnn-vulkan"
chmod +x "$HOME/.local/share/realesrgan-ncnn-vulkan/realesrgan-ncnn-vulkan"
export REALESRGAN_BIN="$HOME/.local/share/realesrgan-ncnn-vulkan/realesrgan-ncnn-vulkan"
export REALESRGAN_MODELS="$HOME/.local/share/realesrgan-ncnn-vulkan/models"
export REALESRGAN_MODEL=realesrgan-x4plus-anime
export REALESRGAN_SCALE=4  # model anime 4×; wynik jest potem redukowany do 1440p
export REALESRGAN_TILE=256  # sprawdzone na RX 6800S 8 GiB; 512 wywołuje reset GPU
export REALESRGAN_GPU_ID=1   # dedykowany RX 6800S; 0 to zintegrowany 680M
tools/wallpapers/upscale/run-night.sh
tools/wallpapers/upscale/collection.sh status
tools/wallpapers/upscale/collection.sh promote
```

Wrapper można uruchomić w `tmux`; sam uruchamia cztery shardy i zapisuje logi
`upscale-logs/shard-*.log`. Liczbę shardów można zmienić przez
`UPSCALE_SHARDS`, ale blokada GPU nadal serializuje inferencję.

Na mocniejszym komputerze z Radeonem RX 9070 XT (16 GiB) użyj gotowego profilu:

```bash
tools/wallpapers/upscale/install-animesharp-ncnn.sh
tools/wallpapers/upscale/run-9070xt.sh
```

Ten sam jakościowy model działa na laptopowym RX 6800S 8 GiB z mniejszym
tile 128, jednym workerem i właściwym identyfikatorem GPU 1:

```bash
tools/wallpapers/upscale/install-animesharp-ncnn.sh
tools/wallpapers/upscale/run-6800s.sh run
tools/wallpapers/upscale/run-6800s.sh status
# Dopiero po obejrzeniu stagingu:
tools/wallpapers/upscale/run-6800s.sh promote
```

Oba profile AnimeSharp korzystają z osobnego stagingu
`work/import-48/upscaled-32x9-animesharp/`, więc pozostałości wcześniejszego
przebiegu Real-ESRGAN nie są uznawane za gotowe wyniki nowego modelu. Na 6800S
można później ostrożnie spróbować `REALESRGAN_TILE=160`, ale domyślne 128
zastępuje niestabilne 192 i ogranicza ryzyko resetu Vulkan oraz czarnych lub
uszkodzonych kafli.

Profil wybiera pełny `4x-AnimeSharp-fp16` zamiast małego
`RealESRGAN_x4plus_anime_6B`. Model autora jest przypięty do konkretnej rewizji,
sprawdzany sumami SHA-256 i objęty licencją CC BY-NC-SA 4.0. Jest przeznaczony
do prywatnego, niekomercyjnego użycia. Upscale działa w skali 4× i z tile 384.
Jeśli pojedynczy przebieg przejdzie bez resetu sterownika, można spróbować
większych bloków: `REALESRGAN_TILE=512 tools/wallpapers/upscale/run-9070xt.sh`.
Gdy karta nie jest urządzeniem Vulkan 0, ustaw `REALESRGAN_GPU_ID` jawnie.

Launcher korzysta z NCNN i Vulkan/RADV. DirectML jest backendem Windows, a
ROCm nie jest potrzebny do tego modelu. RX 9070 XT jest obsługiwany przez ROCm,
lecz oficjalna macierz AMD nie wymienia NixOS jako wspieranego systemu hosta;
na tej samej konfiguracji NixOS Vulkan jest więc wariantem przenośnym. Backend
nie decyduje o jakości obrazu — robi to model i parametry; ROCm nie poprawiłby
oczu w porównaniu z tym samym checkpointem uruchomionym przez Vulkan.

Skrypt obrabia mastery 32:9 i zapisuje wynik wyłącznie w
`work/import-48/upscaled-32x9/`. Dopiero osobne polecenie `promote` tworzy backup
i podmienia aktywny master, po czym odtwarza 16:9 i 21:9 według zaakceptowanych
offsetów cropu. AnimeSharp lepiej rekonstruuje kontury i drobne detale niż
model 6B, ale nie jest generatorem: nie naprawi źle narysowanych lub zezujących
oczu obecnych już w masterze. Taką scenę trzeba poprawić na etapie generacji.

Shardy mogą działać równolegle, ale blokada `upscale-gpu.lock` przepuszcza
tylko jeden worker naraz przez GPU. Dzięki temu nie konkurują o VRAM. Na
laptopie pozostaje lekki `realesrgan-x4plus-anime`; profil 9070 XT wybiera
większy AnimeSharp. Dla fotorealistycznych źródeł nadal można jawnie ustawić
`REALESRGAN_MODELS` i `REALESRGAN_MODEL=realesrgan-x4plus`.

Pierwszy krok używa Seedream 5 Lite; Seedream 4.5 jest tylko moderacyjnym
fallbackiem. QA zapisuje osobne przesunięcia cropu po porównaniu z RAW-em,
więc finalne 16:9 pochodzi z ostrego mastera, ale zachowuje jego oryginalną
kompozycję.

## Kontrakt OLED

- Rdzeń ma natywne `2560×1440`, a master natywne `5120×1440`.
- Bohaterowie, twarze, główna akcja, najważniejsze rekwizyty i najmocniejsze
  akcenty światła mieszczą się całkowicie po prawej stronie.
- Lewa krawędź rdzenia jest już bardzo ciemna, lecz zawiera naturalne linie
  środowiska gotowe do dalszego wygaszenia przez outpaint.
- Około 35–50% każdego widoku tworzy organiczne, rzeczywiste `#000000`, z jego
  wyraźną większością po lewej stronie. Sceneria, GI i kolory stopniowo
  narastają w kierunku prawej strony oraz głównej akcji.
- Lite prowadzi lewą scenerię przez coraz rzadszą geometrię, słabsze GI,
  głębszą okluzję i płynne ciemne gradienty aż do przewagi `#000000` przy
  lewym brzegu. Nie może to być pionowe odcięcie ani doklejony prostokąt.
- Czerń zachowuje objętość dzięki AO, cieniom kontaktowym i śladowemu bounced
  light, dopóki widoczna jest jeszcze geometria środowiska.
- Światła są małe, miękkie i lokalne. Bez dużych białych powierzchni, bloom,
  ostrego HDR, agresywnego neonu i męczącego mikrokontrastu.
- Nie używamy crossoverów, easter eggów, technicznych metafor, tekstu, logo,
  UI ani znaków wodnych. Liczy się wyłącznie piękny i spójny świat.
- Nie stosujemy gradientowej maski, blurra, tilingu, paddingu ani rozciągania.

Obraz odrzucamy tylko wtedy, gdy plik jest nieczytelny lub ma zły wymiar.
W kolekcji 48 QA akceptuje poprawne pliki automatycznie, a porównanie z RAW-em
służy do wyznaczenia najlepszego przesunięcia kadru.
