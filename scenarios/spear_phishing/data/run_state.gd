# The per-run handoff between the phases of scenario 1. Owned by the scenario
# shell and created per scene load, so a replay starts clean without a wipe -
# unlike an autoload, which survives the scene change.
# Preload, no class_name: a bare `godot -s` run has no global class cache.
extends RefCounted

# Recon -> MailBuilder: ids of the finds the player collected.
var collected_find_ids: Array[StringName] = []

# MailBuilder -> Resolve: true once the mail-phase probe has run.
var probe_done: bool = false

# MailBuilder -> Resolve: outcome name, final bars, turns used, played cards.
var mail_result: Dictionary = {}


# Copies on write so the caller cannot mutate what a later phase reads.
func set_collected_finds(ids: Array[StringName]) -> void:
	collected_find_ids = ids.duplicate()


func set_mail_result(result: Dictionary) -> void:
	mail_result = result.duplicate(true)
