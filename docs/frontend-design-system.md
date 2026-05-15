# Frontend UI & UX Design System

Dieses Dokument beschreibt das aktuelle Public-Frontend-System von Russ Live und definiert das Zielsystem für künftige UI-, UX-, Performance-, Accessibility-, Best-Practices- und SEO-Arbeiten. Es ist als Arbeitsgrundlage für Agenten gedacht, die öffentliche Seiten erweitern, vereinheitlichen, modularisieren oder gegen Lighthouse prüfen.

Die Regeln basieren auf der bestehenden Implementierung in `app/views/pages`, `app/views/shared/_public_header.html.erb`, `app/views/shared/_public_footer.html.erb`, den Public-Stimulus-Controllern und `app/assets/stylesheets/application.tailwind.css`.

Backend- und Auth-Oberflächen bleiben getrennt und werden in `docs/backend-design-system.md` beschrieben.

## Grundprinzipien

- Public-Seiten sind bildstark, editorial und eventnah. Große Typografie, echte Veranstaltungsbilder und klare Kontraste tragen die Marke.
- Neue Oberflächen sollen das bestehende System vereinheitlichen, nicht weitere Einzellösungen pro Seite erzeugen.
- Gemeinsame Patterns werden zuerst erweitert. Seitenspezifische Abweichungen sind Modifier oder klar begründete Varianten.
- Alle neuen oder geänderten Public-Screens müssen auf Lighthouse-Grün in Performance, Accessibility, Best Practices und SEO ausgerichtet sein.
- Mobile ist kein nachträglicher Zustand. Layout, Textlängen, Touch-Ziele und Bildausschnitte müssen ab `900px` und `520px` aktiv geprüft werden.
- Keine externen Fonts, Icon-CDNs, Script-CDNs oder globalen neuen Bundles einführen. Fonts und Medien werden lokal über Rails-Assets ausgeliefert.
- Deutschsprachige Texte verwenden echte Umlaute und `ß`.

## Ist-System

### Design Tokens

Die wichtigsten Public-Werte kommen aus globalen CSS Custom Properties:

- `--paper`: warmer Seitenhintergrund.
- `--ink`: primäre Text-, Border- und Aktionsfarbe.
- `--muted`: sekundäre Texte, Metadaten und Hinweise.
- `--line`: Trennlinien, Borders und Eingabekanten.
- `--gold`: Akzent für Referenzdetails, Pressegruppen und besondere Markierungen.
- `--panel`: helle Panel- und Kartenflächen.
- `--max`: Standard-Maximalbreite für Inhaltsbereiche.
- `--reference-max`: breite Referenz- und Mosaic-Flächen.
- `--brand-left`, `--brand-top`, `--header-*`: Header-, Logo- und Navigationsmaße.
- `--mobile-header-height`, `--mobile-hero-content-top`, `--services-jump-height`: mobile Layout-Offsets.

Die Standardschrift ist `"Neue Rational", sans-serif`. Sie wird lokal in `app/views/shared/_public_fonts.html.erb` eingebunden und darf nicht durch externe Font-Dienste ersetzt werden.

### Typografie

- `h1`, `h2`, `h3` sind markant, eng geführt und häufig uppercase.
- Große Hero-Headlines nutzen `font-weight: 650`, kurze Zeilen und starke Kontraste.
- Fließtexte nutzen `font-weight: 300`, großzügige Zeilenhöhe und meist `--muted`.
- Eyebrows verwenden `.eyebrow`, uppercase, kräftiges Gewicht und reduzierte Farbe.
- Lange deutsche Wörter müssen umbrechen dürfen. Neue `white-space: nowrap`-Regeln brauchen immer Mobile-Overrides.

### Layouts

- `.section` ist der Standardcontainer mit `--max`, responsivem Padding und vertikalem Rhythmus.
- `.split` und `.services-preview` bilden zweispaltige Inhaltsmodule mit sticky Aside auf Desktop und einspaltigem Layout auf Mobile.
- Hero-Flächen sind entweder dunkle Image-Heroes, helle Editorial-Heroes oder kompakte Detail-Heroes.
- Full-width Bands wie `.home-references-band`, `.services-showcase`, `.press-contact-strip` und `.job-story-band` dürfen die Seitenbreite brechen, müssen aber innen stabile Abstände behalten.
- Breakpoints sind aktuell `900px` und `520px`. Neue Public-Patterns müssen diese Schwellen respektieren.

### Aktuelle Komponenten

- Header: `.site-header`, `.page-header`, `.brand`, `.main-nav`, `.nav-submenu`, `.mobile-menu-button`.
- Footer: `.site-footer`, `.site-footer-brand`.
- Buttons: `.hero-button`, `.section-button`, `.button`, `.press-outline-button`, `.section-button-outline-light`.
- Akkordeon: `.accordion`, `.accordion-item`, `.accordion-trigger`, `.accordion-panel`.
- Slider: `.klassik-slider`, `.klassik-slide`, `.klassik-slider-arrow`, `.klassik-slider-meta`.
- Event-Lane: `.home-events`, `.home-events-slider`, `.event-slider-card`.
- Referenzen: `.references-filter-nav`, `.reference-grid`, `.reference-mosaic`, `.reference-card`, `.reference-card-flip`.
- Services: `.services-jump-nav`, `.service-chapter`, `.service-company-card`.
- Jobs: `.job-category-filter-nav`, `.job-table`, `.job-story-*`, `.job-detail`, `.job-contact`.
- Presse: `.press-hero`, `.press-search`, `.press-letter-grid`, `.press-artist-card`, `.press-gallery`, `.press-lightbox`.

Stimulus hält Interaktionen zusammen: Mobile-Menü, Akkordeon, Slider, Referenzfilter/Mosaic, Jobfilter, Services-Jump-Navigation, Event-Slider, Pressesuche und Lightbox.

## Zielsystem

Neue Public-UI soll auf Komponentenfamilien statt Seitensilos aufgebaut werden. Die folgenden Zielnamen beschreiben das Design-System; sie müssen nicht sofort als Klassen existieren, sollen aber jede künftige Umsetzung steuern.

| Zielfamilie | Aktuelle Zuordnung | Regel |
| --- | --- | --- |
| `public-header` | `.site-header`, `.page-header`, `.main-nav`, `.mobile-menu-button` | Eine Hauptnavigation mit Desktop-, Sticky- und Mobile-Zustand. |
| `public-footer` | `.site-footer` | Ein konsistenter Abschluss mit Marke, Rechtlichem und klaren Linkzielen. |
| `public-hero` | `.home-hero`, `.services-hero`, `.references-hero`, `.job-overview-hero`, `.press-hero` | Varianten für dunkle Image-Heroes, helle Editorial-Heroes und Detail-Heroes. |
| `public-section` | `.section`, `.split`, `.section-head` | Standardrhythmus, Maximalbreiten und responsive Spalten. |
| `public-button` | `.section-button`, `.hero-button`, `.button`, `.press-outline-button` | Primary, Outline und Textlink mit einheitlichem Fokus- und Hover-Verhalten. |
| `public-filter-nav` | `.references-filter-nav`, `.job-category-filter-nav`, `.services-jump-nav` | Horizontale Filter- oder Sprungnavigation mit korrektem ARIA-Zustand. |
| `public-card` | `.reference-card`, `.event-slider-card`, `.service-company-card`, `.press-artist-card` | Stabile Maße, klare Linkfläche, Bildregeln und mobile Lesbarkeit. |
| `public-slider` | `.klassik-slider`, `.home-events-slider` | Tastaturbedienbare Slider mit sichtbaren Controls und stabilen Slides. |
| `public-directory` | `.press-letter-grid`, `.job-table` | Scanbare Listen, Tabellen und A-Z-Verzeichnisse mit semantischer Struktur. |
| `public-media-grid` | `.reference-mosaic`, `.press-gallery`, `.about-hero-collage` | Bildraster mit festen Seitenverhältnissen, Lazy Loading und sinnvollen Alt-Texten. |
| `public-contact-card` | `.press-contact-card`, `.job-contact`, `.rich-copy address` | Kontaktinformationen als semantische, gut klickbare Module. |

Neue Komponenten sollen zuerst einer dieser Familien zugeordnet werden. Nur wenn keine Familie passt, darf eine neue Familie entstehen und muss hier nachgezogen werden.

## Modularisierung

- Seitenspezifische Klassen bleiben erlaubt, aber nur als Varianten eines wiederverwendbaren Patterns.
- Wiederholte Struktur aus mehreren Seiten ist ein Refactoring-Kandidat: Filterleisten, Hero-Copy-Blöcke, Section-Heads, Button-Varianten, Karten, Slider-Meta und Kontaktmodule.
- Keine Public-Komponenten in Backend/Auth übernehmen und keine Backend/Auth-Klassen für Public-Seiten verwenden.
- Interaktionen mit Zustand gehören in Stimulus-Controller. ARIA-Attribute, sichtbare Klassen und URL-/Scroll-Zustand müssen zusammen aktualisiert werden.
- Inline-Styles in Views sind nur Übergangslösungen. Neue visuelle Regeln gehören in die passende Public-Stylesheet-Struktur.
- Bei künftigen Asset-Refactors muss die Oberflächen-Trennung beachtet werden: Public-Seiten verwenden Public-/Frontend-Assets, Backend/Auth eigene Backend-Assets.

Konsolidierungsziele für spätere Refactors:

- `.hero-button`, `.section-button`, `.button`, `.press-outline-button` in ein Public-Button-System überführen.
- `.references-filter-nav`, `.job-category-filter-nav` und `.services-jump-nav` als ein Filter-/Jump-Nav-Pattern modellieren.
- Hero-Varianten dokumentiert in gemeinsame Partial- und CSS-Strukturen überführen.
- Card-Muster mit gemeinsamen Regeln für Bild, Copy, Linkfläche, Fokus und Empty State zusammenführen.
- Slider-Controls und Meta-Anzeigen angleichen und Tastaturzustände robuster machen.

## Performance

Ziel ist Lighthouse-Grün ohne visuelle Verwässerung.

- Das primäre Hero-Bild einer Seite wird priorisiert und darf nicht lazy geladen werden.
- Bilder außerhalb des initial sichtbaren Bereichs verwenden `loading="lazy"` und `decoding="async"`.
- Jedes Bild braucht feste `width`/`height`, ein stabiles `aspect-ratio` oder eine andere verlässliche Größenreservierung gegen CLS.
- Above-the-fold-Heroes brauchen mobile und desktopgerechte Quellen oder saubere `object-position`-Regeln.
- Animationen sollen auf `transform` und `opacity` basieren. Layout-intensive Animationen, große Schattenorgien und dauerhafte Reflows vermeiden.
- Für neue Animationen `prefers-reduced-motion` berücksichtigen.
- Stimulus-Controller nur dort binden, wo die Interaktion gebraucht wird. Keine Controller auf globalen Wrappers platzieren, wenn ein kleinerer Scope reicht.
- Event- und Referenzlisten dürfen erweitert oder virtuell reduziert werden, aber zentrale Inhalte müssen weiterhin ohne JavaScript sinnvoll sichtbar bleiben.
- Lokale Fonts mit `font-display: swap` beibehalten und nur tatsächlich genutzte Schnitte ausliefern.
- Keine externen CSS-, Font-, Script- oder Tracking-Abhängigkeiten ohne ausdrückliche technische Entscheidung.

## Accessibility & Best Practices

Zielstandard für neue oder geänderte Public-Oberflächen ist WCAG 2.2 AA.

- Jede Seite braucht klare Landmarks: Header, Navigation, Main, Footer und sinnvolle Section-Struktur.
- Interaktive Elemente müssen per Tastatur erreichbar sein und sichtbare `:focus-visible`-Zustände besitzen.
- Touch-Ziele sollen mindestens ungefähr `44px` hoch oder breit sein, besonders Navigation, Slider, Filter, Buttons und Lightbox-Controls.
- Filterbuttons nutzen `aria-pressed`, wenn sie Inhalte filtern. Sprungnavigationen nutzen `aria-current`, wenn sie den aktiven Abschnitt markieren.
- Akkordeons synchronisieren `aria-expanded` mit offenem Zustand und dürfen Inhalt nicht unzugänglich machen.
- Slider-Slides dürfen nicht nur per Maus bedienbar sein. Aktive und versteckte Zustände müssen für Tastatur und Screenreader nachvollziehbar bleiben.
- Lightboxen brauchen `role="dialog"`, `aria-modal="true"`, Fokusmanagement, Escape-Schließen und Rücksprung zum Auslöser.
- Dekorative Bilder haben leeres `alt`. Inhaltliche Bilder beschreiben das relevante Motiv, nicht nur den Dateinamen.
- Externe Links verwenden `target="_blank"` nur mit `rel="noopener noreferrer"` oder `rel="noreferrer"`.
- Fehlende Inhalte brauchen robuste Empty States, zum Beispiel bei Referenzen, Jobs oder Pressesuche.
- Farbkontraste müssen für Text, Controls, Fokus und Zustände geprüft werden. Gold oder Grau alleine darf keinen Status tragen.

## SEO

- Jede öffentliche Seite hat genau eine klare H1. Danach folgen logisch verschachtelte H2/H3.
- Seitentitel und Descriptions werden über `@page_meta` oder `content_for` seitenspezifisch gepflegt.
- Titles müssen eindeutig sein und Russ Live, Seitenthema oder konkreten Inhalt erkennen lassen.
- Descriptions sind kurz, handlungsnah und beschreiben den konkreten Seitenwert.
- Links müssen sprechend sein. Generische sichtbare Labels wie „Mehr“ brauchen ein konkretes `aria-label`.
- Zentrale Inhalte bleiben serverseitig im HTML crawlbar. JavaScript darf filtern, erweitern oder blättern, aber keine wesentlichen Seiteninhalte exklusiv erzeugen.
- Kontaktinformationen gehören in `address` oder klar strukturierte Kontaktmodule.
- Veranstaltungs-, Job- und Presseinformationen werden semantisch mit Listen, Tabellenrollen, Definitionslisten oder Artikeln gegliedert.
- Bilder, die inhaltlich relevant sind, brauchen aussagekräftige Alt-Texte. Bildunterschriften und Credits sollen als sichtbarer Text erhalten bleiben, wenn sie für Presse oder Rechte relevant sind.
- Filter dürfen Inhalte visuell ausblenden, aber nicht so bauen, dass wichtige Seiteninhalte dauerhaft nur nach Client-State erreichbar sind.

## Mobile-Regeln

- `900px` ist der Tablet-/Mobile-Umschlagpunkt für Header, Navigation und mehrspaltige Layouts.
- `520px` ist der kleine Mobile-Breakpoint für einspaltige Karten, kompaktere Headerhöhe und reduzierte Hero-Typografie.
- Mobile Header, Jump-Navigationen und sticky Elemente müssen mit `scroll-padding-top` und `scroll-margin-top` zusammenspielen.
- Horizontale Filterleisten müssen scrollbar, fokussierbar und ohne abgeschnittene aktive Zustände nutzbar sein.
- Buttons und Links dürfen auf Mobile nicht nur über Hover funktionieren.
- Text darf nicht Bildmotive oder nachfolgende Inhalte unlesbar überdecken.
- Große Headlines müssen mit realen deutschen Texten geprüft werden, insbesondere bei Jobs, Services und Presse.

## Agent-Regeln für neue Public-UI

- Vor neuen UI-Klassen prüfen, ob eine Zielfamilie erweitert werden kann.
- Public-Patterns semantisch benennen und Varianten als Modifier führen.
- Keine externen Fonts, Iconsets, Script-CDNs oder Stylesheet-CDNs einführen.
- Bilder immer mit Performance-, SEO- und Accessibility-Regeln prüfen.
- Interaktive Komponenten mit Tastatur testen: Tab, Enter, Space, Escape und Pfeiltasten, wenn passend.
- Mobile bei `900px` und `520px` prüfen. Kein Textüberlauf, keine unbedienbaren Controls, keine verdeckten Inhalte.
- SEO-Basics prüfen: eine H1, logische Headings, Meta-Daten, sprechende Links, crawlbarer Content.
- Lighthouse-Ziel ist Grün in allen Kategorien für zentrale Public-Seiten.
- Prüfen, ob `README.md` betroffen ist. Bei reiner UI-Dokumentation ist keine README-Änderung nötig.

## Prüfliste vor Abschluss

- Ist die neue Oberfläche einer Public-Komponentenfamilie zugeordnet?
- Werden bestehende Tokens, lokale Fonts und vorhandene Layout-Rhythmen genutzt?
- Sind Desktop, `900px` und `520px` ohne Überlappungen geprüft?
- Haben alle interaktiven Elemente Fokuszustände und korrekte ARIA-Zustände?
- Sind Bilder dimensioniert, lazy geladen, sinnvoll beschrieben oder dekorativ leer?
- Bleiben zentrale Inhalte ohne JavaScript im HTML sichtbar?
- Sind `title`, `description`, H1 und Heading-Struktur seitenspezifisch und logisch?
- Sind externe Links abgesichert und Empty States verständlich?
- Wurden Performance, Accessibility, Best Practices und SEO bewusst gegen Lighthouse-Kriterien geprüft?
