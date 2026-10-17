# Russ Live

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Vorrangige Zielgruppen sind Geschäftskunden, Veranstaltungspartner, Presse und
Bewerber*innen. Konzertpublikum ist eine nachrangige Zielgruppe.

- Geschäftskunden und Veranstaltungspartner prüfen Leistungen, Referenzen und
  Ansprechpartner*innen für die Planung und Durchführung von Veranstaltungen.
- Presse und Medien suchen freigegebene Veranstaltungsinformationen, Pressetexte,
  Bildmaterial und den passenden Pressekontakt.
- Bewerber*innen informieren sich über offene Stellen, Aufgaben und Kontakte und
  gelangen von dort zur Bewerbung.
- Konzertpublikum findet ausgewählte Veranstaltungen und den Weg zum Ticketportal
  Stuttgart Live.
- Intern pflegen berechtigte Redakteur*innen und Administrator*innen Referenzen,
  Jobs und Ansprechpartner*innen im Backend.

## Product Purpose

Die Website macht die Leistungen und Erfahrung von Russ Live nachvollziehbar und
führt die vorrangigen Zielgruppen zu den für sie relevanten Informationen und
Kontakten. Geschäftskunden und Veranstaltungspartner sollen die Eignung von Russ
Live für ihr Vorhaben einschätzen können; Presse und Bewerber*innen sollen ihre
jeweiligen Aufgaben über eigene Bereiche erledigen können.

## Positioning

Russ Live ist örtlicher Veranstalter und Produktionspartner für Live Entertainment
in Stuttgart und der Region und gehört zur Konzertdirektion Russ. Das Angebot
verbindet örtliche Durchführung, Produktion und Technik, Marketing, Personal und
Ticketing. Konkrete Referenzen, das Team und vorhandenes Veranstaltungsmaterial
belegen die Arbeit.

## Operating Context

Die öffentliche Website umfasst Unternehmen und Team, Services, Referenzen, Jobs,
Presse und Kontakt. Sie muss auf Desktop und mobilen Geräten nutzbar sein.
Leistungsseiten nennen zuständige Kontakte; Referenzen geben Einblick in bisherige
Projekte. Der Pressebereich bietet freigegebenes Material zum Abruf und Download.
Das Bewerbungsformular auf Jobdetailseiten bereitet eine E-Mail an den hinterlegten
Kontakt vor; fehlt dessen E-Mail-Adresse, wird `info@russ-live.de` verwendet.
Bewerbungsunterlagen werden im E-Mail-Programm angehängt. Die Kontaktseite
bietet direkte Telefon-, E-Mail- und Fahrplanauskunftslinks.

Veranstaltungsinformationen und Presse-Inhalte kommen aus Stuttgart Live.
Tickets werden über das externe Ticketportal Stuttgart Live angeboten.
Das interne Backend dient der wiederkehrenden Inhaltspflege.

## Capabilities and Constraints

- Die bestehende Rails-App ist die Grundlage für weitere Arbeiten. Öffentliche
  Seiten und Backend/Auth verwenden getrennte Assets und Oberflächenmuster.
- Die öffentliche Oberfläche ist deutsch und englisch. Änderungen an Texten müssen
  in beiden vorhandenen Sprachversionen dieselbe Bedeutung und Detailtiefe behalten.
- Veranstaltungsdaten aus Stuttgart Live werden nur lesend angebunden. Russ-eigene
  Inhalte und Sessions liegen in eigenen Datenbanken; Benutzerverwaltung und
  Passwörter bleiben in Stuttgart Live.
- Schriftdateien werden lokal ausgeliefert. Zusätzliche externe Font-CDNs sind
  ausgeschlossen.
- Vorerst sind keine neuen Landingpages geplant.

## Brand Commitments

Die bestehende Russ-Live-Marke, Logos und vorhandenen Originalbilder sind
verbindliche Grundlagen. Die vorhandenen Texte und ihre jeweilige Ansprache werden
übernommen: Geschäftskunden werden in den Leistungstexten mit „Sie“, Bewerber*innen
in den Jobtexten mit „Du“ angesprochen. Deutschsprachige Texte verwenden echte
Umlaute und „ß“.

Die bestehenden visuellen Vorgaben sind separat in
[Frontend-Design-System](docs/frontend-design-system.md) und
[Backend-Design-System](docs/backend-design-system.md) dokumentiert.

## Evidence on Hand

- `config/locales/de.yml` und `config/locales/en.yml`: bestehende Produkt-,
  Leistungs-, Unternehmens-, Job- und Pressetexte.
- `app/assets/images/russ_live`: Logos, Keyvisuals, Team-, Veranstaltungs-,
  Referenz- und Jobbilder.
- Veröffentlichte Referenzen, Jobs und Ansprechpartner*innen aus den Russ-eigenen
  Daten sowie freigegebene Veranstaltungs- und Presse-Inhalte aus Stuttgart Live.
- `README.md`: bestehende Funktionen, Inhaltspflege und technische Betriebsgrenzen.

Vorhandene Inhalte sind die Grundlage für Aussagen und Bildauswahl. Neue
Kundenstimmen, Kennzahlen, Referenzen oder Leistungsversprechen benötigen echte
Belege; sie dürfen nicht für einen Entwurf erfunden werden.

## Product Principles

1. Geschäftskunden, Veranstaltungspartner, Presse und Bewerber*innen haben bei
   Zielkonflikten Vorrang vor dem Konzertpublikum.
2. Leistungen werden durch konkrete Projekte, Menschen und vorhandenes Material
   nachvollziehbar.
3. Jede Zielgruppe findet ihre Informationen und den passenden nächsten Kontakt
   oder Handlungsschritt.
4. Öffentliche Kommunikation und interne Inhaltspflege folgen ihren jeweiligen
   Aufgaben und bleiben als Oberflächen getrennt.
5. Bestehende Marke, Sprachgleichheit und technische Datenverantwortung werden bei
   Weiterentwicklungen gewahrt.

## Accessibility & Inclusion

WCAG 2.2 AA ist der Zielstandard für neue und geänderte öffentliche Oberflächen;
damit ist keine bereits geprüfte Konformität der gesamten Website zugesagt.
Tastaturbedienung, sichtbare Fokuszustände, verständliche Beschriftungen, geeignete
Kontraste, sinnvolle Bildalternativen und die Berücksichtigung reduzierter Bewegung
gehören zu den bestehenden Anforderungen. Zentrale Inhalte bleiben serverseitig
im HTML zugänglich. Mobile Bedienbarkeit wird mit realen deutschen und englischen
Inhalten geprüft.
