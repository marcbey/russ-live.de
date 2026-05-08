# Russ Live Relaunch Prototype

Eigenständiger Prototyp für den Relaunch von `russ-live.de`.

## Wichtig

- Dieses Projekt ist getrennt von `stuttgart-live`.
- Es verändert keine Dateien, Datenbanken, Routen oder Assets der bestehenden Stuttgart-live-App.
- Die Event-Verknüpfung ist nur als read-only Platzhalter vorgesehen.

## Inhalt importieren

```bash
python3 scripts/import_content.py
```

Das Script kopiert lokale Fonts und das Keyvisual in `assets/`, lädt Team- und Referenzbilder von `michaelrussgmbh.de` herunter und schreibt `content/site.json`.

## Vorschau starten

```bash
python3 -m http.server 8080
```

Danach im Browser `http://127.0.0.1:8080` öffnen.

## Asset-Struktur

- `assets/fonts`: Neue Rational Light/SemiBold
- `assets/keyvisuals`: Russ Live Keyvisual
- `assets/team`: importierte Teambilder
- `assets/references`: importierte Referenzbilder
- `content/site.json`: importierter Startcontent für spätere CMS-Seeds
