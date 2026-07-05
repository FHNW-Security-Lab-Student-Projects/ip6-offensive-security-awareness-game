# Static pool of recon finds. Single source of truth for what shows up
# in the Recon sub-state; the UI builds its buttons from this list.
# Dummy placeholder content only, real scenario finds come later.
class_name ReconPool
extends RefCounted


static func get_dummy_finds() -> Array[ReconFind]:
	return [
		ReconFind.create(&"find_linkedin_role", "Platzhalter: Jobtitel des Ziels", "LinkedIn"),
		ReconFind.create(&"find_website_team", "Platzhalter: Teamseite mit Namen", "Firmenwebsite"),
		ReconFind.create(&"find_insta_hobby", "Platzhalter: Hobby-Post", "Instagram"),
		ReconFind.create(&"find_forum_leak", "Platzhalter: versteckter Forumseintrag", "Forum", true, false),
		ReconFind.create(&"find_junk_horoscope", "Platzhalter: irrelevantes Horoskop", "Boulevard-Seite", false, true),
	]
