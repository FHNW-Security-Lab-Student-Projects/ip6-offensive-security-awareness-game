# The bad_usb conversation tree as data: the lines, which answer blows the cover,
# and which pretext a step belongs to.
#
# Hands back translation KEYS, never resolved text, so it stays testable without
# a scene or a locale. The grading lives next to the content on purpose: the tree
# encodes correctness positionally, and split across the two button handlers that
# rule drifts out of sync as soon as anyone edits a line.
extends RefCounted

# step -> [npc line, first option, second option]. An empty second option marks
# a closing step, which offers only the acknowledgement.
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

# Opening step of each path: the FIRST option blows the cover. Follow-up step:
# the SECOND one does. Closing steps appear in neither and are always safe.
const FAIL_ON_CHOICE_1: Array[int] = [10, 20, 30]
const FAIL_ON_CHOICE_2: Array[int] = [11, 21, 31]

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


static func offers_second_choice(step: int) -> bool:
	return not String(choice_key(step, 2)).is_empty()


static func blows_cover(step: int, choice: int) -> bool:
	if choice == 1:
		return FAIL_ON_CHOICE_1.has(step)
	return FAIL_ON_CHOICE_2.has(step)


static func path_for(step: int) -> String:
	return PATHS.get(step / 10, "unknown")
