# Headless test for the flowing text in bad_usb: the Typewriter helper itself,
# and the rule it enforces in the dialogue, namely that the answers stay hidden
# until the question has finished typing and a click reveals the rest at once.
#
# Run:
#   godot --headless --path . -s tests/test_typewriter.gd
extends SceneTree

const Typewriter := preload("res://scenarios/base/typewriter.gd")
const DEBRIEF_PATH := "res://scenarios/bad_usb/debrief.gd"
const Check := preload("res://tests/check.gd")

var _step := 0
var _usb: Node
var _finished_count := 0
var _c := Check.new()


func _on_finished() -> void:
	_finished_count += 1


func _process(_delta: float) -> bool:
	_step += 1
	if _step == 1:
		_usb = (load("res://scenarios/bad_usb/bad_usb.tscn") as PackedScene).instantiate()
		root.add_child(_usb)
		# SceneTransition.launch_scenario does this in the game; a test loads the
		# scene directly and has to start the lifecycle itself.
		_usb.start_scenario("bad_usb")
		return false
	if _step != 2:
		return false

	_test_typewriter_unit()
	_test_dialogue_gating()
	_test_click_skips()
	_test_box_is_clickable()
	_test_debrief()

	quit(_c.finish())
	return true


# --- the helper ----------------------------------------------------------------

func _test_typewriter_unit() -> void:
	var label := Label.new()
	root.add_child(label)
	var typer := Typewriter.new()
	typer.finished.connect(_on_finished)

	typer.start(label, "Hallo Welt", 10.0)  # 10 chars per second
	_c.eq("starts in typing state", true, typer.is_typing())
	_c.eq("nothing shown at the start", 0, label.visible_characters)
	_c.eq("full text is already set", "Hallo Welt", label.text)

	typer.advance(0.5)  # 5 characters
	_c.eq("half a second reveals 5 chars", 5, label.visible_characters)
	_c.eq("still typing", true, typer.is_typing())
	_c.eq("no finish yet", 0, _finished_count)

	typer.finish_now()
	# -1 is Godot's "show everything" and is what a completed line must land on,
	# otherwise a later relayout could clip the tail.
	_c.eq("finish reveals everything", -1, label.visible_characters)
	_c.eq("no longer typing", false, typer.is_typing())
	_c.eq("finished fired once", 1, _finished_count)

	typer.finish_now()
	_c.eq("finishing twice fires only once", 1, _finished_count)

	typer.advance(1.0)
	_c.eq("advancing after the end is harmless", -1, label.visible_characters)

	# Running past the end must finish on its own, without a click.
	typer.start(label, "kurz", 100.0)
	typer.advance(1.0)
	_c.eq("running out finishes by itself", false, typer.is_typing())
	_c.eq("self-finish also fires the signal", 2, _finished_count)

	typer.start(label, "", 10.0)
	_c.eq("an empty line never starts typing", false, typer.is_typing())
	label.queue_free()


# --- the dialogue rule -----------------------------------------------------------

func _test_dialogue_gating() -> void:
	_usb._dialogue_step = 10
	_usb._update_dialogue_ui()
	_c.eq("question types itself out", true, _usb._dialogue_typer.is_typing())
	# The whole point: no answering before the question has been read.
	_c.eq("choice 1 hidden while typing", false, _usb._btn_choice1.visible)
	_c.eq("choice 2 hidden while typing", false, _usb._btn_choice2.visible)

	_usb._dialogue_typer.finish_now()
	_c.eq("choice 1 revealed when done", true, _usb._btn_choice1.visible)
	_c.eq("choice 2 revealed when done", true, _usb._btn_choice2.visible)
	# Decision time must start here, not when the line began typing, or every
	# latency would carry the typewriter duration.
	_c.ok("decision clock started", _usb._clock.elapsed() >= 0)

	# Step 12 is a closing line with a single option; that must survive the
	# hide-and-restore around the typing.
	_usb._dialogue_step = 12
	_usb._update_dialogue_ui()
	_usb._dialogue_typer.finish_now()
	_c.eq("single-option step keeps choice 2 hidden", false, _usb._btn_choice2.visible)
	_c.eq("single-option step shows choice 1", true, _usb._btn_choice1.visible)


# --- click to skip ---------------------------------------------------------------

func _test_click_skips() -> void:
	_usb._dialogue_step = 20
	_usb._update_dialogue_ui()
	_c.eq("typing again", true, _usb._dialogue_typer.is_typing())

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_usb._unhandled_input(click)
	_c.eq("a click finishes the line", false, _usb._dialogue_typer.is_typing())
	_c.eq("and the answers appear", true, _usb._btn_choice1.visible)

	# A click with nothing running must not be swallowed, so world interaction
	# keeps working outside of dialogue.
	var idle_click := InputEventMouseButton.new()
	idle_click.button_index = MOUSE_BUTTON_LEFT
	idle_click.pressed = true
	_usb._unhandled_input(idle_click)
	_c.eq("idle click leaves the state alone", false, _usb._dialogue_typer.is_typing())


func _click_on(target: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	target.gui_input.emit(event)


# The speech box is a Control with mouse_filter STOP, so a click landing on the
# box never reaches _unhandled_input. Without its own handler the hint in the
# corner was the only thing that could be clicked, the opposite of what it
# advertises.
func _test_box_is_clickable() -> void:
	_usb._dialogue_step = 30
	_usb._update_dialogue_ui()
	_c.eq("dialogue typing before the click", true, _usb._dialogue_typer.is_typing())
	_click_on(_usb._ui_dialogue_box)
	_c.eq("clicking the box finishes the line", false, _usb._dialogue_typer.is_typing())


# --- the debrief screen ---------------------------------------------------------

func _stage(title: String, body: String) -> Dictionary:
	return {"title": title, "text": body, "image": null}


func _test_debrief() -> void:
	# Loaded at call time, not preloaded: debrief.gd refers to the SfxPlayer
	# autoload by name, which only resolves once the autoloads are up. A preload
	# here is compiled before that and fails.
	var debrief: Control = (load(DEBRIEF_PATH) as GDScript).new()
	root.add_child(debrief)
	var seen: Array = []
	debrief.stage_advanced.connect(func(index: int, dwell: int) -> void:
		seen.append(index))
	debrief.configure([
		_stage("Eins", "Erste Etappe"),
		_stage("Zwei", "Zweite Etappe"),
		_stage("Drei", "Letzte Etappe"),
	])

	_c.eq("first stage types itself out", true, debrief._typer.is_typing())
	_c.eq("exits hidden while stages run", false, debrief._buttons.visible)

	_click_on(debrief._panel)
	_c.eq("a click finishes the stage", false, debrief._typer.is_typing())
	_c.eq("still not the last stage, no exits", false, debrief._buttons.visible)

	# Second click turns the page, the way the intro advances a line.
	_click_on(debrief._panel)
	_c.eq("click turns to the next stage", 1, debrief._index)
	_c.eq("advance was reported for stage 0", [0], seen)

	debrief._typer.finish_now()
	_click_on(debrief._panel)
	_c.eq("and on to the last stage", 2, debrief._index)
	debrief._typer.finish_now()
	# Only the closing stage offers a way out, so the player cannot skip the
	# lesson by clicking through.
	_c.eq("last stage reveals the exits", true, debrief._buttons.visible)

	# A stray click on the last stage must not leave the screen.
	_click_on(debrief._panel)
	_c.eq("clicking the last stage stays put", 2, debrief._index)
	_c.eq("no advance reported for the last stage", [0, 1], seen)

	# The click target is the whole screen. A container that keeps Control's
	# default STOP filter silently eats every click in its area, which is exactly
	# how the text stopped being clickable once, so the filters are pinned here.
	_c.eq("backdrop takes clicks", Control.MOUSE_FILTER_STOP, debrief._panel.mouse_filter)
	# Checked per part instead of printing only on failure, so the offender is
	# named and a regression cannot pass unnoticed.
	for part in [debrief._stage_box, debrief._title, debrief._body, debrief._image,
			debrief._buttons]:
		_c.eq("%s does not swallow clicks" % (part as Control).name,
			Control.MOUSE_FILTER_IGNORE, (part as Control).mouse_filter)

	var exits: Array = []
	for child in debrief._buttons.get_children():
		if child is Button:
			exits.append((child as Button).text)
	_c.eq("three exits offered like scenario 1", 3, exits.size())

	debrief.queue_free()
