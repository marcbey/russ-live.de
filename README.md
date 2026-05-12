# Russ Live

Rails-Anwendung für den Relaunch von `russ-live.de`. Das Projekt wurde mit Ruby
`4.0.2` über `mise` und Rails `8.1.3` initialisiert.

## Wichtig

- Dieses Projekt ist getrennt von `stuttgart-live`.
- Es verändert keine Dateien, Datenbanken, Routen oder Assets der bestehenden Stuttgart-live-App.
- Die Event-Verknüpfung ist nur als read-only Platzhalter vorgesehen.
- Der bisherige statische Prototyp bleibt unter `statische-site/` erhalten.

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

## Statischen Prototyp aktualisieren

```bash
cd statische-site
python3 scripts/import_content.py
```

Das Script kopiert lokale Fonts und das Keyvisual in `assets/`, lädt Team- und
Referenzbilder von `michaelrussgmbh.de` herunter und schreibt
`content/site.json`.

## Statischen Prototyp ansehen

```bash
cd statische-site
python3 -m http.server 8080
```

Danach im Browser `http://127.0.0.1:8080` öffnen.

## Asset-Struktur

- `assets/fonts`: Neue Rational Light/SemiBold
- `assets/keyvisuals`: Russ Live Keyvisual
- `assets/team`: importierte Teambilder
- `assets/references`: importierte Referenzbilder
- `content/site.json`: importierter Startcontent für spätere CMS-Seeds
