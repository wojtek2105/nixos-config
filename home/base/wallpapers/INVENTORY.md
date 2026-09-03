# Inwentaryzacja tapet Biscuit OLED

## Zaakceptowane obrazy

Stan bieżący (2026-08-26): `collection.json` zawiera 48 kanonicznych scen, a
każdy z katalogów `16x9/`, `21x9/` i `32x9/` ma komplet 48 plików PNG.
Wymiary to odpowiednio `2560×1440`, `3440×1440` i `5120×1440`. Dla 44 nowych
pozycji wygenerowano mastery w `work/import-48/masters/`, zapisano plany QA i
wykonano finalizację; cztery istniejące pozycje zostały zachowane bez
ponownej generacji. Źródła RAW są w `raw/16x9/`, a etap generacji używa Lite
5.0 z fallbackiem 4.5 wyłącznie po kodzie moderacji.

### Regeneracja 2026-08-27

Sceny `18-csm-power-meowy`, `27-demonslayer-shinobu-wisteria` oraz
`Gemini_Generated_Image_c52jltc52jltc52j` zostały ponownie wygenerowane jako
spójne mastery 32:9. Dwie pierwsze przeszły przez Seedream Lite 5.0; trzecia
użyła fallbacku Seedream 4.5 po dwóch odrzuceniach moderacyjnych Lite 5.0.
Nowe prompty są w `prompts/regenerate-32x9/`, a poprzednie mastery i trzy
warianty każdej sceny zachowano odwracalnie w
`work/regenerate-2026-08-27/backup/`. Po pełnym porównaniu z RAW-em finalne
cropy używają odpowiednio offsetów `18: 1536/1024`, `27: 832/256` i
`Gemini: 2048/1480` (16:9/21:9). Wszystkie dziewięć nowych wariantów ma
wysokość 1440 px i jest gotowych do rotacji.

### Rekadrowanie względem RAW 2026-08-27

Pełny wizualny QA 44 planów wykrył 18 kadrów przesuniętych względem źródła.
Zostały ponownie wycięte i zmasterowane z aktualnych masterów 32:9. Poprzednie
54 pliki oraz tabela starych i nowych offsetów są zachowane w
`work/import-48/pre-recrop-2026-08-27/`; pozostałych 26 zaakceptowanych planów
nie zmieniano.

Poniższa sekcja „Próby generacji” jest archiwalną historią wcześniejszej serii
18 scen i nie opisuje już stanu katalogów wynikowych.

Nazwy z sufiksami `_1` i `core-v*` również są zaakceptowane, ponieważ znajdują
się w katalogu wynikowym. Ich ujednolicenie wymaga osobnej decyzji użytkownika.

## Finalna seria 18 scen

| Numery | Uniwersum | Rdzenie 16:9 | Mastery 32:9 |
|---:|---|---|---|
| 01–03 | Frieren | prompty gotowe, brak generacji | brak |
| 04–06 | Chainsaw Man | prompty gotowe, brak generacji | brak |
| 07–09 | Solo Leveling | prompty gotowe, brak generacji | brak |
| 10–12 | Valheim | prompty gotowe, brak generacji | brak |
| 13–15 | V Rising | prompty gotowe, brak generacji | brak |
| 16–18 | Palworld | prompty gotowe, brak generacji | brak |

## Próby generacji

- Sceny Frieren `01–03` są odłożone do wygenerowania przez Nano Banana, ponieważ
  Seedream konsekwentnie odrzuca to uniwersum filtrem wyjściowym.
- `01-frieren-grimoire-vault`: Pro odrzucony przez
  `OutputImageSensitiveContentDetected.PolicyViolation`, a niezmieniony prompt
  Lite przez `OutputImageSensitiveContentDetected`. Drugi Pro z autorską
  stylizacją tapetową, bez imitowania anime, również odrzucony przez filtr.
- `02-frieren-rain-camp`: Pro odrzucony przez
  `OutputImageSensitiveContentDetected.PolicyViolation`; rozpoczęty fallback
  Lite przerwany po decyzji o przeniesieniu scen Frieren do Nano Banana.
- `03-frieren-moonlit-flowers`: bez próby Seedream.
- Sceny anime `01–09` zostały odłożone na koniec serii. Przed ponownymi próbami
  ich prompty mają używać autorskiej ilustracji tapetowej i wyraźnie zabraniać
  kopiowania istniejących klatek, key artu oraz charakterystycznego renderingu
  studia.
- `04-chainsaw-man-alley`: pierwotny prompt odrzucony przez filtr wyjściowy
  zarówno w Pro, jak i Lite. Drugi Pro z autorską stylizacją tapetową, bez
  imitowania anime, również odrzucony; sceny `04–06` przeniesione do Nano Banana.
- `07-solo-leveling-shadow-dungeon`: autorski prompt tapetowy przeszedł w Pro;
  rdzeń v1 `2560×1440` ma prawostronnego Jinwoo, podporządkowaną armię cieni i
  mocną kompozycję OLED. Czeka na akceptację użytkownika.
- `08-solo-leveling-igris-throne`: rdzeń Pro v1 wygenerowany w `2560×1440`;
  Igris i kompozycja OLED są mocne, ale Jinwoo ma błędne srebrne włosy zamiast
  kanonicznych czarnych. Odrzut postaci; brak outpaintu.
- `09-solo-leveling-shadow-gate`: autorski prompt przeszedł w Pro; rdzeń v1
  `2560×1440` ma poprawne czarne włosy Jinwoo, prawostronną armię cieni oraz
  mocne mokre ruiny OLED. Czeka na akceptację użytkownika.
- `10-valheim-black-fjord`: rdzeń Pro v1 wygenerowany w `2560×1440` i czeka na
  ocenę użytkownika; outpaint Lite nie został uruchomiony.
- `11-valheim-meadows-longhouse`: rdzeń Pro v1 wygenerowany w `2560×1440`;
  kompozycja i OLED są mocne, ale rendering jest bardziej realistyczny niż
  charakterystyczne low-poly/painterly Valheim. Czeka na decyzję użytkownika.
- `12-valheim-mountain-forge`: rdzeń Pro v1 wygenerowany w `2560×1440`;
  czytelny styl low-poly i prawostronna akcja, lecz duża powierzchnia śniegu
  wymaga oceny komfortu OLED. Outpaint nie został uruchomiony.
- `13-vrising-castle-heart`: rdzeń Pro v1 wygenerowany w `2560×1440`; kamera
  izometryczna, Castle Heart, prawostronna akcja i całkowicie zamknięty hełm są
  czytelne. Mocny kandydat oczekujący na akceptację użytkownika.
- `14-vrising-blood-moon-balcony`: rdzeń Pro v1 wygenerowany w `2560×1440`;
  bardzo mocna kompozycja OLED i całkowicie ukryta twarz, ale kamera jest
  bardziej filmowa niż izometryczna. Czeka na decyzję użytkownika.
- `15-vrising-gothic-forge`: rdzeń Pro v1 wygenerowany w `2560×1440`; główny
  wampir ma zamknięty hełm bez skóry i twarzy, ale model dodał czerwone świecące
  szczeliny oczu. Czeka na decyzję, czy martwy wizjer jest wymagany.
- `16-palworld-palbox-night-base`: Pro odrzucony przez filtr wyjściowy;
  niezmieniony prompt Lite wygenerował rdzeń v1 `2560×1440` z Palboxem,
  rozpoznawalnymi Pals i prawostronną bazą. Czeka na akceptację użytkownika.
- `17-palworld-chillet-workshop`: rdzeń Pro v1 wygenerowany w `2560×1440`, ale
  model zastąpił kanonicznego jasnoniebieskiego Chilleta fioletowym smokiem.
  Odrzut fabularny mimo dobrej kompozycji OLED; brak outpaintu.
- `18-palworld-mountain-expedition`: rdzeń Pro v1 wygenerowany w `2560×1440`,
  ale Jetragon i pozostałe Pals zostały zastąpione generycznymi stworami, a
  szerokie jasne niebo osłabia OLED. Odrzut fabularny; brak outpaintu.

Obraz trafia do opisu sceny dopiero po obejrzeniu. Wtedy zapisujemy faktycznie
widoczne postacie, zgodność stylu, kompozycję, wymiary, ciągłość outpaintu,
komfort wizualny i udział dokładnego `#000000`. Nie uznajemy elementu za obecny
wyłącznie dlatego, że został wymieniony w prompcie.
