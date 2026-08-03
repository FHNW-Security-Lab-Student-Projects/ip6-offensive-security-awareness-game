# Headless test for the language setting.
#
# Background: a Control re-translates its text at draw time only when the STORED
# text is a translation key. The menu scenes keep raw keys in their .tscn, so
# they flip live; scenario code resolves through tr() at build time and freezes
# whatever locale was active. Rather than rebuild every screen, the language row
# is menu-only. This test pins that rule down, plus the session state the rule
# depends on.
#
# Run:
#   godot --headless --path . -s tests/test_language_switch.gd
#
# Every check compares an expected value against the actual one and prints
# "ok" or "FAIL". The run ends with TEST DONE and exit code 0 when every check
# passed, otherwise with the failure count and exit code 1.
extends SceneTree

const SETTINGS_PANEL_PATH := "res://scenes/settings_panel.gd"
const Check := preload("res://tests/check.gd")

var _step := 0
var _restore_locale := "de"

# Autoloads resolved through the tree: a bare `godot -s` script is compiled
# before the autoload names exist, so `Settings` / `GameState` cannot be used as
# identifiers here (same reason mail_builder_state.gd resolves EventBus by path).
# Assigned in _process rather than @onready, since SceneTree is not a Node.
var _settings: Node
var _game_state: Node
var _aborted_events: Array = []
var _c := Check.new()

# Mirrors GameState.State, which is not reachable as a global type from here.
const STATE_MENU := 0
const STATE_IN_SCENARIO := 1
const STATE_FEEDBACK := 2


# Walks a panel and returns the language buttons (labelled by language name, so
# they are findable without depending on the row's node structure).
func _language_buttons(panel: Node) -> Array:
	var out: Array = []
	_walk(panel, out)
	return out


func _walk(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button and (child as Button).text in ["Deutsch", "English"]:
			out.append(child)
		_walk(child, out)


func _has_hint(node: Node) -> bool:
	for child in node.get_children():
		if child is Label and (child as Label).text == tr("SETTINGS_LANGUAGE_MENU_ONLY"):
			return true
		if _has_hint(child):
			return true
	return false


# Loaded at call time, not preloaded: settings_panel.gd refers to the Settings
# autoload by its global name, which only resolves once the autoloads are up.
# A preload here would be compiled before that and fail.
func _open_panel() -> Control:
	var script: GDScript = load(SETTINGS_PANEL_PATH)
	var panel: Control = script.new()
	root.add_child(panel)
	return panel


func _process(_delta: float) -> bool:
	_step += 1
	if _step == 1:
		_settings = root.get_node("Settings")
		_game_state = root.get_node("GameState")
		root.get_node("EventBus").connect("generic_event", _on_event)
		_restore_locale = _settings.locale
		return false
	if _step != 2:
		return false

	_test_translation_tables()
	_test_menu_state_recovers()
	_test_row_locked_in_scenario()
	_test_row_unlocked_in_menu()
	_test_leave_to_title()

	_settings.set_locale(_restore_locale)
	quit(_c.finish())
	return true


# --- the tables the whole feature rests on -----------------------------------

func _test_translation_tables() -> void:
	_settings.set_locale("de")
	var de_hint := tr("SETTINGS_LANGUAGE_MENU_ONLY")
	_settings.set_locale("en")
	var en_hint := tr("SETTINGS_LANGUAGE_MENU_ONLY")
	_c.ok("hint key exists in German", de_hint != "SETTINGS_LANGUAGE_MENU_ONLY")
	_c.ok("hint key exists in English", en_hint != "SETTINGS_LANGUAGE_MENU_ONLY")
	_c.ok("hint actually differs per locale", de_hint != en_hint)

	# The mechanism the menu relies on: a raw key resolves at display time and
	# follows the locale, which is why .tscn buttons switch and tr() does not.
	var probe := Label.new()
	probe.text = "SETTINGS_LANGUAGE"
	root.add_child(probe)
	var shown_en := probe.atr(probe.text)
	_settings.set_locale("de")
	var shown_de := probe.atr(probe.text)
	_c.ok("a raw key follows the locale", shown_en != shown_de)
	probe.queue_free()


# --- session state ------------------------------------------------------------

func _test_menu_state_recovers() -> void:
	_game_state.transition_to(STATE_MENU)
	_c.eq("starts in the menu", true, _game_state.is_in_menu())

	_game_state.transition_to(STATE_IN_SCENARIO)
	_c.eq("not in menu while playing", false, _game_state.is_in_menu())

	# The bug this guards: nothing used to return the state to MENU, so after one
	# scenario the language stayed locked for the rest of the session.
	_game_state.transition_to(STATE_FEEDBACK)
	_c.eq("not in menu on the debrief", false, _game_state.is_in_menu())

	var menu: Control = (load("res://scenes/LevelAuswahl.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	_c.eq("scenario selection restores MENU", true, _game_state.is_in_menu())
	menu.queue_free()


# --- the row itself ------------------------------------------------------------

func _test_row_locked_in_scenario() -> void:
	_game_state.transition_to(STATE_IN_SCENARIO)
	var panel := _open_panel()
	var buttons := _language_buttons(panel)
	_c.eq("both languages offered", 2, buttons.size())
	var all_disabled := true
	for button in buttons:
		if not button.disabled:
			all_disabled = false
	_c.eq("language locked mid-scenario", true, all_disabled)
	_c.eq("lock is explained to the player", true, _has_hint(panel))
	panel.queue_free()


func _test_row_unlocked_in_menu() -> void:
	_game_state.transition_to(STATE_MENU)
	var panel := _open_panel()
	var buttons := _language_buttons(panel)
	var any_disabled := false
	for button in buttons:
		if button.disabled:
			any_disabled = true
	_c.eq("language switchable in the menu", false, any_disabled)
	_c.eq("no lock hint shown in the menu", false, _has_hint(panel))

	# Switching from the menu must actually take effect.
	var before: String = _settings.locale
	var target: String = "en" if before == "de" else "de"
	_settings.set_locale(target)
	_c.eq("switching applies the locale", target, TranslationServer.get_locale())
	panel.queue_free()


# --- leaving a run from the pause menu ------------------------------------------

func _on_event(payload: Dictionary) -> void:
	if payload.get("action") == "scenario_aborted":
		_aborted_events.append(payload)


func _buttons_in(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button:
			out.append((child as Button).text)
		_buttons_in(child, out)


# Quitting a scenario through the menu has to leave a trace. Without it the
# analysis sees a scenario_start with no debrief and cannot tell a deliberate
# exit from a crash, which is the difference between excluding a participant on
# a stated rule and guessing.
func _test_leave_to_title() -> void:
	_game_state.transition_to(STATE_MENU)
	var in_menu := _open_panel()
	var menu_labels: Array = []
	_buttons_in(in_menu, menu_labels)
	_c.eq("no exit button on the title screen", false,
		tr("RESOLVE_HOME") in menu_labels)
	in_menu.queue_free()

	_game_state.current_scenario_id = "bad_usb"
	_game_state.transition_to(STATE_IN_SCENARIO)
	_game_state.set_mission_phase(&"LOBBY")
	var in_run := _open_panel()
	var run_labels: Array = []
	_buttons_in(in_run, run_labels)
	_c.eq("exit button offered during a run", true,
		tr("RESOLVE_HOME") in run_labels)

	var before: int = _aborted_events.size()
	root.get_node("SettingsMenu").leave_to_title()
	_c.eq("abort recorded", 1, _aborted_events.size() - before)
	var abort: Dictionary = _aborted_events[-1]
	_c.eq("abort names the scenario", "bad_usb", abort["scenario_id"])
	_c.eq("abort records the phase", "LOBBY", abort["payload"].get("phase"))
	_c.ok("abort stays ungraded", abort["is_correct"] == null)
	# The overlay pauses the tree; leaving has to lift that or the fade freezes.
	_c.eq("pause lifted on the way out", false, paused)

	# The typewriter bed must not survive the screen that started it. It used to:
	# stop_typing() was guarded on `playing`, which reads false on a paused tree,
	# so the stop was skipped and the loop resumed on unpause and never ended.
	var sfx: Node = root.get_node("SfxPlayer")
	sfx.start_typing()
	root.get_node("SettingsMenu").open()
	sfx.stop_typing()
	_c.eq("typing stops even from a paused tree", false, sfx._typing.playing)
	root.get_node("SettingsMenu").close()
