# Headless test for the flowing text in bad_usb: the Typewriter helper itself,
# and the rule it enforces in the dialogue, namely that the answers stay hidden
# until the question has finished typing and a click reveals the rest at once.
#
# Run:
#   godot --headless --path . -s tests/test_typewriter.gd
#
# Every line prints the expected value next to the actual one; a run passes
# when all "expect" values match and it ends with TEST DONE.
extends SceneTree

const Typewriter := preload("res://scenarios/base/typewriter.gd")
const DEBRIEF_PATH := "res://scenarios/bad_usb/debrief.gd"

var _step := 0
var _usb: Node
var _finished_count := 0


func _on_finished() -> void:
	_finished_count += 1


func _process(_delta: float) -> bool:
	_step += 1
	if _step == 1:
		_usb = (load("res://scenarios/bad_usb/bad_usb.tscn") as PackedScene).instantiate()
		root.add_child(_usb)
		return false
	if _step != 2:
		return false

	_test_typewriter_unit()
	_test_dialogue_gating()
	_test_click_skips()
	_test_box_is_clickable()
	_test_debrief()

	print("TEST DONE")
	quit()
	return true


# --- the helper ----------------------------------------------------------------

func _test_typewriter_unit() -> void:
	var label := Label.new()
	root.add_child(label)
	var typer := Typewriter.new()
	typer.finished.connect(_on_finished)

	typer.start(label, "Hallo Welt", 10.0)  # 10 chars per second
	print("starts in typing state (expect true): ", typer.is_typing())
	print("nothing shown at the start (expect 0): ", label.visible_characters)
	print("full text is already set (expect Hallo Welt): ", label.text)

	typer.advance(0.5)  # 5 characters
	print("half a second reveals 5 chars (expect 5): ", label.visible_characters)
	print("still typing (expect true): ", typer.is_typing())
	print("no finish yet (expect 0): ", _finished_count)

	typer.finish_now()
	# -1 is Godot's "show everything" and is what a completed line must land on,
	# otherwise a later relayout could clip the tail.
	print("finish reveals everything (expect -1): ", label.visible_characters)
	print("no longer typing (expect false): ", typer.is_typing())
	print("finished fired once (expect 1): ", _finished_count)

	typer.finish_now()
	print("finishing twice fires only once (expect 1): ", _finished_count)

	typer.advance(1.0)
	print("advancing after the end is harmless (expect -1): ", label.visible_characters)

	# Running past the end must finish on its own, without a click.
	typer.start(label, "kurz", 100.0)
	typer.advance(1.0)
	print("running out finishes by itself (expect false): ", typer.is_typing())
	print("self-finish also fires the signal (expect 2): ", _finished_count)

	typer.start(label, "", 10.0)
	print("an empty line never starts typing (expect false): ", typer.is_typing())
	label.queue_free()


# --- the dialogue rule -----------------------------------------------------------

func _test_dialogue_gating() -> void:
	_usb._dialogue_step = 10
	_usb._update_dialogue_ui()
	print("question types itself out (expect true): ", _usb._dialogue_typer.is_typing())
	# The whole point: no answering before the question has been read.
	print("choice 1 hidden while typing (expect false): ", _usb._btn_choice1.visible)
	print("choice 2 hidden while typing (expect false): ", _usb._btn_choice2.visible)

	_usb._dialogue_typer.finish_now()
	print("choice 1 revealed when done (expect true): ", _usb._btn_choice1.visible)
	print("choice 2 revealed when done (expect true): ", _usb._btn_choice2.visible)
	# Decision time must start here, not when the line began typing, or every
	# latency would carry the typewriter duration.
	print("decision clock started (expect true): ", _usb._clock.elapsed() >= 0)

	# Step 12 is a closing line with a single option; that must survive the
	# hide-and-restore around the typing.
	_usb._dialogue_step = 12
	_usb._update_dialogue_ui()
	_usb._dialogue_typer.finish_now()
	print("single-option step keeps choice 2 hidden (expect false): ", _usb._btn_choice2.visible)
	print("single-option step shows choice 1 (expect true): ", _usb._btn_choice1.visible)


# --- click to skip ---------------------------------------------------------------

func _test_click_skips() -> void:
	_usb._dialogue_step = 20
	_usb._update_dialogue_ui()
	print("typing again (expect true): ", _usb._dialogue_typer.is_typing())

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_usb._unhandled_input(click)
	print("a click finishes the line (expect false): ", _usb._dialogue_typer.is_typing())
	print("and the answers appear (expect true): ", _usb._btn_choice1.visible)

	# A click with nothing running must not be swallowed, so world interaction
	# keeps working outside of dialogue.
	var idle_click := InputEventMouseButton.new()
	idle_click.button_index = MOUSE_BUTTON_LEFT
	idle_click.pressed = true
	_usb._unhandled_input(idle_click)
	print("idle click leaves the state alone (expect false): ", _usb._dialogue_typer.is_typing())


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
	print("dialogue typing before the click (expect true): ", _usb._dialogue_typer.is_typing())
	_click_on(_usb._ui_dialogue_box)
	print("clicking the box finishes the line (expect false): ", _usb._dialogue_typer.is_typing())


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

	print("first stage types itself out (expect true): ", debrief._typer.is_typing())
	print("exits hidden while stages run (expect false): ", debrief._buttons.visible)

	_click_on(debrief._panel)
	print("a click finishes the stage (expect false): ", debrief._typer.is_typing())
	print("still not the last stage, no exits (expect false): ", debrief._buttons.visible)

	# Second click turns the page, the way the intro advances a line.
	_click_on(debrief._panel)
	print("click turns to the next stage (expect 1): ", debrief._index)
	print("advance was reported for stage 0 (expect [0]): ", seen)

	debrief._typer.finish_now()
	_click_on(debrief._panel)
	print("and on to the last stage (expect 2): ", debrief._index)
	debrief._typer.finish_now()
	# Only the closing stage offers a way out, so the player cannot skip the
	# lesson by clicking through.
	print("last stage reveals the exits (expect true): ", debrief._buttons.visible)

	# A stray click on the last stage must not leave the screen.
	_click_on(debrief._panel)
	print("clicking the last stage stays put (expect 2): ", debrief._index)
	print("no advance reported for the last stage (expect [0, 1]): ", seen)

	var exits: Array = []
	for child in debrief._buttons.get_children():
		if child is Button:
			exits.append((child as Button).text)
	print("three exits offered like scenario 1 (expect 3): ", exits.size())

	debrief.queue_free()
