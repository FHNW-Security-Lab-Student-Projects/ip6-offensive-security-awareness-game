# Static pool of recon finds. Single source of truth for what shows up
# in the Recon sub-state; the UI builds its tabs and buttons from this list.
# Scenario 1 content (Q1-Q9) minus Q8, which lives in the separate mail app.
# Target is Markus Weber (see briefing.tres); the q7 namesake traps carry the
# exact same name on purpose.
class_name ReconPool
extends RefCounted


static func get_finds() -> Array[ReconFind]:
	return [
		# LinkedIn (LinkBook) styled feed. highlight is the embedded clickable leak.
		ReconFind.create_post(&"q1_kontakt", "Vertrauter Kontakt (IT-Firma in Kontaktliste)", "LinkedIn",
				&"profile", "Markus Weber · CEO bei FinTech AG",
				"Gemeinsame Kontakte (3): Bit & Bürli GmbH, Handelskammer Zürich, Swiss Finance Network.",
				"Bit & Bürli GmbH"),
		ReconFind.create_post(&"q2a_sonntags", "Sonntags-Post: Chef antwortet spätnachts", "LinkedIn",
				&"post", "Nadja Tellenbach · Rechnungswesen bei FinTech AG",
				"Kleiner Realitätscheck fürs Wochenende. Ich schreibe dem Chef am Sonntag um halb zwölf nachts eine Frage zum Quartalsabschluss, und keine zwei Minuten später habe ich seine Antwort. Der Mann schläft nie. Nächste Woche zwinge ich ihn zu einer Mittagspause.",
				"am Sonntag um halb zwölf nachts eine Frage zum Quartalsabschluss, und keine zwei Minuten später habe ich seine Antwort"),
		ReconFind.create_post(&"q2b_neue_it", "Post: Wechsel zur neuen IT-Firma", "LinkedIn",
				&"post", "Nadja Tellenbach · Rechnungswesen bei FinTech AG",
				"Endlich. Nach Wochen des Wartens haben wir die IT gewechselt. Ab jetzt macht Bit & Bürli GmbH unseren Support, und die rufen tatsächlich zurück. Fühlt sich an wie ein neues Zeitalter.",
				"Bit & Bürli GmbH"),
		ReconFind.create_post(&"q2c_katze", "Katzen-Smalltalk", "LinkedIn",
				&"post", "Nadja Tellenbach · Rechnungswesen bei FinTech AG",
				"Homeoffice-Alltag: Mimi hat den ganzen Vormittag auf meiner Tastatur geschlafen und will jetzt auch noch ins Meeting. Prioritäten einer Bürokatze.",
				"Mimi hat den ganzen Vormittag auf meiner Tastatur geschlafen", true),
		ReconFind.create_post(&"q2d_teamfoto", "Team-Foto (Mittagessen)", "LinkedIn",
				&"photo", "Nadja Tellenbach · Rechnungswesen bei FinTech AG",
				"Team-Zmittag mit den besten Kolleginnen und Kollegen. Solche Tage machen den Job aus.",
				""),
		ReconFind.create_post(&"q2x_alt", "Alter Beitrag (beendetes Projekt)", "LinkedIn",
				&"post", "FinTech AG · Unternehmensseite · vor 3 Jahren",
				"Rückblick auf ein starkes Jahr. Mit dem Abschluss von Projekt Atlas haben wir unsere Kernbanking-Migration erfolgreich beendet. Danke an alle Beteiligten.",
				"Projekt Atlas", true),
		ReconFind.create(&"q2d_whiteboard", "Whiteboard im Hintergrund: interner Projektname", "LinkedIn",
				true, false, "Foto zoomen", &"q2d_teamfoto"),
		# Instagram (1 junk + 1 hidden).
		ReconFind.create(&"q5_praktikant", "Praktikant: erster Arbeitstag", "Instagram"),
		ReconFind.create(&"q5x_cafe", "Story: Café verlinkt, Standort geteilt", "Instagram", false, true),
		ReconFind.create(&"q5_schema", "Mail-Schema am Bildschirm sichtbar", "Instagram",
				true, false, "Bildschirm zoomen", &"q5_praktikant"),
		# kununu (1 junk).
		ReconFind.create(&"q6_kununu", "Anonyme Bewertung: Firmenkultur", "kununu"),
		ReconFind.create(&"q6x_lob", "Bewertung: Rundum-Lob ohne Inhalt", "kununu", false, true),
		# Google (2 junk).
		ReconFind.create(&"q7_jodler", "Suchtreffer: Markus Weber, Jodel-Dirigent", "Google", false, true),
		ReconFind.create(&"q7x_makler", "Suchtreffer: Markus Weber, Immobilienmakler", "Google", false, true),
		ReconFind.create(&"q9_verein", "Vereinsprotokoll mit Foto (PDF)", "Google"),
		# JobScout.
		ReconFind.create(&"q3_stelle", "Stellenanzeige nennt IT-Partner", "JobScout"),
		# Firmenwebsite.
		ReconFind.create(&"q4_presse", "Pressemitteilung: laufende Migration", "Firmenwebsite"),
	]
