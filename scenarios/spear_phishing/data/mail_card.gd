# A single MailBuilder card: two bar deltas plus a persuasion-principle tag for
# the thesis telemetry. Pure data, no i18n text stored — name_key()/text_key()
# derive the translation keys from the id (like ReconFind). Referenced by path
# (preload), not a global class name, so headless tests run without an editor
# import.
extends RefCounted

enum Type { EPIC, STANDARD, PAYLOAD, SCHROTT, LEGENDARY }

var id: StringName
var type: Type
var suspicion: int          # delta applied to the target's suspicion bar
var pressure: int           # delta applied to the target's pressure bar
var principle: StringName   # thesis analysis axis, e.g. &"autoritaet"
var amplifies_pressure: bool  # "Keiner fragt nach": boosts later pressure cards


func _init(p_id: StringName, p_type: Type, p_suspicion: int, p_pressure: int,
		p_principle: StringName, p_amplifies_pressure: bool = false) -> void:
	id = p_id
	type = p_type
	suspicion = p_suspicion
	pressure = p_pressure
	principle = p_principle
	amplifies_pressure = p_amplifies_pressure


func name_key() -> String:
	return "MAIL_%s_NAME" % String(id).to_upper()


func text_key() -> String:
	return "MAIL_%s_TEXT" % String(id).to_upper()


# Enum key as a string, for telemetry payloads.
func type_name() -> String:
	return Type.keys()[type]
