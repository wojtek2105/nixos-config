# Historyczne benchmarki pulpitu

Historyczne narzędzie do pomiaru paneli nie jest już częścią konfiguracji,
ale wyniki pozostają zapisane jako pamiątka i punkt odniesienia dla przyszłych
zmian pulpitu. Nowszy benchmark schedulerów jest dostępny wyłącznie na żądanie
jako osobna aplikacja flake opisana niżej.

## Wyniki

| Wariant | CPU systemu | CPU shella (1 wątek) | PSS shella | iGPU busy |
| --- | ---: | ---: | ---: | ---: |
| Waybar + SwayNC + Awww | 1,56% | 2,550% | 105,7 MiB | 2,30% |
| Noctalia v5 | 1,53% | 3,717% | 127,1 MiB | 22,40% |
| Waybar + Biscuit, 2026-08-23 | 1,50% | 1,042% | 124,9 MiB | 6,61% |
| Ironbar + Biscuit, 2026-08-23 | 1,53% | 0,508% | 127,0 MiB | 4,20% |
| Ironbar + Biscuit, 2026-08-24 | 1,09% | 0,942% | 122,4 MiB | 4,10% |

## Warunki pomiarów

Serie z 2026-08-23 trwały po 120 sekund. Docker, Voxtype, bufor GPU Screen
Recordera i Noctalia były wyłączone; działały badany panel, SwayNC, Awww oraz
bezczynny Foot z Codexem. Laptop był podłączony do zasilacza, a timer tapety
wyzerowany, dlatego animacja Awww nie wystąpiła podczas próbki. Pierwsze dwa
wiersze pochodzą ze starszej konfiguracji sprzed wdrożenia motywu Biscuit i są
mniej bezpośrednio porównywalne.

Powtórzony pomiar Ironbara z 2026-08-24 również trwał 120 sekund i obejmował
Ironbar, SwayNC oraz Awww. Został wykonany po restarcie, na baterii, ze średnim
poborem 15,75 W. Timer tapety nie był wyzerowany, więc iGPU nie należy
porównywać jeden do jednego z serią z poprzedniego dnia.

## Interpretacja

W serii z 2026-08-23 Ironbar względem Waybara z Biscuit miał o 51,2% niższe CPU
stale działających procesów shella, o 2,1 MiB wyższe PSS i o 36,5% niższe użycie
iGPU; różnica 0,03 punktu procentowego CPU całego systemu mieściła się w szumie.
W powtórce z 2026-08-24 osiągnął względem Waybara z Biscuit o 27,3% niższe CPU
systemu, o 9,6% niższe CPU shella, o 2,5 MiB niższe PSS i o 38,0% niższe użycie
iGPU. Względem Noctalii było to odpowiednio o 28,8%, 74,7%, 4,7 MiB i 81,7%
mniej.

## Przyszłe porównania

Przyszłe pomiary należy wykonywać przez 120 sekund na tym samym laptopie, przy
identycznym zasilaniu, jasności, profilu energetycznym, stanie usług, buforze
nagrywania i timerze tapety. `system_cpu_percent` obejmował cały system wraz z
krótkotrwałymi skryptami panelu, a `resident_shell_cpu_percent` tylko stale
działający panel, SwayNC i Awww.

## Porównanie schedulerów CPU

Flake udostępnia osobną aplikację benchmarkową, która nie jest instalowana w
systemie i nie zwiększa jego aktywnego closure. Pierwsze uruchomienie pobierze
przypięte przez `flake.lock` pakiety do Nix store, a wszystkie pliki robocze
powstaną w katalogu zwróconym przez `mktemp` pod `${TMPDIR:-/tmp}`.
Ten sam harness zachowuje opcjonalny `modules/scheduler-benchmark.nix`.
`features.schedulerBenchmark = false` jest bezpiecznym ustawieniem codziennym;
wartość `true` tylko instaluje polecenie `scheduler-benchmark` i zależności,
bez automatycznego uruchamiania testu, usługi albo timera.

Domyślna sekwencja wykonuje po dwie próby dla EEVDF, bpfland, LAVD i Flash w
dwóch profilach CPU, czyli łącznie 16 pomiarów:

```bash
nix run path:.#scheduler-benchmark -- run
```

Przed długą oficjalną serią warto wykonać jedną nieoficjalną próbę kontrolną.
Sprawdza ona start gry i nową walidację rozdzielczości, nie służy do porównania
schedulerów, a wynik trafia wyłącznie do `/tmp`:

```bash
nix run path:.#scheduler-benchmark -- run \
  --schedulers eevdf \
  --profiles gaming-cpu \
  --runs 1 \
  --cooldown 3 \
  --output "/tmp/scheduler-benchmark-smoke-$(date +%s)"
```

Oficjalne porównanie czterech schedulerów w trzech rundach obejmuje 24 próby
CPU i celowo pomija profil GPU:

```bash
nix run path:.#scheduler-benchmark -- run \
  --schedulers eevdf,bpfland,lavd,flash \
  --profiles desktop-cpu,gaming-cpu \
  --runs 3
```

Harness przypina wyłącznie `scx_lavd` do wersji 1.1.2, ponieważ 1.1.3 ma
zgłoszoną regresję powodującą zacięcia i wyrejestrowanie schedulera podczas
grania. bpfland i Flash nadal pochodzą z `scx.rustscheds` przypiętego przez
`flake.lock`, a codzienna usługa `scx_bpfland` nie jest zmieniana. Pierwszy
build LAVD 1.1.2 może skompilować jego zależności; paczka pozostaje częścią
wyłącznie uruchamianego na żądanie harnessu. Dokładne wersje każdej binarki są
zapisywane w `metadata.json` oraz w tabeli środowiska `REPORT.md`.

Domyślne profile mają odrębne cele:

- `desktop-cpu` mierzy opóźnienie okresowego zadania użytkowego podczas
  obciążenia `stress-ng` na wszystkich poza dwoma logicznymi CPU;
- `gaming-cpu` odtwarza deterministyczny replay najbardziej wymagającej
  standardowej trasy SuperTuxKart 1.5 w Vulkanie, natywnej rozdzielczości
  aktywnego monitora i niskiej jakości przy równoczesnym pełnym obciążeniu CPU.
  Rozgrzewka i każda punktowana próba odczytują końcowe `width` i `height`
  zapisane przez STK i odrzucają wynik, jeśli faktyczny render target różni się
  od rozdzielczości podanej w raporcie.

Profil `gpu` nie należy do domyślnego porównania schedulerów. Ostatnia pełna
seria pokazała między schedulerami tylko 1,1% rozpiętości Average FPS i 1,4%
rozpiętości 1% Low FPS, więc wynik był zdominowany przez szum pomiarowy GPU i
nie pomagał wybrać schedulera CPU. Implementacja pozostaje w repo jako jawny
test diagnostyczny Mesa, kernela lub ustawień zasilania:

```bash
nix run path:.#scheduler-benchmark -- run --profiles gpu
```

Ten opcjonalny profil odtwarza replay w shaderowym OpenGL, natywnym presecie 7
(Ultimate) i rozdzielczości aktywnego monitora, bez sztucznego obciążenia
procesora.

Wyniki pochodzą bezpośrednio z profilera gry. `Average FPS` jest liczone z
liczby klatek i czasu replayu. `1% Low FPS` oznacza średni FPS najwolniejszego
1% klatek; harness odtwarza go z zapisanej przez STK skumulowanej liczby i czasu
wolnych klatek, z interpolacją ostatniego przedziału o szerokości 1 FPS.
Natywne `Steady FPS` premiuje brak stutteru, `Mostly Steady FPS` równoważy
płynność z ogólną wydajnością, a `Typical FPS` opisuje typową wydajność. Dzięki
temu proces gry nie wymaga zewnętrznej nakładki ani dodatkowego hooka
graficznego.

Przed punktowanymi próbami skrypt wykonuje po jednym replayu rozgrzewającym dla
wybranych wariantów gry. Cache shaderów jest potem wspólny, ale ustawienia i
dane STK trafiają do tymczasowych katalogów XDG, więc prywatna konfiguracja gry
nie jest modyfikowana. Kolejność schedulerów rotuje między rundami, aby
ograniczyć przewagę wynikającą z temperatury. Po każdym replayu skrypt ponownie
czyta `/sys/kernel/sched_ext`; próba zostaje oznaczona jako nieudana, jeżeli
scheduler wyrejestruje się w trakcie. Profile graficzne używają GameMode
jednakowo dla wszystkich schedulerów.

Na komputerze z kilkoma GPU tryb `auto` odczytuje `boot_vga` i wybiera dokładny
adres Mesa, np. `pci-0000_03_00_0`. Profil CPU w Vulkanie dodaje `!`, aby Vulkan
widział wyłącznie wybraną kartę; profil GPU w OpenGL usuwa ten sufiks, zachowując
ten sam adres PCI. Jeżeli sterownik nie ujawnia `boot_vga`, fallback `1!`
wybiera pierwsze GPU inne niż domyślne. Na komputerze z jednym GPU skrypt nie
ustawia `DRI_PRIME`. Raport zapisuje selektor wejściowy oraz nazwę GPU zwróconą
przez STK; wybór można jawnie zmienić przez np. `--gpu-prime default`,
`--gpu-prime '1!'` albo identyfikator `pci-...!`.

Profil GPU przechodzi dalej dopiero wtedy, gdy rozgrzewka potwierdzi renderer
OpenGL, obsługę GLSL, brak fixed pipeline oraz powstanie raportu profilera.
Każda punktowana próba dodatkowo porównuje zapisane przez STK parametry
graficzne z rozdzielczością testu i wymaganiami Ultimate. Końcowe `width` i
`height` z sekcji `Video` są sprawdzane osobno, ponieważ opisują faktyczny
render target sterownika; `real_width` i `real_height` wypisywane przez raport
STK nie są wystarczającym dowodem. Dzięki temu błędny fallback renderera,
niepełny preset albo półekranowy render target nie trafi do agregatów jako
poprawny wynik.

Oba profile gry pozostają na natywnym Waylandzie. STK 1.5 zgłasza jednak stan
OpenGL fullscreen przed zakończeniem negocjacji powierzchni HiDPI, przez co
Hyprland może pozostawić obraz w półekranowym kafelku. W profilu GPU harness
czeka na wczytanie `benchmark_black_forest.replay` i krótkie ustanie logów
ładowania, a dopiero potem przez aktualne API Lua Hyprlanda automatycznie
odtwarza sprawdzoną kolejność: najpierw maximized jak po `Super+F`, następnie
prawdziwy fullscreen bez paneli jak po `Super+Shift+F`. Obie akcje zachowują
semantykę `toggle` rzeczywistych skrótów. Na końcu harness sprawdza przez
Hyprland stan fullscreen i logiczny rozmiar okna. Sekwencja mieści się w
niemierzonej, 2-sekundowej fazie SET; profiler STK włącza się dopiero po niej.
`--gaming-size` i `--gpu-size` określają rozdzielczość renderowania sprawdzaną
w końcowej konfiguracji STK. Obie domyślnie przyjmują rozmiar aktywnego monitora;
jawny rozmiar inny niż wynegocjowany przez pełnoekranowy Wayland zakończy próbę
błędem zamiast zapisać mylący wynik. Raporty utworzone przed tą korektą
2026-08-25 mogą opisywać profil CPU jako 1280×720, mimo że ich surowe parametry
`Video` wskazują 2560×1600; należy je traktować jako testy natywne, a nie 720p.

Podczas pomiarów skrypt blokuje uśpienie, tymczasowo zatrzymuje `scx.service`,
uruchamia badany scheduler jako usługę przejściową i zawsze próbuje przywrócić
zadeklarowany `scx.service`, również po `Ctrl+C`. Na baterii odmawia startu bez
jawnego `--allow-battery`. Przerwanie nie kasuje wykonanych prób: raport częściowy
i wszystkie zebrane do tego momentu dane są kopiowane do katalogu wynikowego.

Końcowy katalog `docs/benchmark-results/RRRR-MM-DD_GG-MM-SS/` zawiera:

- `REPORT.md` z agregatami, automatycznym wnioskiem i tabelą wszystkich prób;
- `results.csv` ze wszystkimi metrykami w formacie maszynowym;
- `metadata.json` z kernelem, CPU, GPU, wersjami narzędzi i warunkami testu;
- `raw/` z logami stress-ng, SuperTuxKart, jego raportem CSV,
  schedulerem i osobnym JSON-em każdej próby.

Stan schedulera bez wykonywania pomiarów:

```bash
nix run path:.#scheduler-benchmark -- status
```

Pełne uruchomienie wykonuje domyślnie dwie rundy na każdy scheduler i profil.
Można to nadal jawnie zmienić opcją `--runs N`.

Krótszy pomiar kontrolny po jednym przebiegu:

```bash
nix run path:.#scheduler-benchmark -- run --runs 1 --cooldown 3
```

Raport z zachowanych danych można odtworzyć bez ponawiania prób:

```bash
nix run path:.#scheduler-benchmark -- report docs/benchmark-results/RRRR-MM-DD_GG-MM-SS
```

Po zakończeniu porównań flaga hosta powinna pozostać `false`. Pakiety pobrane
przez `nix run` nie są częścią generacji systemu; zostaną usunięte dopiero przez
zwykłe garbage collection, gdy nie wskazuje ich żaden inny profil ani korzeń GC.

Źródła metodologii i narzędzi: [sched-ext/scx](https://github.com/sched-ext/scx),
[stress-ng](https://github.com/ColinIanKing/stress-ng),
[SuperTuxKart](https://github.com/supertuxkart/stk-code),
[zgłoszenie fixed pipeline renderera Vulkan STK](https://github.com/supertuxkart/stk-code/issues/4815),
[dokumentacja testów wydajności STK](https://supertuxkart.net/Performance_testing),
[profil STK w OpenBenchmarking](https://openbenchmarking.org/test/pts/supertuxkart),
[Mesa `DRI_PRIME`](https://docs.mesa3d.org/envvars.html#envvar-DRI_PRIME),
[Mesa Vulkan WSI](https://docs.mesa3d.org/envvars.html#envvar-MESA_VK_WSI_PRESENT_MODE) i
[GameMode](https://github.com/FeralInteractive/gamemode). Każdy wygenerowany
`REPORT.md` zachowuje te odnośniki razem z wynikiem.

Profil SuperTuxKart jest odseparowany od ustawień użytkownika. Ustawia limit
gry na 9999 FPS i wyłącza V-Sync. Profil CPU w Vulkanie wymusza w Mesa tryb
prezentacji `immediate`; profil GPU w OpenGL używa `swap-interval=0` oraz
`vblank_mode=0`. Dzięki temu wynik nie jest ograniczony do 60, 120 ani innej
częstotliwości monitora; nie zmienia to konfiguracji zwykłego STK.

Nowych wyników profilu `gpu` nie należy łączyć bezpośrednio z historycznymi
próbami Vulkan. Zmiana renderera jest zmianą metodologii: wcześniejszy Vulkan
STK 1.5 raportował fixed pipeline, natomiast obecny profil celowo wymaga pełnej
ścieżki shaderowej OpenGL Ultimate. Wyniki `desktop-cpu` i `gaming-cpu`
pozostają porównywalne, ponieważ ich metodologia nie została zmieniona.
