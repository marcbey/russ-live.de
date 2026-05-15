# Backend UI & UX Design System

Dieses Dokument beschreibt das aktuelle UI- und UX-System für den Backend-Bereich von Russ Live. Es ist als Arbeitsgrundlage für Agenten gedacht, die Backend- oder Auth-Oberflächen erweitern, refaktorieren oder prüfen.

Die Regeln basieren auf der bestehenden Implementierung in `app/views/backend`, `app/views/sessions`, `app/views/layouts/_flash_messages.html.erb` und `app/assets/stylesheets/application.tailwind.css`.

## Grundprinzipien

- Backend-Oberflächen sind Arbeitswerkzeuge: dicht, ruhig, klar scanbar und auf wiederholte Pflegeaufgaben optimiert.
- Public-Marketing-Muster bleiben im Public-Bereich. Backend und Auth verwenden eigene semantische Klassen wie `backend-*`, `auth-*`, `editor-*`, `form-*` und `status-*`.
- Bestehende Klassen und Muster werden erweitert, bevor neue parallele Varianten eingeführt werden.
- Bedienelemente müssen ohne Erklärung verständlich sein. Sichtbare Hilfetexte sind nur sinnvoll, wenn sie eine konkrete Arbeitsentscheidung unterstützen.
- Keine externen Fonts oder CDN-Ressourcen verwenden. Die Schrift wird lokal über die Rails-Assets ausgeliefert.

## Design Tokens

Die wichtigsten visuellen Werte kommen aus den globalen CSS Custom Properties:

- `--paper`: warmer Seitenhintergrund für Public- und Auth-Flächen.
- `--ink`: primäre Text-, Border- und Aktionsfarbe.
- `--muted`: sekundäre Texte, Metadaten und Hinweise.
- `--line`: Standardlinie für Panels, Inputs und Trennungen.
- `--gold`: Akzent für den Bildausschnitt im Crop-Editor.
- `--panel`: weiße Panel-Flächen.

Backend-Flächen verwenden aktuell zusätzlich `#f5f2ec` als Arbeitsflächen-Hintergrund, `rgba(255, 255, 255, .9)` für Panels und `#111` für aktive Zustände.

Typografie:

- Standardschrift ist `"Neue Rational", sans-serif`.
- Große Backend-Titel sind uppercase, eng geführt und visuell markant.
- Labels, Chips, Tabs und Buttons sind uppercase mit kräftigerem Gewicht.
- Fließ- und Hilfetexte bleiben kleiner, ruhiger und in `--muted`.

Abstände und Größen:

- Layout-Abstände orientieren sich an `14px`, `18px` und `24px`.
- Kompakte Actions verwenden `button-compact` mit mindestens `40px` Höhe.
- Editor-Tab-Actions dürfen dichter sein, aktuell mindestens `30px`.
- Runde Ecken bleiben zurückhaltend. Buttons starten bei `8px`, Panels sind kantig über Border und Fläche definiert.

## Layout-Muster

### Auth

Login und Backend-Startseite nutzen die Auth-Shell:

- `auth-body` setzt Keyvisual-Hintergrund mit heller Überlagerung.
- `auth-shell` zentriert die Oberfläche im Viewport.
- `auth-panel` ist ein einzelnes, helles Panel mit klarer Hierarchie.
- `auth-form` und `auth-actions` strukturieren Login-ähnliche Screens; Labels und Felder nutzen das allgemeine Formularsystem mit `form-label` und `form-input`.

Neue Auth-Ansichten sollen dieses Muster verwenden, solange sie eine fokussierte Aufgabe wie Login, Zugang oder Statusmeldung darstellen.

### Backend Shell

Pflegeoberflächen verwenden die Backend-Shell:

- `backend-shell` füllt den Viewport, verhindert Body-Scroll und enthält eigene Scrollbereiche.
- `backend-topbar` enthält Eyebrow, Seitentitel und primäre Aktionen.
- `backend-topbar-sticky` hält die Kopfzeile sichtbar.
- `backend-split` teilt Pflegeansichten in eine linke Listen-/Filterspalte und eine rechte Arbeitsfläche.
- `backend-list-column` verwaltet Toolbar und scrollbare Liste.
- `backend-editor-column` ist der scrollbare Hauptarbeitsbereich.

Für neue Backend-Module ist dieses Split-Layout der Standard, wenn Datensätze ausgewählt und rechts bearbeitet werden. Einspaltige Seiten sind nur sinnvoll, wenn keine Auswahl- oder Master-Detail-Logik existiert.

## Komponenten

### Buttons und Actions

- Basis: `button`.
- Kompakte Backend-Aktionen: `button button-compact`.
- Sekundäre Hauptaktion: `button button-secondary button-compact`.
- Unauffällige Aktion: `button button-ghost`.
- Destruktive Aktion: `button button-danger button-compact`.

Buttons sind uppercase, kompakt und klar kontrastiert. Destruktive Aktionen müssen visuell rot sein und in Rails-Forms zusätzlich eine Bestätigung über `turbo_confirm` verwenden, wenn Daten gelöscht werden.

### Status und Filter

- Filterchips verwenden `status-chip`.
- Aktive Filter verwenden zusätzlich `status-chip-active`.
- Statusanzeigen in Listen verwenden `status-badge`.

Status-Chips sind Navigation oder Filter, Badges sind reine Information. Diese Rollen nicht vermischen.

### Listen

Referenzlisten verwenden:

- `backend-reference-list-scroll` für den Scrollcontainer.
- `backend-reference-list` für das Grid.
- `backend-reference-list-item` für klickbare Datensätze.
- `is-active` für die ausgewählte Zeile.
- `backend-reference-list-title` und `backend-reference-list-meta` für scanbare Inhalte.

Listenitems sollen eine feste, stabile Höhe behalten und lange Inhalte mit Ellipsis kürzen. Metadaten gehören unter den Titel, Status unten oder am Ende des Items.

### Editor Panel und Tabs

Der rechte Arbeitsbereich nutzt:

- `editor-panel` als Rahmen.
- `editor-tabs` als sticky Kopfzeile des Panels.
- `editor-tab-list` mit `role="tablist"`.
- `editor-tab` mit `role="tab"` und `aria-selected`.
- `editor-tab-panel` für die jeweiligen Inhalte.
- `editor-tabs-actions` für Speichern und destruktive Aktionen.

Tabs werden nur verwendet, wenn sie eine echte Arbeitsaufteilung reduzieren, zum Beispiel Stammdaten und Bildbearbeitung. Für kurze Formulare keine Tabs einführen.

### Formulare

Standardklassen:

- `form-label`
- `form-input`
- `form-textarea`
- `form-range`
- `form-checkbox`
- `editor-grid`
- `editor-grid-span-full`

Formulare sind zweispaltig, solange genügend Breite vorhanden ist. Lange Felder wie Beschreibung, Tags oder breite Suchfelder verwenden die volle Breite. Labels stehen immer oberhalb des Felds und bleiben kurz.

Allgemeine Hilfetexte verwenden `form-hint`. Bildeditor-spezifische Hinweise verwenden weiter `event-image-crop-hint`, teilen sich aber dieselbe visuelle Sprache.

Fehlerblöcke verwenden `form-errors`. Sie stehen direkt im Formular, nennen zuerst die Aufgabe und listen dann konkrete Validierungsfehler.

### Suche und Clear Controls

Such- und Filterformulare verwenden:

- `filter-form`
- `filter-grid`
- `filter-control`
- `filter-input-with-clear`
- `filter-clear`
- `filter-clear.is-visible`

Clear Controls müssen per Tastatur erreichbar sein und ein `aria-label` besitzen. Zustandswechsel laufen über Stimulus, damit Markup und Verhalten nicht durch Inline-JavaScript gekoppelt werden.

### Bildeditor

Der Referenzbildeditor besteht aus:

- `event-image-crop-shell`
- `event-image-crop-editor`
- `event-image-crop-frame`
- `event-image-crop-preview-image`
- `event-image-crop-placeholder`
- `event-image-crop-box`
- `event-image-crop-sidebar`
- `event-image-file-meta`

Die Preview-Fläche ist bewusst dunkel, damit der goldene Crop-Rahmen sichtbar bleibt. Der Ausschnitt wird direkt im Bild per Drag verschoben; Zoom und Grid-Variante bleiben in der Sidebar. Metadaten und Copyright-Felder bleiben nah am Upload.

## Feedback und Zustände

Flash-Messages:

- Wrapper: `flash-wrap`
- Basis: `flash`
- Fehler: `flash-alert`
- Erfolg/Hinweis: `flash-notice`

Flash-Messages sind fixed und überlagern die Seite oben mittig. Sie müssen kurz, handlungsnah und deutsch formuliert sein.

Empty States verwenden `empty-state`. Sie sollen sagen, was gerade fehlt und welche nächste Aktion möglich ist, ohne erklärenden Marketingtext.

Aktive Zustände:

- Listen: `is-active` mit dunkler Kante.
- Tabs: `is-active` mit dunklem Hintergrund.
- Statusfilter: `status-chip-active`.

Aktive Zustände müssen immer auch semantisch abgebildet werden, zum Beispiel mit `aria-selected` bei Tabs oder über aktuelle Links und lesbaren Text.

## Agent-Regeln für neue Backend-UI

- Neue Backend-Views zuerst gegen `backend-shell`, `backend-topbar`, `backend-split`, `editor-panel`, `backend-section` und das bestehende Formularsystem entwerfen.
- Keine Public-Komponenten wie Hero-, Marketing-, Mosaic- oder Public-Navigationselemente in Backend/Auth übernehmen.
- Keine neuen globalen Bundles einführen. Backend/Auth müssen mit der getrennten Asset-Strategie des Projekts kompatibel bleiben.
- Keine externen Fonts, Icons oder Stylesheets laden.
- Semantische Klassen bevorzugen. Utility-Klassen nur verwenden, wenn sie im bestehenden Projektmuster bereits üblich sind oder lokale Ausnahmen vermeiden.
- Interaktionen mit mehreren Zuständen als Stimulus-Controller bauen und ARIA-Zustände synchron halten.
- Texte knapp und arbeitsorientiert schreiben. Für deutschsprachige Texte echte Umlaute und `ß` verwenden.
- Vor visuellen Änderungen prüfen, ob die Oberfläche auf kleinen Viewports ohne Überlappungen, abgeschnittene Buttontexte oder unbedienbare Scrollbereiche funktioniert.

## Prüfliste vor Abschluss

- Passen neue Screens in Auth, Backend-Shell oder Split-Layout?
- Werden lokale Fonts und bestehende Design-Tokens verwendet?
- Sind Buttons, Tabs, Filter und Listen über die bestehenden Klassen abgebildet?
- Haben interaktive Elemente Fokuszustände, sinnvolle ARIA-Attribute und stabile Größen?
- Sind Fehler, Empty States und Flash-Messages kurz, konkret und deutsch?
- Wurde geprüft, ob `README.md` angepasst werden muss, wenn sich Nutzung, Setup, Architektur, Assets oder Betrieb geändert haben?
