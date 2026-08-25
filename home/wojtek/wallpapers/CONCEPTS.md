# Kolekcja Biscuit OLED v3 — storyboard 22 scen

To jest całkowicie nowa kolekcja. Nie dziedziczy kadrów, promptów ani ocen z
v2. Najpierw zatwierdzamy storyboard, potem generujemy źródła. Obraz staje się
aktywną tapetą dopiero po ocenie kompozycji, masteringu i utworzeniu wszystkich
trzech proporcji.

## Kontrakt wizualny

- Źródło powstaje jako prawdziwe `4:1` w najwyższej natywnej jakości. Z niego
  tworzymy prawostronny master `5120×1440`, a następnie prawostronne cropy
  `3440×1440` i `2560×1440`. Nie rozciągamy obrazu i nie dodajemy pasów.
- Wszystkie twarze, dłonie, działania i istotne rekwizyty tworzą zwartą grupę
  naturalnie przesuniętą na prawo od środka, z zapasem wewnątrz cropu 16:9.
  Prompt nie dzieli płótna na procentowe strefy: opisuje jeden kadr, jedną
  perspektywę i spokojniejsze przedłużenie tej samej lokacji przez całą szerokość.
- 16:9, 21:9 i 32:9 są trzema oknami na jeden świat. Foreground, midground i
  background kontynuują perspektywę, geometrię oraz skalę aż do lewego brzegu.
  Te same źródła światła dają po lewej słabszy bounce, AO i cienie kontaktowe.
  Nie wolno ukrywać braku scenografii czarną zasłoną, gradientem, rozmyciem,
  pionową granicą, powielonym tłem ani wielkim obiektem zasłaniającym płótno.
- OLED jest projektowany już w generatorze: około 35–50% organicznego
  `#000000` w prześwitach architektury, wnękach, wodzie, lesie, rackach,
  szczelinach i głębokiej okluzji. Czerń nie może być pustym niebem,
  prostokątem ani doklejoną połową obrazu.
- Cienie zachowują objętość dzięki ambient occlusion, cieniom kontaktowym i
  lokalnemu bounced light. Pierwszy widoczny cień to Biscuit `#1A1515`;
  kolejne poziomy to `#2D2424` i `#453636`.
- Małe akcenty korzystają wyłącznie z Biscuit: krem `#DCC9BC`/`#FFE9C7`,
  bursztyn `#E39C45`, pomarańcz `#F07342`, zieleń `#768F80`, fiolet
  `#756D94`, róż `#AE3F82` i czerwień `#CF223E`. Bez szerokiego niebieskiego
  neonu, białych powierzchni i świecącego nieba.
- Górne około 8% jest spokojną częścią prawdziwego otoczenia pod Ironbar:
  stropem, gałęziami, mgłą, skałą albo rackiem. Nigdy osobnym szarym paskiem.
- Postacie nazwane zachowują domyślny, rozpoznawalny wygląd i strój ze swojego
  anime lub gry. Nie robimy „ulepszonych” seksualizowanych wariantów.
  Bohaterowie autorscy są w pełni ubrani, charakterystyczni i praktyczni.

## Co uznajemy za dobry easter egg

Easter egg ma sens fabularny nawet wtedy, gdy widz nie zna technologii.
Najpierw powstaje scena, potem ukryty detal — nigdy odwrotnie.

- Jedna scena ma jedną główną metaforę techniczną i niewielką liczbę
  wielofunkcyjnych kotwic wizualnych z tego samego problemu. Jedna kotwica może
  reprezentować kilka etapów procesu, ale nie może dodawać niezależnego produktu.
- Budżet kadru to maksymalnie trzy główne rekwizyty techniczne, jeden czytelny
  obiekt przepływu, 2–5 krótkich etykiet i dokładnie jeden crossover. Dłuższy
  łańcuch kompresujemy w sekcje tej samej maszyny, bramy albo drogi; nie
  dokładamy osobnego pudełka dla każdej nazwy z mapy.
- System musi dotyczyć bohatera. Jedna czytelna emocja pokazuje incydent i
  zmianę stanu: frustrację przy konflikcie lub czerwonych testach, skupienie
  podczas naprawy i ulgę przy zdrowym wyniku. Unikamy postaci pozujących obok
  technicznego diagramu, na który nie reagują.
- Narzędzia tworzą związek przyczynowy. Przykład: Pi-hole przechwytuje reklamy,
  resolver używa portu 53, TTL jest klepsydrą cache, a DNSSEC zamyka łańcuch
  zaufania. To jedna historia, nie lista produktów.
- Tekst występuje tylko tam, gdzie naturalnie istnieje: na krótkim ekranie,
  etykiecie portu, kasecie, kontrakcie, tabliczce urządzenia albo grzbiecie
  księgi. Bez unoszących się słów, losowych cyfr, strzałek i „rebusów”.
- Logo nie jest ozdobą. Jeśli urządzenie można rozpoznać po kształcie lub
  działaniu, logo pomijamy. W razie konfliktu usuwamy easter egg, a nie
  bohatera, kompozycję lub światło.
- Każda scena ma dokładnie jeden dyskretny crossover między światami: tapetę
  na ekranie, brelok, grawer, figurkę, szkic, plakat, wzór na tarczy albo
  przedmiot osobisty. Nie może wyglądać jak naklejony losowo obraz.
- Żółta gumowa kaczka i małe `w.` mogą wracać jako podpis kolekcji, ale tylko
  wtedy, gdy naturalnie pasują do warsztatu, biurka albo ekwipunku.

## Podział kolekcji

| Sekcja | Numery | Język wizualny |
|---|---:|---|
| Frieren | 01–06 | premium anime/concept art, kanoniczne postacie i stroje |
| Wiedźmin 3 | 07–10 | styl gry, materiały i kamera jak w wysokiej jakości cutscence |
| Palworld | 11–13 | oficjalny język gry: anime 3D, Palbox, baza i specjalizacje Pali |
| V Rising | 14–16 | oficjalny język gry: izometria, gotyk, Castle Heart i zarządzanie domeną |
| Valheim | 17–19 | oficjalny język gry: low-poly, malowane materiały, survival i pogoda |
| Chainsaw Man | 20–22 | oficjalny język anime/mangi, kanoniczne postacie i Public Safety |

## Role zaczerpnięte z realnego homelabu

Sceny korzystają z istniejącego i docelowego podziału odpowiedzialności, ale nie kopiują
adresów, sekretów ani ekranów administracyjnych. Forgejo przechowuje Git,
Woodpecker wykonuje CI, Traefik terminuje TLS i kieruje ruch, Semaphore uruchamia
Ansible, Proxmox tworzy VM, Ceph utrzymuje replikowane dane, a PBS odpowiada za
backup i restore. Prometheus/Grafana odpowiadają za observability. Glance jest
tylko pasywną startpage z kaflami, linkami i prostymi checkami — nigdy źródłem
telemetrii, korelacji, alertu ani sterowania.

Media stack dzielimy na dwa kadry. Intake to Overseerr → Sonarr/Radarr →
Prowlarr → qBittorrent. Playback to gotowa biblioteka → Bazarr → Plex →
Tautulli. Dzięki temu role są poprawne, a żadna tapeta nie musi zmieścić ośmiu
paneli naraz.

## Mapa spójnych przepływów

To jest źródło prawdy dla easter eggów technicznych. Każda tapeta pokazuje
jeden mały, domknięty wycinek systemu w maksymalnie czterech widocznych
przejściach. Nie próbujemy opowiedzieć całego SDLC ani całej platformy jednym
obrazem. Nazwa technologii bez roli w wybranym łańcuchu jest błędem.

| Nr | Jeden system story od początku do końca |
|---:|---|
| 01 | podpisany tag + `flake.lock` → build Nix → podpisany artefakt w cache |
| 02 | konflikt i czerwony test → krótka gałąź do `main` → feature flag dla canary → `flag off` przy regresji |
| 03 | zapytanie → Pi-hole → walidujący resolver z TTL → odpowiedź albo blokada |
| 04 | utracony ref → reflog → gałąź `rescue` → podpisane odzyskanie |
| 05 | manifest GitOps → Flux reconcile → scheduling + volume → `Ready` i ruch usługi |
| 06 | awaryjne `vi`/`nano` → Neovim z LSP/testem → diff i commit; GUI IDE zostają opcją sytuacyjną |
| 07 | przejęty artefakt → lokalne SHA-256 → zgodność dopuszcza, niezgodność kwarantannuje |
| 08 | request z OTel → wspólny przyrząd metryk/logów/trace → issue Sentry → fix i zielona weryfikacja |
| 09 | żądanie dostępu → Authentik + MFA → krótki token o małym scope → dostęp albo wygaśnięcie |
| 10 | podejrzany plik → wspólne YARA/Sigma/host evidence → korelacja → izolacja i zabezpieczenie dowodu |
| 11 | czerwony stan Proxmox/Ceph → decyzja operatora → fencing węzła → quorum utrzymuje VM i dane |
| 12 | request Overseerr → wybór Sonarr/Radarr → wyszukanie Prowlarr → pobranie qBittorrent |
| 13 | HTTP → brama API/Traefik → Laravel Octane/FrankenPHP + Redis/PostgreSQL → odpowiedź |
| 14 | ACME challenge → wydanie pełnego chain → Traefik HTTPS `443` → status i odnowienie |
| 15 | PgBouncer → primary + replica → fence/promote → nowe połączenia do zdrowego primary |
| 16 | push do Forgejo → Woodpecker test + build/SBOM → podpisany artefakt w registry → `latest` odrzucone |
| 17 | import FAT/exFAT/NTFS/APFS → wybór ext4/Btrfs/ZFS → checksum, snapshot albo scrub |
| 18 | snapshot → PBS z retencją/offsite → izolowany restore → checksum i test usługi |
| 19 | Git + OpenTofu plan → Proxmox VM → Semaphore/Ansible → test i korekta driftu |
| 20 | lockfile/SBOM → skan → patch i rebuild → ponowny skan |
| 21 | sekret IaC w Git/logu → revoke → rotate → SOPS/age szyfruje nową wartość |
| 22 | gotowy plik → Bazarr dopina napisy → Plex transkoduje/odtwarza → Tautulli obserwuje sesję |

## I. Frieren — 01–06

### 01. `moonless-root-archive`

Frieren w swoim rozpoznawalnym biało-złotym stroju otwiera korzeniowe archiwum
pod opactwem. Mechanizm zamka ma sześć ramion Nix, a katalog artefaktów jest
małym drzewem Git: podpisany tag wskazuje niezmienny wpis, podczas gdy luźna
gałąź prowadzi do błędnej wersji. Nie potrzebujemy ściany komend.

- Technika: Nix + Git, niezmienność i podpisany artefakt.
- Crossover: wilczy medalion z Wiedźmina tworzy osłonę mosiężnego klucza.
- Kadr: lampka Frieren i zamek po prawej; łuki i korzenie wypełniają lewą czerń.

### 02. `canary-over-silent-bridge`

Frieren, Fern i Stark prowadzą jedno wydanie przez stary most. Stark jest
przybity przy splątanym, zbyt długo żyjącym rusztowaniu: ma konflikt i czerwony
test. Fern sprowadza zmianę do krótkiej gałęzi i scala ją ze wspólnym pniem
`main`. Złoty ptak reprezentuje małą kohortę canary, a fizyczna feature flag
otwiera jej nową funkcję. Gdy stan znów robi się czerwony, Frieren opuszcza
flagę i natychmiast odcina regresję bez cofania całego wdrożenia.

- Technika: trunk-based development, konflikt/test, canary feature flag i
  szybki rollback przez `flag off`.
- Crossover: niewielki brelok Pal Sphere przy pasie topora Starka.
- Tekst wyłącznie na tabliczkach `main`, `test` i `flag`.

### 03. `dns-of-the-old-stars`

Frieren i Fern pracują w starym obserwatorium-resolverze. Kamienna studnia
Pi-hole pochłania papierowe reklamy i trackery, podczas gdy poprawne pakiety
przechodzą do mechanicznej sfery DNS. Klepsydra pokazuje czas cache, a zamknięty
łańcuch gwiazd jest DNSSEC.

- Technika: Pi-hole, resolver, port 53, TTL i DNSSEC — wyłącznie ten stos.
- Crossover: mała figurka Pochity służy jako przeciwwaga teleskopu.
- Wymóg: reklamy muszą fizycznie wpadać do Pi-hole; nie wystarczy napis.

### 04. `reflog-by-river-stones`

Frieren odzyskuje z ciemnej rzeki kamień utraconej historii, Fern utrzymuje
pieczęć poprawnej gałęzi, a Stark buduje stabilny brzeg. Kolejne kamienie
naturalnie pokazują reflog; ślepa droga `reset --hard` znika pod wodą.

- Technika: reflog, odzyskanie commita, nowa gałąź i podpisany tag.
- Crossover: w mokrym kamieniu odbija się mała korona cienia z Solo Leveling.
- Tekst ograniczamy do kilku krótkich oznaczeń na kamieniach.

### 05. `familiar-cluster-gate`

Frieren przekazuje krótki manifest do znajomego Flux, który uzgadnia go z
lekkim klastrem K3s. Kontroler kieruje zadanie do workera, lecz brak wolumenu
zostawia je jako `Pending`; Fern podpina właściwy magazyn, readiness zmienia się
na `Ready` i dopiero wtedy brama usługi wpuszcza ruch.

- Technika: manifest GitOps, Flux reconcile, scheduler, persistent volume i readiness.
- Crossover: valheimowy kruk jest płaskorzeźbą na tronie kontrolera.
- Kadr: postacie i uszkodzony węzeł po prawej, uśpione golemy po lewej.

### 06. `editors-after-last-tea`

W starej pracowni Frieren wykonuje minimalną awaryjną poprawkę na odległym,
ubogim systemie kluczem `vi`; prosty zwój `nano` leży obok jako łatwa ścieżka
ratunkowa. Fern przenosi poprawkę do codziennego warsztatu Neovim, gdzie LSP,
formatter i test wykrywają problem przed pokazaniem diffu i commitem. Rodowód
Vim jest wygrawerowany w tym samym stole. Większe pulpity VS Code i JetBrains
są wygaszone, lecz dostępne do zadań wymagających GUI albo głębokiej analizy.

- Technika: świadomy dobór edytora od rescue po pełny workflow; Neovim jako
  szybkie centrum pracy, a cięższe IDE jako narzędzia sytuacyjne, nie wrogowie.
- Crossover: zaparzacz do herbaty ma kształt Pochity.
- Nastrój: ciepła, ciemna scena o kunszcie, bez logo wall i wojny fanboyów.

## II. Wiedźmin 3 — 07–10

### 07. `silver-hash-contract`

Ciri w domyślnym języku stroju z Wiedźmina 3 sprawdza trofeum przed przyjęciem
zapłaty. Wzór na srebrnym mieczu odpowiada pieczęci SHA-256 na kontrakcie;
stara pieczęć MD5 jest widocznie pęknięta i odrzucona.

- Technika: identyfikacja artefaktu, mocny hash i kwarantanna.
- Crossover: na marginesie kontraktu znajduje się odręczny szkic Frieren.
- Kadr: Ciri, kontrakt i klatka kwarantanny po prawej; czarne mokradło po lewej.

### 08. `logwood-trace`

Yennefer i Geralt tropią problem w lesie. Ślady dzielą się naturalnie na logi,
metryki i trace, ale dopiero OpenTelemetry nadaje im wspólny identyfikator.
Prometheus waży metryki, Loki kataloguje logi, Tempo prowadzi ślad, a jeden
przyrząd Grafany koreluje wynik z konkretnym issue Sentry. Geralt usuwa realne
wąskie gardło i dopiero zielony pomiar zamyka incydent; głośny czerwony alert
prowadzący do pustego drzewa okazuje się fałszywym tropem.

- Technika: OTel → jeden przyrząd Prometheus/Loki/Tempo/Grafana → issue Sentry
  → fix i zielona weryfikacja.
- Crossover: mały Pal siedzi jako pluszak przy jukach Płotki.
- Styl: wyraźnie Wiedźmin 3, nie serial i nie fotorealizm aktorów.

### 09. `zero-trust-keep`

Ciri, Yennefer i Geralt przechodzą przez warstwy zamkowej ochrony. Każda brama
Authentik sprawdza tożsamość oraz klucz MFA, po czym wydaje krótką pieczęć o
małym scope. Sam medalion lub wcześniejsze wejście nie otwiera kolejnej komnaty;
Geralt pilnuje ścieżki minimalnych uprawnień, a wygasła pieczęć zamyka bramę.

- Technika: Authentik → MFA → short-lived scoped token → least privilege/expiry.
- Crossover: wzór laski Frieren jest grawerem na kluczu sprzętowym Ciri.
- Bez listy Keycloak/Authelia/authentik — pokazujemy zasadę, nie katalog.

### 10. `quarantine-at-old-mine`

Yennefer izoluje skażony artefakt w opuszczonej kopalni, Geralt zbiera ślady,
a Ciri odcina jedyną drogę rozprzestrzeniania. Reguła YARA rozpoznaje artefakt,
Sigma opisuje zachowanie, a dowód hosta potwierdza wynik. To jedna ścieżka
dochodzenia, nie zestaw znaczków SOC.

- Technika: YARA -> Sigma -> dowód hosta -> kwarantanna.
- Crossover: mały plakat Power wisi wewnątrz skrzyni górniczego strażnika.
- Czerń tworzą tunele i podparcia, nie puste tło.

## III. Palworld — 11–13

### 11. `palbox-homelab`

Scena ma wyglądać jak wysokiej jakości rozwinięcie prawdziwego Palworld:
rozpoznawalny anime-game rendering, Palbox, przesadnie rozbudowana baza i kilka
różnych Pali wykonujących własne specjalizacje. Elektryczny Pal zasila rack,
lodowy chłodzi, techniczny układa kable, a transportowy przenosi dyski.

- Technika: czerwony stan Proxmox/Ceph → decyzja operatora → fencing → quorum
  utrzymuje VM i dane; UPS i chłodzenie są scenografią, nie osobnym pipeline.
- Crossover: na małym ekranie Palboxa jest ciemna tapeta z Frieren.
- Wymóg: Palworld rozpoznawalny bez napisu; żadnej generycznej maskotki.

### 12. `palbox-media-request`

W bazie Palworld jeden Pal prosi o film przy kiosku Overseerr. Dwukomorowy
sortownik Sonarr/Radarr rozpoznaje serial lub film, a wspólny teleskop Prowlarr
odnajduje źródło. Transportowy Pal uruchamia qBittorrent i dowozi jeden gotowy
ładunek do bramy biblioteki. Bohater przechodzi od zniecierpliwienia do radości,
gdy zamówienie dociera; Plex i napisy pozostają celowo poza tym kadrem.

- Technika: Overseerr → Sonarr/Radarr → Prowlarr → qBittorrent.
- Crossover: wilczy medalion Wiedźmina jest brelokiem przy konsoli operatora.
- OLED: nieczynne hale i przestrzenie między maszynami pozostają czarne.

### 13. `palbox-request-path`

Rozbudowana baza Palworld pokazuje request lifecycle w trzech urządzeniach.
Dwustopniowa brama łączy API Gateway i zwrotnicę Traefik. Jedno stanowisko
aplikacji zawiera dwa workery Laravel Octane/FrankenPHP i odcina chory worker.
Jeden piętrowy magazyn łączy szybki Redis nad trwałym PostgreSQL. Zniecierpliwiony
transportowy Pal wnosi kapsułę HTTP; cache hit zawraca z górnej półki, a miss
schodzi na dół, uzupełnia Redis i wraca tą samą drogą.

- Technika: HTTP → brama API/Traefik → stanowisko Laravel/FrankenPHP z
  magazynem Redis/PostgreSQL → odpowiedź; health check zamyka chory worker.
- Crossover: miecz Ciri jest miniaturą służącą za dźwignię przy Palboxie.
- Przepływ pokazują Pals, kapsuły, taśmy i urządzenia, nie unoszące się strzałki.

## IV. V Rising — 14–16

### 14. `blood-certificate-domain`

Scena używa prawdziwego języka V Rising: izometrycznej kamery, Castle Heart,
krwistej esencji, gotyckich posadzek, sług i budowy domeny. Wampirzy zarządca
odnawia ochronną pieczęć zamku przed świtem. Łańcuch certyfikatu jest fizycznym
łańcuchem wardów od wyzwania ACME do bramy 443.

- Technika: ACME → pełny chain → Traefik `443` → status i odnowienie.
- Crossover: mała zabawka Pochity leży przy palenisku wyzwania ACME.
- Wymóg: rozpoznawalny V Rising, nie generyczna wampirzyca na tle zamku.

### 15. `castle-heart-failover`

W kolejnej domenie V Rising Castle Heart zasila dwie komory danych. Główna
komora gaśnie, słudzy przenoszą ruch przez bramę połączeń, a zapasowa przejmuje
pracę bez utraty ostatniego zapisu. Izometryczny kadr pokazuje zależność
serca, bramy i dwóch magazynów.

- Technika: PostgreSQL primary/replica, PgBouncer i kontrolowany failover.
- Crossover: korona cienia Sung Jinwoo jest grawerem na wieku jednej trumny.
- Nie dodajemy Redis, Ceph ani Kubernetes — scena dotyczy wyłącznie HA bazy.

### 16. `signed-servant-armory`

W domenie V Rising push do kuźni Forgejo przywołuje sługę Woodpecker. Pierwsza
komora testuje recepturę, druga raz buduje broń i zapisuje jej krótki SBOM, a
pieczęć Castle Heart podpisuje artefakt przed odłożeniem do registry po digest.
Fałszywy przedmiot `latest` bez pieczęci trafia do stopienia.
Izometryczna budowa pomieszczeń i praca sług muszą wyglądać jak rozgrywka, nie
jak generyczna kuźnia fantasy.

- Technika: Forgejo → Woodpecker test/build + SBOM → podpis → immutable registry.
- Crossover: gumowa kaczka nosi malutki hełm Starka z Frieren.
- Tekst tylko na recepcie, pieczęci i jednej etykiecie skrzyni.

## V. Valheim — 17–19

### 17. `filesystems-at-black-fjord`

Port Valheim przyjmuje obce skrzynie i wybiera właściwy magazyn dla danych.
FAT32 jest małą łodzią wymiany ograniczoną bramą `4 GiB`, exFAT przewozi duże
pliki między światami, a zamknięte kufry NTFS i APFS trafiają do stanowiska
zgodności zamiast pod fundament serwera. Otwarta hala Linux oferuje prosty,
solidny regał ext4, migawkowe drzewo Btrfs oraz pulę ZFS z mirror, checksumem
i scrubem. Zweryfikowane dane trafiają do magazynu odpowiedniego do roli.

- Technika: migracja/interoperacyjność oraz świadomy wybór ext4/Btrfs/ZFS;
  Linux wygrywa otwartością i kontrolą, bez udawania, że każdy format służy temu samemu.
- Crossover: laska Frieren jest dyskretnie wyrzeźbiona na kamieniu runicznym.
- Etykiety tylko na skrzyniach i stanowiskach; bez wielkich logo systemów.

### 18. `offsite-under-first-snow`

Ekipa w stylu Valheim przygotowuje łódź z kopią poza siedzibę podczas
pierwszego śniegu. Jedna kopia zostaje w długim domu, druga na innym nośniku,
trzecia odpływa. Zanim łódź ruszy, archiwistka wykonuje rzeczywisty test
odtworzenia na małym mechanicznym stanowisku.

- Technika: snapshot → PBS z retencją → offsite → izolowany restore z testem.
- Crossover: jaskółczy medalion Ciri jest płaskorzeźbą na skrzyni offsite.
- Wymóg: klimat i materiały Valheim, bez generycznej realistycznej wioski.

### 19. `world-seed-blueprint`

Budowniczowie Valheim odtwarzają odporny posterunek z deklaracji w Git. Kamień
stanu zamyka równoległą zmianę; OpenTofu najpierw pokazuje plan, a po akceptacji
wznosi wirtualną chatę Proxmox. Zwój cloud-init daje jej pierwszą tożsamość,
stanowisko Semaphore/Ansible urządza wnętrze i uruchamia usługę, a kruk wskazuje
późniejszy drift.
Dopiero powtórzony plan oraz kontrolowana korekta przywracają zgodność.

- Technika: Git/OpenTofu plan → Proxmox VM → Semaphore/Ansible → test i drift fix.
- Crossover: mała Pal Sphere pełni rolę ciężarka na pergaminie budowy.
- Bez terminala w lesie: cała automatyzacja jest czytelną metaforą rzemiosła.

## VI. Chainsaw Man — 20–22

Ta sekcja zachowuje oficjalny język anime i mangi: mocne sylwetki, dynamiczną
perspektywę, kontrolowany kontrast, charakterystyczną ekspresję oraz kanoniczne
stroje Public Safety. Makima, Denji i Power muszą być rozpoznawalni bez
podpisów. Nie zmieniamy ich w generyczne postacie, nie robimy erotycznych
wariantów i ograniczamy gore do niegraficznych śladów walki.

### 20. `dependency-devil`

Makima analizuje potwora zbudowanego z łańcucha zależności, Denji odcina jedno
skażone ogniwo, a Power przytrzymuje zdrową ścieżkę. Lockfile jest fizycznym
zwojem, a SBOM mapą wnętrza demona; dopiero zależność przechodnia ujawnia
prawdziwe źródło problemu.

- Technika: lockfile, transitive dependency, SBOM i skan podatności jako jedna historia.
- Crossover: w opuszczonym kiosku wisi mały plakat Frieren z laską.
- Bez ściany nazw npm/Cargo/Composer; jeden ekosystem wystarczy.

### 21. `secret-devil-revocation`

Power przypadkiem ujawnia czerwony token IaC w zwoju Git. Denji odkrywa, że
samo wyrwanie strony nie zatrzymuje Secret Devil; Makima najpierw unieważnia
token u wystawcy, potem obraca wartość i zamyka zastępstwo pieczęcią SOPS/age.
Stary token rozpada się dopiero po revoke, a nowa jawna wartość nigdy nie jest
widoczna.

- Technika: leak w Git/logu → revoke → rotate → SOPS/age encryption.
- Crossover: wilczy medalion Geralta jest brelokiem przy zamkniętym sejfie.
- Etykiety tylko na tokenie i pieczęci; żadnych przykładowych sekretów.

### 22. `media-devil-after-midnight`

Finał rozgrywa się w opuszczonym kinie. Power wścieka się na brak napisów,
Denji czeka przy zacinającym się projektorze, a Makima spokojnie prowadzi jeden
gotowy plik przez stanowisko Bazarr do projektora Plex. Tautulli jest wyłącznie
małym miernikiem aktywnej sesji i transkodowania; po starcie napisów oraz płynnego
obrazu stan zmienia się z czerwonego na zielony.

- Technika: biblioteka → Bazarr → Plex playback/transcode → Tautulli monitoring.
- Crossover: mała figurka Palworld siedzi na obudowie projektora.
- Bez Overseerr, Sonarr, Radarr, Prowlarr i qBittorrent — ich historia kończy się w 12.

## Bramka przed generacją

Każdy prompt musi odpowiedzieć „tak” na sześć pytań:

1. Czy świat lub postać są rozpoznawalne bez czytania nazwy pliku?
2. Czy techniczna metafora jest logiczna i widoczna w działaniu?
3. Czy crossover jest naturalnym przedmiotem, a nie naklejonym rebusem?
4. Czy prawy crop 16:9 zachowa twarze, dłonie i całą historię?
5. Czy rozszerzenia 21:9/32:9 zachowują trzy warstwy głębi, perspektywę i
   słabszą iluminację tej samej sceny bez szwu lub maskowania?
6. Czy czerń OLED wynika z geometrii sceny i nadal ma AO/GI?

Jeśli nie, prompt wraca do poprawy przed wydaniem jakiegokolwiek wywołania API.
