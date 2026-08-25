# Wyniki benchmarków schedulerów

Każde pełne uruchomienie `scheduler-benchmark` tworzy tutaj osobny katalog z
datą i godziną. Raport przechowuje sześć prób każdego schedulera dla CPU
pulpitu, CPU podczas rzeczywistego replayu gry oraz GPU.

Nie należy ręcznie poprawiać wartości w wygenerowanych plikach. Jeżeli warunki
pomiaru były błędne, trzeba zachować raport jako diagnostyczny albo usunąć cały
konkretny katalog przed jego zatwierdzeniem w Git.

Przed porównywaniem dwóch sesji należy sprawdzić w `metadata.json` co najmniej:

- ten sam kernel i wersję SCX;
- to samo źródło zasilania, governor i profil platformy;
- tę samą rozdzielczość, jakość obrazu, GPU renderujące oraz liczbę powtórzeń;
- brak nagrywania/replay, aktualizacji, kompilacji i innych obciążeń w tle.

Użyte projekty:

- [sched-ext/scx](https://github.com/sched-ext/scx)
- [stress-ng](https://github.com/ColinIanKing/stress-ng)
- [SuperTuxKart](https://github.com/supertuxkart/stk-code)
- [Testy wydajności SuperTuxKart](https://supertuxkart.net/Performance_testing)
- [Profil SuperTuxKart w OpenBenchmarking](https://openbenchmarking.org/test/pts/supertuxkart)
- [Mesa `DRI_PRIME`](https://docs.mesa3d.org/envvars.html#envvar-DRI_PRIME)
- [MangoHud](https://github.com/flightlessmango/MangoHud)
- [GameMode](https://github.com/FeralInteractive/gamemode)

Kompletna procedura i komendy znajdują się w
[głównej dokumentacji benchmarków](../benchmarks.md#porównanie-schedulerów-cpu-i-gpu).

## Zachowane sesje

Brak. Poprzednie próby syntetyczne zostały usunięte; pierwszym punktem
odniesienia będzie pełna seria na replayu SuperTuxKart.
