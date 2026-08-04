# Lerninhalte-Extraktion (Basis für den Kontroll-Foliensatz)

**Zweck:** Vollständige Erfassung aller Lerninhalte, die das Spiel den Spielenden
tatsächlich vermittelt, als Grundlage für eine passive Kontrollbedingung
(Foliensatz) in der User-Studie.

**Stand:** Branch `main`, Commit `de1f6ae`, extrahiert am 2026-08-02.
`feature/mail-builder` ist vollständig in `main` enthalten; `main` ist die
massgebliche Fassung.

**Methodik und Abgrenzung:**

- Quellen: alle `.tscn`-Szenen, alle GDScript-Dateien, alle `.tres`-Ressourcen,
  alle fünf i18n-CSVs, die Telemetrie-Autoloads, `tools/analyze.py`,
  `docs/event_schema.md`.
- Es wurde **nichts ergänzt, umformuliert oder aus Allgemeinwissen aufgefüllt**.
  Alle Zitate sind wörtlich aus der jeweiligen Datei, mit Pfad und Zeilennummer.
- Als „vermittelt" zählt nur, was im laufenden Build **auf dem Bildschirm
  erscheinen kann**. Der laufende Code ist die einzige Referenz; ältere
  Design-Dokumente wurden bewusst nicht herangezogen.
- Balancing-Zahlen stammen aus `scenarios/spear_phishing/data/mail_card_pool.gd:13-27`,
  der einen zentralen Tuning-Stelle.

**Sprachen:** Deutsch und Englisch. Alle fünf CSVs haben die Spalten
`keys,de,en` (`autoloads/i18n.gd`); umschaltbar über das Hauptmenü
(`strings.csv:48-49`: „Sprache" / „Nur im Hauptmenü änderbar"). Alle Zitate in
diesem Dokument sind die **deutsche** Spalte.

---

## Gesamtaufbau des Spiels

| Ebene | Datei | Inhalt |
|---|---|---|
| Startbildschirm | `scenes/StartScreen.tscn` | „Level", „Einstellungen", „Beenden" (`strings.csv:44-46`) |
| Einstellungen | `scenes/settings_panel.gd` | Lautstärke, Vollbild, Sprache, **Teilnehmer-Code** (`strings.csv:37-50`) |
| Levelauswahl | `scenes/LevelAuswahl.tscn` | Einstieg in Szenario 1 / Szenario 2 |
| Szenario 1 | `scenarios/spear_phishing/` | Spear Phishing, 4 Sub-States |
| Szenario 2 | `scenarios/bad_usb/` | Physische Infiltration / Bad USB, 8 Sub-States |

**Beide Szenarien sind im aktuellen Stand vollständig spielbar und haben ein
ausformuliertes Debriefing.** Szenario 2 ist nicht mehr der Prototyp aus dem
Feature-Branch.

Szenario-Registrierung (`resources/scenarios/*.tres`):

> `spear_phishing.tres` — `display_name = "Szenario: Spear-Phishing"`,
> `description = "Identifiziere eine gezielte Phishing-E-Mail und reagiere richtig."`

> `bad_usb.tres` — `display_name = "Szenario: Bad USB"`,
> `description = "Entscheide, was mit dem gefundenen USB-Stick passieren soll."`

**Achtung:** Beide `description`-Texte beschreiben eine **Verteidiger**-Perspektive.
Gespielt wird in beiden Levels die **Angreifer**-Perspektive. Siehe L-02.

---

# Level 1 — Spear Phishing

## 1.1 Level-Name und Angriffsszenario in einem Satz

**Name:** „Szenario: Spear-Phishing"

**Szenario:** Die Spielenden übernehmen die Rolle eines Angreifers, der per OSINT
öffentlich verfügbare Informationen über das Umfeld eines CEO sammelt und daraus
eine personalisierte Phishing-Mail baut, die ihn zum Klick auf einen
Zugangs-Bestätigungslink bewegen soll.

**Ablauf (4 Sub-States,** `scenarios/spear_phishing/spear_phishing.gd:21`**):**
`BRIEFING → RECON → MAIL → RESOLVE`, mit optionaler „Spielbewertung" auf dem
Resolve-Screen.

**Figuren (nur die tatsächlich auftretenden):**

| Figur | Rolle | Quelle |
|---|---|---|
| Hannes Zinsli | CEO der FinTech AG, das Ziel | `strings.csv:60-61` |
| Nadja Tellenbach | Rechnungswesen, FinTech AG | `recon_content.csv:6,9,12,15` |
| Kevin Brösmeli (`kevin_broesmeli`) | Praktikant | `recon_content.csv:25,28,93` |
| „Direktor" | Auftraggeber / Handler | `strings.csv:59` |
| Bit & Bürli GmbH | externe IT-Firma, wird gespooft | `recon_content.csv:4,10,53,56` |
| Hannes Zinsli (Jodel-Dirigent) | Namensvetter-Falle | `recon_content.csv:42-44` |
| Hannes Zinsli (Immobilienmakler) | zweite Namensvetter-Falle | `recon_content.csv:45-47` |
| Prof. Dr. Hannes Zinsli (Uni Basel) | dritter Namensvetter, reines Rauschen | `recon_content.csv:69-71` |

---

## 1.2 Phase 0 — Briefing (Auftrag)

Kein Entscheidungspunkt. Vier Dialogzeilen mit Schreibmaschineneffekt
(40 Zeichen/s, `dialog_box.gd:20`), danach Akzeptieren-Button.

Die Texte liegen seit der Zweisprachigkeit als i18n-Schlüssel in der
`.tres` und werden aus `strings.csv` aufgelöst
(`resources/scenarios/spear_phishing/briefing.tres`).

**Wörtlich, `resources/i18n/strings.csv:63-66` (Sprecher „Direktor", `strings.csv:59`):**

> „Setz dich, Agent. Die FinTech AG hat ein Netzwerk, an das wir ran müssen. Der einfachste Weg rein ist ein Mensch, der auf das Falsche klickt."

> „Dein Ziel: Hannes Zinsli, CEO. Schreibt am Wochenende seine eigenen Mails. Wenn jemand klickt, dann er."

> „Bevor du ihm schreibst, willst du wissen, wer er ist. LinkedIn, Stellenanzeigen. Die Firma postet mehr, als ihr lieb wäre. Sammle alles, was du findest. Jedes Detail wird zu Munition."

> „Dann baust du die Mail zusammen. Zu viel Druck und er meldet dich. Zu wenig und er löscht dich. Fünf Versuche, bevor sich seine IT wundert. Mach den Job."

**Missions- und Belohnungszeile (`strings.csv:60-62`, `briefing.tres`):**

> Ziel: „H. Zinsli · CEO" · Mission: „Phishe Hannes Zinsli, CEO der FinTech AG"
> Belohnung: „Zugang zum internen Netzwerk" · `turn_budget = 5`

**Rahmung (`strings.csv:2-10`):**

> „● LIVE · SECURE CHANNEL · %s" · „● LIVE" · „VIDEO FEED · ENCRYPTED" ·
> „▲ TASK ASSIGNED" · „MISSION · %s" · „Belohnung: %s · Zeitlimit: %d Züge" ·
> „▶ Akzeptieren" · „▼ klicken für weiter"

**Persistente OS-Leiste (`strings.csv:11-19`, `os_chrome.gd`):**

> „DarkMail OS" · „● SECURE" · „MISSION" · „ZÜGE %d/%d" · „▲ MISSIONS-DOSSIER" ·
> „[ Klicken zum Schliessen ]" · Stepper „Recon ▸ Mail ▸ Resolve"

**Lerninhalt dieser Phase (textlich belegt):**

1. Der einfachste Weg in ein Netzwerk ist ein Mensch, der auf das Falsche klickt.
2. Vor dem Angriff steht die Aufklärung über die Zielperson.
3. Genannte OSINT-Quellenarten: LinkedIn, Stellenanzeigen.
4. „Die Firma postet mehr, als ihr lieb wäre." — die Organisation ist die Leckquelle.
5. „Jedes Detail wird zu Munition."
6. Zu viel Druck → Meldung; zu wenig Druck → Löschung.
7. Der Angreifer hat ein begrenztes Zeitfenster, bevor die IT aufmerksam wird.

---

## 1.3 Phase 1 — Recon (Entscheidungspunkt 1)

### 1.3.1 Mechanik

| Fakt | Wert | Quelle |
|---|---|---|
| Deck-Limit | **7** | `states/recon.gd:15` |
| Fundstücke gesamt | 31 | `data/recon_pool.gd:13-64` |
| davon Rauschen (`is_noise`, nie einsammelbar) | 8 | `recon_pool.gd` |
| davon Foto-Träger für Hotspots (nicht einsammelbar) | 3 | `q2d_teamfoto`, `q5_praktikant`, `q5b_badge` |
| **einsammelbar** | **19** (12 Epic, 7 Fallen) | Abgleich mit `mail_card_pool.gd:47-67` |
| Quellen-Tabs | 6 | LinkBook, Instasnap, kmunu, Goggle, JobScoot, Firmenseite |
| Zeitlimit in dieser Phase | **keines** | kein Timer im Code |

**Interaktionsmodell:** Der Leak steckt **inline im Fliesstext**, markiert mit
`⟦…⟧` (`data/recon_find.gd:15-16`), wird erst beim Hover sichtbar und per Klick
auf genau diese Textstelle eingesammelt. Kommentar im Code:

> „so a card never advertises where the leak sits" (`recon.gd`)

Drei Funde sind **nur per Foto-Zoom** erreichbar (Hotspot-Rechteck auf dem Bild):
`q2d_whiteboard`, `q5_schema`, `q5b_details`.

**Statusanzeige (`strings.csv:51-58`):**

> „Browser" · „⇅ INTERCEPT" · „RECON // OSINT-SWEEP" · „DECK %d/%d" ·
> „Eingesammelt: (noch nichts)" · „Eingesammelt (%d): %s" ·
> „RECON ABSCHLIESSEN ▸" · „LinkBook — Recherche"

**Fantasie-Plattformnamen:** LinkedIn→„LinkBook", Instagram→„Instasnap",
kununu→„kmunu", Google→„Goggle", JobScout→„JobScoot",
Firmenwebsite→„Firmenseite" (`strings.csv:73`), mit `.local`-URLs.

### 1.3.2 Der Entscheidungspunkt

**Situation:** 31 Beiträge auf 6 Plattformen; höchstens 7 dürfen mitgenommen werden.

**Optionen:** pro einsammelbarem Fund binär — einsammeln oder liegenlassen
(umkehrbar per erneutem Klick).

**Wertung:** Das Einsammeln wird **geloggt und benotet**: Ein Fund mit
`is_junk = true` gilt als Fehler (`recon.gd:142-156`, `is_correct = not find.is_junk`).
Im Spiel selbst gibt es dazu **kein sichtbares Feedback** — die Wertung passiert
nur in den Studiendaten. Der Spieler merkt den Fehler erst in der Mail-Phase.

**Konsequenz im Spiel:** Die gewählten Funde bestimmen die Hand im MailBuilder
(`recon.gd` → `GameState.set_collected_finds` → `mail_card_pool.build_hand`).
Fallen produzieren Karten, die das Misstrauen **erhöhen**.

### 1.3.3 Alle Fundstücke wörtlich

Notation: `⟦…⟧` = die klickbare Leck-Textstelle. Alle Texte aus
`resources/i18n/recon_content.csv` (deutsche Spalte).

#### Tab „LinkBook" (LinkedIn)

**`q1_kontakt` → Karte „Vertrauter Kontakt" (Epic, 0/0)** · CSV 2-4
> Titel: „Vertrauter Kontakt (IT-Firma in Kontaktliste)"
> Autor: „Hannes Zinsli · CEO bei FinTech AG"
> Body: „Gemeinsame Kontakte (3): ⟦Bit & Bürli GmbH⟧, Handelskammer Zürich, Swiss Finance Network."

**`q2a_sonntags` → „Sonntags-Hannes" (Epic, Misstrauen −2)** · CSV 5-7
> Titel: „Sonntags-Post: Chef antwortet spätnachts"
> Autor: „Nadja Tellenbach · Rechnungswesen bei FinTech AG"
> Body: „Kleiner Realitätscheck fürs Wochenende. Ich schreibe dem Chef ⟦am Sonntag um halb zwölf nachts eine Frage zum Quartalsabschluss, und keine zwei Minuten später habe ich seine Antwort⟧. Der Mann schläft nie. Nächste Woche zwinge ich ihn zu einer Mittagspause."

**`q2b_neue_it` → „Frische IT" (Epic, Misstrauen −2)** · CSV 8-10
> Titel: „Post: Wechsel zur neuen IT-Firma"
> Body: „Endlich. Nach Wochen des Wartens haben wir die IT gewechselt. Ab jetzt macht ⟦Bit & Bürli GmbH⟧ unseren Support, und die rufen tatsächlich zurück. Fühlt sich an wie ein neues Zeitalter."

**`q2c_katze` — FALLE → „Katzen-Smalltalk" (Schrott, Misstrauen +1)** · CSV 11-13
> Titel: „Katzen-Smalltalk"
> Body: „Homeoffice-Alltag: ⟦Mimi hat den ganzen Vormittag auf meiner Tastatur geschlafen⟧ und will jetzt auch noch ins Meeting. Prioritäten einer Bürokatze."

**`q2d_teamfoto` — NICHT einsammelbar, Träger für den Zoom-Hotspot** · CSV 14-16
> Titel: „Team-Foto (Mittagessen)"
> Body: „Team-Zmittag mit den besten Kolleginnen und Kollegen. Solche Tage machen den Job aus."

**`q2d_whiteboard` — NUR per Foto-Zoom → „Projekt Helvetia" (Epic, Druck +2)** · CSV 20-23
> Titel: „Whiteboard im Hintergrund: interner Projektname" · Hotspot: „Foto zoomen"
> Autor: „Team-Foto · herangezoomt"
> Body: „Im Hintergrund, halb verdeckt von einem Kollegen, ein Whiteboard. Oben lesbar steht ⟦HELVETIA⟧. Darunter eine Tabelle mit Wochennummern, in der Spalte KW 24 ist eine Zeile grün markiert, daneben steht Go-Live?."

**`q2x_alt` — FALLE → „Alter Beitrag" (Schrott, Misstrauen +1)** · CSV 17-19
> Titel: „Alter Beitrag (beendetes Projekt)" · Autor: „FinTech AG · Unternehmensseite · vor 3 Jahren"
> Body: „Rückblick auf ein starkes Jahr. Mit dem Abschluss von ⟦Projekt Atlas⟧ haben wir unsere Kernbanking-Migration erfolgreich beendet. Danke an alle Beteiligten."

#### Tab „Instasnap" (Instagram)

**`q5_praktikant` — NICHT einsammelbar, Träger für den Zoom-Hotspot** · CSV 24-26
> Titel: „Praktikant: erster Arbeitstag" · Autor: „kevin_broesmeli · FinTech AG"
> Body: „Tag 1 im neuen Job. So ein cooler Arbeitsplatz, ich freu mich mega. Danke an meinen Onboarding-Buddy fürs Setup, meine Adresse ist schon eingerichtet. #praktikum #firstday #fintech"

**`q5_schema` — NUR per Foto-Zoom → „Mail-Schema" (Epic, 0/0)** · CSV 30-33
> Titel: „Mail-Schema am Bildschirm sichtbar" · Hotspot: „Bildschirm zoomen"
> Body: „Auf dem Bildschirm hinter Kevin ist die frisch eingerichtete Mail-Signatur offen. Kevin Brösmeli, kevin.broesmeli@fintech.ch. Daraus lässt sich das Schema ableiten: ⟦vorname.nachname@fintech.ch⟧."

**`q5b_badge` — NICHT einsammelbar, Träger für den Zoom-Hotspot** · CSV 93-94
> Autor: „kevin_broesmeli · Beitrag"
> Body: „Endlich offiziell, mein eigener Badge ist da. Fühlt sich richtig gut an. #newjob #fintech"

**`q5b_details` — NUR per Foto-Zoom → „Badge-Leck" (Epic, Misstrauen −1)** · CSV 95-98
> Titel: „Badge herangezoomt: Nummer und Gebäude" · Hotspot: „Badge zoomen"
> Body: „Auf dem Badge lesbar: Firmenlogo, Kevin Brösmeli, ⟦Mitarbeiternummer MA-0473, Gebäude A, 4. OG⟧. Genug, um am Empfang niemandem aufzufallen."

**`q5x_cafe` — FALLE → „Café-Standort" (Schrott, Misstrauen +1)** · CSV 27-29
> Titel: „Story: Café verlinkt, Standort geteilt"
> Body: „Bester Kaffee der Stadt gefunden. Verlinke mal den Laden hier, ⟦Standort ist getaggt⟧. Kommt vorbei."

**`n_insta_sunset` — Rauschen** · CSV 57-58 · „Feierabend mit Aussicht. So lässt sich die Woche ausklingen. #sunset #feierabend"

**`n_insta_setup` — Rauschen** · CSV 59-60 · „Neues Homeoffice-Setup steht endlich. Produktiv und gemütlich zugleich. #homeoffice #setup"

#### Tab „kmunu" (kununu)

**`q6_kununu` → „Keiner fragt nach" (Epic, Misstrauen −1, Druck-Verstärker)** · CSV 34-37
> Titel: „Anonyme Bewertung: Firmenkultur" · Sterne: 2 · Autor: „Rechnungswesen · Ehemalige/r · 2 Sterne"
> Body: „Solide Firma, aber die Hierarchie ist old school. Fachlich lernt man viel, das Team ist top. Was mich gestört hat: Prozesse werden nicht hinterfragt. ⟦Kommt eine Anweisung von oben oder von der IT, wird sie ausgeführt, Punkt. Nachfragen ist unerwünscht⟧, das wurde mir früh klargemacht. Der Chef ist zudem kaum je greifbar, alles läuft über die Assistenz. Für Eigenständige frustrierend, für Leute die klare Ansagen mögen ok."

**`q6x_lob` — FALLE → „Rundum-Lob" (Schrott, Misstrauen +2)** · CSV 38-41
> Titel: „Bewertung: Rundum-Lob ohne Inhalt" · Sterne: 5
> Body: „Beste Firma überhaupt. ⟦Mega Team, mega Spirit⟧, würde sofort wieder anfangen. Gibt nichts zu meckern."

**`n_kmunu_neutral` — Rauschen** · CSV 61-64 · „Ganz okay", 3 Sterne
> „Weder gut noch schlecht. Man kommt, man arbeitet, man geht. Kantine ist in Ordnung, Parkplätze sind knapp. Nichts, worüber man gross reden müsste."

**`n_kmunu_kantine` — Rauschen** · CSV 65-68 · „Essen könnte besser sein", 4 Sterne
> „Insgesamt zufrieden. Einziger Kritikpunkt: das Mittagsangebot wiederholt sich zu oft. Sonst faire Löhne und nette Kollegen."

#### Tab „Goggle" (Google-Suche)

**`q7_jodler` — FALLE → „Namensvetter: Jodler" (Schrott, Misstrauen +3)** · CSV 42-44
> Titel: „Suchtreffer: Hannes Zinsli, Jodel-Dirigent" · Autor: „goggle.local · Ergebnis 3 von 41"
> Body: „Hannes Zinsli holt Gold am Eidgenössischen. jodlerverband-emmental.ch. Unser Dirigent Hannes Zinsli leitet das ⟦Jodelchörli Schangnau⟧ seit 1998."

**`q7x_makler` — FALLE → „Namensvetter: Makler" (Schrott, Misstrauen +3)** · CSV 45-47
> Titel: „Suchtreffer: Hannes Zinsli, Immobilienmakler" · Autor: „goggle.local · Ergebnis 7 von 41"
> Body: „Hannes Zinsli, ⟦Immobilienmakler in Chur⟧. Ihr zuverlässiger Partner für Wohnungen und Häuser im Bündnerland."

**`q9_verein` → „Vereinskollege" (Epic, 0/0)** · CSV 48-50
> Titel: „Vereinsprotokoll mit Foto (PDF)" · Autor: „goggle.local · Ergebnis 12 von 41"
> Body: „Schützengesellschaft Adliswil, Jahresprotokoll 2024 als PDF. ⟦Als Kassier wiedergewählt: Hannes Zinsli⟧. Dazu ein Foto vom Vereinsfest mit vollem Namen und Bildunterschrift."

**`q10_archiv` → „Archiv-Fund" (Epic, 0/0)** · CSV 84-86
> Titel: „FinTech AG Team (archivierte Seite)" · Autor: „web.archive.org · Snapshot 12.03.2019"
> Body: „Alte Team-Seite der FinTech AG aus dem Webarchiv, längst gelöscht, hier aber noch gespeichert. Zeigt eine inzwischen ausgeschiedene Mitarbeiterin mit ⟦Direktwahl 044 555 21 40 und der Adresse vorname.nachname@fintech.ch⟧. Das Format war schon damals dasselbe."

**`n_goggle_uni` — Rauschen** · CSV 69-71 · „Prof. Dr. Hannes Zinsli, Universität Basel"
> „Lehrstuhl für mittelalterliche Geschichte. Publikationen, Sprechstunden und Vorlesungsverzeichnis im Herbstsemester."

**`n_goggle_ad` — Rauschen** · CSV 72-74 · „Zinsli günstig kaufen, Top Preise" · „goggle.local · Anzeige"
> „Riesenauswahl zu Bestpreisen. Jetzt vergleichen und sparen, versandkostenfrei ab 50 Franken."

#### Tab „JobScoot" (Stellenportal)

**`q3_stelle` → „Bit & Bürli bestätigt" (Epic, 0/0)** · CSV 51-53
> Titel: „Stellenanzeige nennt IT-Partner" · Autor: „JobScoot · Stelleninserat"
> Body: „FinTech AG sucht System Engineer, 80 bis 100 Prozent. Sie betreuen unsere Microsoft-365- und Azure-Umgebung in enger Zusammenarbeit mit unserem ⟦externen IT-Partner Bit & Bürli GmbH⟧. Wir bieten flexible Arbeitszeiten, ein modernes Büro am Zürichsee und ein motiviertes Team. Bewerbungen an jobs@fintech.ch."

**`q3z_system` → „Systemwissen" (Epic, Misstrauen −1)** · CSV 87-89
> Titel: „FinTech AG sucht: Sachbearbeiter/in Zahlungsverkehr 80%"
> Body: „Sie verarbeiten Zahlungen in unserem Kernbankensystem ⟦Finnova und betreuen den Fernzugang über unser VPN⟧. Wir bieten ein eingespieltes Team und moderne Infrastruktur. Bewerbungen an jobs@fintech.ch."

**`q3y_konkurrenz` — FALLE → „Falsche Firma" (Schrott, Misstrauen +2)** · CSV 90-92
> Titel: „ZugFin AG sucht: Community Manager 100%"
> Body: „Junges Fintech-Team sucht Verstärkung für Social Media und Community. ⟦Büro in Zug, Homeoffice möglich⟧, Start nach Vereinbarung."

**`n_jobscoot_verkauf` — Rauschen** · CSV 75-77 · „Verkaufsberater/in Sportartikel 60%"
> „Für unsere Filiale in Winterthur suchen wir eine motivierte Persönlichkeit mit Freude am Kundenkontakt. Erfahrung im Detailhandel von Vorteil."

**`n_jobscoot_pflege` — Rauschen** · CSV 78-80 · „Pflegefachperson HF, Nachtdienst"
> „Regionalspital sucht per sofort oder nach Vereinbarung. Attraktive Anstellungsbedingungen, gutes Team, moderne Infrastruktur."

#### Tab „Firmenseite" (Unternehmenswebsite)

**`q4_presse` → „Migrations-Aufhänger" (Epic, Druck +2)** · CSV 54-56
> Titel: „Pressemitteilung: laufende Migration" · Autor: „fintech-ag.local · Medienmitteilung"
> Body: „Die FinTech AG ⟦schliesst diesen Monat die Migration auf eine neue Cloud-Plattform ab⟧. Ein wichtiger Schritt für unsere Sicherheit, so CEO Hannes Zinsli. Umgesetzt wurde das Projekt gemeinsam mit dem Partner Bit & Bürli GmbH. Weitere Informationen folgen im nächsten Quartalsbericht."

**`n_presse_jubilaeum` — Rauschen** · CSV 81-83 · „25 Jahre FinTech AG"
> „Dieses Jahr feiern wir unser 25-jähriges Bestehen. Wir danken unseren Kundinnen und Kunden für ihr Vertrauen und blicken mit Zuversicht in die Zukunft."

---

## 1.4 Phase 2 — MailBuilder (Entscheidungspunkte 2 bis n)

### 1.4.1 Mechanik und alle Balancing-Konstanten

Alle Werte aus `scenarios/spear_phishing/data/mail_card_pool.gd:13-27`
(**gegenüber dem Feature-Branch unverändert**):

| Konstante | Wert | Bedeutung |
|---|---|---|
| `TURN_BUDGET` | **5** | Anzahl Mails, die gesendet werden dürfen |
| `SUSPICION_START` | **4** | Startwert Misstrauen |
| `SUSPICION_TARGET` | **3** | Sieg verlangt Misstrauen ≤ 3 |
| `SPAM_THRESHOLD` | **7** | Misstrauen > 7 ⇒ sofort SPAM |
| `PRESSURE_START` | **3** | Startwert Handlungsdruck |
| `PRESSURE_TARGET` | **7** | Payload erst ab Druck ≥ 7 spielbar |
| `KOLLEGEN_MIN` / `KOLLEGEN_MAX` | 4 / 7 | Misstrauensband für „Kollegen-Rückfrage" |
| `AMPLIFIER_BONUS` | +1 | Bonus von „Keiner fragt nach" auf Druckkarten |
| `SUSPICION_BAR_MAX` / `PRESSURE_BAR_MAX` | 10 / 10 | Anzeigeskala |
| `MAX_SLOTS` | **3** | Karten pro Mail (`states/mail_builder.gd`) |

**Zugmodell:** Eine Mail = ein Zug. Der Spieler entwirft 1 bis 3 Karten, sendet
sie gebündelt; die Effekte werden **erst nach dem Senden** Karte für Karte
aufgedeckt (0,5 s pro Schritt). Zusätzlich: „Zug überspringen".

**Regeländerung gegenüber dem Feature-Branch** (`mail_builder_state.gd:62-75`):
Nicht-Payload-Karten bleiben spielbar, bis der Angriff tatsächlich **gewinnen
würde** (`not payload_would_win()`), nicht mehr nur bis das Gate offen ist.
Begründung im Code:

> „Locking on the open gate alone would strand a player whose pressure is high
> but whose suspicion is still above target: they could neither repair the
> suspicion nor win, and every remaining move would be a loss."

Der Spieler kann also bei hohem Druck und zu hohem Misstrauen noch nachbessern.

**Zentrale didaktische Designentscheidung — keine Effektvorschau:**

> „There is deliberately NO effect indicator — the player must judge the card's
> CONTENT, not read arrows." — `components/mail_hand_card.gd:1-4`

Neu auf `main`: ein „[i]"-Abzeichen in der Kartenecke als Hinweis auf den
Hover-Tooltip, plus ein eigens gestalteter Tooltip im DarkMail-Look.

**Fallen sind visuell nicht markiert:**

> „Traps are NOT visually flagged: schrott wears the same label and accent as the
> card it masquerades as (collected recon intel -> EPIC, a generic scam ->
> STANDARD). Recognising junk from its name/text is the measured skill."
> — `components/mail_hand_card.gd`

**Vier Ausgänge (`mail_builder_state.gd`, Enum `Outcome`):**

| Ausgang | Bedingung |
|---|---|
| `WIN` | Payload gespielt bei Druck ≥ 7 **und** Misstrauen ≤ 3 |
| `KOLLEGEN_RUECKFRAGE` | Payload gespielt bei Druck ≥ 7, aber Misstrauen 4–7 |
| `SPAM` | Misstrauen > 7 nach einer Mail |
| `IGNORIERT` | Zugbudget aufgebraucht ohne Payload-Treffer |

### 1.4.2 Der wiederkehrende Entscheidungspunkt

**Situation:** Zwei Balken (Misstrauen ≤ 3 anstreben, Handlungsdruck ≥ 7
anstreben), 5 Züge, eine Hand aus bis zu 17 Karten.

**Handzusammensetzung (`mail_card_pool.gd:111-127`):** gesammelte Recon-Karten
(≤ 7) + freigeschaltete Legendaries (0–4) + Probe-Karte *oder* das durch sie
freigeschaltete „Abwesenheits-Fenster" + 4 Generikkarten (unerschöpflich) + Payload.

**Optionen pro Zug:** 1–3 spielbare Karten in die Mail legen und senden, **oder**
den Zug überspringen.

**Wertung:** Das Spielen einer SCHROTT-Karte gilt als Fehler
(`mail_builder_state.gd:283-291`, `is_correct = card.type != SCHROTT`), ebenso ein
Payload gegen nicht gewinnbare Balken. Alles andere ist ein legitimer Zug, dessen
Güte sich erst im Ausgang zeigt.

### 1.4.3 Vollständiger Kartenkatalog

Werte: `mail_card_pool.gd:47-100`. Texte: `resources/i18n/mail_content.csv`.
**Tooltip** = Text beim Überfahren, **Mail-Fragment** = der Satz, der in die Mail
geschrieben wird.

#### Recon-Karten, Typ EPIC (12)

| ID | Name | Δ Misstrauen | Δ Druck | Prinzip | aus Fund |
|---|---|---|---|---|---|
| `sonntags_hannes` | Sonntags-Hannes | **−2** | 0 | konsistenz | `q2a_sonntags` |
| `frische_it` | Frische IT | **−2** | 0 | autoritaet | `q2b_neue_it` |
| `keiner_fragt_nach` | Keiner fragt nach | **−1** | 0 | konformitaet | `q6_kununu` |
| `systemwissen` | Systemwissen | **−1** | 0 | plausibilitaet | `q3z_system` |
| `badge_leck` | Badge-Leck | **−1** | 0 | autoritaet | `q5b_details` |
| `migrations_aufhaenger` | Migrations-Aufhänger | 0 | **+2** | plausibilitaet | `q4_presse` |
| `projekt_helvetia` | Projekt Helvetia | 0 | **+2** | similaritaet | `q2d_whiteboard` |
| `vereinskollege` | Vereinskollege | 0 | 0 | sympathie | `q9_verein` |
| `vertrauter_kontakt` | Vertrauter Kontakt | 0 | 0 | sympathie | `q1_kontakt` |
| `mail_schema` | Mail-Schema | 0 | 0 | konsistenz | `q5_schema` |
| `bit_buerli` | Bit & Bürli bestätigt | 0 | 0 | autoritaet | `q3_stelle` |
| `archiv_fund` | Archiv-Fund | 0 | 0 | konsistenz | `q10_archiv` |

„Keiner fragt nach" trägt `amplifies_pressure = true`: alle **späteren**
Druckkarten wirken +1 stärker.

**Tooltips und Mail-Fragmente wörtlich:**

- **Sonntags-Hannes** (CSV 2-3, 62) — Tooltip: „Er antwortet noch spätabends zuverlässig. Eine Mail zur Unzeit wirkt bei ihm normal." · Fragment: „Entschuldigen Sie die Nachricht ausserhalb der üblichen Zeit."
- **Frische IT** (CSV 4-5, 63) — Tooltip: „Die neue IT-Firma kennt niemand persönlich. Ideal, um sie vorzutäuschen." · Fragment: „wir betreuen ab sofort die IT-Infrastruktur Ihres Hauses."
- **Keiner fragt nach** (CSV 6-7, 64) — Tooltip: „Anweisungen von der IT werden ohne Rückfrage befolgt. Verstärkt deine Druckkarten." · Fragment: „Bitte führen Sie die Schritte wie gewohnt direkt aus."
- **Migrations-Aufhänger** (CSV 8-9, 65) — Tooltip: „Die laufende Migration ist ein legitimer Vorwand für eine dringende IT-Mail." · Fragment: „Im Zuge der laufenden Systemmigration ist eine Bestätigung erforderlich."
- **Projekt Helvetia** (CSV 10-11, 66) — Tooltip: „Der interne Projektname macht dich zum vermeintlichen Insider." · Fragment: „Es betrifft die Zugänge im Umfeld von Projekt Helvetia."
- **Vereinskollege** (CSV 12-13, 67) — Tooltip: „Allein kaum nützlich. Wertvoll erst kombiniert mit einem zweiten Fund." · Fragment: „Wir kennen uns übrigens aus dem Verein."
- **Vertrauter Kontakt** (CSV 14-15, 68) — Tooltip: „Ein gemeinsamer Kontakt im Netzwerk. Kein Effekt allein, aber ein Baustein." · Fragment: „Ein gemeinsamer Kontakt hat mich an Sie verwiesen."
- **Mail-Schema** (CSV 16-17, 69) — Tooltip: „Das Adressformat der Firma. Technische Voraussetzung, allein ohne Wirkung." · Fragment: „Diese Nachricht folgt dem üblichen Format des Supports."
- **Bit & Bürli bestätigt** (CSV 18-19, 70) — Tooltip: „Bestätigt Bit & Bürli als IT-Partner und legt den Spoof-Absender fest." · Fragment: „Wir handeln im Auftrag Ihres IT-Partners Bit & Bürli."
- **Systemwissen** (CSV 20-21, 71) — Tooltip: „Nennt das echte Kernsystem beim Namen und wirkt dadurch legitim." · Fragment: „Es geht um Ihr Kernsystem, mit dem Sie täglich arbeiten."
- **Archiv-Fund** (CSV 22-23, 72) — Tooltip: „Ein Archiv-Snapshot bestätigt das Adressschema ein zweites Mal." · Fragment: „Ihre hinterlegten Angaben stimmen mit unseren Unterlagen überein."
- **Badge-Leck** (CSV 24-25, 73) — Tooltip: „Interne Badge-Details beweisen Zugehörigkeit und senken Misstrauen." · Fragment: „Zur Verifizierung nennen wir Ihre bekannten Badge-Details."

#### Fallen aus der Recon, Typ SCHROTT (7) — im Deck als EPIC getarnt

| ID | Name | Δ Misstrauen | Prinzip |
|---|---|---|---|
| `namensvetter_jodler` | Namensvetter: Jodler | **+3** | kontextbruch |
| `namensvetter_makler` | Namensvetter: Makler | **+3** | kontextbruch |
| `falsche_firma` | Falsche Firma | **+2** | kontextbruch |
| `rundum_lob` | Rundum-Lob | **+2** | irrelevanz |
| `katzen_smalltalk` | Katzen-Smalltalk | **+1** | irrelevanz |
| `alter_beitrag` | Alter Beitrag | **+1** | irrelevanz |
| `cafe_standort` | Café-Standort | **+1** | irrelevanz |

- **Katzen-Smalltalk** (CSV 26-27, 74) — Tooltip: „Ein Katzenfoto in einer Phishing-Mail. Wirkt creepy und ahnungslos." · Fragment: „PS: Anbei ein Foto meiner Katze, herzig oder?"
- **Namensvetter: Jodler** (CSV 28-29, 75) — Tooltip: „Der falsche Hannes Zinsli. Ein Hobby, das dein Ziel gar nicht hat." · Fragment: „Grüsse auch vom Jodlerklub, wie letztes Mal."
- **Namensvetter: Makler** (CSV 30-31, 76) — Tooltip: „Wieder der falsche Hannes Zinsli, diesmal ein Immobilienmakler." · Fragment: „Zur Immobilie melde ich mich separat noch."
- **Falsche Firma** (CSV 32-33, 77) — Tooltip: „Gehört zu einem anderen Unternehmen. Komplett am Ziel vorbei." · Fragment: „Dies betrifft Ihr Konto bei der Muster GmbH."
- **Rundum-Lob** (CSV 34-35, 78) — Tooltip: „Nichtssagendes Lob ohne jeden verwertbaren Inhalt." · Fragment: „Ganz generell machen Sie wirklich einen super Job!"
- **Alter Beitrag** (CSV 36-37, 79) — Tooltip: „Ein längst beendetes Projekt. Veraltet und wertlos." · Fragment: „Bezugnehmend auf das längst abgeschlossene Altprojekt."
- **Café-Standort** (CSV 38-39, 80) — Tooltip: „Ein getaggter Café-Standort. Nett, aber keine Munition." · Fragment: „Schöner Ort übrigens, das Café von neulich."

#### Generikkarten (immer in der Hand, unerschöpflich)

| ID | Name | Typ | Δ Misstrauen | Δ Druck | Prinzip |
|---|---|---|---|---|---|
| `konto_gesperrt` | Konto gesperrt | STANDARD | +1 | **+4** | autoritaet |
| `rechnung_unbezahlt` | Rechnung unbezahlt | STANDARD | +1 | **+3** | konsequenz |
| `frist_heute` | Frist heute | STANDARD | +1 | **+3** | knappheit |
| `gratis_krypto` | Gratis Krypto | **SCHROTT** | **+3** | 0 | gier |

- **Konto gesperrt** (CSV 40-41, 81) — Tooltip: „Ihr Konto wurde gesperrt. Plumper Druck, der Misstrauen weckt." · Fragment: „Ihr Konto wurde vorübergehend gesperrt."
- **Rechnung unbezahlt** (CSV 42-43, 82) — Tooltip: „Offene Rechnung, letzte Mahnung. Druck mit Beigeschmack." · Fragment: „Eine offene Rechnung ist noch nicht beglichen."
- **Frist heute** (CSV 44-45, 83) — Tooltip: „Die Frist läuft heute ab. Zeitdruck, der auch Misstrauen hebt." · Fragment: „Die Frist zur Bestätigung läuft heute ab."
- **Gratis Krypto** (CSV 46-47, 84) — Tooltip: „Gratis Krypto für Sie. Viel zu offensichtlich, reiner Alarm." · Fragment: „Sichern Sie sich jetzt Ihr kostenloses Krypto-Guthaben!"

#### Payload und Probe

- **Zugang bestätigen** (`zugang_bestaetigen`, PAYLOAD, 0/0, `commitment`) — CSV 48-49, 85
  Tooltip: „Der eigentliche Angriff: der Link zum Bestätigen des Zugangs."
  Fragment: „Bitte bestätigen Sie Ihren Zugang: bit-buerli-services.example/zugang"
- **Erreichbarkeit prüfen** (`probe_ooo`, EPIC 0/0, `aufklaerung`, `grants_probe`) — CSV 60-61, 91
  Tooltip: „Eine harmlose Testmail. Löst womöglich eine automatische Abwesenheitsnotiz aus."
  Fragment: „Kurze Rückfrage: Sind Sie diese Woche im Haus erreichbar?"
  *(Auf `main` ergänzt — im Feature-Branch fehlte dieses Fragment.)*
- **Abwesenheits-Fenster** (`abwesenheits_fenster`, EPIC, 0/**+3**, `knappheit`) — CSV 58-59, 90
  Tooltip: „Er ist abwesend und im Stress. Eine Deadline wirkt jetzt völlig normal."
  Fragment: „Da Sie gleich abwesend sind, erledigen wir das jetzt rasch."

Toast nach der Probe-Mail (CSV 101):
> „Automatische Antwort erhalten. Er ist abwesend."

#### Legendaries (Cross-Reference-Kombinationen)

| ID | Name | Δ Misstrauen | Δ Druck | Freischaltung |
|---|---|---|---|---|
| `perfekter_absender` | Perfekter Absender | **−3** | 0 | `q2b_neue_it` + `q3_stelle` |
| `verifiziert` | Verifiziert | **−3** | 0 | `q9_verein` + `q7_jodler` |
| `echter_vorwand` | Echter Vorwand | **−1** | **+3** | `q4_presse` + `q2d_whiteboard` |
| `identitaet_gesichert` | Identität gesichert | 0 | **+2** | `q5_schema` + (Probe **oder** `q10_archiv`) |

- **Perfekter Absender** (CSV 50-51, 86) — Tooltip: „Frische IT plus bestätigter Partner. Ein Absender ganz ohne Baseline." · Fragment: „Als Ihr verifizierter IT-Partner schreiben wir Sie direkt an."
- **Echter Vorwand** (CSV 52-53, 87) — Tooltip: „Migration plus Projektname. Ein konkreter, zeitlich begrenzter Grund." · Fragment: „Konkret geht es um die migrationsbedingte Freischaltung bis heute."
- **Verifiziert** (CSV 54-55, 88) — Tooltip: „Das Vereinsfoto entschärft die Namensvetter-Falle und sichert das Ziel." · Fragment: „Zur Sicherheit: die Anfrage ist intern bestätigt und legitim."
- **Identität gesichert** (CSV 56-57, 89) — Tooltip: „Schema plus Bestätigung. Exakte Adresse und Dringlichkeit zugleich." · Fragment: „Absender und Vorgang sind eindeutig Ihrem Konto zugeordnet."

### 1.4.4 Mailkopf und Balkenbeschriftung

`mail_content.csv:92-94`, `strings.csv:20-36`:

> `MAIL_PREVIEW_FROM_VALUE` → „it-support@bit-buerli-services.example" *(im UI nicht gerendert, siehe L-05)*
> `MAIL_PREVIEW_TO_VALUE` → „hannes.zinsli@fintech-ag.example"
> `MAIL_PREVIEW_SUBJECT_VALUE` → „Dringend: Zugang bestätigen"
> „MISSTRAUEN" · „HANDLUNGSDRUCK" · „Ziel ≤" · „Ziel ≥"
> „▤ MAILVERLAUF" · „▸ Du" · „◂ Hannes Zinsli"
> „Mail senden ▶" · „Zug überspringen" · „Mail %d/3"

**Hinweis zur Ziel-Mailadresse:** Der Mailkopf zeigt
`hannes.zinsli@fintech-ag.example`, das per Recon geleakte Schema lautet
`vorname.nachname@fintech.ch`. Die Domains stimmen nicht überein. Siehe L-06.

### 1.4.5 Handler-Kommentare (Auftraggeber-Chat) — wörtlich

Jede Zeile feuert höchstens einmal pro Lauf. Texte aus `mail_content.csv:95-100`.

| Auslöser | Text |
|---|---|
| beim Öffnen der Phase | „Bau die Mail zusammen. Erst Druck aufbauen, dann den Link setzen. Und halt das Misstrauen unten." |
| Schrottkarte in der Mail | „Was soll das? Der Mist gehört nicht in die Mail." |
| Misstrauen ≥ 7 | „Noch eine falsche Karte und er meldet uns als Spam. Rudere zurück." |
| Misstrauen ≥ 5 | „Vorsicht. Das wird ihm langsam suspekt." |
| Gewinnbereit | „Sauber, kaum Misstrauen. Jetzt den Link, das sitzt." |
| Gate offen, aber misstrauisch | „Gut. Er steht unter Druck und die Mail ist sendebereit." |

### 1.4.6 Reaktionen von Hannes — wörtlich

Der Zustand wird aus den beiden Balken abgeleitet (`mail_card_pool.gd:176-183`),
pro Zustand rotieren drei Varianten. Texte aus `mail_content.csv:102-113`.

**NEUTRAL** (Misstrauen ≤ 3, Druck ≤ 3):
> „Guten Tag. Worum geht es genau?" / „Hallo. Ich schaue es mir bei Gelegenheit an." / „Danke für die Nachricht. Was steht an?"

**MISSTRAUISCH** (Misstrauen > 3):
> „Wer sind Sie nochmal? Das kommt mir komisch vor." / „Woher haben Sie meine Adresse? Ich kenne Sie nicht." / „Das klingt nicht seriös. Ich frage besser intern nach."

**INTERESSIERT** (Misstrauen ≤ 3, Druck 4–6):
> „Okay, das klingt dringend. Erzählen Sie mehr." / „Verstehe. Was genau brauchen Sie von mir?" / „Gut, ich höre zu. Wie geht es weiter?"

**ANGEBISSEN** (Misstrauen ≤ 3, Druck ≥ 7 — der gewinnbereite Zustand):
> „Alles klar, was muss ich tun? Sagen Sie mir wo ich klicke." / „Verstanden, ich erledige das sofort. Wohin muss ich?" / „Passt, machen wir. Schicken Sie mir den Link."

---

## 1.5 Phase 3 — Resolve (Debriefing) — die wichtigste Lernquelle

Drei nacheinander eingeblendete Blöcke (1,1 s Versatz, überspringbar per Klick):
1. ausgangsspezifisches Feedback, 2. der Twist (**immer**), 3. die Schlussstatistik (**immer**).

### 1.5.1 Ausgangsspezifisches Feedback — alle vier Varianten wörtlich

**WIN** — `resolve_content.csv:2-3`
> **„Zugriff erhalten"**
> „Hannes hat geklickt. Drei Sekunden nach dem die Mail ankam. Er war ja im Stress."

**SPAM** — `resolve_content.csv:4-5`
> **„Abgeblockt"**
> „Zu dick aufgetragen. Der Druck kam zu platt und zu schnell. Hannes wurde stutzig und brach den Austausch ab, bevor es zum Link kam. Generischer Druck ohne Vertrauen fliegt auf."

**KOLLEGEN_RUECKFRAGE** — `resolve_content.csv:6-7`
> **„Aufgeflogen"**
> „Hannes wurde misstrauisch und hat bei der echten Bit & Bürli angerufen. Druck alleine reicht nicht, wenn das Vertrauen fehlt."

**IGNORIERT** — `resolve_content.csv:8-9`
> **„Kein Treffer"**
> „Kein Treffer. Deine Mails blieben unbeantwortet, das Zeitfenster ist zu. Die IT von Hannes ist jetzt wach. Zu wenig Recon, kein gezielter Angriff."

### 1.5.2 Der Twist (erscheint IMMER, auch beim Gewinn) — `resolve_content.csv:10`

> „Hannes Zinsli hat kaum je etwas online gestellt. Du bist trotzdem reingekommen. Nadja wollte nur nett sein. Kevin war stolz auf seinen ersten Tag. Der Verein wollte sein Protokoll teilen. Und Hannes' eigener Posteingang hat dir die Tür aufgehalten. So funktioniert echtes Spear Phishing. Nicht der Chef leakt. Sondern alle um ihn herum."

Dies ist die zentrale Lernbotschaft des gesamten Levels.

### 1.5.3 Die Schlussstatistik (erscheint IMMER) — `resolve_content.csv:11-12`

> „In einer Studie mit über 14.000 Mitarbeitenden fiel fast jeder Dritte auf Phishing herein. Und das war ungezieltes Massen-Phishing. Du hast gerade gesehen, wie viel gefährlicher es wird, wenn es auf eine Person zugeschnitten ist."
>
> Quellenangabe: „Lain, Kostiainen & Čapkun (2022), IEEE S&P"

### 1.5.4 Schaltflächen — `resolve_content.csv:13-17`

> „Spielbewertung" (öffnet das Review) · „Nächstes Szenario" · „Zum Hauptmenü" · „Nochmal spielen"
> (`RESOLVE_LEVELS` = „Zur Levelauswahl" existiert, wird aber nur in Szenario 2 verwendet)

---

## 1.6 Phase 3b — Spielbewertung (optionales Review-Overlay)

Zug-für-Zug-Nachbesprechung, `components/mail_review.gd`.

### 1.6.1 Urteil pro Kartentyp — die einzige Stelle mit expliziter Wertung

Texte in `resolve_content.csv:21-24`:

| Kartentyp | Urteilstext wörtlich | Farbe |
|---|---|---|
| EPIC **und** LEGENDARY | „Gezielte Recon-Info." | grün |
| STANDARD | „Billiger Druck. Erhöht das Misstrauen, ohne Recon-Deckung riskant." | amber |
| SCHROTT | „Falle." | rot |
| PAYLOAD | „Der eigentliche Angriff." | amber |

Pro Zug zusätzlich die Balkenbilanz, Format:
> „MISSTRAUEN 4 → 5 (+1)    HANDLUNGSDRUCK 3 → 7 (+4)"

Rahmentexte (`resolve_content.csv:18-20`): „Deine Entscheidungen" · „Zug %d" · „Zurück"

### 1.6.2 „Verpasste Chancen" — wörtlich

Legendaries, deren Zutaten gesammelt, die aber nie gespielt wurden.
Texte aus `resolve_content.csv:25-30`:

> **„Verpasste Chancen"**

> „Du hattest ‚Frische IT' und ‚Bit & Bürli bestätigt' gesammelt. Zusammen wären sie ‚Perfekter Absender' gewesen, ein glaubwürdiger Vendor-Spoof, der das Misstrauen stark senkt."

> „Du hattest ‚Migrations-Aufhänger' und ‚Projekt Helvetia' gesammelt. Zusammen wären sie ‚Echter Vorwand' gewesen, ein konkretes Projekt als Grund, das Druck aufbaut ohne Misstrauen."

> „Du hattest das Vereinsfoto und den Namensvetter gesammelt. Zusammen hätten sie ‚Verifiziert' ergeben und die Namensvetter-Falle entschärft."

> „Du hattest das Mail-Schema und den Archiv-Fund gesammelt. Zusammen wären sie ‚Identität gesichert' gewesen, exakte Adresse plus Bestätigung."

> (wenn nichts verpasst wurde) „Du hast deine gesammelten Infos gut ausgereizt. Keine ungenutzten Kombinationen."

---

## 1.7 Angriffstechniken und Social-Engineering-Prinzipien

### 1.7.1 Als `principle`-Tag im Code geführt

Wird **in der Telemetrie mitgeloggt**, erscheint aber **nicht auf dem Bildschirm**:

| Tag | Karten |
|---|---|
| `autoritaet` | Frische IT, Bit & Bürli bestätigt, Badge-Leck, Konto gesperrt |
| `konformitaet` | Keiner fragt nach |
| `knappheit` | Frist heute, Abwesenheits-Fenster |
| `konsistenz` | Sonntags-Hannes, Mail-Schema, Archiv-Fund |
| `plausibilitaet` | Migrations-Aufhänger, Systemwissen |
| `similaritaet` | Projekt Helvetia |
| `sympathie` | Vereinskollege, Vertrauter Kontakt |
| `konsequenz` | Rechnung unbezahlt |
| `commitment` | Zugang bestätigen (Payload) |
| `gier` | Gratis Krypto |
| `kontextbruch` | Namensvetter Jodler/Makler, Falsche Firma |
| `irrelevanz` | Katzen-Smalltalk, Rundum-Lob, Alter Beitrag, Café-Standort |
| `aufklaerung` | Erreichbarkeit prüfen (Probe) |
| `kombination` | alle vier Legendaries |

### 1.7.2 Im sichtbaren Spieltext ausdrücklich benannte Techniken

1. **OSINT-Recon als Angriffsvorbereitung** — „RECON // OSINT-SWEEP", „Sammle alles, was du findest."
2. **Vendor-/Absender-Spoofing einer neu beauftragten IT-Firma** — „Die neue IT-Firma kennt niemand persönlich. Ideal, um sie vorzutäuschen."; Review: „ein glaubwürdiger Vendor-Spoof"
3. **Pretexting über ein echtes laufendes Projekt** — „Die laufende Migration ist ein legitimer Vorwand für eine dringende IT-Mail."
4. **Insider-Vortäuschung über interne Projektnamen** — „Der interne Projektname macht dich zum vermeintlichen Insider."
5. **Ableitung des Mailadress-Schemas über eine Nebenperson** — `recon_content.csv:33`
6. **Bestätigung eines Schemas über Web-Archive** — „Ein Archiv-Snapshot bestätigt das Adressschema ein zweites Mal."
7. **Ausnutzen von Badge-/Ausweisdaten** — „Genug, um am Empfang niemandem aufzufallen."
8. **Timing-Ausnutzung (Arbeitsrhythmus)** — „Eine Mail zur Unzeit wirkt bei ihm normal."
9. **Timing-Ausnutzung (Abwesenheit/Stress)** — „Er ist abwesend und im Stress. Eine Deadline wirkt jetzt völlig normal."
10. **Ausnutzen einer Gehorsamskultur** — „Anweisungen von der IT werden ohne Rückfrage befolgt."
11. **Generischer Druck / Massen-Phishing-Köder** — Konto gesperrt, Rechnung unbezahlt, Frist heute, Gratis Krypto
12. **Der Payload-Link als eigentlicher Angriff** — „Der eigentliche Angriff: der Link zum Bestätigen des Zugangs."
13. **Aufklärungs-Testmail zur Auslösung einer Abwesenheitsnotiz**
14. **Kombination einzelner Funde als Verstärker** — die vier Legendaries

### 1.7.3 Im Spieltext benannte Fehler und Fallen des Angreifers

1. **Namensverwechslung / Kontextbruch** — drei verschiedene Hannes Zinsli
2. **Falsche Firma zuordnen** — „Komplett am Ziel vorbei."
3. **Irrelevante Privatinformation** — „Nett, aber keine Munition."
4. **Veraltete Information** — „Ein längst beendetes Projekt. Veraltet und wertlos."
5. **Zu plumper Köder** — „Viel zu offensichtlich, reiner Alarm."
6. **Druck ohne Vertrauensaufbau** — „Generischer Druck ohne Vertrauen fliegt auf."
7. **Zu wenig Aufklärung** — „Zu wenig Recon, kein gezielter Angriff."

---

## 1.8 Vermeidungsstrategien in Level 1

**Befund:** Level 1 enthält **keinen expliziten, an die Verteidigerseite
gerichteten Handlungsratschlag.** Es gibt keinen Satz der Form „Prüfe X" oder
„Melde Y". Alle Lektionen sind in der Angreiferperspektive formuliert.
*(Level 2 ist hier grundlegend anders — siehe 2.5.)*

Was Level 1 liefert, sind **invertierte Lektionen**. Nur die linke Spalte ist
textlich belegt; die rechte ist eine **Ableitung** und steht so **nicht** im Spiel:

| Im Spiel wörtlich gesagt | Daraus ableitbare Empfehlung (**nicht im Spiel formuliert**) |
|---|---|
| „Nicht der Chef leakt. Sondern alle um ihn herum." | Awareness muss das gesamte Umfeld erfassen, nicht nur Führungskräfte |
| „Hannes Zinsli hat kaum je etwas online gestellt. Du bist trotzdem reingekommen." | Eigene Zurückhaltung online schützt nicht ausreichend |
| „Nadja wollte nur nett sein. Kevin war stolz auf seinen ersten Tag." | Harmlose Motive führen zu verwertbaren Lecks |
| „Die Firma postet mehr, als ihr lieb wäre." | Unternehmenskommunikation, Inserate und Presse als Angriffsfläche prüfen |
| „Kommt eine Anweisung von oben oder von der IT, wird sie ausgeführt, Punkt." | Rückfragekultur ist eine Schutzmassnahme |
| „Hannes wurde misstrauisch und hat bei der echten Bit & Bürli angerufen." | Verifikation über einen unabhängigen Kanal stoppt den Angriff — **die einzige in Level 1 gezeigte erfolgreiche Abwehrhandlung** |
| „Woher haben Sie meine Adresse? Ich kenne Sie nicht." | Nachfragen bei unbekannten Absendern |
| „Das klingt nicht seriös. Ich frage besser intern nach." | Interne Rückversicherung |
| „Alte Team-Seite … längst gelöscht, hier aber noch gespeichert." | Löschen entfernt Daten nicht aus Archiven |
| „Genug, um am Empfang niemandem aufzufallen." | Ausweise nicht fotografieren/posten |

---

## 1.9 Geschätzte Durchspielzeit

**Kein Timer, kein Echtzeitlimit.** Das einzige Limit ist das Zugbudget von 5
Mails, im Briefing als „Zeitlimit: 5 Züge" bezeichnet — ein Zug-, kein Zeitbudget.

| Grösse | Wert |
|---|---|
| Briefing-Text | 4 Zeilen à 40 Zeichen/s, per Klick überspringbar |
| Recon-Inhalt | `recon_content.csv` ≈ 9,9 KB DE-Spalte, 31 Beiträge auf 6 Tabs |
| Mail-Inhalt | `mail_content.csv` ≈ 8,2 KB DE-Spalte |
| Resolve/Review | `resolve_content.csv` ≈ 2,8 KB DE-Spalte |
| Aufdeck-Animation | 0,5 s/Karte, max. 3 Karten = 1,5 s pro Zug |
| Antwort-Nachlauf | 1,4 s pro Zug |
| Resolve-Staffelung | 3 × 1,1 s + Fade, per Klick überspringbar |

**Abgeleitete Schätzung (kein gemessener Playtest, siehe L-13):**

| Phase | Schätzung |
|---|---|
| Briefing | 0,5–1 min |
| Recon | 6–12 min |
| MailBuilder | 4–8 min |
| Resolve | 1–2 min |
| Spielbewertung (optional) | 1–3 min |
| **Gesamt Level 1** | **13–26 min** |

Ein Wiederholungslauf überspringt das Briefing und dürfte deutlich kürzer sein.

---

# Level 2 — Bad USB (physische Infiltration)

> **Gegenüber dem Feature-Branch vollständig ausgebaut:** eigenes Briefing,
> drei Dialogbäume, Tailgating-Sequenz, gesperrter Aufzug, misstrauischer
> IT-Kollege, fünfstufiges Debriefing mit expliziten Handlungsempfehlungen und
> vollständige Telemetrie.

## 2.1 Level-Name und Angriffsszenario in einem Satz

**Name:** „Szenario: Bad USB"

**Szenario:** Nach dem gescheiterten Phishing-Versuch dringen die Spielenden
physisch in das Firmengebäude ein, überwinden Empfang, Etagentür und einen
misstrauischen Kollegen durch Vorwand-Gespräche und Tailgating, und stecken einen
präparierten USB-Stick an einen unbeaufsichtigten Rechner.

**Ablauf (8 Sub-States, `bad_usb.gd:7`):**
`BRIEFING → STREET → FRONT → INSIDE → CORRIDOR → TAILGATE → OFFICE → RESOLVE`

**Phasen-Stepper (5 Gruppen, `bad_usb.gd:358-364`, `bad_usb_content.csv:51-55`):**
„Anreise ▸ Lobby ▸ Etage ▸ Büro ▸ Debrief"

`turn_budget = 0` in `resources/scenarios/bad_usb/briefing.tres`, deshalb blendet
die OS-Leiste ihren Zugzähler aus. **Es gibt in Level 2 kein Zug- und kein Zeitlimit.**

## 2.2 Phase 0 — Briefing

Vier Dialogzeilen, gleicher Sprecher „Direktor" wie Level 1
(`resources/scenarios/bad_usb/briefing.tres`). Wörtlich, `strings.csv:69-72`:

> „Der Phishing-Versuch ist aufgeflogen. Hannes' IT ist jetzt wach. Also machen wir es auf die harte Tour."

> „Du gehst rein. Physisch. Ins Gebäude der FinTech AG, mitten am Tag."

> „Kein Ausweis, keine Einladung. Du kommst über die Menschen rein: Rezeption, Aufzug, eine offen gehaltene Tür. Freundlichkeit ist deine Waffe."

> „Bring diesen USB-Stick an einen unbeaufsichtigten Rechner im Inneren. Steck ihn ein. Den Rest erledigt er selbst."

Mission: „Infiltriere die FinTech AG vor Ort" · Ziel: „FinTech AG · Vor Ort" ·
Belohnung: „Fernzugriff auf einen Arbeitsplatz-Rechner" (`strings.csv:67-68`,
`bad_usb_content.csv:50`)

> **Hinweis:** Ein zweiter, älterer Briefing-Text existiert noch in
> `bad_usb_content.csv:41-43` („Mission Infiltration" / „Weil der Versuch das
> Unternemen mit einem Spear Phishing angriff zu besiegen fehlschlug …", mit
> Tippfehlern). Er wird vom aktuellen Briefing-Flow **nicht mehr verwendet**.
> Siehe L-10.

## 2.3 Entscheidungspunkte

**Kernregel (`scenarios/bad_usb/dialogue.gd:27-30`):** In den Eröffnungsschritten
(10, 20, 30) blockiert **Option 1** die Tarnung; in den Folgeschritten (11, 21, 31)
**Option 2**. Die Abschlussschritte (12, 22, 32) bieten nur eine Bestätigung und
sind immer sicher. Die Position der richtigen Antwort wechselt also bewusst.

**Ein Fehlgriff beendet den Lauf sofort** (`bad_usb.gd:705-715`, `_fail_run`) und
führt zum Fehlschlag-Debriefing. Der frühere Wiederholungs-Popup ist entfernt:

> „a run now has exactly one outcome instead of silent retries" — `bad_usb.gd:704`

### E1 — Ansprache am Empfang (ungewertet)

**Optionen** (`bad_usb_content.csv:48-49`):
> „Rezeptionist gestresst ansprechen" (Pfad `stressed`, Schritt 10) ·
> „Rezeptionist überzeugt ansprechen" (Pfad `confident`, Schritt 20)

**Wertung:** keine. Begründung im Code:

> „Both openings are viable pretexts rather than a right/wrong pair, so the
> choice is recorded ungraded." — `bad_usb.gd:628-630`

### E2 — Dialogpfad A „gestresst" (`bad_usb_content.csv:2-9`)

**Schritt 10** — NPC: „Guten Tag, kann ich Ihnen helfen? Sie wirken völlig außer Atem!"
- Option 1 (**Tarnung auffliegt**): „Lassen Sie mich durch, sonst werde ich zusehen, wie Sie gefeuert werden!"
- Option 2 (**richtig**): „Ich bin von der externen Security und bin zu spät für mein Meeting!"

**Schritt 11** — NPC: „Oh je, beruhigen Sie sich. Mit wem haben Sie das Meeting denn?"
- Option 1 (**richtig**): „Herrn Müller... Dritter Stock, richtig?"
- Option 2 (**Tarnung auffliegt**): „Das geht Sie nichts an!"

**Schritt 12** — NPC: „Genau, dritter Stock! Beeilen Sie sich."
- Option 1 (Abschluss): „Vielen Dank!" → Sicherheitsschranke wird deaktiviert

### E3 — Dialogpfad B „überzeugt" (`bad_usb_content.csv:10-17`)

**Schritt 20** — NPC: „Guten Tag. Haben Sie einen Termin? Sie tragen keinen Besucherausweis."
- Option 1 (**Tarnung auffliegt**): „Ich bin der neue Chef. Hat man Sie nicht informiert?"
- Option 2 (**richtig**): „Ich wurde angestellt, um die Sicherheit in diesem Unternehmen zu überprüfen."

**Schritt 21** — NPC: „Ein Audit? Davon weiß ich absolut nichts."
- Option 1 (**richtig**): „Wie ich sehe, lesen Sie Ihre Mails nicht. Das ist ein Sicherheitsrisiko. Dann bräuchte ich einmal Ihren Namen und den Ihres Vorgesetzten."
- Option 2 (**Tarnung auffliegt**): „Oh, bitte rufen Sie niemanden an, ich muss unangekündigt bleiben!"

**Schritt 22** — NPC: „Oh... warten Sie, das ist nicht nötig! Ich erinnere mich dunkel an die Mail. Es ist alles in Ordnung, gehen Sie ruhig durch!"
- Option 1 (Abschluss): „Vielen Dank. Achten Sie künftig besser auf interne Mitteilungen."

### E4 — Der gesperrte Aufzug (gewertet, aber aus der Fehlerquote ausgeschlossen)

**Situation:** Der Aufzug ist badge-geschützt.
**Meldung** (`bad_usb_content.csv:36`): „Zugriff verweigert: Ausweis erforderlich"
**Wertung:** `is_correct = false`, aber `tools/analyze.py:64` schliesst die Aktion
aus der Fehlerquote aus:

> „walking into the badge-protected lift shows a refusal and costs nothing. …
> It measures exploration, not a security decision."

Wird separat als `usb_restricted_attempts` berichtet.

### E5 — Tailgating an der Etagentür (gewertet als richtig)

**Optionen** (`bad_usb_content.csv:38-40`): „Aufzug benutzen" · „Durch schleichen" · „Tür Öffnen"

Warten an der verschlossenen Tür, bis jemand mit Ausweis kommt:
> „Waiting at the locked door for someone with a badge is the tailgating
> technique this level teaches, so it is graded as the intended move."
> — `bad_usb.gd:476-478`

**NPC-Reaktion** (`bad_usb_content.csv:37`):
> „Oh, bei der Kleidung bist du bestimmt vom HR... Wir halten dir die Tür auf!"

### E6 — Dialogpfad C: misstrauischer IT-Kollege im Büro (`bad_usb_content.csv:18-25`)

**Schritt 30** — NPC: „Moment mal... Sie sind doch vorhin mit mir im Aufzug gefahren. Arbeiten Sie nicht in der HR-Abteilung? Was machen Sie hier im IT-Büro?"
- Option 1 (**Tarnung auffliegt**): „Ich bin versetzt worden, das ist mein neuer Arbeitsplatz."
- Option 2 (**richtig**): „Ich habe ein wichtiges Meeting mit der IT-Leitung!"

**Schritt 31** — NPC: „Mit der IT-Leitung... Was muss die HR mit der IT-Leitung besprechen."
- Option 1 (**richtig**): „Das darf ich Ihnen leider nicht sagen. Wenn Sie mich nun entschuldigen würden."
- Option 2 (**Tarnung auffliegt**): „Was geht Sie das an?"

**Schritt 32** — NPC: „Oh nein ich komme noch zu spät. Schönen Tag."
- Option 1 (Abschluss): „Vielen Dank, Ihnen auch!" → der Kollege geht weg, der Rechner wird zugänglich

### E7 — USB-Stick einstecken (gewertet als richtig, Levelziel)

Schaltfläche „USB-Stick einstecken" (`bad_usb_content.csv:62`).
> „Planting the drive is the objective of the level: the attack succeeded."
> — `bad_usb.gd:608`

### Navigationsschaltflächen (keine Entscheidungen)

> „Gebäude Betreten" · „Zum Aufzug gehen" · „Weiter" · „Erneut Versuchen" · „Szenario Beenden"

## 2.4 Debriefing — wörtlich

Fünf Stufen bei Erfolg, zwei bei Fehlschlag; jeweils mit Bild, Schreibmaschinen-
Text und Klick zum Weiterblättern (`bad_usb.gd:888-908`, `debrief.gd`).

Titel des Screens: „SIMULATION ABGESCHLOSSEN" (`bad_usb_content.csv:44`)

### 2.4.1 Erfolgs-Debriefing (5 Stufen) — `bad_usb_content.csv:26-35`

**Schritt 1: Die Rezeption**
> „Du hast die Empfangsperson unter Druck gesetzt oder mit falscher Autorität getäuscht. Selbst geschultes Personal kann in Stresssituationen Sicherheitsrichtlinien vergessen. Ausweise müssen immer und ohne Ausnahme kontrolliert werden, egal wer vor einem steht."

**Schritt 2: Der Aufzug (Mitläufer-Effekt)**
> „Du konntest den eingeschränkten Bereich betreten, weil die Mitarbeiter am Aufzug dachten: 'Wenn die Person schon hier drin ist, wird sie wohl hier arbeiten.' Wachsamkeit endet nicht an der Eingangstür. Unbekannte ohne sichtbaren Ausweis müssen freundlich angesprochen werden."

**Schritt 3: Tailgating an der Tür**
> „Jemand hat dir aus reiner Freundlichkeit oder aus Unachtsamkeit die gesicherte Tür aufgelassen. In der realen Welt ist dies eine der häufigsten Schwachstellen. Höflichkeit darf Sicherheit nicht überschreiben. Jeder muss seinen eigenen Ausweis scannen, um Zutritt zu erhalten."

**Schritt 4: Der ungesperrte Arbeitsplatz**
> „Ein kurzer Moment der Unachtsamkeit – ein nicht gesperrter Computer. Dies ermöglichte es dir erst, den präparierten USB-Stick anzuschließen. Der Bildschirm muss beim Verlassen des Platzes immer und sofort gesperrt werden auch wenn man nur kurz weggeht."

**Fazit: Hätten die anderen ihren Job gemacht**
> „Das Unternehmen hatte eigentlich gute Sicherheits-Vorkehrungen. Doch weil sich jeder auf den anderen verließ, funktionierte deine Infiltration. Physische Sicherheit ist eine Teamaufgabe – sie funktioniert nur, wenn jeder die Verantwortung übernimmt und Sicherheit nicht als 'die Aufgabe der Anderen' ansieht."

### 2.4.2 Fehlschlag-Debriefing (2 Stufen) — `bad_usb_content.csv:56-59`

**Aufgeflogen**
> „Gescheitert: Deine Antworten haben aufsehen erregt und du wurdest zurückgewiesen."

**Fazit: Nachfragen hat gereicht**
> „Ein physischer Angriff steht und fällt mit der ersten Person, die ihn durchwinkt. Dein Gegenüber hat stattdessen nachgefragt, statt die Geschichte zu glauben. Mehr brauchte es nicht: Der USB-Stick kam nie in die Nähe eines Rechners."

## 2.5 Benannte Angriffstechniken und Vermeidungsstrategien

**Level 2 ist das einzige Level mit expliziten, ausformulierten
Handlungsempfehlungen an die Verteidigerseite.** Sie stehen im Erfolgs-Debriefing.

### Angriffstechniken (im Text benannt)

1. **Druck und falsche Autorität am Empfang** — „unter Druck gesetzt oder mit falscher Autorität getäuscht"
2. **Pretexting als externe Security / Sicherheitsauditor** — Schritte 10-C2, 20-C2
3. **Umkehr der Beweislast** — der Angreifer macht die Nachfrage selbst zum Vorwurf („Das ist ein Sicherheitsrisiko")
4. **Mitläufer-Effekt im gesperrten Bereich** — „Wenn die Person schon hier drin ist, wird sie wohl hier arbeiten."
5. **Tailgating an gesicherter Tür** — „eine der häufigsten Schwachstellen"
6. **Kleidung/Auftreten als Zugehörigkeitssignal** — „bei der Kleidung bist du bestimmt vom HR"
7. **Ausweichende Autoritätsberufung gegenüber Kollegen** — Schritt 31-C1
8. **Bad USB / Drop-Angriff am ungesperrten Rechner**

### Vermeidungsstrategien (wörtlich im Spiel formuliert)

1. „Ausweise müssen immer und ohne Ausnahme kontrolliert werden, egal wer vor einem steht."
2. „Wachsamkeit endet nicht an der Eingangstür. Unbekannte ohne sichtbaren Ausweis müssen freundlich angesprochen werden."
3. „Höflichkeit darf Sicherheit nicht überschreiben. Jeder muss seinen eigenen Ausweis scannen, um Zutritt zu erhalten."
4. „Der Bildschirm muss beim Verlassen des Platzes immer und sofort gesperrt werden auch wenn man nur kurz weggeht."
5. „Physische Sicherheit ist eine Teamaufgabe – sie funktioniert nur, wenn jeder die Verantwortung übernimmt und Sicherheit nicht als 'die Aufgabe der Anderen' ansieht."
6. „Selbst geschultes Personal kann in Stresssituationen Sicherheitsrichtlinien vergessen." *(Risikohinweis)*
7. Nachfragen genügt: „Dein Gegenüber hat stattdessen nachgefragt, statt die Geschichte zu glauben. Mehr brauchte es nicht."

## 2.6 Geschätzte Durchspielzeit

Kein Timer, kein Zugbudget. Inhalt: 4 Briefing-Zeilen, 9 NPC-Zeilen, 15
Antwortoptionen, fünf begehbare 2D-Räume mit Character-Movement, NPC-Laufsequenz
(6 s Tailgate-Tween), fünfstufiges Debriefing mit Schreibmaschineneffekt
(45 Zeichen/s) und Bildern.

**Schätzung: 8–15 min** bei Erfolg. Ein Fehlgriff beendet den Lauf und führt zum
kurzen Fehlschlag-Debriefing (dann 3–6 min plus optionaler Wiederholung).
Ableitung aus Textmenge, Animationskonstanten und Raumanzahl; nicht gemessen — siehe L-13.

---

# Telemetrie (beide Level)

**Persistenz:** eine JSONL-Datei pro Session unter `user://logs/session_<uuid>.jsonl`,
append-only (`autoloads/telemetry.gd`). Jede Zeile wird ergänzt um `seq`
(monotoner Zähler, damit Events mit gleichem Millisekunden-Stempel eine
eindeutige Reihenfolge haben), `timestamp_ms`, `session_uuid` und
**`participant_code`** (im Einstellungsmenü erfassbar, `strings.csv:50`).

**Entscheidungszeit:** `scenarios/base/prompt_clock.gd` misst ab dem Moment, in
dem eine Auswahl anklickbar wird, bis zum Commit — bewusst nicht ab Szenenbeginn.
`-1` (`PromptClock.UNKNOWN`) heisst „keine Uhr lief" und wird von der Analyse
verworfen.

## Geloggte Events

| `phase` / `action` | Wo | Bewertet | Nutzlast |
|---|---|---|---|
| `state_change` | `game_state.gd:45` | – | `from`, `to` |
| `scenario_start` | `scenario_base.gd:27` | – | – |
| `substate_change` | `spear_phishing.gd:140`, `bad_usb.gd:845` | – | `from`, `to` |
| `scenario_complete` | `scenario_base.gd:44` | – | `latency_ms` = Gesamtdauer |
| **Szenario 1 — Briefing** | | | |
| `briefing_advanced` | `briefing.gd:75` | nein | `lines_shown`; Verweildauer |
| **Szenario 1 — Recon** | | | |
| `recon_find_collected` | `recon.gd:142` | **ja** (`not is_junk`) | `find_id`, `source`, `is_junk`, `is_hidden`, `deck_size`, `phase_elapsed_ms` |
| `recon_find_uncollected` | `recon.gd:168` | nein | `find_id`, `source`, `is_junk` |
| `recon_deck_full` | `recon.gd:132` | nein | `find_id`, `source` |
| `recon_tab_opened` | `recon.gd:291` | nein | `from`, `to`; Verweildauer auf der verlassenen Seite |
| `recon_completed` | `recon.gd:618` | nein | `collected_count`, `junk_count`, `deck_limit`, `sources_opened`, `sources_available`, `collected_ids` |
| **Szenario 1 — MailBuilder** | | | |
| `mail_card_drafted` / `mail_card_undrafted` | `mail_builder.gd:318,324` | nein | `card_id`, `card_type`, `principle`, `slots_used`, `turn` |
| `mail_card_played` | `mail_builder_state.gd:289` | **ja** (`≠ SCHROTT`) | `card_type`, `principle`, Balken vorher/nachher, `turn`, `turns_left` |
| `mail_sent` | `mail_builder_state.gd:265` | nein | `card_ids`, `card_count`, `turn`, Balken vorher/nachher, Entscheidungszeit |
| `mail_pass` | `mail_builder_state.gd:165` | nein | `turn`, `turns_left`, Balken |
| `hannes_state` | `mail_builder_state.gd:245` | nein | `state`, `turn`, Balken |
| `mail_payload_attempt` | `mail_builder_state.gd:189` | **ja** (Sieg) | `pressure`, `suspicion`, `outcome` |
| `mail_outcome` | `mail_builder_state.gd:207` | **ja** (`== WIN`) | `turns_used`, `turn_budget`, Balken |
| **Szenario 1 — Resolve** | | | |
| `scenario_debrief` | `resolve.gd:102` | **ja** (`== WIN`) | `outcome`, `turns_used`, `suspicion`, `pressure`, `cards_played` |
| `review_opened` / `review_closed` | `resolve.gd:242,255` | nein | Verzögerung bzw. Lesedauer |
| `resolve_reveal_skipped` | `resolve.gd:312` | nein | – |
| `resolve_left` | `resolve.gd:264` | nein | `exit`, `review_opened`; Standzeit des Debriefs |
| **Szenario 2 — Bad USB** | | | |
| `enter_building`, `enter_corridor`, `leave_elevator_area` | `bad_usb.gd:441,456,545` | nein | Entscheidungszeit |
| `reception_approach` | `bad_usb.gd:633` | nein | `path` (`stressed`/`confident`) |
| `dialogue_choice` | `bad_usb.gd:684` | **ja** (Tarnung hält) | `step`, `choice`, `path`, `attempt` |
| `restricted_elevator_attempt` | `bad_usb.gd:523` | **ja** (immer falsch, aber aus der Fehlerquote ausgeschlossen) | `attempt` |
| `tailgate_wait`, `tailgate_through_door` | `bad_usb.gd:478,505` | **ja** (richtig) | Entscheidungszeit |
| `usb_inserted` | `bad_usb.gd:609` | **ja** (richtig) | Entscheidungszeit |
| `run_failed` | `bad_usb.gd:707` | nein | `at_step`, `path` |
| `debrief_advanced` | `bad_usb.gd:942` | nein | `story_step`; Standzeit der Stufe |
| `scenario_debrief` | `bad_usb.gd:374` | **ja** (kein Fehlschlag) | `outcome` (`USB_PLANTED`/`COVER_BLOWN`), `failures`, `restricted_attempts`, `reception_path` |
| **Einstellungen** | | | |
| Sprach-/Settingwechsel | `settings_menu.gd:65` | nein | `phase` |

## Auswertungsskript `tools/analyze.py`

Standard-Library-only, Python 3.9+:

```
python3 tools/analyze.py <log-folder> [-o analysis] [-p participants.csv]
```

Erzeugt `events.csv` (eine Zeile pro Event) und `summary.csv` (eine Zeile pro
Session). `-p` joint eine `session_uuid,participant_code`-Tabelle für die
Verknüpfung mit den Pre/Post-Fragebögen.

**Spalten von `summary.csv`** (`analyze.py:89-134`): `participant_code`,
`session_uuid`, `started_at`, `ended_at`, `duration_s`, `scenarios_played`,
`events_total`, `runs_started`, `runs_finished`, `runs_aborted`,
`decisions_graded`, `decisions_correct`, `decisions_wrong`, `error_rate`,
`decision_ms_median`, `decision_ms_mean`, dieselben Werte nochmals mit `_all`
(inkl. Wiederholungen), sowie pro Szenario: `sp_attempts`, `sp_outcome`,
`sp_outcomes_all`, `sp_turns_used`, `sp_suspicion`, `sp_pressure`,
`sp_cards_played`, `sp_cards_played_all`, `sp_recon_collected`, `sp_recon_junk`,
`sp_recon_sources_opened`, `usb_attempts`, `usb_outcome`, `usb_outcomes_all`,
`usb_failures`, `usb_restricted_attempts`, `usb_reception_path`.

**Methodische Festlegungen im Skript:**
- Fehlerquote nur über echte Einzelentscheidungen (`action`, `mail_card_played`,
  `mail_payload_attempt`); Outcome-Zeilen sind ausgeschlossen, damit Aggregate
  den Nenner nicht doppelt belasten (`analyze.py:43-51`).
- Spalten ohne Suffix beschreiben den **ersten** Versuch; `_all` enthält
  Wiederholungen, damit ein besser informierter Zweitlauf die Zahlen nicht schönt.
- Abgebrochene Läufe (`scenario_start` ohne `scenario_debrief`) werden als
  `runs_aborted` ausgewiesen.
- `recon_completed` und `debrief_advanced` sind Dauern, keine Deliberationszeiten,
  und bleiben aus der Entscheidungszeit-Statistik draussen (`analyze.py:56-58`).

**Was das Spiel als Fehler zählt** (`docs/event_schema.md:82-88`):

| Szenario | Als falsch gewertet |
|---|---|
| Recon | Einsammeln eines `is_junk`-Funds |
| MailBuilder | Spielen einer `SCHROTT`-Karte; Payload gegen nicht gewinnbare Balken |
| bad_usb | Die Dialogantwort, die die Tarnung auffliegen lässt |

---

# Konsolidierte Lernziel-Liste

Deduplizierte Liste aller Lernpunkte, die das Spiel im Stand `1e175cd`
tatsächlich vermittelt. Basis für den Foliensatz. Belegstelle in Klammern.

## A — Die Kernbotschaft

1. **Nicht die Zielperson leakt, sondern ihr Umfeld.** Ein CEO, der selbst kaum
   etwas online stellt, ist dennoch angreifbar, weil Kolleginnen, Praktikanten,
   Vereine und die Firma selbst über ihn publizieren.
   (`resolve_content.csv:10` — erscheint immer, unabhängig vom Ausgang)
2. **Gezieltes Phishing ist deutlich gefährlicher als Massen-Phishing.** In einer
   Studie mit über 14 000 Mitarbeitenden fiel fast jeder Dritte auf ungezieltes
   Phishing herein. (`resolve_content.csv:11-12`; Lain, Kostiainen & Čapkun 2022, IEEE S&P)
3. **Der einfachste Weg in ein Netzwerk ist ein Mensch, der auf das Falsche
   klickt.** (`strings.csv:63`)
4. **Sicherheit ist eine Teamaufgabe.** Gute Vorkehrungen versagen, wenn sich
   jeder auf den anderen verlässt. (`bad_usb_content.csv:35`)

## B — Wie ein Angreifer Informationen sammelt (OSINT)

5. **Öffentliche Profile Dritter verraten den Arbeitsrhythmus der Zielperson**,
   was eine Mail zur Unzeit unauffällig macht. (`recon_content.csv:7`)
6. **Ein publizierter Dienstleisterwechsel liefert eine spoofbare Identität**,
   weil eine neu beauftragte Firma persönlich noch niemand kennt.
   (`recon_content.csv:10`, `mail_content.csv:5`)
7. **Stelleninserate verraten IT-Partner, Tech-Stack und Kernsysteme**
   (Microsoft 365, Azure, Finnova, VPN). (`recon_content.csv:53,89`)
8. **Pressemitteilungen liefern den Vorwand samt Zeitfenster.** (`recon_content.csv:56`)
9. **Das Mailadress-Schema lässt sich über eine beliebige Nebenperson ableiten** —
   der Praktikant leakt es, die Adresse des CEO folgt daraus. (`recon_content.csv:33`)
10. **Web-Archive bewahren gelöschte Seiten auf.** (`recon_content.csv:86`)
11. **Bilddetails im Hintergrund sind auswertbar** — ein halb verdecktes
    Whiteboard verrät Projektnamen und Go-Live-Woche. (`recon_content.csv:23`)
12. **Fotografierte Ausweise verraten Mitarbeiternummern-Schema, Gebäude und
    Stockwerk.** (`recon_content.csv:98`)
13. **Anonyme Arbeitgeberbewertungen verraten die Sicherheitskultur.**
    (`recon_content.csv:37`)
14. **Vereins- und Protokoll-PDFs bestätigen Identitäten.** (`recon_content.csv:50`)
15. **Kontaktlisten offenbaren Geschäftsbeziehungen**, auch ohne eigene Posts.
    (`recon_content.csv:4`)
16. **Der eigene Posteingang der Zielperson verrät sie** — eine Testmail löst
    eine Abwesenheitsnotiz aus. (`mail_content.csv:61,101`)
17. **Relevante Information steckt beiläufig in Beiträgen, die um etwas anderes
    gehen** — mechanisch umgesetzt als unmarkierte Textstelle im Fliesstext.

## C — Was gesammelte Information zur Waffe macht

18. **Die Gefahr liegt in der Kombination, nicht im Einzelfund.** Vier
    Zweier-Kombinationen wirken deutlich stärker als ihre Bestandteile.
    (`mail_card_pool.gd:91-100`, `resolve_content.csv:26-29`)
19. **Ein Angriff braucht Vertrauen und Handlungsdruck gleichzeitig.** Nur Druck
    fliegt auf, nur Vertrauen bewegt niemanden zum Klick.
    (Zwei-Balken-Mechanik; `resolve_content.csv:5,7`)
20. **Recon-basierte Argumente wirken, ohne Misstrauen zu wecken; generischer
    Druck erkauft Wirkung mit Misstrauen.** (`resolve_content.csv:21-22`)
21. **Der Link ist der eigentliche Angriff**, alles davor ist Vorbereitung.
    (`mail_content.csv:49`, `resolve_content.csv:24`)

## D — Die ausgenutzten Überzeugungsprinzipien

22. **Autorität** — Auftreten als IT-Partner, „Konto gesperrt", Badge-Details.
23. **Soziale Konformität / Gehorsamskultur** — „Anweisungen werden ohne
    Rückfrage befolgt", verstärkt zusätzlich jede Druckwirkung.
24. **Knappheit und Zeitdruck** — „Frist heute", das Abwesenheitsfenster.
25. **Konsistenz und Plausibilität** — gewohnte Formate, echte Systemnamen.
26. **Sympathie und Ähnlichkeit** — gemeinsamer Kontakt, Verein, Projektname.
27. **Commitment** — die Bestätigungshandlung als Abschluss.
28. **Gier** — als *plumpes*, sofort auffliegendes Muster markiert.
    (`principle`-Tags in `mail_card_pool.gd`, Kartentexte `mail_content.csv:40-59`)

## E — Woran ein Angriff scheitert

29. **Verifikation über einen unabhängigen Kanal stoppt den Angriff.**
    (`resolve_content.csv:7`)
30. **Nachfragen genügt.** „Ein physischer Angriff steht und fällt mit der ersten
    Person, die ihn durchwinkt." (`bad_usb_content.csv:58`)
31. **Nachfragen bei unbekannten Absendern.** (`mail_content.csv:106-107`)
32. **Zu plumper oder zu schneller Druck wird als Spam erkannt.**
    (`resolve_content.csv:5`)
33. **Kontextfehler entlarven den Angreifer** — falscher Namensvetter, falsche
    Firma, veraltetes Projekt. (`mail_content.csv:29,31,33,37`)
34. **Irrelevante Privatinformation wirkt creepy statt vertrauensbildend.**
    (`mail_content.csv:27,39`)
35. **Nicht jede Namensübereinstimmung ist die Zielperson** — drei verschiedene
    „Hannes Zinsli". (`recon_content.csv:42,45,69`)

## F — Physische Infiltration

36. **Ein Vorwand schlägt eine Forderung.** Plausible Gründe kommen am Empfang
    durch, Drohung und Aggression nicht. (`bad_usb_content.csv:2-4,7`)
37. **Auftritt als externer Sicherheitsauditor ist ein funktionierender
    physischer Pretext.** (`bad_usb_content.csv:12`)
38. **Der Angreifer kann die Nachfrage in einen Vorwurf umkehren** („Das ist ein
    Sicherheitsrisiko"). (`bad_usb_content.csv:14`)
39. **Ein fehlender Besucherausweis wird bemerkt, aber nicht durchgesetzt.**
    (`bad_usb_content.csv:10`)
40. **Mitläufer-Effekt:** Wer schon im gesperrten Bereich ist, gilt als
    berechtigt. (`bad_usb_content.csv:29`)
41. **Tailgating an einer gesicherten Tür ist eine der häufigsten
    Schwachstellen.** (`bad_usb_content.csv:31`)
42. **Kleidung und Auftreten ersetzen den Ausweis in der Wahrnehmung.**
    (`bad_usb_content.csv:37`)
43. **Ein ungesperrter Rechner ermöglicht den USB-Angriff überhaupt erst.**
    (`bad_usb_content.csv:33`)

## G — Explizite Handlungsempfehlungen (nur Level 2)

Dies sind die einzigen wörtlich im Spiel formulierten Schutzhandlungen:

44. „Ausweise müssen immer und ohne Ausnahme kontrolliert werden, egal wer vor
    einem steht." (`bad_usb_content.csv:27`)
45. „Wachsamkeit endet nicht an der Eingangstür. Unbekannte ohne sichtbaren
    Ausweis müssen freundlich angesprochen werden." (`bad_usb_content.csv:29`)
46. „Höflichkeit darf Sicherheit nicht überschreiben. Jeder muss seinen eigenen
    Ausweis scannen, um Zutritt zu erhalten." (`bad_usb_content.csv:31`)
47. „Der Bildschirm muss beim Verlassen des Platzes immer und sofort gesperrt
    werden auch wenn man nur kurz weggeht." (`bad_usb_content.csv:33`)
48. „Physische Sicherheit ist eine Teamaufgabe – sie funktioniert nur, wenn jeder
    die Verantwortung übernimmt und Sicherheit nicht als 'die Aufgabe der
    Anderen' ansieht." (`bad_usb_content.csv:35`)
49. „Selbst geschultes Personal kann in Stresssituationen Sicherheitsrichtlinien
    vergessen." (`bad_usb_content.csv:27`)

---

# Lücken und Unklarheiten

> **Erledigt:** Zwei abgeschnittene deutsche Texte in `mail_content.csv`
> (`MAIL_BOSS_PAYLOAD_READY` → nur „Sauber", `HANNES_REPLY_INTERESSIERT_1` →
> nur „Okay") wurden in `de1f6ae` repariert. Beide Felder sind jetzt gequotet
> und tragen den vollständigen Wortlaut.

### L-01 — Szenariobeschreibungen versprechen die Verteidigerperspektive
`spear_phishing.tres` („Identifiziere eine gezielte Phishing-E-Mail und reagiere
richtig.") und `bad_usb.tres` („Entscheide, was mit dem gefundenen USB-Stick
passieren soll.") beschreiben beide ein Spiel, das so nicht existiert. Gespielt
wird durchgängig die Angreiferseite. Die Texte erscheinen im Config-Registry;
ob sie im UI sichtbar sind, wurde nicht verifiziert.

### L-02 — Recon gibt dem Spieler kein Feedback
Das Einsammeln wird geloggt und benotet (`is_correct = not is_junk`), aber der
Spieler erfährt **im Spiel nichts davon**. Es gibt keinen Hinweis, keine Farbe,
keine Zeile beim Einsammeln einer Falle. Die Wertung existiert nur in den
Studiendaten. Für die Lernwirkung heisst das: Der Recon-Fehler wird erst indirekt
in der Mail-Phase spürbar (die Karte hebt das Misstrauen) und erst im
Review-Screen benannt („Falle."). Die Recon-Phase ist damit die einzige Phase
ganz ohne inhaltliche Rückmeldung an den Spieler.

### L-03 — Der gespoofte Absender wird nie angezeigt
`MAIL_PREVIEW_FROM_LABEL` („Von:") und `MAIL_PREVIEW_FROM_VALUE`
(„it-support@bit-buerli-services.example") sind in `strings.csv:25` und
`mail_content.csv:92` definiert, werden aber von keiner Datei referenziert
(verifiziert per Grep über `*.gd` und `*.tscn`). `mail_preview.gd` rendert nur
„An:" und „Betreff:". Der Lernpunkt „der Absender ist gefälscht und sieht dem
echten Partner nur ähnlich" wird damit **nirgends sichtbar** — obwohl der Payload-
Link inzwischen genau diese Domain trägt (`bit-buerli-services.example/zugang`).

### L-04 — Zwei widersprüchliche Mail-Domains
Der Recon-Fund leakt `vorname.nachname@fintech.ch` (`recon_content.csv:33,86`),
der Mailkopf zeigt `hannes.zinsli@fintech-ag.example` (`mail_content.csv:93`).
Unklar, ob Absicht (`.example` als reservierte Testdomain) oder Inkonsistenz.
Für einen Foliensatz, der die Schema-Ableitung erklärt, ist das eine Stolperstelle.

### L-05 — Drei definierte UI-Texte werden nie angezeigt
`MAIL_HAND_TITLE` („DECK"), `MAIL_COMBO_TAG` („KOMBO") und `MAIL_PROBE_HINT`
(„löst Antwort aus") in `strings.csv:31-33` haben keine Referenz im Code.
Insbesondere fehlt jede visuelle Kennzeichnung, dass eine Karte eine Kombination
ist — der Lernpunkt „Kombinationen sind stärker" wird erst im nachträglichen
Review erklärt, nicht während des Spiels.

### L-06 — Die Abwesenheitsnotiz bleibt inhaltlich dünn
Die Probe-Karte funktioniert, hat ein Mail-Fragment (`mail_content.csv:91`) und
schaltet „Abwesenheits-Fenster" frei. Vom Fund selbst sieht der Spieler aber nur
den Toast „Automatische Antwort erhalten. Er ist abwesend."
(`mail_content.csv:101`). Die Notiz wird nie im Wortlaut gezeigt, obwohl sie der
dramaturgische Höhepunkt des Twists ist („Und Hannes' eigener Posteingang hat dir
die Tür aufgehalten"). Damit bleibt der Lernpunkt „eine Abwesenheitsnotiz leakt
Abwesenheit, Signatur und Vertretung" auf einen Halbsatz reduziert.

### L-07 — Kartentypen werden als englische Enum-Namen angezeigt
`mail_hand_card.gd` zeigt als Typ-Tag die rohen Enum-Schlüssel „EPIC",
„STANDARD", „PAYLOAD", „LEGENDARY" bzw. „PROBE" — untranslatiert und
spielmechanisch statt didaktisch benannt. In der englischen Fassung fällt das
nicht auf, in der deutschen schon. Ob ein Teilnehmer „EPIC" als „recon-basiert"
liest, ist offen.

### L-08 — Verwaister Briefing-Text in `bad_usb_content.csv`
`bad_usb_content.csv:41-43` enthält noch den alten Briefing-Text („Mission
Infiltration" / „Weil der Versuch das Unternemen mit einem Spear Phishing angriff
zu besiegen fehlschlug …") samt Tippfehlern („Unternemen", „ein zu stecken").
Der aktuelle Flow nutzt stattdessen `BADUSB_BRIEF_LINE_1..4` aus `strings.csv`.
Tote Zeilen; sollten entfernt werden, damit niemand sie für den Foliensatz
verwendet.

### L-09 — Durchspielzeiten sind Schätzungen, keine Messungen
Es existiert kein Timer und keine Playtest-Messung im Repository. Die Angaben in
1.9 und 2.6 sind aus Textmenge, Animationskonstanten und Zugbudget abgeleitet.
**Für die Studienplanung sollten sie durch einen gemessenen Pilotdurchlauf
ersetzt werden**, weil die Foliensatz-Dauer der Kontrollbedingung daran
ausgerichtet werden muss. Immerhin: `summary.csv` liefert `duration_s` pro
Session, sodass ein einziger Pilotlauf die Zahl direkt liefert.

### L-10 — Es gibt keine berechnete Rückmeldung im Spiel
Der `FeedbackEngine`-Autoload war ein Stub ohne einen einzigen Aufrufer und
wurde am 2026-08-02 entfernt (ADR-0006). Alles Feedback im Spiel ist autorierter
Text, den die Debrief-Screens nach Outcome auswählen
(`spear_phishing/states/resolve.gd`, `bad_usb/debrief.gd`) — keine
personalisierte, aus den Events berechnete Rückmeldung. Für die Studie ist das
kein Mangel (die Auswertung übernimmt `analyze.py`), aber der Foliensatz und die
Arbeit sollten es nicht als „adaptives Feedback" beschreiben.

### L-11 — Ungleichgewicht der Handlungsempfehlungen zwischen den Levels
Level 2 nennt sechs konkrete Schutzmassnahmen wörtlich (Lernziele 44–49).
Level 1 nennt **keine einzige**; dort ist alles Ableitung. Wenn der Foliensatz
beide Level gleich behandelt, entsteht eine inhaltliche Asymmetrie, die im Spiel
genauso besteht. **Designfrage für die Studie:** Soll der Foliensatz die
Phishing-Erkennungsregeln ergänzen, die das Spiel nicht nennt (Absenderdomain
prüfen, Link-Ziel vor dem Klick prüfen, Dringlichkeitsmuster, ungewöhnliche
Anrede)? Das würde die Bedingungen inhaltlich ungleich machen — das Weglassen
lässt beide Bedingungen an derselben Stelle unvollständig.

### L-12 — Keine Erkennungsheuristik für die Empfängerseite in Level 1
Impliziert, aber nirgends ausformuliert: Das Spiel zeigt sehr detailliert, wie
eine Mail gebaut wird, benennt aber keine Prüfregel für Empfänger. Die einzigen
gezeigten Abwehrhandlungen sind der Rückruf beim echten Dienstleister und die
Rückfrage („Ich frage besser intern nach"). Siehe L-11 für die Konsequenz.

### L-13 — Eingecheckte `__pycache__`-Dateien
`tools/__pycache__/analyze.cpython-313.pyc` und `test_analyze.cpython-313.pyc`
sind versioniert. Kein Lerninhalt betroffen; gehört in die `.gitignore`.
