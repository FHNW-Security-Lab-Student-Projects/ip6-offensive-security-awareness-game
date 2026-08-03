# Headless test for the OSChrome shell: configure() from a BriefingResource,
# stepper highlight follows GameState.mission_phase, the turn budget label
# recolours at the low threshold and clamps at zero, dossier opens/holds the
# mission text. Plain SceneTree script, no test framework.
#
# Run:
#   godot --headless --path . -s tests/test_os_chrome.gd
#
# Every check compares an expected value against the actual one and prints
# "ok" or "FAIL". The run ends with TEST DONE and exit code 0 when every check
# passed, otherwise with the failure count and exit code 1.
extends SceneTree

const Check := preload("res://tests/check.gd")

var _chrome: Control
var _done := false
var _c := Check.new()


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
	_c.eq("target from briefing", "· H. Zinsli · CEO", target.text)
	_c.ok("turns show full budget", turns.text.contains("8/8"))
	_c.ok("turns green at full budget",
		turns.get_theme_color("font_color") == DarkMailPalette.GREEN)

	# Stepper: three steps, two separators; highlight follows mission_phase.
	var stepper: HBoxContainer = _chrome.get_node("%StepperRow")
	_c.eq("stepper children", 5, stepper.get_child_count())
	var recon_label := _find_step_label(stepper, "Recon")
	var mail_label := _find_step_label(stepper, "Mail")
	_c.ok("no highlight during briefing",
		recon_label.get_theme_color("font_color") == DarkMailPalette.TEXT_DIM)
	gs.set_mission_phase(&"RECON")
	_c.ok("recon highlighted after phase change",
		recon_label.get_theme_color("font_color") == DarkMailPalette.GREEN_BRIGHT)
	gs.set_mission_phase(&"MAIL")
	_c.ok("highlight moved to mail",
		mail_label.get_theme_color("font_color") == DarkMailPalette.GREEN_BRIGHT
		and recon_label.get_theme_color("font_color") == DarkMailPalette.TEXT_DIM)

	# Turn budget: down to the threshold -> amber + pulse, to zero -> red.
	for i in 6:
		gs.consume_mission_turn()
	_c.ok("turns label at threshold", turns.text.contains("2/8"))
	_c.ok("turns amber at <=2",
		turns.get_theme_color("font_color") == DarkMailPalette.WARN_AMBER)
	gs.consume_mission_turn()
	gs.consume_mission_turn()
	_c.ok("turns red at 0",
		turns.get_theme_color("font_color") == DarkMailPalette.ALERT_RED)
	gs.consume_mission_turn()
	_c.ok("clamped at zero, no underflow", turns.text.contains("0/8"))

	# Dossier: opens via the MISSION tag and carries the briefing facts.
	var tag: Button = _chrome.get_node("%MissionTag")
	var dossier: Control = _chrome.get_node("%Dossier")
	tag.pressed.emit()
	_c.eq("dossier opens on MISSION click", true, dossier.visible)
	_c.ok("dossier shows mission text",
		(_chrome.get_node("%DossierMission") as Label).text.contains(briefing.mission_text))
	tag.pressed.emit()
	_c.eq("dossier closes on second click", false, dossier.visible)
	# A scenario without a turn budget (bad_usb) must not show an empty readout.
	# Both the counter and the reward line would otherwise render as "0/0" and
	# "Belohnung:  · Zeitlimit: 0 Zuege".
	var bare := BriefingResource.new()
	bare.target_name = "FinTech AG · Vor Ort"
	bare.mission_text = "Infiltriere die FinTech AG vor Ort"
	bare.reward_text = "Fernzugriff auf einen Arbeitsplatz-Rechner"
	bare.turn_budget = 0
	_chrome.configure(bare, steps)
	_c.eq("no turn counter without a budget", false,
		(_chrome.get_node("%TurnsLabel") as Label).visible)
	# The reward still belongs on screen; only the time limit does not.
	var reward_line := (_chrome.get_node("%DossierReward") as Label)
	_c.eq("reward line still shown", true, reward_line.visible)
	_c.eq("reward names the payoff", true, reward_line.text.contains("Fernzugriff"))
	_c.eq("no time limit without a budget", false, reward_line.text.contains("Zeitlimit"))

	# With no reward at all the line disappears entirely.
	var nothing := BriefingResource.new()
	nothing.mission_text = "Ohne Belohnung"
	nothing.reward_text = ""
	nothing.turn_budget = 0
	_chrome.configure(nothing, steps)
	_c.eq("no reward line without a reward", false,
		(_chrome.get_node("%DossierReward") as Label).visible)
	_c.eq("mission line still shown", true,
		(_chrome.get_node("%DossierMission") as Label).text.contains(nothing.mission_text))

	quit(_c.finish())
	return true
