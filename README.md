# Russ Live

Rails-Anwendung für den Relaunch von `russ-live.de`. Die Anwendung verwendet Ruby
`4.0.2` über `mise` und Rails `8.1.3.1`.

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
mit Ausschnitt und Zoom; auf `/referenzen` werden normale Referenzen als
quadratische Kacheln gezeigt. Referenzen werden automatisch nach Datum sortiert,
die aktuellsten stehen oben; das gilt auch für Slider-Referenzen. Im Slider-Tab
kann eine Referenz als
`Hauptprojekt / im Slider anzeigen` markiert werden. Diese Hauptprojekte
erscheinen im Referenzslider auf der Startseite und zusätzlich oben auf
`/referenzen`, aber nicht noch einmal im darunterliegenden Kachelgrid. Für den
Slider kann ein breites separates Slider-Bild gepflegt werden; fehlt es, fällt
die Ausgabe auf das normale Referenzbild zurück.

Gespeicherte Entwürfe können im Editor über `Veröffentlichen` direkt sichtbar
geschaltet werden. Danach erscheinen sie im Filter `Veröffentlicht` und auf der
öffentlichen Referenzseite.

Die Beschreibung wird getrennt für Deutsch und Englisch gepflegt; fehlt die
englische Beschreibung, zeigt die englische Seite die deutsche Beschreibung als
Fallback.

Auf `/services` wird kein Referenzslider mehr ausgegeben.

Bestehende Referenzen werden beim Einspielen der Russ-Migration als
veröffentlichte Startdaten übernommen. Neue Uploads werden im Rails-Storage
unter `storage/reference_images` abgelegt und über Russ Live ausgeliefert; die
readonly Stuttgart-Live-Datenbank bleibt davon unberührt. JPEG-, PNG- und
WebP-Uploads werden beim Speichern automatisch auf Webgröße komprimiert und als
WebP ausgeliefert.

Bereits gespeicherte Russ-Live-Uploads können nachträglich auf dieselbe
Webgröße gebracht werden:

```bash
mise exec -- bin/rails images:optimize_uploads
```

Der Task verarbeitet Referenz-, Slider-, Job-, Ansprechpartner- und Teambilder
im Russ-Live-Storage.

## Jobs, Ansprechpartner und Team

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

Job-Inhalte sind zweisprachig pflegbar. Neben den deutschen Hauptfeldern gibt
es im Job-Editor optionale englische Felder für Titel, Badge, Intro,
optionalen Text, Tätigkeitsfeld und Anforderungen. Wenn ein englisches Feld leer
bleibt, nutzt die englische öffentliche Seite automatisch den deutschen Inhalt
als Fallback.

Das Team wird unter `/backend/team_members` gepflegt. Dort können Name,
deutsche und englische Rolle sowie das Porträt bearbeitet werden. In der
ungefilterten Liste lässt sich die Reihenfolge per Drag-and-drop ändern; sie
wird direkt für die öffentliche Teamseite übernommen. Teamfotos liegen unter
`storage/team_member_images`.

## Seitenpflege

Die redaktionellen Seiten `Kontakt`, `Impressum`, `Datenschutz`, `AGB` und
`Jugendschutz` werden im Backend unter `/backend/pages` gepflegt. Jede Seite
gibt es getrennt für Deutsch und Englisch. `Speichern` legt Änderungen als
Entwurf ab; erst `Veröffentlichen` übernimmt sie auf die öffentliche Seite.
Über `Vorschau anzeigen` kann der aktuelle Entwurf vor dem Veröffentlichen
kontrolliert werden.

Die Kontaktseite verwaltet Titel und Kontakttext als ein HTML-Feld.
Direkte Aktionen für Telefon, E-Mail und die VVS-Fahrplanauskunft stehen
vor dem längeren Text und dem Standortfoto.

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

## Pressebilder aus Stuttgart Live

Der Pressebereich zeigt nur veröffentlichte Stuttgart-Live-Events, die über den
Haken „Auf Russ Live veröffentlichen“ freigegeben sind. Für die
Pressebild-Galerie und das ZIP werden zuerst die im Stuttgart-Live-Tab
„Presse“ gepflegten Sliderbilder verwendet. Wenn für ein freigegebenes Event
keine Sliderbilder vorhanden sind, verwendet Russ Live stattdessen das Eventbild
aus dem Tab „Eventbild“ zusätzlich zum Header als Pressebild und nimmt es in das
ZIP auf. Ohne angehängte Slider- oder Eventbilder wird kein Bilder-Download
angeboten.

## Entwicklung starten

```bash
mise exec -- bin/dev
```

Die Anwendung läuft danach standardmäßig unter `http://127.0.0.1:3001`.

Öffentliche Seiten laden die `frontend`-Bundles, Login und Backoffice die
`backend`-Bundles. Die Einstiegspunkte liegen unter `app/javascript` und
`app/assets/stylesheets`; nur Tokens, Grundelemente, Formularfelder und
Meldungen werden über `shared.css` gemeinsam verwendet. Neue
Stimulus-Controller werden im passenden Manifest unter
`app/javascript/controllers/frontend.js` oder `backend.js` registriert.
`bin/dev` überwacht beide JavaScript-Einstiege und beide CSS-Builds.
Die lokalen Schriftdateien werden auf beiden Oberflächen ausgeliefert.

## Checks

```bash
mise exec -- bin/ci
```

`bin/ci` bündelt die relevanten Tests, Security-Checks und Linter.

Für die Tastatur-, Dialog- und mobilen Layoutregressionen zusätzlich mit
installiertem Chrome ausführen:

```bash
yarn build && yarn build:css
mise exec -- bin/rails test:system
```

Der GitHub-Systemtest baut diese Assets ebenfalls vor dem Browserlauf.

### Frontend mit Impeccable prüfen

`PRODUCT.md` hält Zielgruppen und Markenbedingungen fest. Der native
Impeccable-Detektor lässt sich mit Node.js/npm direkt ausführen; die
Projektkonfiguration erkennt Rails-Templates mit `.html.erb` als HTML.

```bash
npx --yes impeccable@4.6.0 detect app/views/pages app/views/shared app/assets/stylesheets/frontend.tailwind.css app/assets/stylesheets/shared.css
npx --yes impeccable@4.6.0 detect http://127.0.0.1:3001/ --viewport 1440x1000
npx --yes impeccable@4.6.0 detect http://127.0.0.1:3001/services --viewport 320x900
```

Quelltext- und Browserprüfung ergänzen sich. Browserläufe benötigen die
gestartete App; über die Sprachumschaltung beide Sprachen prüfen.
Exit-Code `0` bedeutet keine primären Befunde, `2` gemeldete Befunde und
`1` einen unvollständigen oder fehlgeschlagenen Scan. Interaktive Zustände
wie Referenzdetails zusätzlich per Tastatur und Touch kontrollieren.
Der [Prüfbericht](docs/frontend-audit.md) dokumentiert die Korrekturen und die
verbleibende Detektorheuristik bei geschlossenen Referenzkarten.

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

## Getrennte Umgebungen vorbereiten

Das neue Kamal-Ziel `staging` verwendet weiterhin `RAILS_ENV=production`, aber
`APP_ENVIRONMENT=staging`. Datenbanken, PostgreSQL-Rollen, Credentials und das
Medienvolume sind von Produktion getrennt. Beide Staging-Apps teilen sich nur
`stuttgart_live_de_staging_storage`; Russ liest ausschließlich die
Stuttgart-Staging-Datenbank. Produktionswerte in geerbten Datenbank-URLs werden
beim Start abgelehnt.

Produktion bleibt zunächst unter der bisherigen `schopp3r.de`-Adresse und dem
Kamal-Ziel `hetzner`. Diese Konfiguration allein schaltet keine Domain um.
Für Staging müssen eigene `config/credentials/staging.yml.enc` sowie ein eigener
Schlüssel bereitgestellt werden; der Produktionsschlüssel ist kein Ersatz.
Das Beispiel `.kamal/secrets.staging.example` liest ausschließlich ausdrücklich
bereitgestellte Staging-Werte. `bin/hetzner-check --destination staging` lädt
keine Produktions-`.env` und lehnt `.kamal/secrets-common` für Staging ab. Der bisherige Check verwendet `--destination hetzner`.

Die Staging-Profile sind erst nach Einrichtung der Datenbanken, bereinigten Daten,
Zugriffsschutz und Deployment-Prüfungen betriebsbereit. Der vollständige Ablauf
steht im freigegebenen Umzugsplan; vor Abschluss dieser Vorbereitung nicht deployen.

Staging versendet E-Mails ausschließlich an das gemeinsame interne Mailpit-Postfach.
Die Oberfläche ist auf Hetzner nur über `127.0.0.1:8025` erreichbar. Für den lokalen
Zugriff: `ssh -N -L 8025:127.0.0.1:8025 deploy@46.225.224.194`, danach
`http://localhost:8025` öffnen. Mailpit hält höchstens 1.000 Nachrichten und hat
keinen externen SMTP-Relay. Das Image ist auf einen Digest festgelegt (siehe
[offizielle Docker-Dokumentation](https://mailpit.axllent.org/docs/install/docker/)).
Automatische wiederkehrende Jobs sind in Staging ausgeschaltet; lokale manuelle
Jobs bleiben möglich. Mailjet-, Meta-, externe Import- und kostenpflichtige
KI-Aufrufe werden an den echten Client-Grenzen blockiert, auch bei versehentlich
vorhandenen API-Zugangsdaten. Öffentliche Tracking-Pixel bleiben in Staging aus.

Das Staging-Ziel benötigt zusätzlich `STAGING_BASIC_AUTH_HTPASSWD` als vollständige
htpasswd-Zeile (`Benutzer:Hash`), beispielsweise mit einem Bcrypt-Hash. Der Hash
wird als Secret behandelt; das Startskript schreibt ihn mit Dateirechten `0600`.
Fehlt er, startet nginx nicht. In Staging gelten Basic Auth und `noindex, nofollow`
auch für Assets, Medien und Fehlerantworten. Antworten werden dort nicht öffentlich
zwischengespeichert. Ausschließlich der exakte Healthcheck `/up` bleibt öffentlich
und enthält keine Anwendungsdaten. nginx prüft dabei den Rails-Healthcheck von
Puma, damit ein noch nicht gestarteter oder defekter App-Prozess nicht als bereit gilt.

`APP_ALLOWED_HOSTS` enthält die erlaubten Hostnamen als kommagetrennte Liste.
`CANONICAL_REDIRECT_ENABLED=false` hält die Weiterleitung bis zum Umschaltfenster
ausgeschaltet. Bei aktivierter Weiterleitung führen erlaubte Alias-Hosts mit
HTTP 308 auf den festen HTTPS-Host aus `APP_HOST`; Pfad und Suchparameter bleiben
erhalten. Fremde Hosts werden abgewiesen. Die bisherige Produktionsdomain und ihre
Medien-Signierschlüssel bleiben bis zur geplanten Umschaltung erhalten.

Nach jedem Image-Build ist der HTTP-Test verpflichtend:
`APP_IMAGE=<gebautes-image> mise exec -- ruby test/ops/nginx_runtime_check.rb`.
Er startet ausschließlich isolierte Testcontainer mit synthetischen Dateien und
prüft Weiterleitungen, Zugriffsschutz sowie beide Medien-Signaturverfahren.

Alle Deployments beider Projekte und Umgebungen müssen dieselbe Sperre auf dem
Hetzner-Host halten. Der Wrapper `mise exec -- script/ops/deploy_with_lock --host
46.225.224.194 --key ~/.ssh/stgt-live-hetzner-github -- BEFEHL` hält sie während
des gesamten Befehls. Geht die SSH-Verbindung verloren, wird der verwaltete
Prozess samt Unterprozessen beendet. Gemeinsame Proxy-Neustarts gehören in einen
separat koordinierten Host-Eingriff und nicht in einen automatischen Deploy-Retry.

Die tatsächlichen Staging-Rechte werden nach Einrichtung und Datenübernahme mit
`bin/rails runner script/ops/check_staging_acl.rb` im jeweiligen Staging-Container
geprüft. Schreibprüfungen verwenden ausschließlich `WHERE FALSE` und Rollback;
Produktionsdatenbanken werden nur auf die erwartete Verbindungsverweigerung geprüft.

### Staging-Daten erneuern

Den gemeinsamen manuellen Refresh aus dem Stuttgart-Projekt ausführen
(`mise exec -- bin/staging-refresh --snapshot MANIFEST`, zunächst ohne `--execute`).
Der dort dokumentierte Ablauf hält beide Staging-Apps bis zur vollständigen
Bereinigung und Medien-/Rechteprüfung gesperrt. Russ bereinigt ausschließlich seine
eigene `russ_live_de_staging`; die gemeinsame Nutzerquelle wird in Stuttgart
bereinigt und bleibt für Russ schreibgeschützt. Die IDs und Medienzuordnungen
bleiben erhalten, Kontakt- und Teamangaben werden synthetisch. Alte Sessions und
Login-Versuche verschwinden. Der neue eigene Staging-Admin aus Stuttgart kann sich
anschließend auch hier anmelden.

Web und Worker prüfen die gemeinsame Readiness-Datei bereits vor dem Rails-Start.
Offline-Runner und Migrationen benötigen diese Datei nicht. Bei fehlgeschlagenem
Refresh erfolgt kein automatischer Neustart alter Worker. Die Sanitizer-Tests
verwenden vollständige Schemata in isolierten PostgreSQL-16.15-Containern; `bin/ci`
benötigt deshalb eine laufende Docker-Engine.
