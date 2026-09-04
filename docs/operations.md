# Obsługa systemu

Wszystkie polecenia należy uruchamiać z katalogu repozytorium.

## Walidacja

Ewaluacja wszystkich outputów flake:

```bash
nix flake check path:.
```

Pełny build laptopa bez aktywowania:

```bash
nix build path:.#nixosConfigurations.rog-polamaniec.config.system.build.toplevel
```

Użycie `path:.` uwzględnia wszystkie pliki robocze i działa również bez metadanych
Git. W zwykłym checkoutcie można używać także `.#...`.

## Aktywacja

Preferowana pierwsza próba, ważna do restartu:

```bash
sudo nixos-rebuild test --flake path:.#rog-polamaniec
```

Po ręcznym sprawdzeniu pulpitu, sieci, dźwięku i nagrywania:

```bash
sudo nixos-rebuild switch --flake path:.#rog-polamaniec
```

## Ollama

Moduł `modules/ollama.nix` włącza się wyłącznie przez `features.ollama = true`
w manifeście wybranego hosta i wymaga równoczesnego `features.docker = true`.
Po aktywacji umieszcza `compose.yaml` oraz krótkie `README.md` w
`~/Dev/Ollama`; nie uruchamia Dockera ani kontenerów. Wszystkie modele i dane
Open WebUI pozostają mutowalne w `~/Dev/Ollama/data/`.

Ręczny start jednego backendu GPU:

```bash
sudo systemctl start docker
cd ~/Dev/Ollama
make vulkan
# albo na obsługiwanym GPU AMD:
make rocm
```

Open WebUI jest dostępne w LAN pod `http://ADRES-LAN:3000`, a API wybranego GPU
pod `http://ADRES-LAN:11434`; adres hosta pokaże `hostname -I`. Profil `cpu`
można dodać równolegle; jego API działa na porcie `11435`. Vulkan jest
przenośnym fallbackiem, natomiast ROCm na nieobsługiwanym GPU należy traktować
jako eksperymentalny. Szczegóły zarządzania profilami znajdują się w
`~/Dev/Ollama/README.md`. Ollama i SearXNG nie mają uwierzytelniania, więc
porty LAN są przeznaczone wyłącznie dla zaufanej sieci.

Ten sam stos uruchamia też SearXNG w LAN pod `http://ADRES-LAN:8080`. Cache jest
w `~/Dev/Ollama/data/searxng/cache/`, a jego mutowalna konfiguracja w
`~/Dev/Ollama/data/searxng/config/settings.yml`. Pierwsze `make vulkan`,
`make rocm` albo `make cpu` tworzy ten plik z unikalnym 256-bitowym
`server.secret_key`; kolejne uruchomienia nie nadpisują konfiguracji ani sekretu.
Jeżeli zastaną oficjalny placeholder `ultrasecretkey`, bezpiecznie zastępują go
nowym sekretem. Istniejący plik bez żadnego `server.secret_key` powoduje błąd
zamiast cichego nadpisania potencjalnych ręcznych ustawień.
Plik pozostaje poza Nix store i Git. Open WebUI jest już skonfigurowane
zmiennymi Compose do korzystania z SearXNG: web search jest włączone, pobiera
najwyżej trzy strony po 12 000 znaków, `DEFAULT_MODEL_METADATA` udostępnia tę
funkcję modelom i ustawia ją jako ich domyślną funkcję, a
`DEFAULT_INTERFACE_SETTINGS` włącza ją w każdym nowym czacie i ustawia
domyślną regułę języka odpowiedzi. Konfiguracja
bazowa włącza też `search.formats: [html, json]`, więc endpoint wymagany przez
Open WebUI nie zwraca 403. Model korzystający z Native function calling sam
decyduje, czy i ile razy wyszukać; użytkownik może wyłączyć narzędzie tylko w
konkretnym czacie, gdy rozmowa ma pozostać offline.

SearXNG działa z UID i GID użytkownika wywołującego Make; na standardowym
NixOS dla `wojtek:users` jest to `1000:100`. `FORCE_OWNERSHIP=false` zapobiega
ponownemu przejmowaniu bind mountów przez kontenerowy UID 977. Po migracji ze
starszej konfiguracji napraw właściciela tylko danych SearXNG, a potem uruchom
stos ponownie:

```bash
cd ~/Dev/Ollama
make fix-searxng-permissions
make vulkan
```

Konfiguracja usuwa z odziedziczonego katalogu silniki `ahmia` i `torch`, które
w aktualnym obrazie nie rejestrują się poprawnie. Limiter instancji publicznych
jest wyłączony, ponieważ ten stos działa wyłącznie w zaufanym LAN-ie i nie ma
Valkey. Pusty `limiter.toml` jest obejściem ostrzeżenia emitowanego przez SearXNG
nawet przy wyłączonym limiterze. CAPTCHA lub `Too Many Requests` z pojedynczego
silnika nie oznacza awarii całego SearXNG: silnik jest czasowo zawieszany, a
wyniki zwracają pozostałe źródła.

Open WebUI zapisuje ustawienia administratora typu ConfigVar w swojej bazie,
więc same ENV są seedem pierwszego startu. `make apply-webui-defaults` wykonuje
deklaratywną synchronizację wyłącznie globalnych ustawień należących do stosu:
SearXNG, WWW, streaming, Native function calling, kompaktowanie oraz parametry
zadań. Polecenie następnie restartuje tylko Open WebUI. Nie usuwa ani nie
zmienia kont, czatów, pobranych modeli, ręcznie utworzonych modeli ani połączeń
API. Przed restartem wypisuje diff wyłącznie synchronizowanych kluczy; nie
wyświetla sekretów ani danych ręcznie konfigurowanych połączeń.

Wszystkie kontenery Ollamy dostają domyślny kontekst 16k, Flash Attention i
8-bitowy cache KV. Native function calling jest domyślnym i wspieranym trybem
Open WebUI; nie włączaj Legacy. Dla agentowych wywołań narzędzi wybieraj model
z prawdziwą obsługą structured tool calls — małe modele mogą zwracać
niepoprawne wywołania. `DEFAULT_MODEL_PARAMS` włącza też strumieniowanie
odpowiedzi domyślnie (`stream: true`) i celowo nie ustawia `max_tokens`.
Ominięcie opcjonalnego pola pozostawia modelowi decyzję o zakończeniu odpowiedzi;
twardą granicą nadal jest jego okno kontekstu 16k współdzielone przez prompt,
historię, narzędzia i wynik. Limit `1200` dotyczy wyłącznie pomocniczego modelu
zadań Open WebUI. Parametry można nadpisać dla modelu lub pojedynczego czatu.

Context Compaction jest włączony: przy około 11k tokenów Open WebUI streszcza
starsze tury, zachowując ostatnie 40% wiadomości dosłownie. Pełna historia
pozostaje w GUI, a kompaktowanie zmienia tylko kontekst wysyłany do modelu.
Próg pozostawia miejsce w 16k dla system promptu, narzędzi, wyników SearXNG i
odpowiedzi. Streszczenia używają modelu zadań Open WebUI; dla krytycznych,
długich rozmów ustaw w GUI mocniejszy task model niż mały lokalny worker.

Globalne ustawienia konta zawierają prompt nakazujący odpowiadać w języku
ostatniej wiadomości użytkownika, więc polskie pytania dostają polskie
odpowiedzi mimo angielskich wyników wyszukiwania. Kod, polecenia, logi, nazwy API
i identyfikatory pozostają w oryginalnej formie. Prompt modelu utworzonego przez
administratora w Workspace ma wyższy priorytet i może tę regułę zastąpić.

## PoC Neovima z Kickstart

`nvim-kickstart` korzysta z osobnego `NVIM_APPNAME`, więc nie modyfikuje
zwykłego `~/.config/nvim` ani jego pluginów. Przy pierwszym uruchomieniu tworzy
zapisywalny katalog `~/.config/nvim-kickstart` z wersji Kickstart przypiętej w
`flake.lock`. Kolejne aktualizacje inputu nie nadpisują tego katalogu, aby nie
niszczyć lokalnych zmian przygotowywanych do przyszłego repozytorium.

Po pierwszym starcie sprawdź `:checkhealth`. Pełne usunięcie PoC wymaga usunięcia
osobnych katalogów `nvim-kickstart` z `~/.config`, `~/.local/share`,
`~/.local/state` i `~/.cache`; zwykły profil Neovima pozostaje wtedy nietknięty.

## Zespół agentów w Agent Managerze

Uruchom panel z terminala:

```bash
agent-manager
```

Na farmie wybierz jako sesję główną `rog-polamaniec-off`; na hoście lokalnym
jest to `local-off`. To kierownik na Qwenie 3.5 9B bez thinking, który sprawdza
`ollama-farm-status` i tworzy przez MCP widoczne workery. ROG oferuje profile
`off` i `thinking`; po skonfigurowaniu White Monstera z Qwenem 3.8 27B
dostępne będą `white-monster-off`, `white-monster-low`,
`white-monster-medium` i `white-monster-xhigh`. Trudne zadanie trafia najpierw do White Monstera, a
Codex jest używany dopiero, gdy większy model lokalny nie wystarczy lub jest
niedostępny. Routowanie i podsumowania nie zużywają tokenów Codexa.

Zwykłe polecenie `cline` pozostaje skrótem terminalowym do lokalnego profilu
`off`, ale celowo nie pojawia się jako kolejna pozycja w Agent Managerze.

Na `izakomp` panel pokazuje wyłącznie `local-off`, `local-thinking` i `codex`;
nie instaluje zdalnej farmy. Model zmienisz przez `OLLAMA_LOCAL_MODEL` w
`~/.config/ollama-router/hosts.env`.

Wszystkie profile Cline/Ollama i Codex odpowiadają w języku ostatniego
żądania użytkownika. Manager wpisuje ten język jawnie do zadań delegowanych,
aby angielskie instrukcje techniczne workera nie zmieniły języka odpowiedzi.

Każda widoczna sesja może przez MCP Agent Managera wywołać `create_session`;
parametr `tool` wybiera launcher i backend modelu, a nie drugi serwer MCP.
Rodzic zachowuje odpowiedzialność za przegląd i integrację wyniku dziecka.
Polecenie pracy wyłącznie lokalnej zabrania managerowi uruchamiania Codexa. Po
błędzie limitu Codexa ani manager, ani White Monster nie ponawiają go i
kontynuują na osiągalnych workerach lokalnych, wskazując ewentualne ograniczenia.
Limitu nie da się pewnie sprawdzić przed uruchomieniem sesji, a kontekst nie jest
automatycznie przenoszony pomiędzy różnymi CLI.

White Monster z 9070 XT jest preferowany dla większego modelu lub dłuższego
kontekstu. Dla trudnego zadania jest obowiązkowym pierwszym stopniem eskalacji,
jeśli endpoint i skonfigurowany model są dostępne; opóźnienie sondy wpływa tylko
na wybór hosta dla pracy rutynowej.

Przed uruchomieniem panelu skonfiguruj na swoim koncie
`~/.config/ollama-router/hosts.env` z trwałymi adresami LAN i modelami faktycznie
pobranymi na każdym hoście:

```bash
OLLAMA_ROG_BASE_URL=http://192.168.1.10:11434
OLLAMA_ROG_MODEL=qwen3.5:9b
OLLAMA_WHITE_MONSTER_BASE_URL=http://192.168.1.20:11434
OLLAMA_WHITE_MONSTER_MODEL=Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp:latest
```

Adres ROG-u jest interpretowany wewnątrz kontenera LiteLLM. Dla Ollamy z tego
samego pliku Compose użyj `OLLAMA_ROG_BASE_URL=http://ollama:11434`; skrypt
migracyjny zamienia na tę wartość starszy lokalny adres `127.0.0.1`.

`make vulkan`, `make rocm` i `make cpu` uruchamiają także lokalny LiteLLM na
`http://127.0.0.1:4000/v1`. Target `init-litellm-env` tworzy prywatny plik, jeśli
go brakuje, oraz migruje starsze zmienne `OLLAMA_*_URL` kończące się `/v1` do
wartości `OLLAMA_*_BASE_URL` wymaganych przez natywne API Ollamy. Lista aliasów
jest dostępna pod `/v1/models`; port 4000 nie jest wystawiony do sieci LAN.
Po zmianie modelu lub adresu wykonaj `make restart-litellm`, ponieważ zwykły
restart kontenera nie wczytuje ponownie jego zmiennych środowiskowych.

Pobierz model do aktualnie uruchomionego kontenera Ollamy:

```bash
cd ~/Dev/Ollama
make pull MODEL=qwen3.5:9b
```

Target wybiera działającą usługę w kolejności Vulkan, ROCm, CPU. Gdy uruchomione
są równocześnie GPU i CPU, model trafia do wariantu GPU; gdy żadna Ollama nie
działa, polecenie kończy się czytelnym błędem.

LiteLLM wystawia Qwena 3.5 jako aliasy `off` / `thinking`, a Qwena 3.8 jako
`off` / `low` / `medium` / `xhigh`. Każdy alias wymusza natywny parametr
`think` Ollamy i odrzuca `reasoning_effort` przesłany przez klienta. Cline nie
pokazuje więc drugiego, mylącego selektora Thinking. Launcher używa wbudowanego
providera `litellm`, który pobiera aliasy z `/v1/models`; w samodzielnej sesji
poziom zmienisz przez `/model`, bez utraty historii i kontekstu.

### MCP w Cline

Każdy profil Cline dostaje Agent Manager, lokalny `searxng`, zdalny `context7`
oraz Playwright. SearXNG zwraca maksymalnie pięć skróconych wyników. Playwright
jest zarejestrowany, ale domyślnie wyłączony; włącz go w ekranie MCP Cline tylko
na czas zadania wymagającego prawdziwej przeglądarki. Nie ma osobnych launcherów
dla dodatkowych serwerów MCP.

### Poziom reasoning Qwen3.8 w Open WebUI

`Reasoning Tags` modelu służą tylko do zwijania `<think>...</think>`; nie
ustawiają intensywności reasoning. Zainstalowana ręcznie Function
[Reasoning Effort Selector](https://openwebui.com/posts/reasoning_effort_selector_ee572967)
zapewnia właściwy parametr Qwen3.8. To zewnętrzny kod Python wykonywany przez
Open WebUI, dlatego przed aktualizacją należy przeczytać jego źródło w GUI.

Function jest potrzebna tylko przy awaryjnym, bezpośrednim połączeniu z Ollamą.
Dla modeli z LiteLLM wybierz alias `white-qwen38-off`, `-low`, `-medium` albo
`-xhigh` i nie przypinaj Function do modelu: alias jest źródłem prawdy.

Ustaw ją raz jako filtr domyślny, aby nie wybierać jej przy każdej wiadomości:

1. `Workspace -> Functions`: włącz `Reasoning Effort` i w menu `...` aktywuj
   ikonę globu.
2. `Workspace -> Models -> <Qwen3.8> -> Filters`: zaznacz `Reasoning Effort`.
3. W `Default Filters` wybierz `Reasoning Effort` i rozpocznij nowy czat.
4. W Valve/ustawieniach Function ustaw `low` jako domyślne.

Qwen3.8 rozumie tylko `low`, `medium` i `xhigh`; `high` nie jest jego poziomem.
Wybór wpływa na kolejną wiadomość, a nie na już zakończone odpowiedzi.

Plik jest celowo lokalny i mutowalny: modele, adresy i sprzęt różnią się między
hostami. `ollama-farm-status` mierzy tylko osiągalność, krótki czas API i listę
już załadowanych modeli; nie widzi kolejki tokenów, więc nie gwarantuje czasu
całej odpowiedzi. Worker ma zgłosić timeout/przeciążenie, a rodzic może wtedy
ponowić małą, ograniczoną próbę na innym hoście — nie uruchamiaj równolegle tych
samych zmian tylko po to, aby „ścigać” hosty.

Farmę można uruchamiać etapami. Host bez działającego endpointu albo pobranego
modelu pojawi się jako `unavailable` i nie może zostać wybrany. Przy samym
ROG-u kierownik pracuje tylko lokalnie; Armaniec nie jest obecnie aktywnym
profilem ani kandydatem do delegowania.

Najważniejsze operacje w panelu:

- `n` tworzy sesję; jako korzeń wybierz `rog-polamaniec-off` lub `local-off`,
- `Enter` otwiera zaznaczoną sesję, a `Ctrl+Q` wraca do panelu,
- `Space` wysyła wiadomość bez przełączania sesji,
- `Ctrl+R` otwiera przegląd zmian workera,
- `x` zatrzymuje sesję z zachowaniem rekordu, a `v` ją wznawia,
- `q` zamyka tylko panel; sesje nadal działają w prywatnym serwerze tmux.

Po aktywacji sprawdź ręcznie, że `rog-polamaniec-off` widzi serwery MCP,
domyślnie tworzy lokalne workery, a trudne zadanie najpierw przekazuje do
`white-monster-xhigh`. White Monster powinien móc utworzyć `codex`; po jego
wyłączeniu kierownik powinien dla trudnego zadania móc utworzyć Codexa
bezpośrednio. Każdy rodzic powinien czekać na wynik i pokazywać status oraz diff.
Logowanie Codexa i limity konta są współdzielone z normalnym CLI, ale nie mają
wpływu na sesje Cline/Ollama. Konfiguracja nie zapisuje tokenów ani danych
uwierzytelniających w repozytorium.

Gdy `features.ollamaFarm = true`, selektor zawiera dwa profile ROG i cztery
profile White Monstera. LiteLLM pobiera adresy i modele z `hosts.env`; wybór
narzędzia przy tworzeniu sesji określa backend i stały tryb thinking. Cline udostępnia
Agent Managera bezpośrednio jako własny MCP, więc
kierownik może tworzyć workery na farmie, a White Monster może oszczędnie
delegować nierozwiązane trudne zadanie do Codexa. Open WebUI można podłączyć ręcznie przez jego
API zgodne z OpenAI pod `http://ADRES-LAN:3000/api` i osobny klucz API
użytkownika; nie zapisuj klucza w Nix ani Git.

Agent Manager 0.33 zawsze dodaje wbudowany wpis `opencode`. Konfiguracja
przekierowuje go bezpiecznie do `rog-polamaniec-off` (lub `local-off`), lecz
nie instaluje OpenCode. Alias ukryj raz przez `s -> CLIs`, odznaczając
`opencode`; do nowych sesji używaj wyłącznie profili aliasów LiteLLM.
Cline przechowuje historię we własnym katalogu `~/.cline/`; launchery izolują
tylko bieżące ustawienia providera i MCP, nie bazę sesji.
Samo `q` lub `Ctrl+Q` nie zatrzymuje sesji tmux i nie powoduje utraty kontekstu.

Wersja Agent Managera jest przypięta razem z oficjalnym hashem, aby build i
rollback były powtarzalne. Aktualizacja do najnowszego taga sprowadza się do:

```bash
update-agent-manager
```

Polecenie należy uruchomić z katalogu repozytorium. Odczytuje `releases/latest`,
pobiera archiwum i oficjalne `checksums.txt`, weryfikuje SHA-256, aktualizuje
wersję oraz hash w module i pokazuje diff. Nie buduje ani nie aktywuje systemu;
po przejrzeniu zmian należy użyć zwykłych poleceń walidacji z początku dokumentu.

## Generacje i garbage collection

Lista zachowanych generacji systemu:

```bash
make generations
```

Usunięcie starszych generacji oraz nieosiągalnych ścieżek z `/nix/store`, z
pozostawieniem czterech ostatnich generacji do bieżącej:

```bash
make gc KEEP=4
```

Parametr `KEEP` musi być dodatnią liczbą całkowitą. Jeśli aktywna jest starsza
generacja po rollbacku, Nix zachowuje również generacje nowsze od niej. GC nie
usuwa ścieżek nadal używanych przez inne profile lub pozostałe korzenie GC.
Usuniętych generacji nie można już wybrać podczas bootowania ani użyć do
rollbacku.

## Aktualizacja zależności

```bash
nix flake update
nix flake check path:.
nix build path:.#nixosConfigurations.rog-polamaniec.config.system.build.toplevel
```

Zmiany `flake.lock` należy przejrzeć przed aktywacją.

## Diagnostyka Hyprlanda

```bash
hyprctl configerrors
hyprctl version
hyprctl monitors
```

Centrum skrótów jest dostępne pod `Super+F1`. Poszczególne sekcje można
sprawdzić również z terminala, np. przez `shortcut-menu capture` albo
`shortcut-menu all`.

## Diagnostyka usług użytkownika

```bash
systemctl --user status hypridle.service
journalctl --user -u hypridle.service -b
systemd-inhibit --list
hyprctl clients -j | jq -r '.[] | select(.inhibitingIdle == true) | [.class, .title] | @tsv'
pgrep -a gsr-ui
gsr-ui-cli --help
```

Bezpośrednio po zalogowaniu `pgrep -a gsr-ui` nie powinno nic zwrócić. Użycie
`Alt+Z`, `Super+G`, `Super+Shift+R` albo `Super+R` uruchamia UI na żądanie.

Natychmiastowe przejście do następnej tapety bez czekania na timer:

```bash
systemctl --user start rotate-wallpaper.service
```

Pierwsza tapeta w nowej sesji powinna rozwinąć się okręgiem od środka. Kolejne
wywołania przeplatają `wave`, `grow`, `wipe` i `outer`, zmieniając kierunek,
punkt startu oraz geometrię fali bez zwykłego `fade`. Rotator odczytuje
geometrię każdego aktywnego wyjścia z `hyprctl monitors -j`: 16:9 wybiera
`wallpapers/16x9`, około 3440:1440 wybiera `wallpapers/21x9`, a 32:9 wybiera
`wallpapers/32x9`. Każdy monitor otrzymuje ten sam indeks sceny i własną pełną
częstotliwość przejścia.

Stan przenośnego, kompresowanego swapu po aktywacji:

```bash
zramctl
swapon --show
```

W sekcji pamięci Ironbara trzy słupki oznaczają kolejno użycie RAM, zapełnienie
ZRAM (ikona archiwum ``) i faktyczną oszczędność pamięci dzięki kompresji
(ikona kompresji ``). Najechanie pokazuje również rozmiar logiczny i fizyczny,
współczynnik oraz algorytm kompresji; wartości powinny odpowiadać licznikom
widocznym w `zramctl`.

Źródło zasilania wykryte bez zależności od nazw urządzeń oraz wynikowy limit
FPS wygaszacza:

```bash
power-source-state
screensaver-refresh-rate
```

Na baterii drugie polecenie zwraca najwyżej `60`; na zasilaniu zewnętrznym
zwraca pełną częstotliwość aktywnego monitora.

## Gry i responsywność pod obciążeniem

Stan schedulera SCX po restarcie do nowej generacji:

```bash
systemctl status scx.service
cat /sys/kernel/sched_ext/state
journalctl -u scx.service -b
```

Usługa powinna uruchamiać `scx_bpfland`, a stan kernela powinien wynosić
`enabled`. Jeżeli scheduler użytkowy zakończy się błędem, mechanizm `sched_ext`
oddaje zadania standardowemu schedulerowi kernela; log usługi pozostaje źródłem
przyczyny. Moduł używa wyłącznie rustowego wariantu pakietu SCX i jest aktywny
tylko na hostach z `features.gaming = true`.

GameMode działa na żądanie. Jego integrację można sprawdzić przez:

```bash
gamemoded -t
```

Dla gry bez natywnej integracji należy wpisać w jej opcjach uruchamiania Steam:

```text
gamemoderun %command%
```

Pełna instrukcja dla Steam, Proton, Gamescope i diagnostyki znajduje się w
[tutorialu GameMode](gaming.md).

Podczas działania gry GameMode nada jej priorytet `nice -10` i najwyższy
priorytet I/O, przełączy governor CPU oraz profil platformy na `performance`
i zablokuje wygaszacz. Zmiany są ograniczone czasem życia klienta GameMode;
po wyjściu z ostatniej gry daemon przywraca poprzedni stan. Konfiguracja nie
włącza podkręcania ani ręcznego poziomu wydajności GPU.

Buildy Nix działają z polityką CPU i klasą I/O `idle`. Dzięki temu pulpit i gra
zachowują pierwszeństwo przy jednoczesnym obciążeniu, ale build może wtedy trwać
dłużej, a pod stałym pełnym obciążeniem nawet okresowo czekać. Ustawienia ZRAM
można potwierdzić poleceniem:

```bash
sysctl vm.swappiness vm.page-cluster
```

Oczekiwane wartości to odpowiednio `100` i `0`.

## Historia schowka

Stan Rustowego watchera Stash i rozmiar historii można sprawdzić bez zmiany
danych:

```bash
systemctl --user status stash-clipboard.service
stash db stats
```

`Super+Shift+V` powinno pokazać tekst oraz opisy zapisanych obrazów, skopiować
wybrany wpis z powrotem do schowka i wkleić go do aktywnego okna.

## Minimalna kontrola po aktywacji

1. Otworzyć Foot przez `Super+Enter`.
2. Sprawdzić launcher, aktywny panel i powiadomienia. Otworzyć Wleave przez
   `Super+Escape` i zamknąć je przez `Esc`.
3. Otworzyć aplikację GTK3 i GTK4, potwierdzając ciemny motyw.
4. Przetestować historię schowka przez `Super+Shift+V`.
5. Sprawdzić głośność, mikrofon, Bluetooth i klawisze multimedialne.
6. Potwierdzić brak `gsr-ui` po logowaniu, włączyć replay pierwszym skrótem,
   zapisać klip i sprawdzić trzy ścieżki audio.
7. Najechać na każdą grupę metryk, przytrzymać kursor i następnie go odsunąć,
   przejść kursorem z wyspy do samego popupu, a następnie odsunąć go poza oba
   obszary; szczegóły nie mogą migać ani zamknąć się podczas przejścia i powinny
   zniknąć po około 180 ms od faktycznego opuszczenia; pozostawienie kursora nad
   metryką przez co najmniej kilka sekund nie może tworzyć cyklu pokaż–schowaj,
   a bieżące wartości powinny zmieniać się w popupie co około 2 sekundy;
   sprawdzić wyśrodkowanie cyfr pulpitów oraz osobne miejsce dzwonka i licznika
   przy co najmniej jednym powiadomieniu.
8. Sprawdzić `Print`, `Super+Shift+S` oraz zapis i kopiowanie z Satty; na
   laptopie hybrydowym dGPU powinno pozostać uśpione także podczas edycji.
9. Otworzyć `about:policies` w Zen i potwierdzić Dark Reader oraz Bitwarden na
   pasku narzędzi i w prywatnym oknie.
10. Po zamknięciu i ponownym uruchomieniu Zen sprawdzić Biscuit w interfejsie,
    nowej karcie oraz `about:preferences`; profil powinien zachować historię,
    zakładki i poprzednią sesję, ale nie wybrane karty powinny pozostać
    niezaładowane. Przy otwartym Zen `Super+B` ma fokusować jego ostatnio używane
    okno także z innego pulpitu, a po pełnym zamknięciu uruchomić nowy proces.
11. W Yazi sprawdzić `f`, `g c` w repozytorium oraz `Ctrl+D` po zaznaczeniu
    jednego pliku i wskazaniu drugiego.
12. Najpierw uruchomić wygaszacz przez `Super+Ctrl+S`, potwierdzić, że pozostaje
    widoczny, a następnie zamyka się po klawiszu, ruchu albo kliknięciu myszy.
    Przy wyłączonym Caffeine potwierdzić jego automatyczny start po 5 minutach,
    animację od 5. do 10. minuty, blokadę po 10 minutach i DPMS sekundę później
    na dowolnym zasilaniu oraz
    suspend po 30 minutach wyłącznie na baterii. Na zasilaczu automatyczny
    suspend nie może wystąpić; po włączeniu Caffeine cała sekwencja ma pozostać
    zablokowana. Podczas wygaszacza sprawdzić w `pgrep -af tte`, że na baterii
    używa `--frame-rate 60`, a po podłączeniu zasilacza kolejny efekt wraca do
    pełnej częstotliwości monitora.
13. Na laptopie sprawdzić `display-power-refresh status`, odłączyć zasilacz i
    potwierdzić przez `hyprctl monitors`, że matryca przeszła na 60 Hz. Po
    ponownym podłączeniu zasilacza ma automatycznie wrócić do najwyższego trybu
    tej samej rozdzielczości, obecnie 120 Hz.
14. Po docelowym `switch` i restarcie potwierdzić jednosekundowe menu
    systemd-boot; `nixos-rebuild test` nie instaluje tej zmiany na następny boot.
15. Po restarcie sprawdzić aktywny `scx_bpfland`, uruchomić `gamemoded -t`, a
    następnie porównać tę samą grę z `gamemoderun %command%` i bez niego;
    obserwować przede wszystkim płynność i 1% low, nie tylko średni FPS.
