# Hosty

## ROG Polamaniec

Repozytorium automatycznie wystawia tylko hosty z własnym
`hardware-configuration.nix`; obecnie gotowe do aktywacji są hosty opisane
przez ich manifesty i sprzęt.

- output flake: `rog-polamaniec`,
- hostname: `rog-polamaniec`,
- konfiguracja: `hosts/rog-polamaniec/configuration.nix`,
- sprzęt: `hosts/rog-polamaniec/hardware-configuration.nix`,
- dodatkowe funkcje: Docker, gaming, nagrywanie, aplikacje osobiste i profil laptopa,
- diagnostyka GPU na żądanie jest wyłączona w manifeście, bo codzienne metryki
  zapewniają Ironbar i btop,
- opcjonalny benchmark schedulerów jest wyłączony, więc stress-ng,
  SuperTuxKart i schedulery testowe nie trafiają z jego powodu do codziennego
  closure,
- moduł GPU: `modules/hardware-amd-gpu.nix`,
- moduł laptopa: `modules/hardware-asus-laptop.nix`.

Laptop to ASUS ROG Zephyrus G14 GA402RK. Moduł AMD zapewnia grafikę i wczesne
ładowanie `amdgpu`. Niezależny moduł ASUS używa najnowszego jądra z przypiętego
`nixpkgs`, ładuje `asus-armoury` oraz uruchamia `asusd`; polecenie `asusctl`
i ROG Control Center są dostępne deklaratywnie. `asusd` wybiera profil
`Balanced` na zasilaczu i `Quiet` na baterii. Każdy profil ma osobną,
deklaratywną krzywą wentylatorów CPU i GPU, która rozpoczyna chłodzenie
wcześniej od ustawień firmware i dochodzi do pełnych obrotów przy 100°C.
`Performance` nie jest wymuszany na pulpicie. Pierwsza gra uruchomiona przez
GameMode przełącza go tymczasowo przez `asusctl`, używając wtedy najbardziej
agresywnej z trzech krzywych; po zamknięciu ostatniej gry wraca `Balanced` na
zasilaczu lub `Quiet` na baterii. Na zasilaniu AC ten profil stosuje maksima
zgłaszane przez firmware: 80 W dla APU i 115 W dla całej platformy. Na baterii
ręczny power tuning pozostaje wyłączony. Po
wczytaniu wartości początkowych `asusd` zapisuje tuning oraz krzywe jako swój
mutowalny stan; dalsze zmiany z ROG Control Center przetrwają restart usługi.

Flake automatycznie wystawia katalogi `hosts/<nazwa>/` zawierające `default.nix`
i własny `hardware-configuration.nix`.
Allowlista w `.gitignore` decyduje, które hosty i profile użytkowników mogą być
wersjonowane. Sekrety, hasła, profile Wi-Fi i klucze SSH pozostają poza repo.

## izakomp

Host `izakomp` używa własnego profilu i nakładki użytkownika, ale współdzieli
bazową konfigurację Cline. Ma włączony lokalny stos Ollamy. Agent Manager
pokazuje na nim `local-low`, `local-medium`, `local-high` oraz `codex`; nie
instaluje profili zdalnej farmy. `local-low` jest kierownikiem i może przez MCP
eskalować naprawdę trudne zadanie bezpośrednio do Codexa.

## ASUS Vivobook S 15 ze Snapdragonem

`hosts/armaniec/` jest przygotowany jako host `aarch64-linux` dla Vivobooka S
15 ze Snapdragonem X Elite. Używa profilu `home/wojtek`, który importuje
`home/base`, oraz
zewnętrznego modułu X Elite z device tree, kernelem, initrd i firmware dla tego
modelu. Obejmuje Ironbar, kompletną sesję Hyprlanda i narzędzia użytkownika,
w tym Zen Browser, Codex i GNU Make. Gaming, Docker, VR, nagrywanie, metryki
AMD oraz aplikacje opcjonalne pozostają wyłączone; host nie importuje modułów
AMD GPU ani ASUS ROG. Katalog celowo nie zawiera `hardware-configuration.nix`,
więc flake nie wystawi outputu, dopóki plik z własnymi UUID-ami nie zostanie
dodany na konkretnym laptopie. Instrukcja znajduje się w jego `README.md`.

## White Monster

`hosts/white-monster/` jest przygotowany dla desktopa z Radeonem RX 9070 XT.
Współdzieli profil `home/wojtek` importujący `home/base`: pulpit, tapety, aplikacje, Docker, gaming,
nagrywanie i przewodowy ALVR, ale ma `features.laptop = false` i nie importuje
modułu ASUS-a ani ustawień pokrywy. Do czasu wygenerowania na tym komputerze
jego własnego `hardware-configuration.nix` host pozostaje bezpiecznie pominięty
przez flake; dokładna komenda znajduje się w `hosts/white-monster/README.md`.

## Nowy host i użytkownik

1. Uruchom `make host-manager`; przy braku Gum i jq skrypt sam otwiera
   jednorazowy `nix shell`, bez instalowania zależności do systemu. W menu
   używaj `↑`/`↓` do wyboru, `→` lub Enter, aby przejść dalej albo przełączyć
   opcję, oraz `←` lub Esc, aby wrócić. Każda pozycja pokazuje krótki opis i
   aktualny stan.
2. Utwórz lub edytuj `hosts/<nowy-host>/host.json`, wybierając moduły i
   funkcje. Generator nie tworzy konfiguracji sprzętu.
3. Profil `home/base` jest wspólną bazą pulpitu dla kont. Profile użytkowników importują go; nie kopiuj bazy dla
   kolejnego użytkownika: wybierz go w managerze, a różnice sprzętowe i moduły
   zachowaj wyłącznie w `hosts/<host>/host.json`.
4. Dodaj nowy host i użytkownika do allowlist w `.gitignore`, a następnie do
   indeksu Git, ponieważ flake oparty na repo nie widzi plików nieśledzonych.
