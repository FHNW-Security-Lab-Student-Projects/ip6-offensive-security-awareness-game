# The per-run handoff between the phases of scenario 1: Recon fills the
# collected finds, the MailBuilder reads them and writes back the probe flag
# and the finished mail, Resolve reads all three.
#
# Owned by the scenario shell and created per scene load, so a fresh run starts
# clean on its own. The same three fields used to live on the GameState
# autoload, which survives a scene change and therefore needed an explicit
# wipe before every replay.
#
# Referenced by preload, no global class name: a bare `godot -s` test script
# cannot compile one (same reason as mail_builder_state.gd).
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
