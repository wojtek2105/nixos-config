# Tapety Biscuit OLED v3

Katalog opisuje projektowaną od zera kolekcję 22 tapet. Storyboard, logiczne
easter eggi i podział na światy są w [CONCEPTS.md](CONCEPTS.md), a stan
rzeczywistych plików w [INVENTORY.md](INVENTORY.md).

Każda scena ma jeden kompletny, technicznie poprawny przepływ systemowy od
wejścia do wyniku i obsługi błędu. Produkty są rekwizytami o konkretnej roli,
nie kolekcją logo; mapa wszystkich 22 przepływów znajduje się w `CONCEPTS.md`.

## Kolejność pracy

1. Zatwierdzamy storyboard i produkcyjne prompty.
2. Seedream 5.0 Pro generuje krótko opisany, kompletny rdzeń `2560×1440`.
3. Oglądamy rdzeń 16:9 przed każdą kolejną warstwą. Pro poprawia osobno jeden
   element wizualny, a potem najwyżej dwa–trzy krótkie napisy.
4. Seedream 5.0 Lite rozszerza zaakceptowany rdzeń wyłącznie w lewo do
   `5120×1440`, nie przemalowując prawego kadru.
5. Odrzucamy obraz z generycznym światem, przypadkowymi napisami, słabą
   kompozycją, widocznym łączeniem albo sztuczną czernią.
6. Dopiero zaakceptowane źródło przechodzi mastering do `32x9/`, `21x9/` i
   `16x9/` oraz zostaje dodane do trzech list w `theme.nix`.

Po resecie katalogi wynikowe są puste, a konfiguracja korzysta z technicznych
czarnych fallbacków. Żaden prompt ani sam wynik API nie aktywuje tapety.

## Warstwowy workflow Seedream Pro → Lite

Pro otrzymuje krótki prompt obejmujący wyłącznie rozpoznawalną postać lub świat,
jedną scenę, kompozycję 16:9 i kierunek OLED. Nie dokładamy w pierwszym wywołaniu
całej historii technicznej, wszystkich etykiet, crossoveru, pełnej palety oraz
długiej listy zakazów. Minimalny test z samą Frieren przeszedł moderację Pro;
trzy przeładowane warianty tej samej sceny zostały odrzucone dopiero przez filtr
wyniku. To wskazuje na przeciążenie semantyczne promptu, a nie blokadę postaci.

Kolejne wywołania są małymi edycjami image-to-image:

1. Pro tworzy finalny wizualnie rdzeń `2560×1440` bez napisów.
2. Pro dodaje lub poprawia jeden mechanizm techniczny, nie zmieniając reszty.
3. Pro dodaje najwyżej dwa–trzy krótkie napisy w jednym przebiegu. Typografię,
   której model nadal nie zapisuje dokładnie, poprawiamy deterministycznie przy
   masteringu zamiast ponawiać całą ilustrację. Taka poprawka musi należeć do
   świata sceny: haft na fladze, grawer w metalu albo tekst na ekranie. Nie
   dokładamy płaskich plakietek, paneli UI ani napisów unoszących się w kadrze.
4. Lite dostaje zaakceptowany rdzeń jako referencję i dopowiada tylko naturalną
   architekturę, teren, światło i głębię po lewej stronie do `5120×1440`.
5. Wariant `3440×1440` jest prawostronnym cropem mastera, natomiast
   `2560×1440` zachowuje zaakceptowany rdzeń Pro.

Każdą warstwę ogląda użytkownik przed następnym płatnym wywołaniem. Oryginały są
wersjonowane; edycja nigdy nie nadpisuje ostatniego zaakceptowanego obrazu.

## Rozdzielczości

- rdzeń Pro: natywne `2560×1440`, bez pasów i paddingu;
- źródło/master Lite: natywne `5120×1440`, bez pasów i paddingu;
- `32x9/`: `5120×1440`;
- `21x9/`: `3440×1440`;
- `16x9/`: `2560×1440`.

Wysokość jest zawsze dokładnie `1440 px`. Lite dodaje szerokość tylko po lewej
stronie zaakceptowanego rdzenia; niczego nie rozciągamy. Szersze warianty
odsłaniają kolejne warstwy tej samej sceny; nie używamy osobnego tła,
gradientowej maski, blurra, tilingu ani czarnej zasłony do wypełnienia lewej
strony.

## OLED i Biscuit

Scena powinna już ze źródła mieć niski poziom światła i organiczne obszary
`#000000`. Mastering utrwala czerń, lecz nie naprawia jasnej, płaskiej albo źle
skomponowanej generacji. Kolory wynikają z Biscuit de Mar Dark; zakazane są
duże białe powierzchnie, szaro-niebieski wash, neonowa ściana i osobny pasek
pod Ironbar.

## Narzędzia

- `tools/generate-wallpaper-seedream.sh [PROMPT] [WYNIK]` generuje wersjonowany
  kandydat przez wybrany `SEEDREAM_MODEL` i `SEEDREAM_WALLPAPER_SIZE`;
- `tools/edit-wallpaper-seedream.sh [ŹRÓDŁO] [PROMPT] [WYNIK]` wykonuje
  zachowawczą edycję image-to-image bez publicznego hostowania źródła;
- `tools/generate-wallpapers.sh [OD] [DO]` łączy kontrakt globalny z jednym
  numerowanym promptem i zapisuje źródło wraz z dokładnym sidecarem;
- `tools/master-wallpapers.sh [OD] [DO]` tworzy trzy warianty i zapisuje
  pomiary czerni w `METRICS.tsv`.
- `tools/finalize-vrising14-core.sh` zachowuje historyczny prototyp lokalnej
  kompozycji sceny 14; finalna tapeta używa zaakceptowanego rdzenia Pro v3 z
  napisami i dużą Pochitą wygenerowanymi przez AI;
- `tools/finalize-vrising14-wallpapers.sh` składa jego źródło oraz trzy
  gotowe proporcje bez ponownego generowania obrazu.

Oficjalny sygnet w `assets/traefik-labs-icon.svg` pochodzi z press kitu
Traefik Labs. Finalizer używa go jako przygaszonego haftu w świecie V Rising,
bez produktowego wordmarku i bez płaskiego tła.

Klucze pozostają poza repozytorium w prywatnym katalogu
`${XDG_CONFIG_HOME:-$HOME/.config}/nixos-config/secrets/`. Domyślne pliki to
`gemini-wallpapers.key`, `byteplus-wallpapers.key` i `bfl-wallpapers.key`;
zmienne `GEMINI_API_KEY_FILE`, `ARK_API_KEY_FILE` oraz `BFL_API_KEY_FILE`
pozwalają wskazać inne ścieżki. Katalog ma uprawnienia `0700`, a klucze `0600`.

Punkt wznowienia sceny 01 po restarcie: użyć minimalnego, działającego promptu
`prompts/seedream/00-frieren-minimal-pro-test.txt` jako wzorca krótkiej formy,
przygotować wersjonowany produkcyjny rdzeń Pro `2560×1440`, pokazać go
użytkownikowi i dopiero po akceptacji dodać mechanizm Nix w osobnej edycji.
