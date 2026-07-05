# Static pool of recon finds. Single source of truth for what shows up
# in the Recon sub-state; the UI builds its tabs and buttons from this list.
# Dummy placeholder content spread over several sources with roughly one
# third junk traps. Real Q1-Q9 scenario content lands in a later slice.
class_name ReconPool
extends RefCounted


static func get_finds() -> Array[ReconFind]:
	return [
		# LinkedIn (2 junk).
		ReconFind.create(&"d_li_role", "Platzhalter: Jobtitel des Ziels", "LinkedIn"),
		ReconFind.create(&"d_li_teamfoto", "Platzhalter: Team-Foto vom Mittagessen", "LinkedIn"),
		ReconFind.create(&"d_li_whiteboard", "Platzhalter: Whiteboard im Hintergrund", "LinkedIn",
				true, false, "Foto zoomen", &"d_li_teamfoto"),
		ReconFind.create(&"d_li_motivation", "Platzhalter: Motivationspost vom Montag", "LinkedIn", false, true),
		ReconFind.create(&"d_li_smalltalk", "Platzhalter: belangloser Small-Talk", "LinkedIn", false, true),
		# Instagram (1 junk).
		ReconFind.create(&"d_ig_firstday", "Platzhalter: Post zum ersten Arbeitstag", "Instagram"),
		ReconFind.create(&"d_ig_schema", "Platzhalter: Detail auf dem Bildschirm", "Instagram",
				true, false, "Bildschirm zoomen", &"d_ig_firstday"),
		ReconFind.create(&"d_ig_arbeitsplatz", "Platzhalter: Arbeitsplatz-Detail", "Instagram"),
		ReconFind.create(&"d_ig_hobby", "Platzhalter: irrelevanter Hobby-Post", "Instagram", false, true),
		# kununu (1 junk).
		ReconFind.create(&"d_ku_kultur", "Platzhalter: Bewertung zur Firmenkultur", "kununu"),
		ReconFind.create(&"d_ku_prozesse", "Platzhalter: Hinweis auf starre Prozesse", "kununu"),
		ReconFind.create(&"d_ku_alt", "Platzhalter: uralte Bewertung von 2014", "kununu", false, true),
		# Google (2 junk).
		ReconFind.create(&"d_go_presse", "Platzhalter: Pressemitteilung zur Migration", "Google"),
		ReconFind.create(&"d_go_verein", "Platzhalter: Vereinsprotokoll (PDF)", "Google"),
		ReconFind.create(&"d_go_namensvetter", "Platzhalter: Namensvetter im falschen Kontext", "Google", false, true),
		ReconFind.create(&"d_go_werbung", "Platzhalter: Krypto-Werbebanner", "Google", false, true),
	]
