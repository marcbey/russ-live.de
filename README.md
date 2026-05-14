# Russ Live

Rails-Anwendung für den Relaunch von `russ-live.de`. Das Projekt wurde mit Ruby
`4.0.2` über `mise` und Rails `8.1.3` initialisiert.

## Wichtig

- Dieses Projekt ist getrennt von `stuttgart-live`.
- Es verändert keine Dateien, Routen oder Assets der bestehenden Stuttgart-Live-App.
- In Production liest es Stuttgarts Primärdatenbank nur read-only und nutzt dasselbe Active-Storage-Volume.
- Queue, Cache und Cable sind eigene Russ-Live-Datenbanken und werden nicht mit Stuttgart geteilt.
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
Verbindungsdaten beim Start von `russ-live` überschrieben werden:

```bash
STUTTGART_LIVE_DB_HOST=127.0.0.1 \
STUTTGART_LIVE_DB_PORT=5432 \
STUTTGART_LIVE_DB_USER=russ_live_de_reader \
STUTTGART_LIVE_DB_PASSWORD=... \
mise exec -- bin/dev
```

Active Storage liest lokal standardmäßig aus `../stuttgart-live.de/storage`,
damit Bilder aus der gemeinsam genutzten Stuttgart-Datenbank gefunden werden.
Bei anderer Ordnerstruktur kann der Pfad überschrieben werden:

```bash
ACTIVE_STORAGE_ROOT=/pfad/zu/stuttgart-live.de/storage mise exec -- bin/dev
```

## Entwicklung starten

```bash
mise exec -- bin/dev
```

Die Anwendung läuft danach standardmäßig unter `http://127.0.0.1:3000`.

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

- `russ_live_de_production_cache`
- `russ_live_de_production_queue`
- `russ_live_de_production_cable`

Das Docker-Volume für Active Storage ist bewusst gemeinsam:
`stuttgart_live_de_storage:/rails/storage`. Deshalb muss
`MEDIA_PROXY_SECRET` denselben Wert wie bei Stuttgart haben.

## Asset-Struktur

- `app/assets/images/russ_live`: in Rails übernommene Logos, Keyvisuals, Team-, Job- und Referenzbilder
- `app/assets/fonts/russ_live`: lokal ausgelieferte Neue-Rational-Webfonts
