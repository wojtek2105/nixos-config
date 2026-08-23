# Plan rozbudowy

Roadmapa jest kierunkiem rozwoju, nie obietnicą kolejności. Każdy etap powinien
kończyć się `nix flake check` oraz pełnym buildem dotkniętych hostów.

## Najbliższe zadania

- [ ] Aktywować i ręcznie sprawdzić bieżącą konfigurację na laptopie.
- [ ] Przetestować wklejanie tekstu i obrazów z historii schowka.
- [ ] Przetestować jakość replay w dynamicznej grze przy 2560x1600.
- [ ] Sprawdzić kolejność i synchronizację trzech ścieżek audio.
- [ ] Usunąć przejściowe aliasy skrótów po utrwaleniu nowego układu.
- [ ] Okresowo sprawdzać listę pakietów i usuwać nieużywane zależności.

## Osobny host PC

- [ ] Dodać `hosts/pc/` i output `nixosConfigurations.pc`.
- [ ] Wydzielić współdzieloną definicję użytkownika Home Manager w `flake.nix`,
      aby nie duplikować konfiguracji między hostami.
- [ ] Dodać konfigurację wielu monitorów specyficzną dla hosta.

## Pulpit

- [ ] Wybrać pełnego klienta kalendarza z obsługą CalDAV.
- [ ] Rozważyć scratchpad dla terminala lub odtwarzacza muzyki.
- [ ] Dodać czytelne opisy skrótów bezpośrednio do konfiguracji Hyprlanda.

## Replay

- [ ] Dodać wskaźnik aktywnego bufora do Waybara.
- [ ] Zmierzyć faktyczne użycie GPU i RAM podczas gry.
- [ ] Rozważyć automatyczne usuwanie najstarszych klipów po przekroczeniu limitu.

## Utrzymanie

- [ ] Dodać formatter Nix i kontrolę formatowania.
- [ ] Dodać automatyczne sprawdzanie flake w CI po udostępnieniu repozytorium Git.
- [ ] Wprowadzić deklaratywne zarządzanie sekretami przed dodaniem jakichkolwiek
      danych prywatnych.
- [ ] Dokumentować wyniki testów oraz ryzyka przy większych zmianach sprzętowych.
