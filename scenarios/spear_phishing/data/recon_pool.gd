# Static pool of recon finds: the single source of truth for WHICH finds show
# up in the Recon sub-state and how they behave (source, kind, hidden/junk,
# parent link). It carries NO display text — every visible string is keyed off
# the find id and lives in resources/i18n/recon_content.csv (see ReconFind).
#
# Scenario 1 content (Q1-Q9) minus Q8, which lives in the separate mail app.
# Target is Hannes Zinsli (see briefing.tres); the q7 namesake traps carry the
# exact same name on purpose (content in the CSV).
class_name ReconPool
extends RefCounted


static func get_finds() -> Array[ReconFind]:
	return [
		# LinkedIn (LinkBook) styled feed. Body leaks are ⟦…⟧-marked in the CSV.
		ReconFind.create_post(&"q1_kontakt", "LinkedIn", &"profile"),
		ReconFind.create_post(&"q2a_sonntags", "LinkedIn", &"post"),
		ReconFind.create_post(&"q2b_neue_it", "LinkedIn", &"post"),
		ReconFind.create_post(&"q2c_katze", "LinkedIn", &"post", true),
		ReconFind.create_post(&"q2d_teamfoto", "LinkedIn", &"photo"),
		ReconFind.create_post(&"q2x_alt", "LinkedIn", &"post", true),
		ReconFind.create(&"q2d_whiteboard", "LinkedIn", true, false, &"q2d_teamfoto"),
		# Instagram (1 junk + 1 hidden).
		ReconFind.create(&"q5_praktikant", "Instagram"),
		ReconFind.create(&"q5x_cafe", "Instagram", false, true),
		ReconFind.create(&"q5_schema", "Instagram", true, false, &"q5_praktikant"),
		# kununu (1 junk).
		ReconFind.create(&"q6_kununu", "kununu"),
		ReconFind.create(&"q6x_lob", "kununu", false, true),
		# Google (2 junk).
		ReconFind.create(&"q7_jodler", "Google", false, true),
		ReconFind.create(&"q7x_makler", "Google", false, true),
		ReconFind.create(&"q9_verein", "Google"),
		# JobScout.
		ReconFind.create(&"q3_stelle", "JobScout"),
		# Firmenwebsite.
		ReconFind.create(&"q4_presse", "Firmenwebsite"),
	]
