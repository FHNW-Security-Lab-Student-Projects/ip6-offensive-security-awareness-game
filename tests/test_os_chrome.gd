# Headless test for the OSChrome shell: configure() from a BriefingResource,
# stepper highlight follows GameState.mission_phase, the turn budget label
# recolours at the low threshold and clamps at zero, dossier opens/holds the
# mission text. Plain SceneTree script, no test framework.
#
# Run:
#   godot --headless --path . -s tests/test_os_chrome.gd
#
# Every line prints the expected value next to the actual one; a run passes
# when all "expect" values match and it ends with TEST DONE.
extends SceneTree

var _chrome: Control
var _done := false


func _initialize() -> void:
	var scene: PackedScene = load("res://scenarios/base/components/OSChrome.tscn")
	_chrome = scene.instantiate()
	root.add_child(_chrome)


func _find_step_label(stepper: HBoxContainer, text: String) -> Label:
	for c in stepper.get_children():
		if c is Label and c.text == text:
			return c
	return null


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# GameState reached by node path: the autoload global is not resolvable in a
	# bare `-s` script's compile scope (same reason test_recon loads i18n by path).
	var gs = root.get_node_or_null("GameState")

	var briefing := BriefingResource.new()
	briefing.target_name = "H. Zinsli · CEO"
	briefing.mission_text = "Phishe Hannes Zinsli, CEO der FinTech AG"
	briefing.reward_text = "Zugang zum internen Netzwerk"
	briefing.turn_budget = 8

	gs.begin_mission(briefing.turn_budget)
	var steps: Array[Dictionary] = [
		{"id": &"RECON", "label": "Recon"},
		{"id": &"MAIL", "label": "Mail"},
		{"id": &"RESOLVE", "label": "Resolve"},
	]
	_chrome.configure(briefing, steps)

	var turns: Label = _chrome.get_node("%TurnsLabel")
	var target: Label = _chrome.get_node("%TargetLabel")
	print("target from briefing (expect '· H. Zinsli · CEO'): ", target.text)
	print("turns show full budget (expect true): ", turns.text.contains("8/8"))
	print("turns green at full budget (expect true): ",
		turns.get_theme_color("font_color") == DarkMailPalette.GREEN)

	# Stepper: three steps, two separators; highlight follows mission_phase.
	var stepper: HBoxContainer = _chrome.get_node("%StepperRow")
	print("stepper children (expect 5): ", stepper.get_child_count())
	var recon_label := _find_step_label(stepper, "Recon")
	var mail_label := _find_step_label(stepper, "Mail")
	print("no highlight during briefing (expect true): ",
		recon_label.get_theme_color("font_color") == DarkMailPalette.TEXT_DIM)
	gs.set_mission_phase(&"RECON")
	print("recon highlighted after phase change (expect true): ",
		recon_label.get_theme_color("font_color") == DarkMailPalette.GREEN_BRIGHT)
	gs.set_mission_phase(&"MAIL")
	print("highlight moved to mail (expect true): ",
		mail_label.get_theme_color("font_color") == DarkMailPalette.GREEN_BRIGHT
		and recon_label.get_theme_color("font_color") == DarkMailPalette.TEXT_DIM)

	# Turn budget: down to the threshold -> amber + pulse, to zero -> red.
	for i in 6:
		gs.consume_mission_turn()
	print("turns label at threshold (expect true): ", turns.text.contains("2/8"))
	print("turns amber at <=2 (expect true): ",
		turns.get_theme_color("font_color") == DarkMailPalette.WARN_AMBER)
	gs.consume_mission_turn()
	gs.consume_mission_turn()
	print("turns red at 0 (expect true): ",
		turns.get_theme_color("font_color") == DarkMailPalette.ALERT_RED)
	gs.consume_mission_turn()
	print("clamped at zero, no underflow (expect true): ", turns.text.contains("0/8"))

	# Dossier: opens via the MISSION tag and carries the briefing facts.
	var tag: Button = _chrome.get_node("%MissionTag")
	var dossier: Control = _chrome.get_node("%Dossier")
	tag.pressed.emit()
	print("dossier opens on MISSION click (expect true): ", dossier.visible)
	print("dossier shows mission text (expect true): ",
		(_chrome.get_node("%DossierMission") as Label).text.contains(briefing.mission_text))
	tag.pressed.emit()
	print("dossier closes on second click (expect false): ", dossier.visible)
	# A scenario without a turn budget (bad_usb) must not show an empty readout.
	# Both the counter and the reward line would otherwise render as "0/0" and
	# "Belohnung:  · Zeitlimit: 0 Zuege".
	var bare := BriefingResource.new()
	bare.target_name = "FinTech AG · Vor Ort"
	bare.mission_text = "Infiltriere die FinTech AG vor Ort"
	bare.reward_text = "Fernzugriff auf einen Arbeitsplatz-Rechner"
	bare.turn_budget = 0
	_chrome.configure(bare, steps)
	print("no turn counter without a budget (expect false): ",
		(_chrome.get_node("%TurnsLabel") as Label).visible)
	# The reward still belongs on screen; only the time limit does not.
	var reward_line := (_chrome.get_node("%DossierReward") as Label)
	print("reward line still shown (expect true): ", reward_line.visible)
	print("reward names the payoff (expect true): ", reward_line.text.contains("Fernzugriff"))
	print("no time limit without a budget (expect false): ", reward_line.text.contains("Zeitlimit"))

	# With no reward at all the line disappears entirely.
	var nothing := BriefingResource.new()
	nothing.mission_text = "Ohne Belohnung"
	nothing.reward_text = ""
	nothing.turn_budget = 0
	_chrome.configure(nothing, steps)
	print("no reward line without a reward (expect false): ",
		(_chrome.get_node("%DossierReward") as Label).visible)
	print("mission line still shown (expect true): ",
		(_chrome.get_node("%DossierMission") as Label).text.contains(nothing.mission_text))

	print("TEST DONE")
	return true
