# Static pool of recon finds. Single source of truth for what shows up
# in the Recon sub-state; the UI builds its tabs and buttons from this list.
# Scenario 1 content (Q1-Q9) minus Q8, which lives in the separate mail app.
# Target is Markus Weber (see briefing.tres); the q7 namesake traps carry the
# exact same name on purpose.
class_name ReconPool
extends RefCounted


static func get_finds() -> Array[ReconFind]:
	return [
		# LinkedIn (2 junk + 1 hidden).
		ReconFind.create(&"q1_kontakt", "Vertrauter Kontakt (IT-Firma in Kontaktliste)", "LinkedIn"),
		ReconFind.create(&"q2a_sonntags", "Sonntags-Post: Chef antwortet spätnachts", "LinkedIn"),
		ReconFind.create(&"q2b_neue_it", "Post: Wechsel zur neuen IT-Firma", "LinkedIn"),
		ReconFind.create(&"q2c_katze", "Katzen-Smalltalk", "LinkedIn", false, true),
		ReconFind.create(&"q2d_teamfoto", "Team-Foto (Mittagessen)", "LinkedIn"),
		ReconFind.create(&"q2x_alt", "Alter Beitrag von 2019 (beendetes Projekt)", "LinkedIn", false, true),
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
