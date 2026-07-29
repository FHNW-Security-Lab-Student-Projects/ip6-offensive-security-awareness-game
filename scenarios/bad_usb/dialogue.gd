# The bad_usb conversation tree as data: which lines belong to which step, which
# answer blows the cover, and which social-engineering path a step belongs to.
#
# Pure data and pure functions, no node access and no translation: it hands back
# translation KEYS and lets the caller resolve them, so this stays testable
# without a scene and a locale.
#
# Why the grading lives here: the tree encodes correctness positionally, and
# spreading that rule over the two button handlers is how it silently drifts out
# of sync with the content. One table, one place to change.
#
# Referenced by preload path rather than a class_name, so the headless tests
# compile it without the editor's global class cache.
extends RefCounted

# step -> [npc line, first option, second option]
# An empty second option marks a closing step: the conversation ends here and
# only the acknowledgement is offered.
const LINES: Dictionary = {
	# stressed path
	10: ["BADUSB_DLG_10_NPC", "BADUSB_DLG_10_C1", "BADUSB_DLG_10_C2"],
	11: ["BADUSB_DLG_11_NPC", "BADUSB_DLG_11_C1", "BADUSB_DLG_11_C2"],
	12: ["BADUSB_DLG_12_NPC", "BADUSB_DLG_12_C1", ""],
	# confident path
	20: ["BADUSB_DLG_20_NPC", "BADUSB_DLG_20_C1", "BADUSB_DLG_20_C2"],
	21: ["BADUSB_DLG_21_NPC", "BADUSB_DLG_21_C1", "BADUSB_DLG_21_C2"],
	22: ["BADUSB_DLG_22_NPC", "BADUSB_DLG_22_C1", ""],
	# suspicious IT colleague in the office
	30: ["BADUSB_DLG_30_NPC", "BADUSB_DLG_30_C1", "BADUSB_DLG_30_C2"],
	31: ["BADUSB_DLG_31_NPC", "BADUSB_DLG_31_C1", "BADUSB_DLG_31_C2"],
	32: ["BADUSB_DLG_32_NPC", "BADUSB_DLG_32_C1", ""],
}

# On the opening step of each path the FIRST option blows the cover; on the
# follow-up step the SECOND one does. Closing steps appear in neither, so their
# single option is always safe.
const FAIL_ON_CHOICE_1: Array[int] = [10, 20, 30]
const FAIL_ON_CHOICE_2: Array[int] = [11, 21, 31]

# step / 10 -> which pretext the player is running.
const PATHS: Dictionary = {
	1: "stressed",
	2: "confident",
	3: "office_npc",
}


static func has_step(step: int) -> bool:
	return LINES.has(step)


static func npc_key(step: int) -> String:
	return LINES.get(step, ["", "", ""])[0]


static func choice_key(step: int, choice: int) -> String:
	return LINES.get(step, ["", "", ""])[choice]


# False on a closing step, which offers the acknowledgement only.
static func offers_second_choice(step: int) -> bool:
	return not String(choice_key(step, 2)).is_empty()


static func blows_cover(step: int, choice: int) -> bool:
	if choice == 1:
		return FAIL_ON_CHOICE_1.has(step)
	return FAIL_ON_CHOICE_2.has(step)


static func path_for(step: int) -> String:
	return PATHS.get(step / 10, "unknown")
