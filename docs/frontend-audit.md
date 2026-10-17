# Frontend-Prüfung vom 17. Oktober 2026

Die Korrekturen übernehmen Marke, Originalbilder und bestehende Seitenstruktur.
Geschäftskunden, Veranstaltungspartner, Presse und Bewerber bleiben die
vorrangigen Zielgruppen; neue Landingpages sind nicht Teil dieser Arbeit.

## Behobene Befunde

| Bereich | Ergebnis |
| --- | --- |
| Referenzdetails | Enter und Leertaste öffnen und schließen die Karten; der Fokus bleibt erhalten. Maus und Touch funktionieren weiterhin. |
| Mobiles Menü | Der erste Eintrag bleibt sichtbar. Fokus und Tab-Reihenfolge bleiben im Menü; Escape, Größenwechsel und Turbo-Navigation geben die Seite wieder frei. |
| Presse-Dialog | Tab und Shift+Tab bleiben im Dialog. Hintergrund, Scrollzustand und Auslöserfokus werden wiederhergestellt. Das Vorschaubild hat von Beginn an eine gültige Quelle. |
| Öffentliche Texte | Ungenutzte Lorem- und interne Entwurfsübersetzungen sind in beiden Sprachen entfernt. Die aktuellen Templates enthielten diese Texte bereits nicht mehr. |
| Schmale Displays | Service-Kontakte und Jugendschutzformular bleiben bei 320 Pixeln innerhalb des Bildschirms. |
| Sprunglink | Der Sprung zum Hauptinhalt setzt Fokus und URL-Fragment. |
| Desktop-Untermenüs | Escape schließt ein geöffnetes Untermenü und setzt den Fokus auf den übergeordneten Link. |
| Kontakt | Telefon, E-Mail und VVS-Fahrplanauskunft stehen vor dem längeren Inhalt; auf Mobilgeräten folgt das Foto danach. Redaktioneller Inhalt bleibt erhalten. |
| Assets | Öffentliche Seiten laden `frontend`, Login und Backoffice `backend`. Gemeinsame Grundelemente und lokale Schriftdateien stehen beiden zur Verfügung. |
| Reduzierte Bewegung | Auch die JavaScript-gesteuerten Sprünge und horizontalen Slider beachten die Systemeinstellung. |

Zusätzlich sind Textbreiten und Zeilenabstände, Navigations- und
Formularhinweiskontraste, die Überschriftenfolge der Jobseite, der Umbruch der
Pressetextkachel und der Desktop-Überlauf der Unternehmenskollage korrigiert.
Die Firmenlogos stehen auf kleinen Displays in einem festen Raster.

Der zuvor beobachtete Fehler beim Aufbau der ActionText-Testtabelle trat auf
dem aktuellen `main` mit frisch angelegten Testdatenbanken nicht mehr auf.
Eine zusätzliche Änderung am Datenbankaufbau war deshalb nicht erforderlich.

## Prüfung

- `mise exec -- bin/ci`: Linter, Sicherheitsprüfungen, 195 Rails-Tests und Seeds erfolgreich.
- `mise exec -- bin/rails test:system`: 9 Browsertests, 69 Assertions erfolgreich.
- Beide Sprachen auf zwölf Seiten bei 320, 390, 900 und 1440 Pixeln geprüft:
  keine horizontalen Seitenüberläufe oder defekten sichtbaren Bilder.
- Nativer Impeccable-Detektor 4.6.0: Quelltextprüfung ohne Befunde;
  gerenderte Seiten auf Desktop und Mobilgeräten sowie Job- und Presse-Details geprüft.

## Einordnung der verbleibenden Detektormeldung

Auf `/referenzen` meldet `content-hidden-at-rest` die geschlossenen Rückseiten
der Referenzkarten. Diese sind bewusst erst nach Hover, Touch oder
Tastaturaktivierung sichtbar. Die Meldung beschreibt hier keinen ausgefallenen
Einblendeeffekt: Die Browsertests prüfen das tatsächliche Öffnen und Schließen.
Die Regel bleibt aktiv; es gibt dafür weder eine globale Ausnahme noch eine
unterdrückende Konfiguration.

Der Detektor meldet diese Heuristik weiterhin mit Exit-Code `2`. Das ist kein
vollständig befundfreier Browserlauf.
