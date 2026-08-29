# Lan Mouse

Lan Mouse udostępnia klawiaturę i mysz z `rog-polamaniec` na
`white-monster` po zaufanej sieci LAN. Nie przesyła obrazu; White Monster jest
odbierany osobno przez kartę przechwytującą HDMI.

Oba hosty uruchamiają usługę użytkownika i otwierają UDP `4242`. Na ROG
`white-monster` jest skonfigurowany po prawej stronie, więc przejście kursorem
przez prawą krawędź przekazuje sterowanie razem z klawiaturą.

## Pierwsze parowanie

Po aktywacji obu hostów uruchom `lan-mouse` na White Monster, znajdź przychodzące
połączenie z ROG i zatwierdź jego fingerprint. Odcisk zostanie zapisany lokalnie
w `~/.config/lan-mouse/config.toml`; nie jest częścią konfiguracji Nix ani Git.

Lan Mouse działa natywnie z wlroots/Hyprland i nie wymaga nieobecnego w
Hyprlandzie portalu `RemoteDesktop`. Nie synchronizuje schowka między hostami.
