# Plan rozbudowy

Roadmapa jest kierunkiem rozwoju, nie obietnicą kolejności. Każdy etap powinien
kończyć się `nix flake check` oraz pełnym buildem dotkniętych hostów.

## Najbliższe zadania

- [ ] Aktywować i ręcznie sprawdzić bieżącą konfigurację na laptopie.
- [x] Zmierzyć Ironbar przez 120 sekund i porównać go z zapisanym
      wynikiem Waybara oraz Noctalii.
- [x] Wybrać Ironbar jako jedyny docelowy panel i usunąć konfigurację Waybara.
- [ ] Przetestować wklejanie tekstu i obrazów z historii schowka.
- [ ] Przetestować jakość replay w dynamicznej grze przy 2560x1600.
- [ ] Sprawdzić kolejność i synchronizację trzech ścieżek audio.
- [x] Przeprowadzić audyt pakietów, wydzielić opcjonalne funkcje i usunąć
      domyślne narzędzia diagnostyczne GPU; audyt okresowo powtarzać.

## Znane problemy

- Poprawka wygaszacza ignorująca fałszywe wznowienie przy otwarciu okna czeka
  na aktywację i ręczne potwierdzenie. Trzeba również sprawdzić późniejszą
  blokadę oraz wyłączenie ekranu na zasilaczu i baterii.

## Osobny host PC

- [ ] Dodać `hosts/pc/` i output `nixosConfigurations.pc`.
- [ ] Wydzielić współdzieloną definicję użytkownika Home Manager w `flake.nix`,
      aby nie duplikować konfiguracji między hostami.
- [ ] Dodać konfigurację wielu monitorów specyficzną dla hosta.

## Pulpit

- [ ] Automatycznie przełączać częstotliwość odświeżania wbudowanego monitora:
      60 Hz podczas pracy z baterii i maksymalna dostępna wartość po podłączeniu
      zasilania zewnętrznego.
- [ ] Wybrać pełnego klienta kalendarza z obsługą CalDAV.
- [ ] Rozważyć scratchpad dla terminala lub odtwarzacza muzyki.
- [x] Dodać przeszukiwalne centrum skrótów z czytelnymi opisami pulpitu,
      nagrywania, Yazi, tmux, Neovim i menu zasilania.

## Replay

- [ ] Dodać wskaźnik aktywnego bufora do wybranego panelu.
- [ ] Zmierzyć faktyczne użycie GPU i RAM podczas gry.
- [ ] Rozważyć automatyczne usuwanie najstarszych klipów po przekroczeniu limitu.

## Utrzymanie

- [ ] Przeprowadzić pełny przegląd i porządki w całym `nixos-config`: usunąć
      zbędne pliki, nieużywaną konfigurację, martwy kod i pozostałe śmieci.
- [ ] Dodać formatter Nix i kontrolę formatowania.
- [ ] Dodać automatyczne sprawdzanie flake w CI po udostępnieniu repozytorium Git.
- [ ] Wprowadzić deklaratywne zarządzanie sekretami przed dodaniem jakichkolwiek
      danych prywatnych.
- [ ] Dokumentować wyniki testów oraz ryzyka przy większych zmianach sprzętowych.
