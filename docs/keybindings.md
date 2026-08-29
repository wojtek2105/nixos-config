# Skróty klawiszowe

Głównym modyfikatorem pulpitu jest `Super`. `Super+F1` otwiera deklaratywne
centrum pomocy z osobnymi sekcjami dla pulpitu, nagrywania, multimediów, Yazi,
tmux, Neovim i menu zasilania. Sekcje zależne od hosta są widoczne tylko wtedy,
gdy odpowiadająca funkcja jest włączona w manifeście `features` hosta.

Menu można też otworzyć z terminala bezpośrednio na wybranej sekcji:

```bash
shortcut-menu yazi
shortcut-menu tmux
shortcut-menu nvim
shortcut-menu capture
shortcut-menu all
```

Menu obejmuje wszystkie skróty zadeklarowane przez tę konfigurację. Dla Yazi,
tmux i Neovim pokazuje dodatkowo najważniejsze skróty wbudowane; pełne mapy tych
aplikacji pozostają dostępne w ich kontekstowej pomocy.

## System i aplikacje

| Skrót | Działanie |
| --- | --- |
| `Super+Enter` | Uruchom terminal Foot |
| `Super+Space` | Otwórz launcher aplikacji Fuzzel |
| `Super+D` | Otwórz globalne menu pulpitu |
| `Super+B` | Pokaż ostatnio używane okno Zen albo uruchom przeglądarkę |
| `Super+E` | Uruchom Yazi w osobnym oknie Foot |
| `Super+Alt+E` | Uruchom awaryjny menedżer plików Thunar |
| `Super+M` | Uruchom odtwarzacz Plexamp, jeśli włączono `personalApps.plexamp` |
| `Super+Shift+A` | Uruchom EasyEffects, jeśli włączono `personalApps.easyeffects` |
| `Super+N` | Pokaż lub ukryj centrum powiadomień SwayNC |
| `Super+L` | Zablokuj sesję przez Hyprlock |
| `Super+Escape` | Otwórz menu zasilania Wleave |
| `Super+Shift+V` | Wybierz wpis historii schowka i automatycznie go wklej |
| `Super+F1` | Otwórz centrum pomocy ze skrótami |

## Okna i pulpity

| Skrót | Działanie |
| --- | --- |
| `Super+Q` / `Super+C` | Zamknij aktywne okno |
| `Super+T` | Przełącz aktywne okno między floating i tiling |
| `Super+F` | Przełącz maksymalizację z widocznymi panelami |
| `Super+Shift+F` | Przełącz pełny ekran bez paneli |
| `Super+P` | Przełącz pseudotile aktywnego okna |
| `Super+S` | Zmień kierunek następnego podziału dwindle |
| `Super+strzałki` | Przenieś fokus między oknami |
| `Super+Shift+strzałki` | Przenieś aktywne okno |
| `Super+lewy przycisk myszy` | Przeciągnij aktywne okno |
| `Super+prawy przycisk myszy` | Zmień rozmiar aktywnego okna |
| `Super+Tab` | Przejdź do następnego używanego pulpitu |
| `Super+Shift+Tab` | Przejdź do poprzedniego używanego pulpitu |
| `Super+1…0` | Przejdź do pulpitu 1–10 |
| `Super+Shift+1…0` | Przenieś aktywne okno na pulpit 1–10 |

## Zrzuty, schowek i nagrywanie

| Skrót | Działanie |
| --- | --- |
| `Print` | Kliknij okno albo przeciągnij obszar i otwórz edytor Satty |
| `Shift+Print` | Przechwyć aktywne okno i otwórz Satty |
| `Ctrl+Print` | Przechwyć cały ekran i otwórz Satty |
| `Super+Shift+S` | Otwórz menu wyboru trybu zrzutu ekranu |
| `Super+Ctrl+S` | Uruchom animowany wygaszacz `WOJTECH` |
| `Enter` w Satty | Zapisz PNG, skopiuj go do schowka i zamknij edytor |
| `Esc` w Satty | Anuluj edycję i zamknij bez zapisu |
| prawy przycisk w Satty | Zapisz, skopiuj i zamknij edytor |
| `Alt+Z` | Pokaż lub ukryj nakładkę GPU Screen Recorder |
| `Super+G` | Pokaż lub ukryj nakładkę GSR — alternatywny skrót |
| `Super+Shift+R` | Włącz lub wyłącz bufor replay |
| `Super+R` | Zapisz ostatnie 120 sekund replay |

Skróty GSR pojawiają się wyłącznie na hostach z
`features.screenRecording = true`. Pierwsze użycie uruchamia nakładkę na żądanie.
Długość klipu w opisie menu pochodzi z
`replayConfig.seconds`, dlatego nie jest w nim zakodowana na stałe.

## Multimedia i laptop

| Klawisz | Działanie |
| --- | --- |
| głośniej / ciszej | Zmień głośność wyjścia o 5% i pokaż OSD |
| wyciszenie głośników | Przełącz wyciszenie wyjścia i pokaż OSD |
| wyciszenie mikrofonu | Przełącz wyciszenie mikrofonu i pokaż OSD |
| play/pause | Wstrzymaj lub wznów odtwarzanie przez Playerctl |
| następny / poprzedni | Zmień utwór przez Playerctl |
| jaśniej / ciemniej | Zmień jasność ekranu o 5% i pokaż OSD na hostach laptopowych |

## Yazi

| Klawisz | Działanie |
| --- | --- |
| `Enter` | Otwórz plik albo wejdź do katalogu |
| `h` / `l` lub strzałki | Przejdź do katalogu nadrzędnego / podrzędnego |
| `j` / `k` | Wybierz następny / poprzedni plik |
| `H` / `L` | Wróć / przejdź dalej w historii katalogów |
| `Spacja` | Zaznacz plik i przejdź do następnego |
| `v` / `V` | Rozpocznij zaznaczanie / odznaczanie zakresu |
| `y` / `x` | Skopiuj / wytnij zaznaczone pliki |
| `p` | Wklej do wskazanego katalogu albo katalogu bieżącego |
| `d` / `D` | Przenieś do kosza / usuń bezpowrotnie |
| `a` | Utwórz plik; zakończ nazwę `/`, aby utworzyć katalog |
| `r` | Zmień nazwę; przy wielu plikach otwórz listę w Neovim |
| `.` | Pokaż lub ukryj pliki ukryte |
| `f` | Skocz do pliku zaczynającego się od wybranego znaku |
| `F` | Filtruj ciągle i automatycznie wejdź w jednoznaczny wynik |
| `s` / `S` | Szukaj nazw przez `fd` / treści przez `ripgrep` |
| `z` / `Z` | Skocz przez `fzf` / historię katalogów Zoxide |
| `g c` | Pokaż pliki zmienione w bieżącym repozytorium Git |
| `Ctrl+D` | Porównaj zaznaczony plik ze wskazanym i skopiuj patch |
| `Tab` | Pokaż szczegółowe informacje o wskazanym pliku |
| `w` | Pokaż menedżer zadań Yazi |
| `M` | Zamontuj, odmontuj lub wysuń nośnik |
| `c m` | Zmień uprawnienia zaznaczonych plików |
| `c l` / `c L` | Utwórz dowiązanie bezwzględne / względne |
| `T` | Pokaż lub ukryj panel podglądu |
| `t p` | Zmaksymalizuj lub przywróć panel podglądu |
| `+` / `-` | Powiększ lub pomniejsz podgląd obrazu |
| `t t` | Otwórz nową kartę w bieżącym katalogu |
| `[` / `]` | Przejdź do poprzedniej / następnej karty |
| `1…9` | Przejdź bezpośrednio do wybranej karty |
| `q` | Zamknij Yazi; wrapper `y` może przejąć bieżący katalog |
| `F1` / `~` | Otwórz pełną, kontekstową pomoc Yazi |

## tmux

`Ctrl+B` jest domyślnym prefiksem. Przecinek oznacza kolejny klawisz naciskany
po puszczeniu prefiksu.

| Skrót | Działanie |
| --- | --- |
| `Ctrl+B, c` | Utwórz nowe okno |
| `Ctrl+B, n` / `p` | Przejdź do następnego / poprzedniego okna |
| `Ctrl+B, 0…9` | Przejdź do okna o podanym numerze |
| `Ctrl+B, ,` | Zmień nazwę bieżącego okna |
| `Ctrl+B, &` | Zamknij bieżące okno z potwierdzeniem |
| `Ctrl+B, %` | Podziel panel pionowo na lewą i prawą część |
| `Ctrl+B, "` | Podziel panel poziomo na górną i dolną część |
| `Ctrl+B, strzałki` | Przenieś fokus do sąsiedniego panelu |
| `Ctrl+B, Ctrl+strzałki` | Zmień rozmiar bieżącego panelu |
| `Ctrl+B, z` | Powiększ lub przywróć bieżący panel |
| `Ctrl+B, x` | Zamknij bieżący panel z potwierdzeniem |
| `Ctrl+B, [` | Wejdź do trybu kopiowania z klawiszami Vi |
| `Ctrl+B, d` | Odłącz klienta od sesji |
| `Ctrl+B, s` | Pokaż i wybierz sesję |
| `Ctrl+B, w` | Pokaż drzewo okien i paneli |
| `Ctrl+B, ?` | Pokaż pełną listę aktywnych skrótów tmux |

Obsługa myszy jest włączona: można wybierać okna i panele, przewijać historię
oraz przeciągać krawędzie podziału.

## Neovim

Profil nie nadpisuje obecnie domyślnej mapy Neovim; poniżej znajduje się
praktyczny zestaw wbudowanych poleceń zgodny z aktywną konfiguracją.

Polecenie `nvim-kickstart` uruchamia oficjalny Kickstart w osobnym profilu.
Nie zmienia konfiguracji ani danych zwykłego `nvim`. Mapowania dodane przez
Kickstart można odkrywać przez `Space`, `:Telescope keymaps` i `:checkhealth`.
Przy pierwszym uruchomieniu wrapper kopiuje przypięty przez Nix szablon do
zapisywalnego `~/.config/nvim-kickstart`; ten katalog można później bezpośrednio
zamienić w osobne repozytorium Git.

| Skrót | Działanie |
| --- | --- |
| `i` / `a` | Wejdź w tryb Insert przed / za kursorem |
| `Esc` | Wróć do trybu Normal |
| `h j k l` | Przesuń kursor w lewo, dół, górę i prawo |
| `w` / `b` / `e` | Skocz do następnego / poprzedniego słowa / końca słowa |
| `0` / `^` / `$` | Skocz na początek / pierwszy znak / koniec wiersza |
| `gg` / `G` | Skocz na początek / koniec pliku |
| `Ctrl+D` / `Ctrl+U` | Przewiń o pół ekranu w dół / górę |
| `v` / `V` / `Ctrl+V` | Zaznacz znaki / wiersze / blok kolumnowy |
| `y` / `d` / `c` + ruch | Kopiuj / usuń / zmień wskazany zakres |
| `yy` / `dd` / `cc` | Kopiuj / usuń / zmień cały wiersz |
| `p` / `P` | Wklej za / przed kursorem |
| `u` / `Ctrl+R` | Cofnij / ponów zmianę |
| `.` | Powtórz ostatnią zmianę |
| `/tekst`, potem `n` / `N` | Wyszukaj i przechodź po wynikach |
| `:w` / `:q` / `:wq` | Zapisz / zamknij / zapisz i zamknij |
| `:e plik` | Otwórz plik w bieżącym buforze |
| `:sp` / `:vsp` | Podziel okno poziomo / pionowo |
| `Ctrl+W, h/j/k/l` | Przenieś fokus między oknami Neovim |
| `Ctrl+W, q` / `o` | Zamknij okno / pozostaw tylko bieżące |
| `:tabnew`, `gt`, `gT` | Utwórz kartę / przejdź dalej / wróć |
| `:terminal` | Otwórz terminal w buforze |
| `:help temat` | Otwórz dokumentację wybranego polecenia |
| `:map` | Pokaż aktywne mapowania klawiszy |

## Menu zasilania Wleave

Po otwarciu przez `Super+Escape`:

| Klawisz | Działanie |
| --- | --- |
| `l` | Zablokuj sesję |
| `u` | Uśpij komputer |
| `e` | Wyloguj użytkownika |
| `r` | Uruchom komputer ponownie |
| `s` | Wyłącz komputer |
| `Esc` | Zamknij menu bez wykonywania akcji |

Menu pojawia się jako pojedynczy rząd pięciu kafli na aktywnym monitorze i
wyświetla skróty obok etykiet. Wylogowanie używa uporządkowanego zatrzymania
sesji UWSM, zamiast natychmiastowego zakończenia procesu Hyprlanda.
