# One MailBuilder card: two bar deltas plus a persuasion-principle tag for the
# telemetry. No text stored - the translation keys derive from the id.
# Preload, no class_name: a bare `godot -s` run has no global class cache.
extends RefCounted

enum Type { EPIC, STANDARD, PAYLOAD, SCHROTT, LEGENDARY }

var id: StringName
var type: Type
var suspicion: int          # delta applied to the target's suspicion bar
var pressure: int           # delta applied to the target's pressure bar
var principle: StringName   # thesis analysis axis, e.g. &"autoritaet"
var amplifies_pressure: bool  # "Keiner fragt nach": boosts later pressure cards
var grants_probe: bool        # probe card: playing it flips the run's probe flag


func _init(p_id: StringName, p_type: Type, p_suspicion: int, p_pressure: int,
		p_principle: StringName, p_amplifies_pressure: bool = false,
		p_grants_probe: bool = false) -> void:
	id = p_id
	type = p_type
	suspicion = p_suspicion
	pressure = p_pressure
	principle = p_principle
	amplifies_pressure = p_amplifies_pressure
	grants_probe = p_grants_probe


func name_key() -> String:
	return "MAIL_%s_NAME" % String(id).to_upper()


func text_key() -> String:
	return "MAIL_%s_TEXT" % String(id).to_upper()


# Enum key as a string, for telemetry payloads.
func type_name() -> String:
	return Type.keys()[type]
