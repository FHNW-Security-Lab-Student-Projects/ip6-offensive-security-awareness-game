# Typed data for Scenario 1's boss briefing. One .tres per scenario
# under resources/scenarios/<scenario>/. Edit copy in the Godot
# inspector; no code changes needed.
class_name BriefingResource
extends Resource

@export var speaker_name: String = ""
# Short target descriptor for the OS status bar (e.g. "H. Zinsli · CEO").
@export var target_name: String = ""
@export var intro_lines: PackedStringArray = PackedStringArray()
@export_multiline var mission_text: String = ""
@export_multiline var reward_text: String = ""
@export var turn_budget: int = 8


# The reward line as the briefing screen and the OS dossier both show it.
#
# Lives here rather than in the two screens because the shape depends on this
# resource's own fields: empty when the scenario offers no reward, and without
# the time limit when it runs without a turn budget (bad_usb), where the full
# template would print "Zeitlimit: 0 Züge".
func reward_line() -> String:
	if reward_text.is_empty():
		return ""
	if turn_budget > 0:
		return tr("BRIEFING_REWARD_LINE") % [tr(reward_text), turn_budget]
	return tr("BRIEFING_REWARD_ONLY") % tr(reward_text)
