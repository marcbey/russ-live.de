# Russ Live

Rails-Anwendung für den Relaunch von `russ-live.de`. Das Projekt wurde mit Ruby
`4.0.2` über `mise` und Rails `8.1.3` initialisiert.

## Wichtig

- Dieses Projekt ist getrennt von `stuttgart-live`.
- Es verändert keine Dateien, Routen oder Assets der bestehenden Stuttgart-Live-App.
- In Production liest es Stuttgarts Primärdatenbank nur read-only und nutzt dasselbe Active-Storage-Volume.
- Russ-eigene Domain-Daten, Queue, Cache und Cable sind eigene Russ-Live-Datenbanken und werden nicht mit Stuttgart geteilt.
- Benutzer und Passwörter bleiben in Stuttgart Live; Russ Live speichert nur eigene Sessions und Login-Audit-Daten.
- Die öffentlichen Rails-Seiten liefern die vormals statischen Russ-Live-Seiten aus.
- Der bisherige statische Prototyp wurde entfernt. Neue Arbeiten passieren ausschließlich in der Rails-App-Struktur.

## Voraussetzungen

- `mise`
- PostgreSQL
- Bun und Yarn für die generierten JavaScript- und CSS-Build-Schritte

Ruby-Befehle müssen über `mise` laufen, damit die in `mise.toml` festgelegte
Version verwendet wird.

## Setup

```bash
mise exec -- bin/setup
```

Falls die Datenbank separat vorbereitet werden soll:

```bash
mise exec -- bin/rails db:prepare
```

Für lokale Entwicklung liest `russ-live` standardmäßig die lokale
Stuttgart-Live-Datenbank `stuttgart_live_de_development`. Diese Datenbank wird
nicht aus diesem Repository migriert; sie muss im benachbarten
`stuttgart-live.de`-Repository vorbereitet werden:

```bash
cd ../stuttgart-live.de
mise exec -- bin/rails db:prepare
```

Falls PostgreSQL lokal nicht über den Standard-Socket erreichbar ist, können die
Verbindungsdaten beim Start von `russ-live` überschrieben werden. Den
Produktions-Read-Only-Benutzer `russ_live_de_reader` solltest du lokal nur
setzen, wenn diese Rolle in deiner lokalen PostgreSQL-Instanz auch wirklich
existiert:

```bash
STUTTGART_LIVE_DB_HOST=127.0.0.1 \
STUTTGART_LIVE_DB_PORT=5432 \
STUTTGART_LIVE_DB_USER=dein_lokaler_postgres_user \
STUTTGART_LIVE_DB_PASSWORD=... \
mise exec -- bin/dev
```

Active Storage liest lokal standardmäßig aus `../stuttgart-live.de/storage`,
damit Bilder aus der gemeinsam genutzten Stuttgart-Datenbank gefunden werden.
Bei anderer Ordnerstruktur kann der Pfad überschrieben werden:

```bash
ACTIVE_STORAGE_ROOT=/pfad/zu/stuttgart-live.de/storage mise exec -- bin/dev
```

Russ Live hat zusätzlich eine eigene writable Datenbank für Russ-Domain-Modelle.
Lokal heißt sie standardmäßig `russ_live_development`; ihre Migrationen liegen
unter `db/russ_migrate` und werden über `db:prepare` aus diesem Repository
verwaltet. Falls PostgreSQL nicht mit dem aktuellen Systembenutzer laufen soll,
können `RUSS_DB_NAME`, `OPERATIONAL_DB_USER`, `RUSS_LIVE_OPERATIONAL_DB_PASSWORD`,
`DB_HOST` und `DB_PORT` gesetzt werden.

Die Authentifizierung nutzt die Stuttgart-Live-Benutzer (`admin` und `editor`),
legt Sessions aber in der Russ-Datenbank ab. Passwort-Reset und
Benutzerverwaltung bleiben in Stuttgart Live.

## Referenzenpflege

Referenzen werden als Russ-eigene Domain-Daten in der `russ`-Datenbank
verwaltet. Das Backend unter `/backend/references` bietet eine
stuttgart-live-inspirierte Inbox mit Liste, Suche, Statusfilter und
Editor-Panel. Pro Referenz gibt es einen eigenen Eventbild-ähnlichen Bildeditor
mit Grid-Variante, Ausschnitt und Zoom; diese Werte steuern die Kachel auf
`/referenzen`. Die Beschreibung wird getrennt für Deutsch und Englisch gepflegt;
fehlt die englische Beschreibung, zeigt die englische Seite die deutsche
Beschreibung als Fallback.

Auf `/services` nutzt der Referenzslider dieselben veröffentlichten Referenzen,
beschränkt auf Einträge mit den Tags `Concert`, `Konzert` oder `Live`.

Bestehende Referenzen werden beim Einspielen der Russ-Migration als
veröffentlichte Startdaten übernommen. Neue Uploads werden im Rails-Storage
unter `storage/reference_images` abgelegt und über Russ Live ausgeliefert; die
readonly Stuttgart-Live-Datenbank bleibt davon unberührt. JPEG-, PNG- und
WebP-Uploads werden beim Speichern automatisch auf Webgröße komprimiert und als
WebP ausgeliefert.

Wenn bestehende Referenzen bereits andere Positionszahlen in der Datenbank
haben, kann die Reihenfolge einmal lückenlos neu nummeriert werden:

```bash
mise exec -- bin/rails russ:references:renumber_positions
```

Die Aufgabe übernimmt die aktuelle sichtbare Reihenfolge und schreibt daraus
fortlaufende Positionswerte von oben nach unten.

Bereits gespeicherte Russ-Live-Uploads können nachträglich auf dieselbe
Webgröße gebracht werden:

```bash
mise exec -- bin/rails images:optimize_uploads
```

Der Task verarbeitet Referenz-, Slider-, Job- und Ansprechpartnerbilder im
Russ-Live-Storage.

## Jobs und Ansprechpartner

Jobs und Ansprechpartner werden ebenfalls als Russ-eigene Domain-Daten in der
`russ`-Datenbank gepflegt. Das Backend bietet dafür `/backend/jobs` und
`/backend/contacts`; beide Ansichten folgen der Referenzen-Inbox mit Liste,
Suche und Editor-Panel. Jobs haben die Status `Entwurf` und `Veröffentlicht`,
mehrere Bereichs-Kategorien, eine optionale JOIN-Recruiting-URL und verweisen
auf einen Ansprechpartner.

Auf `/jobs` erscheinen nur veröffentlichte Jobs. Die Bereichs-Kategorien werden
dort als Filter angeboten; Job-Detailseiten zeigen dagegen nur das ausgewählte
Profil, den hinterlegten Ansprechpartner und den Bewerbungslink, falls eine
JOIN-URL gepflegt ist. Job- und Ansprechpartnerbilder werden unter
`storage/job_images` beziehungsweise `storage/contact_images` abgelegt und beim
Upload ebenfalls als komprimierte WebP-Dateien gespeichert.

## Mehrsprachigkeit

Die öffentlichen Frontend-Seiten werden über Rails I18n auf Deutsch und
Englisch ausgeliefert. Ohne gespeicherte Auswahl nutzt die App die im Browser
bevorzugte Sprache, sofern sie `de` oder `en` ist; andernfalls fällt sie auf
Deutsch zurück.

Die Sprache wird über den Header gewechselt und in einem Cookie gespeichert.
Dadurch bleiben die öffentlichen URLs sauber; es gibt keine lokalisierten Pfade
und keinen sichtbaren `locale`-Query-Parameter in den generierten Links.
Statische UI-, Marketing-, Presse-, Job- und Rechtstexte liegen in
`config/locales/de.yml` und `config/locales/en.yml`. Russ-eigene Domain-Inhalte
aus Referenzen, Ansprechpartnern und Jobs sowie angebundene Event-/Pressetexte
bleiben vorerst einsprachig aus den jeweiligen Datenquellen.

## Entwicklung starten

```bash
mise exec -- bin/dev
```

Die Anwendung läuft danach standardmäßig unter `http://127.0.0.1:3001`.

## Checks

```bash
mise exec -- bin/ci
```

`bin/ci` bündelt die relevanten Tests, Security-Checks und Linter.

## Deployment und Betrieb

Production läuft auf demselben Hetzner-Host wie `stuttgart-live.de` und wird
ebenfalls mit Kamal ausgerollt. Die öffentliche Domain
`russ-live.schopp3r.de` zeigt auf `46.225.224.194`; `kamal-proxy` routet anhand
des Hostnamens zum Kamal-Service `russ_live_de`.

Die Runtime entspricht Stuttgart: Der Container startet `nginx` auf Port `80`
und Puma intern auf Port `3000`. `nginx` liefert Assets und signierte
`/media/...`-Dateien direkt aus `/rails/public` beziehungsweise
`/rails/storage` aus.

Die Staging-Domain `https://russ-live.schopp3r.de/` wird in der
Hetzner-Deployment-Konfiguration mit `STAGING_NOINDEX=true` ausgeliefert.
`nginx` setzt dadurch global den Header `X-Robots-Tag: noindex, nofollow`,
auch für Assets, Media-Dateien und den Healthcheck `/up`. `robots.txt` wird
dafür bewusst nicht gesperrt, damit Suchmaschinen das `noindex` crawlen können.

Für manuelle Produktions-Kommandos brauchst du lokal:

- `config/master.key`
- die versionierte Datei `config/deploy.hetzner.shared.yml`
- eine lokale `.kamal/secrets.hetzner`
- den SSH-Key `~/.ssh/stgt-live-hetzner-github` für den Benutzer `deploy`
- eine `.env` mit `KAMAL_REGISTRY_PUSH_TOKEN`, `KAMAL_REGISTRY_PULL_PASSWORD`,
  `RUSS_LIVE_PRIMARY_DB_PASSWORD`, `RUSS_LIVE_OPERATIONAL_DB_PASSWORD` und
  `MEDIA_PROXY_SECRET`

Vor manuellen Kamal-Eingriffen sollte immer dieser Check laufen:

```bash
mise exec -- bin/hetzner-check
```

Deployment von lokal:

```bash
mise exec -- bin/hetzner-check
mise exec -- bin/kamal deploy -d hetzner
```

Status und Logs:

```bash
mise exec -- bin/kamal details -d hetzner
mise exec -- bin/kamal app containers -d hetzner
mise exec -- bin/kamal app logs -f -d hetzner -r web
mise exec -- bin/kamal app logs -f -d hetzner -r job
```

GitHub Actions baut bei Pushes auf `main` ein Image nach
`ghcr.io/marcbey/russ-live-de` und deployt danach mit Kamal. Im GitHub
Environment `production` müssen diese Secrets gepflegt sein:

- `KAMAL_REGISTRY_PULL_PASSWORD`
- `KAMAL_SSH_PRIVATE_KEY`
- `MEDIA_PROXY_SECRET`
- `RAILS_MASTER_KEY`
- `RUSS_LIVE_OPERATIONAL_DB_PASSWORD`
- `RUSS_LIVE_PRIMARY_DB_PASSWORD`

### Datenbankgrenzen

`primary` zeigt in Production auf `stuttgart_live_de_production` und nutzt den
read-only Benutzer `russ_live_de_reader`. Diese Datenbank wird ausschließlich
aus dem `stuttgart-live.de`-Repository migriert.

Russ Live nutzt eigene writable Operational-Datenbanken:

- `russ_live_de_production`
- `russ_live_de_production_cache`
- `russ_live_de_production_queue`
- `russ_live_de_production_cable`

Die `russ_live_de_production`-Datenbank ist die allgemeine Russ-Domain-DB. Sie
enthält aktuell Auth-Sessions und Login-Audit-Daten und ist für spätere
Russ-eigene Domain-Modelle vorgesehen. Der Name kann im Deployment über
`RUSS_DB_NAME` überschrieben werden.

Das Docker-Volume für Active Storage ist bewusst gemeinsam:
`stuttgart_live_de_storage:/rails/storage`. Deshalb muss
`MEDIA_PROXY_SECRET` denselben Wert wie bei Stuttgart haben.

## Asset-Struktur

- `app/assets/images/russ_live`: in Rails übernommene Logos, Keyvisuals, Team-, Job- und Referenzbilder
- `app/assets/fonts/russ_live`: lokal ausgelieferte Neue-Rational-Webfonts
