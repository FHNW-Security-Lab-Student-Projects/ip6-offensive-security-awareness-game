# Content-Bibel: Szenario 1 "Spear Phishing" (v2, konsolidiert)

**Spiel:** Offensive Security Awareness Game (Godot 4.7)
**Sprache:** Deutsch
**Ton:** realistisch, schweizerischer FinTech-Kontext, Humor ohne Albernheit, Lektion durch Gameplay
**Stand:** Recon-Inhalt überarbeitet, Kartensystem und Mechanik definiert, an den bestehenden spear_phishing-Sub-State angedockt
**Stilregel:** keine Gedankenstriche im Spieltext, Punkte und Kommas verwenden

> Was in v2 neu ist gegenüber der ersten Fassung:
> - Realismus-Umbau an Q2 (Post A und Post D), Q5 und Q6. Infos sind jetzt eingebettet statt präsentiert, Funde teils unvollständig, Figuren kompetent statt trottelig.
> - Die Karte "Link statt Anhang" als Kommentar-Leck ist raus, weil unrealistisch. Der Payload steht jetzt für sich (siehe Abschnitt 6).
> - Neuer Abschnitt 0 mit dem Design-Grundsatz für glaubwürdige Lecks.
> - Neuer Abschnitt 6 mit dem vollständigen Kartensystem (Typen, Quelle, Effekt, Prinzip).
> - Neuer Abschnitt 7 mit den gelockten Mechanik- und Schwierigkeitsentscheidungen.
> - Neuer Abschnitt 8 mit dem Persuasion-Prinzipien-Mapping als Anker für Kapitel 2 und 4 der Thesis.

> Hinweis zu den Namen: Ihr habt die Namen projektseitig geändert. Diese Bibel nutzt weiter die dokumentierten Namen. Tauscht sie per Suchen und Ersetzen über die Tabelle unten, oder gebt mir die neuen Namen und ich backe sie ein.

> Hinweis für die technische Umsetzung: Dieses Dokument enthält Inhalt, nicht Engine-Logik. Die Phishing-Mail selbst wird im MailBuilder aus Karteneffekten zusammengesetzt, es gibt hier bewusst keine fertig formulierte, einsatzbereite Betrugsmail. Das ist didaktisch gewollt. Die Lernenden sollen das Muster verstehen, nicht eine Vorlage abtippen.

---

## Namens-Mapping (zum Ersetzen)

| Rolle | Name in dieser Bibel | Euer neuer Name |
|---|---|---|
| CEO, das Ziel | Hannes Zinsli | … |
| Sachbearbeiterin Rechnungswesen | Nadja Tellenbach | … |
| externe IT-Firma (gespooft) | Bit & Bürli GmbH | … |
| Praktikant | Kevin Brösmeli | … |
| Namensvetter (Falle) | Hannes Zinsli (Jodelchörli) | … |
| Assistentin | Frau Roth | … |
| internes Projekt | Projekt Helvetia | … |
| Firma | FinTech AG | … |

---

## 0. Design-Grundsatz für glaubwürdige Lecks

Der eine Satz, an dem sich jeder Fund messen muss:

> Ein Leck ist dann glaubwürdig, wenn die Figur einen anderen Grund hat, es zu erwähnen, als dir die Info zu geben.

Drei Regeln, die daraus folgen und die den ganzen Recon-Inhalt tragen:

1. **Einbetten statt präsentieren.** Die relevante Info steckt beiläufig in einem Post, der eigentlich um etwas anderes geht (eine Anekdote, eine Beschwerde, ein Stolzmoment). Der Spieler muss sie als relevant erkennen. Genau dieses Erkennen ist der Lernmoment.
2. **Funde dürfen unvollständig sein.** Ein Whiteboard im Hintergrund ist halb verdeckt. Ein Schema wird über eine Nebenperson geleakt, nicht direkt. Der Spieler kombiniert und interpretiert, statt abzuschreiben. OSINT ist Puzzlearbeit.
3. **Figuren sind kompetent, nicht dumm.** Nadja ist sympathisch und fähig und leakt trotzdem. Das trifft die Lektion härter als eine Karikatur. Sobald jemand quasi in die Kamera erklärt, wie der Angriff funktioniert, kippt es ins Künstliche.

---

## 1. Figuren

| Figur | Rolle | Funktion im Spiel |
|---|---|---|
| **Hannes Zinsli** | CEO der FinTech AG, das Ziel | Postet selbst fast nichts. Der Twist: er macht alles richtig und wird trotzdem verraten. |
| **Nadja Tellenbach** | Sachbearbeiterin Rechnungswesen | Das Comedy-Herz, aber kompetent. Sympathisch, fähig, digital sorglos. Jeder Post ist Lacher und Leck. |
| **Bit & Bürli GmbH** | externe IT-Firma | Wird als Absender gespooft. Frischer Vendor, darum glaubwürdig. |
| **Kevin Brösmeli** | Praktikant (austauschbar) | Stolz auf seinen ersten Job. Leakt im Hintergrund. |
| **Hannes Zinsli (der Zweite)** | Namensvetter, Jodelchörli-Dirigent | Die Verifikations-Falle. Gleicher Name, falscher Kontext. |
| **"Ehemalige_im_Rechnungswesen"** | anonyme kununu-Bewerterin | Leakt Firmenkultur, ist aber unbestätigt und teils widersprüchlich. |
| **Frau Roth** | Assistentin von Hannes | Taucht nur in der Abwesenheitsnotiz als Alternativ-Ziel auf. |

---

## 2. OSINT-Quellen (Fenster im DarkMail OS)

Übersicht. Details und ausformulierte Fundstücke in Abschnitt 3.

| # | Fenster | Wer/Was | Kernleck | Lektion |
|---|---|---|---|---|
| Q1 | LinkedIn | Hannes (Profil) | fast nichts, nur seine Kontakte | Das Ziel selbst ist nicht das Leck. |
| Q2 | LinkedIn | Nadja (Posts) | CEO-Routine, IT-Wechsel, Projekt, Ton | Eine Person leakt für alle. |
| Q3 | JobScout | Stellenanzeige | Tech-Stack, nennt Bit & Bürli | Inserate verraten, wen man spooft. |
| Q4 | Firmen-Website | Pressemitteilung | laufende Migration, Deadline | Firmen liefern den Aufhänger selbst. |
| Q5 | Instagram | Kevin (Fotos) | Mail-Schema über seine eigene Adresse | Stolz ist ein Datenleck. |
| Q6 | kununu | anonyme Bewertung | Firmenkultur, "keiner fragt nach" | Anonyme Quellen muss man prüfen. |
| Q7 | Google-Suche | Rauschen + Namensvetter | die Falle | Nicht jede Übereinstimmung ist dein Ziel. |
| Q8 | Mail (Probe) | Abwesenheitsnotiz | Hannes ist weg, Signatur, Assistentin | Sein eigener Posteingang verrät ihn. |
| Q9 | Google/PDF | Vereins-Leak | bestätigt Identität, Rapport | Privatleben offen, Schutz nutzlos. |

Hidden-Interaktionen (Info erst nach Aktion sichtbar): Kommentare aufklappen (Q2), Foto zoomen (Q2, Q5), Probe-Mail senden (Q8), Suchergebnis anklicken (Q7, Q9). Technisch: Foto-Zoom-Funde tragen ein `hotspot: Rect2` (normierte Region) auf dem ReconFind und werden per Klick auf die Bildstelle direkt eingesammelt, Hover zeigt den Hinweis. Die übrigen Hidden-Interaktionen (Kommentare aufklappen, Probe-Mail) sind Future Work.

---

## 3. Die Fundstücke im Detail

Pro Quelle: der Text im Ton der Figur, das Leck, die Karte, der Awareness-Wink beim Einsammeln.

Kartentypen-Legende: **Epic** (grün, aus Recon, stark und personalisiert), **Standard** (rot, generischer Druck), **Payload** (lila, der eigentliche Angriff), **Schrott** (X, plump, erhöht Misstrauen), **Legendary** (Gold, nur per Cross-Reference). Im MailBuilder gibt es zwei Balken beim Ziel: **Misstrauen** (Ziel ≤ 3) und **Handlungsdruck** (Ziel ≥ 7).

### Q1 · LinkedIn, Hannes Zinsli (das leere Profil)

> **Hannes Zinsli** · CEO bei FinTech AG · Zürich
> Aktivität: 1 Beitrag in 3 Jahren. Letzter Beitrag: "Wir stellen ein. #fintech" (vor 2 Jahren)
> Info: keine. Keine Fotos, keine privaten Angaben.

**Leck:** fast nichts. Aber in seiner Kontaktliste tauchen zwei Profile von "Bit & Bürli GmbH" auf. Wer genau hinsieht, erkennt die Vendor-Beziehung schon hier.
**Karte:** Epic "Vertrauter Kontakt", liefert keinen direkten Effekt, ist aber ein Cross-Reference-Baustein für die IT-Spoof-Legendary.
**Awareness-Wink:** "Hannes macht alles richtig. Er postet nichts. Schade nur, dass das nicht reicht."

### Q2 · LinkedIn, Nadja Tellenbach (die Goldgrube)

**Post A, der Sonntags-Post (überarbeitet):**
> **Nadja Tellenbach** · Rechnungswesen @ FinTech AG
> Kleiner Realitätscheck fürs Wochenende. Ich schreib meinem Chef Sonntagabend halb zwölf eine Frage zum Quartalsabschluss, eigentlich nur als Notiz für Montag. Zwei Minuten später Antwort. Zwei Minuten! Ich glaub der Mann schläft nie. Nächste Woche zwing ich ihn zu einer Mittagspause, das ist jetzt persönlich. 😄

**Leck:** Hannes liest und beantwortet Mails spät und zuverlässig, sogar am Wochenende. Die Info steckt in einer Anekdote mit Pointe, der Spieler muss selbst extrahieren "er antwortet nachts in Minuten".
**Karte:** Epic "Sonntags-Hannes", eine spät gesendete Mail wirkt plausibel, **senkt Misstrauen**.
**Awareness-Wink:** "Nadja wollte nur nett sein. Sie hat dir gerade seinen Arbeitsrhythmus verraten."

**Post B, der IT-Wechsel:**
> 📞 Tschüss alte IT, hallo **Bit & Bürli**! Endlich Leute, die zurückrufen. Drei Wochen drauf gewartet, aber jetzt läufts. #neuera

**Leck:** Bit & Bürli ist die aktuelle, neue IT-Firma. Neu heisst: Hannes kennt deren Gesichter und Mailadressen noch nicht.
**Karte:** Epic "Frische IT", ein Spoof einer neuen, unbekannten Vendor-Firma **senkt Misstrauen**.
**Awareness-Wink:** "Eine neue IT-Firma kennt niemand persönlich. Perfekt zum Vortäuschen."

**Post C, das Rauschen (Red Herring):**
> Mein Büsi Mimi hat heute den ganzen Tag auf meiner Tastatur geschlafen 🐱 #catsoflinkedin #homeoffice

**Leck:** keines.
**Karte:** Schrott "Katzen-Smalltalk", wer das in die Mail packt, wirkt creepy und ahnungslos, **erhöht Misstrauen**.
**Awareness-Wink:** "Süss. Aber nutzlos. Nicht jede Info ist Munition."

**Post D, das Team-Foto (Zoom versteckt, überarbeitet):**
> Team-Zmittag heute, beste Kollegen der Welt! 🍝 #fintechfamily
> *(Foto. Zoombar.)*

*Hidden, nach Zoom:* im Hintergrund, halb verdeckt von einem Kollegen, ein Whiteboard. Lesbar sind nur Bruchstücke. Oben steht "HELVETIA", darunter eine Tabelle mit Wochennummern, in der Spalte "KW 24" ist eine Zeile grün markiert, daneben steht "Go-Live?".

**Leck:** interner Projektname (sicher) und ein ungefähres Datum (Fragezeichen, also noch nicht fix). Der Spieler muss interpretieren statt abschreiben.
**Karte:** Epic "Projekt Helvetia" *(nur per Zoom)*, ein interner Projektbezug **erhöht Handlungsdruck** und ist Cross-Reference-Baustein.
**Awareness-Wink:** "Ein halb verdecktes Whiteboard im Hintergrund eines Mittagsfotos. Mehr brauchte es nicht."

### Q3 · JobScout, die Stellenanzeige

> **FinTech AG sucht: System Engineer (m/w/d), 80 bis 100%**
> Sie betreuen unsere Microsoft-365- und Azure-Umgebung in enger Zusammenarbeit mit unserem externen IT-Partner **Bit & Bürli GmbH**. Bewerbungen an jobs@fintech.ch.

**Leck:** der Tech-Stack (Microsoft 365, Azure) und die Bestätigung, dass Bit & Bürli der IT-Partner ist.
**Karte:** Epic "Bit & Bürli bestätigt", legt den Spoof-Absender fest, **Voraussetzung für den glaubwürdigen Absender**.
**Red Herring:** die generische Recruiter-Adresse und die Benefits-Liste, reines Rauschen.
**Awareness-Wink:** "Eure Stellenanzeige hat uns gerade verraten, als wen wir uns ausgeben."

### Q4 · Firmen-Website, die Pressemitteilung

> **Medienmitteilung:** Die FinTech AG schliesst diesen Monat die Migration auf eine neue Cloud-Plattform ab. "Ein wichtiger Schritt für unsere Sicherheit", so CEO Hannes Zinsli. Umgesetzt wurde das Projekt mit dem Partner Bit & Bürli GmbH.

**Leck:** der Vorwand. Eine laufende Migration macht eine IT-Mail à la "letzter Schritt, bitte Zugang bestätigen" glaubwürdig.
**Karte:** Epic "Migrations-Aufhänger", liefert einen legitim klingenden Kontext, **erhöht Handlungsdruck**, Cross-Reference-Baustein.
**Awareness-Wink:** "Die Firma hat den perfekten Vorwand selbst veröffentlicht. In der Presse."

### Q5 · Instagram, Kevin Brösmeli (der Praktikant, überarbeitet)

> **kevin_broesmeli** · 📍 FinTech AG
> Tag 1 im neuen Job! So ein cooler Arbeitsplatz, ich freu mich mega. Danke an meinen Onboarding-Buddy fürs Setup, meine Adresse ist schon eingerichtet 🙌 #praktikum #firstday #fintech
> *(Selfie am Schreibtisch. Zoombar.)*

*Hidden, nach Zoom:* auf dem Bildschirm hinter Kevin ist seine frisch eingerichtete Mail-Signatur offen: "Kevin Brösmeli, kevin.broesmeli@fintech.ch". Das Schema ist damit ableitbar: vorname.nachname@fintech.ch. Hannes' Adresse ergibt sich daraus.

**Leck:** das Mail-Schema, geleakt über Kevins eigene Adresse. Der Spieler muss die Abstraktion vom konkreten Fund zum Schema selbst leisten. Ohne das kann man gar nicht erst senden.
**Karte:** Epic "Mail-Schema" *(nur per Zoom)*, ein "Bootstrap"-Fund, **technische Voraussetzung für den Angriff**.
**Red Herring:** Kevin verlinkt ein Café in der Story, ortet sich selbst, aber das nützt nichts.
**Awareness-Wink:** "Kevin ist seit drei Tagen dabei. Er hat das ganze Adressschema mitgeliefert, ohne die Adresse des Chefs je zu nennen."

### Q6 · kununu, die anonyme Bewertung (überarbeitet)

> ⭐⭐ Rechnungswesen · Ehemalige/r
> **"Solide Firma, aber die Hierarchie ist old school"**
> Fachlich lernt man viel, das Team ist top. Was mich gestört hat: Prozesse werden nicht hinterfragt. Kommt eine Anweisung von oben oder von der IT, wird sie ausgeführt, Punkt. Nachfragen ist unerwünscht, das wurde mir früh klargemacht. Der Chef ist zudem kaum je greifbar, alles läuft über die Assistenz. Für Eigenständige frustrierend, für Leute die klare Ansagen mögen ok.

**Leck:** Firmenkultur. Anweisungen, vor allem von der IT, werden ohne Rückfrage befolgt. Genau der Autoritäts- und Dringlichkeitshebel. Eingebettet in einen glaubwürdigen, ambivalenten Erfahrungsbericht statt als Durchsage.
**Karte:** Epic "Keiner fragt nach", **senkt Misstrauen**, weil die Kultur auf Gehorsam ausgelegt ist. Verstärkt zusätzlich Druckkarten (siehe Abschnitt 6).
**Falle:** die Behauptung "der Chef ist kaum greifbar" steht mitten im Text und widerspricht Q2 (antwortet nachts in Minuten) und Q8. Wer die Bewertung ungeprüft als Ganzes nutzt, **erhöht Misstrauen**. Der aufmerksame Spieler merkt den Widerspruch und cross-checkt.
**Awareness-Wink:** "Anonym heisst nicht falsch. Aber auch nicht wahr. Prüf es gegen, bevor du dich drauf verlässt."

### Q7 · Google-Suche, das Rauschen und die Falle

> **Suchergebnis 3 von 41**
> **Hannes Zinsli** holt Gold am Eidgenössischen
> jodlerverband-emmental.ch › mitglieder
> "...unser Dirigent Hannes Zinsli leitet das Jodelchörli Schangnau seit 1998..."

**Leck:** keines, das ist ein anderer Hannes Zinsli.
**Karte:** Schrott getarnt als Epic. Wer es einbaut, schreibt Hannes über ein Hobby an, das er nicht hat, **erhöht Misstrauen stark**.
**Awareness-Wink:** "Gleicher Name. Falscher Mensch. Immer den Kontext prüfen."

### Q8 · Abwesenheitsnotiz (Überraschungsquelle, fix)

Mechanik: Der Spieler schickt eine harmlose Probe-Mail ("Sorry, falsche Adresse erwischt") an Hannes und bekommt automatisch die Out-of-Office-Antwort zurück.

> **Automatische Antwort:** Besten Dank für Ihre Nachricht. Ich bin bis Freitag an der Swiss Finance Konferenz in Genf und nur eingeschränkt erreichbar. In dringenden Fällen wenden Sie sich bitte an meine Assistentin, Frau Roth (r.roth@fintech.ch).
> Freundliche Grüsse
> Hannes Zinsli, CEO FinTech AG

**Leck, dreifach:** Hannes ist abwesend und im Stress (Dringlichkeitsfenster), die Signatur bestätigt Format und Titel, und Frau Roth ist ein Alternativ-Ziel.
**Karte:** Legendary-fähig "Abwesenheits-Fenster", **erhöht Handlungsdruck** (eine Deadline, während er gehetzt unterwegs ist, wirkt normal) und bestätigt das Schema.
**Awareness-Wink:** "Niemand hat etwas gepostet. Sein eigener Posteingang hat geantwortet."

### Q9 · Vereins-Leak (Überraschungsquelle)

Erreichbar über ein weiteres Google-Resultat.

> **Schützengesellschaft Adliswil, Jahresprotokoll 2024 (PDF)**
> "...als Kassier wiedergewählt: Hannes Zinsli..."
> Dazu ein Foto aus dem Lokalanzeiger: Hannes am Vereinsfest, mit Bildunterschrift und vollem Namen.

**Leck:** bestätigt, welcher Hannes Zinsli der echte ist (entschärft die Namensvetter-Falle Q7), und liefert Rapport-Material (Hobby, persönliche Anrede).
**Karte:** Epic "Vereinskollege", für einen reinen IT-Spoof nur schwach nützlich, aber der **Schlüssel zur Verifikations-Legendary**.
**Awareness-Wink:** "Beruflich dicht. Privat offen. Das Vereinsprotokoll war die Lücke."

---

## 4. Cross-References, die Legendary-Karten freischalten

Zwei kombinierte Fundstücke ergeben eine stärkere Karte. Das belohnt gründliche Recon und lehrt, dass die Gefahr in der Kombination liegt, nicht im Einzelfund.

| Legendary | Aus | Effekt-Idee |
|---|---|---|
| **"Perfekter Absender"** | Q2 Post B (Frische IT) + Q3 (Bit & Bürli bestätigt) | Spoof einer neuen, unbekannten Vendor-Firma. Misstrauen stark gesenkt. |
| **"Echter Vorwand"** | Q4 (Migrations-Aufhänger) + Q2 Post D (Projekt Helvetia) | Konkretes, zeitlich begrenztes Projekt als Grund. Handlungsdruck hoch, Misstrauen tief. |
| **"Identität gesichert"** | Q5 (Mail-Schema) + Q8 (Signatur) | Exakte Adresse plus Bestätigung, dass er gehetzt ist. Bootstrap plus Dringlichkeit. |
| **"Verifiziert"** | Q9 (Vereinsfoto) + Q7 (Namensvetter) | Entschärft die Falle, bestätigt das richtige Ziel. Belohnt den sorgfältigen Spieler. |

Wichtig fürs Balancing (siehe Abschnitt 7): Legendaries sind die Kür, nicht die Pflicht. Der Level ist ohne sie gewinnbar, mit ihnen wird er sauber und sicher.

---

## 5. Awareness-Winks und der finale Lehrmoment

**Beim Einsammeln** erscheint jeweils der kurze Wink aus Abschnitt 3, eine Zeile, nie belehrend, immer mit dem leisen Stich "ups, das war zu einfach".

**Resolve, der Twist am Ende** (egal ob Hannes klickt oder meldet, diese Botschaft kommt immer):

> Hannes Zinsli hat in seinem ganzen Leben kaum etwas online gestellt. Du bist trotzdem reingekommen.
> Nadja wollte nur nett sein. Kevin war stolz auf seinen ersten Tag. Der Verein wollte sein Protokoll teilen. Und Hannes' eigener Posteingang hat dir die Tür aufgehalten.
> So funktioniert echtes Spear Phishing. Nicht der Chef leakt. Sondern alle um ihn herum.

**Die Zahl zum Schluss** (Quelle für die schriftliche Arbeit: Barracuda-Analyse, oft über IBM/Vectra zitiert):

> Spear-Phishing-Mails sind weniger als 0,1 Prozent aller Mails. Sie stecken hinter 66 Prozent aller Sicherheitsvorfälle.

---

## 6. Das Kartensystem (Starter-Set Szenario 1)

Jede Info aus der Recon ist eine Karte, die ein Persuasion-Prinzip operationalisiert. Deck ca. 12 aus einem grösseren Pool. Die Effektwerte sind erste Balancing-Zahlen zum Drandrehen, nicht final.

| Karte | Typ | Quelle | Effekt (Vorschlag) | Prinzip |
|---|---|---|---|---|
| Sonntags-Hannes | Epic | Q2A | Misstrauen −2 | Konsistenz, Sympathie |
| Frische IT | Epic | Q2B | Misstrauen −2 | Autorität ohne Baseline |
| Keiner fragt nach | Epic | Q6 | Misstrauen −1, verstärkt Druckkarten | soziale Konformität |
| Migrations-Aufhänger | Epic | Q4 | Druck +2, kein Misstrauen | Plausibilität → Dringlichkeit |
| Projekt Helvetia | Epic | Q2D | Druck +2 | Insider-Similarität |
| Abwesenheits-Fenster | Epic | Q8 | Druck +3 | Knappheit, Zeit |
| Vereinskollege | Epic | Q9 | schwach allein, Legendary-Baustein | Sympathie |
| Konto gesperrt | Standard | generisch | Druck +4, Misstrauen +1 | Autorität, Angst |
| Rechnung unbezahlt | Standard | generisch | Druck +3, Misstrauen +1 | Konsequenz |
| Frist heute | Standard | generisch | Druck +3, Misstrauen +1 | Knappheit |
| Zugang bestätigen (Link) | Payload | Angriffsziel | feuert nur bei Druck ≥ 7 und Misstrauen ≤ 3 | Commitment |
| Gratis Krypto | Schrott | generisch | Misstrauen +3 | Gier, zu plump |
| Katzen-Smalltalk | Schrott | Q2C | Misstrauen +1, Zug vertan | irrelevant, creepy |
| Namensvetter-Jodler | Schrott (getarnt) | Q7 | Misstrauen +3 | Kontextbruch |
| Perfekter Absender | Legendary | Q2B + Q3 | Misstrauen −3 | Kombination |
| Echter Vorwand | Legendary | Q4 + Q2D | Druck +3, Misstrauen −1 | Kombination |
| Verifiziert | Legendary | Q9 + Q7 | entschärft Namensvetter-Falle | Kombination |

**Zum Payload:** Er steht für sich als der eigentliche Angriff (der "Zugang bestätigen"-Link) und braucht kein Recon-Leck als Voraussetzung. Die frühere Idee, seine Wirkung über ein Kommentar-Leck "Hannes öffnet nur Links" zu begründen, ist raus, weil kein Mensch so über eine Link-Vorliebe redet. Falls ihr das Detail doch behalten wollt, gehört es dahin, wo jemand echten Grund hat es zu sagen (Nadja beschwert sich in einem eigenen Post, dass sie alles auf den Share laden muss), nicht in einen fremden Kommentar. Offene Designentscheidung, kein Muss.

Der Payload bleibt bewusst auf Effekt-Ebene. Keine ausformulierte Betrugsmail. Der Spieler lernt das Muster, nicht eine Vorlage.

---

## 7. Mechanik und Schwierigkeit (gelockt)

**Zwei Balken beim Ziel.**
- Misstrauen: Start 3, Ziel ≤ 3, Spam-Schwelle > 7. Ein Deckel.
- Handlungsdruck: Start 5, Ziel ≥ 7. Ein Boden.
- Die Spannung: billige Druckkarten (Standard, rot) heben Druck und Misstrauen gleichzeitig. Man kann nicht einfach draufhauen. Recon-Karten (Epic, grün) bewegen die Balken sauber.

**Gewinnbedingung.** Payload spielen, während Handlungsdruck ≥ 7 und Misstrauen ≤ 3, innerhalb des Zugbudgets. Es zählt der erreichte Schwellenwert. Legendaries sind nicht nötig, sie machen es nur sicherer und sauberer.

**Ein Schwierigkeitsgrad.** Für die Bachelorarbeit ist genau ein Schwierigkeitsgrad vorgesehen. Keine adaptive Schwierigkeit. Die Werte oben sind der eine Default. Adaptivität (Shute) bleibt Future Work, sonst zerfasert die Datenbasis der User-Study.

**Zugbudget.** 8 Züge (aus dem Briefing, `turn_budget` in der BriefingResource).

**Fehlerzustände als Lehrmomente und Telemetrie.** Jeder Fehlerzustand mappt auf eine konkrete Fehlvorstellung. Das ist eure "Decision Awareness"-Messung.
- **Spam markiert:** Misstrauen > 7. Zu plump, generische Druck-Taktik. "Zu plump. Hannes hat es nach zwei Zeilen gelöscht."
- **Kollegen-Rückfrage:** Druck erreicht, aber Misstrauen im Bereich 4 bis 7. Druck ohne Vertrauen. "Hannes hat bei der echten Bit & Bürli angerufen. Dumm gelaufen."
- **Ignoriert:** Zugbudget aufgebraucht ohne Payload. Zu wenig Recon. "Acht Mails, kein Treffer. Die IT von Hannes ist jetzt wach."
- **Win:** "Hannes hat geklickt. Genau drei Sekunden, nachdem die Mail ankam. Er war ja im Stress."

**Warum diese Balance die Lernbotschaft trägt.** Der Level ist mit reinen Generik- und Schrottkarten praktisch nicht zu gewinnen (man fliegt als Spam auf oder erreicht den Druck nur um den Preis von zu viel Misstrauen). Mit Recon-Karten wird er lösbar. Diese eine Asymmetrie ist die spielbare Form eurer Schlussstatistik: Spear Phishing ist selten, aber trifft, weil es gezielt ist.

**Stellschrauben (für spätere Iteration, als Konstanten im Code):** Startwerte der Balken, Schwellen (≤ 3 und ≥ 7), Spam-Schwelle, Zugbudget, Deck-Zusammensetzung (Verhältnis Schrott zu Epic), Handkartenzahl. An einer Stelle definiert, damit Pre-Tests schnelles Nachjustieren erlauben.

---

## 8. Persuasion-Prinzipien-Mapping (Anker für die Thesis)

Die Kartenwirkung ist kein Zufall, sie bildet etablierte Prinzipien ab. Das gehört fast 1:1 in Kapitel 2 (Grundlagen) und Kapitel 4 (Umsetzung) der Arbeit.

**Misstrauen senken** entspricht den Vertrauens- und Plausibilitätsprinzipien: Liking und Similarity, Social Proof, Autorität als Legitimität, Konsistenz. Die neue IT-Firma, der bekannte Arbeitsrhythmus, die Gehorsamskultur, das exakte Schema.

**Handlungsdruck heben** entspricht Autorität als Befehl, Knappheit und Zeitdruck sowie Commitment. Die laufende Migration, der interne Projektname, das Abwesenheits- und Stressfenster.

**Backfire (Misstrauen hoch)** entspricht Prinzipien, die plump oder im falschen Kontext eingesetzt werden: Gier zu offensichtlich (Need and Greed), Kontextbruch, Distraction, die schiefgeht.

Theoretischer Anker: Ferreira, Coventry und Lenzini (2015) fassen die dominierenden Persuasion-Prinzipien in Social Engineering zusammen (unter anderem Autorität, Knappheit, Sympathie, soziale Konformität, Commitment und Distraction). Stajano und Wilson (2011) beschreiben die ausgenutzten Verhaltensmuster als sieben Prinzipien, darunter soziale Konformität, Zeitdruck und Distraction. Die OSINT-Recon als Angriffsvorbereitung ist bei Edwards et al. (2017) systematisiert. Der Perspektivwechsel Angreifer zu Verteidiger als Reflexionsmechanik ist bei Constant et al. (2015) beschrieben, das Feedback-Design bei Shute (2008).

---

## Anhang A: Bonus-Quellen (einbaufertig, optional)

**Wayback Machine.** Die gelöschte Team-Seite von 2019, im Webarchiv noch da. Zeigt eine Ex-Mitarbeiterin und bestätigt das alte Mail-Schema plus eine Durchwahl. Lektion: Das Netz vergisst nicht, Löschen reicht nicht. Karte-Idee: Epic "Archiv-Fund", Schema-Bestätigung.

**PDF-Metadaten.** Im Geschäftsbericht steht im Autorfeld ein interner Benutzername wie "h.zinsli", plus "zuletzt bearbeitet von" einer zweiten Person. Bestätigt das Login-Schema, ohne dass es jemand bewusst preisgegeben hat. Karte-Idee: Epic "Metadaten-Leck", technischer Wow-Moment.

Realer Anker für beide: die Strava-Heatmap 2018, die weltweit Standorte und Routinen von Militärpersonal verriet, einfach weil Leute ihre Laufstrecken öffentlich teilten. Gleiche Logik, anderes Fenster.

## Anhang C: Recon-Ausbau (umgesetzt im Spiel)

Zusätzliche Funde, die die dünnen Fenster (JobScout, Instagram, Google) füllen und die OSINT-Fläche verbreitern. Gleiche Designregeln wie Abschnitt 0. Code-Ids in Klammern.

### Q3b · JobScout, zweite Anzeige, Systemwissen (Code: q3z_system)

> **FinTech AG sucht: Sachbearbeiter/in Zahlungsverkehr, 80%**
> Sie verarbeiten Zahlungen in unserem Kernbankensystem Finnova und betreuen den Fernzugang über unser VPN. Bewerbungen an jobs@fintech.ch.

**Leck:** das interne Kernsystem (Finnova) und der VPN-Fernzugang. Der Angreifer weiss jetzt, über welches System und welchen Zugang er glaubwürdig schreiben kann, etwa eine Mail "Finnova-Wartung, bitte VPN neu bestätigen".
**Karte:** Epic "Systemwissen", senkt Misstrauen, weil eine Mail, die das echte interne System nennt, legitim wirkt.
**Awareness-Wink:** "Ein Inserat nennt euer Kernsystem beim Namen. Jetzt weiss er, worüber er schreiben muss."

### Q5b · Instagram, Kevins Badge, Badge-Leck per Zoom (Code: q5b_badge, q5b_details)

> **kevin_broesmeli** · FinTech AG
> Endlich offiziell, mein eigener Badge ist da. Fühlt sich richtig gut an. #newjob #fintech
> *(Foto vom Badge am Lanyard. Zoombar.)*

*Hidden, nach Zoom:* auf dem Badge lesbar sind Firmenlogo, "Kevin Brösmeli", die Mitarbeiternummer "MA-0473" und "Gebäude A, 4. OG".

**Leck:** das Badge-Format, das Mitarbeiternummern-Schema und das Gebäude mit Stockwerk. Physische Recon (ein Vorwand fürs Tailgating) oder ein ID-basierter Pretext. Verstärkt Q5: Kevins Stolz zeigt jetzt auch die physische Zugangsseite.
**Karte:** Epic "Badge-Leck".
**Awareness-Wink:** "Der Badge im Selfie. Logo, Name, Mitarbeiternummer, Stockwerk. Alles lesbar."

### Q10 · Google, der Archiv-Fund (aus Anhang A übernommen, Code: q10_archiv)

Erreichbar über ein weiteres Google-Resultat, das ins Webarchiv führt.

> **FinTech AG Team (archivierte Seite)**
> web.archive.org, Snapshot 12.03.2019
> "...eine inzwischen ausgeschiedene Mitarbeiterin mit Direktwahl 044 555 21 40 und der Adresse vorname.nachname@fintech.ch..."

**Leck:** bestätigt das Mail-Schema ein zweites Mal und liefert eine Durchwahl, die die längst gelöschte Live-Seite nicht mehr zeigt.
**Karte:** Epic "Archiv-Fund", Schema-Bestätigung.
**Awareness-Wink:** "Die Seite ist seit Jahren offline. Das Archiv hat sie trotzdem noch."

### Junk-Ergänzung (Code: q3y_konkurrenz)

Eine zusätzliche Schrott-Falle: ein Stelleninserat der "ZugFin AG" (Community Manager), ein anderes Unternehmen der Branche. Wer im JobScout-Fenster wahllos einsammelt, greift es mit und vertut einen Deck-Slot. Lektion wie beim Namensvetter (Q7): prüfe, WEM der Fund gehört, nicht nur, dass er nach Firma aussieht.

## Anhang B: Quellen für die schriftliche Arbeit (nicht Spielinhalt)

- Ferreira, A., Coventry, L., Lenzini, G. (2015): Principles of Persuasion in Social Engineering and Their Use in Phishing. HAS 2015, LNCS 9190, S. 36 bis 47.
- Stajano, F., Wilson, P. (2011): Understanding scam victims: seven principles for systems security. Communications of the ACM, 54(3), S. 70 bis 75.
- Edwards, M., Larson, R., Green, B., Rashid, A., Baron, A. (2017): Panning for gold: Automatically analysing online social engineering attack surfaces. Computers and Security, 69, S. 18 bis 34.
- Constant, T., Buendia, A., Rolland, C., Natkin, S. (2015): A Role-Switching Mechanic for Reflective Decision-Making Games.
- Shute, V. J. (2008): Focus on Formative Feedback. Review of Educational Research, 78(1), S. 153 bis 189.
- Scherb, C., Heitz, L. B., Grimberg, F., Grieder, H., Maurer, M.: A Cyber Attack Simulation for Teaching Cybersecurity (eigenes Betreuer-Paper, direkter Vorläufer des Projekts).
