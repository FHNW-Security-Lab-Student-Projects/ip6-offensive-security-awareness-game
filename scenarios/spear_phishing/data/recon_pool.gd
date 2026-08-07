# Which finds exist in the Recon phase and how they behave. No display text:
# every visible string is keyed off the find id and lives in
# resources/i18n/recon_content.csv.
#
# Target is Hannes Zinsli; the q7 namesake traps carry the same name on purpose.
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
		# Zoomed out of the team photo via a hotspot. Rect is normalised to the
		# photo, so it has to be retuned if the image changes.
		ReconFind.create(&"q2d_whiteboard", "LinkedIn", false, false, &"q2d_teamfoto",
				Rect2(0.60, 0.10, 0.27, 0.33)),
		# The mail schema is zoomed out of the screen behind Kevin. Noise is
		# interleaved so the relevant post is not simply the first one.
		ReconFind.create_post(&"q5_praktikant", "Instagram", &"photo"),
		ReconFind.create_noise(&"n_insta_sunset", "Instagram"),
		ReconFind.create(&"q5x_cafe", "Instagram", false, true),
		ReconFind.create_noise(&"n_insta_setup", "Instagram"),
		ReconFind.create(&"q5_schema", "Instagram", false, false, &"q5_praktikant",
				Rect2(0.60, 0.33, 0.37, 0.40)),
		# The badge is zoomed out of the selfie, leaking the employee-number
		# scheme and the building.
		ReconFind.create_post(&"q5b_badge", "Instagram", &"photo"),
		ReconFind.create(&"q5b_details", "Instagram", false, false, &"q5b_badge",
				Rect2(0.33, 0.42, 0.32, 0.46)),
		# kununu (1 junk + noise reviews).
		ReconFind.create(&"q6_kununu", "kununu"),
		ReconFind.create_noise(&"n_kmunu_neutral", "kununu"),
		ReconFind.create(&"q6x_lob", "kununu", false, true),
		ReconFind.create_noise(&"n_kmunu_kantine", "kununu"),
		# Google (2 junk + noise results).
		ReconFind.create(&"q7_jodler", "Google", false, true),
		ReconFind.create_noise(&"n_goggle_uni", "Google"),
		ReconFind.create(&"q7x_makler", "Google", false, true),
		ReconFind.create(&"q9_verein", "Google"),
		# Archive snapshot: confirms the mail schema plus a direct-dial number the
		# deleted live page no longer shows.
		ReconFind.create(&"q10_archiv", "Google"),
		ReconFind.create_noise(&"n_goggle_ad", "Google"),
		# Real listings, one wrong-company junk listing, plus noise.
		ReconFind.create(&"q3_stelle", "JobScout"),
		ReconFind.create(&"q3z_system", "JobScout"),
		ReconFind.create(&"q3y_konkurrenz", "JobScout", false, true),
		ReconFind.create_noise(&"n_jobscoot_verkauf", "JobScout"),
		ReconFind.create_noise(&"n_jobscoot_pflege", "JobScout"),
		# Firmenwebsite.
		ReconFind.create(&"q4_presse", "Firmenwebsite"),
		ReconFind.create_noise(&"n_presse_jubilaeum", "Firmenwebsite"),
	]
