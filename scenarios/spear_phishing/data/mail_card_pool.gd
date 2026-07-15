# The MailBuilder card catalog, the central balancing constants (ONE place to
# tune), the Recon-find -> card bridge, the legendary unlock rules and the hand
# builder. Referenced by path (preload), no global class name.
#
# Card definition format (Array):
#   [id: StringName, type, suspicion: int, pressure: int, principle: StringName,
#    amplifies_pressure: bool]
extends RefCounted

const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")

# --- central tuning: the design's explicit difficulty knobs, one place -------
const TURN_BUDGET := 5            # mails the player may send before the run ends
const SUSPICION_START := 4        # one above target: lowering suspicion is real work
const SUSPICION_TARGET := 3       # win requires suspicion <= this
const SUSPICION_MIN := 0          # bar floor: no banking negative suspicion
const SPAM_THRESHOLD := 7         # suspicion > this => SPAM outcome
const PRESSURE_START := 3         # 4 below target: one +2 card no longer opens the gate
const PRESSURE_TARGET := 7        # win requires pressure >= this
const PRESSURE_MIN := 0
const KOLLEGEN_MIN := 4           # suspicion in [MIN,MAX] at payload => KOLLEGEN
const KOLLEGEN_MAX := 7
const AMPLIFIER_BONUS := 1        # "Keiner fragt nach" adds this to pressure cards

# Display range for the two status bars (0..MAX). Presentation lives with the
# other tuning knobs so the UI never hardcodes a scale.
const SUSPICION_BAR_MAX := 10
const PRESSURE_BAR_MAX := 10

# Hannes' reactive state, mirrored from the two bars (no new numbers, no effect
# on the bars). ANGEBISSEN is exactly the win-ready state (payload_would_win);
# gate-open-but-suspicious reads as MISSTRAUISCH — the "playable but risky"
# moment. Derived from the existing thresholds only.
enum HannesState { NEUTRAL, MISSTRAUISCH, INTERESSIERT, ANGEBISSEN }

const EPIC := MailCard.Type.EPIC
const STANDARD := MailCard.Type.STANDARD
const PAYLOAD := MailCard.Type.PAYLOAD
const SCHROTT := MailCard.Type.SCHROTT
const LEGENDARY := MailCard.Type.LEGENDARY

# Recon find id -> card definition. Every collectable find maps to a card; the
# traps (Katzen-Smalltalk, Namensvetter, ...) become playable on purpose so the
# player CAN make the mistake — that is the decision-awareness measurement.
# Two weak -1 suspicion senkers (Systemwissen, Badge-Leck); the other new epics
# are 0/0 legendary building blocks so the suspicion economy stays tight.
const RECON_CARDS := {
	&"q2a_sonntags":     [&"sonntags_hannes",       EPIC,    -2, 0, &"konsistenz",     false],
	&"q2b_neue_it":      [&"frische_it",            EPIC,    -2, 0, &"autoritaet",     false],
	&"q6_kununu":        [&"keiner_fragt_nach",     EPIC,    -1, 0, &"konformitaet",   true],
	&"q4_presse":        [&"migrations_aufhaenger", EPIC,     0, 2, &"plausibilitaet", false],
	&"q2d_whiteboard":   [&"projekt_helvetia",      EPIC,     0, 2, &"similaritaet",   false],
	&"q9_verein":        [&"vereinskollege",        EPIC,     0, 0, &"sympathie",      false],
	&"q1_kontakt":       [&"vertrauter_kontakt",    EPIC,     0, 0, &"sympathie",      false],
	&"q5_schema":        [&"mail_schema",           EPIC,     0, 0, &"konsistenz",     false],
	&"q3_stelle":        [&"bit_buerli",            EPIC,     0, 0, &"autoritaet",     false],
	&"q3z_system":       [&"systemwissen",          EPIC,    -1, 0, &"plausibilitaet", false],
	&"q10_archiv":       [&"archiv_fund",           EPIC,     0, 0, &"konsistenz",     false],
	&"q5b_details":      [&"badge_leck",            EPIC,    -1, 0, &"autoritaet",     false],
	&"q2c_katze":        [&"katzen_smalltalk",      SCHROTT,  1, 0, &"irrelevanz",     false],
	&"q7_jodler":        [&"namensvetter_jodler",   SCHROTT,  3, 0, &"kontextbruch",   false],
	&"q7x_makler":       [&"namensvetter_makler",   SCHROTT,  3, 0, &"kontextbruch",   false],
	&"q3y_konkurrenz":   [&"falsche_firma",         SCHROTT,  2, 0, &"kontextbruch",   false],
	&"q6x_lob":          [&"rundum_lob",            SCHROTT,  2, 0, &"irrelevanz",     false],
	&"q2x_alt":          [&"alter_beitrag",         SCHROTT,  1, 0, &"irrelevanz",     false],
	&"q5x_cafe":         [&"cafe_standort",         SCHROTT,  1, 0, &"irrelevanz",     false],
}

# Always in hand (no recon source).
const GENERIC_CARDS := [
	[&"konto_gesperrt",     STANDARD, 1, 4, &"autoritaet", false],
	[&"rechnung_unbezahlt", STANDARD, 1, 3, &"konsequenz", false],
	[&"frist_heute",        STANDARD, 1, 3, &"knappheit",  false],
	[&"gratis_krypto",      SCHROTT,  3, 0, &"gier",       false],
]

const PAYLOAD_CARD := [&"zugang_bestaetigen", PAYLOAD, 0, 0, &"commitment", false]

# The probe: a harmless mail whose only effect is to flip the run's probe flag
# (grants_probe = 7th field). In hand until played; playing it costs a turn and
# swaps in the Abwesenheits-Fenster card next refresh.
const PROBE_CARD := [&"probe_ooo", EPIC, 0, 0, &"aufklaerung", false, true]

# Q8 card, enters the hand once the probe has run (replaces PROBE_CARD).
const ABWESENHEITS_FENSTER := [&"abwesenheits_fenster", EPIC, 0, 3, &"knappheit", false]

# Cross-reference legendaries. `needs`: all find ids required. `needs_any`
# (optional): at least one satisfied, where &"__probe__" means the Q8 probe
# flag. Identität gesichert has a second path (Archiv-Fund) so it is reachable
# before the probe mechanic exists.
const LEGENDARIES := [
	{"card": [&"perfekter_absender", LEGENDARY, -3, 0, &"kombination", false],
		"needs": [&"q2b_neue_it", &"q3_stelle"]},
	{"card": [&"echter_vorwand", LEGENDARY, -1, 3, &"kombination", false],
		"needs": [&"q4_presse", &"q2d_whiteboard"]},
	{"card": [&"verifiziert", LEGENDARY, -3, 0, &"kombination", false],
		"needs": [&"q9_verein", &"q7_jodler"]},
	{"card": [&"identitaet_gesichert", LEGENDARY, 0, 2, &"kombination", false],
		"needs": [&"q5_schema"], "needs_any": [&"__probe__", &"q10_archiv"]},
]


static func _make(def: Array) -> MailCard:
	var grants_probe: bool = def[6] if def.size() > 6 else false
	return MailCard.new(def[0], def[1], def[2], def[3], def[4], def[5], grants_probe)


# The player's fixed hand (no draw, no randomness): collected recon cards (incl.
# traps) + unlocked legendaries + the probe (or, once run, the Q8 card it
# unlocks) + the fixed generic set + the payload (last).
static func build_hand(collected_find_ids: Array, probe_done: bool) -> Array:
	var hand: Array = []
	for fid in collected_find_ids:
		if RECON_CARDS.has(fid):
			hand.append(_make(RECON_CARDS[fid]))
	for leg in LEGENDARIES:
		if _legendary_unlocked(leg, collected_find_ids, probe_done):
			hand.append(_make(leg["card"]))
	# Exactly one of the two: the probe before it runs, the unlocked window after.
	if probe_done:
		hand.append(_make(ABWESENHEITS_FENSTER))
	else:
		hand.append(_make(PROBE_CARD))
	for def in GENERIC_CARDS:
		hand.append(_make(def))
	hand.append(_make(PAYLOAD_CARD))
	return hand


static func unlocked_legendary_ids(collected_find_ids: Array, probe_done: bool) -> Array:
	var ids: Array = []
	for leg in LEGENDARIES:
		if _legendary_unlocked(leg, collected_find_ids, probe_done):
			ids.append(leg["card"][0])
	return ids


static func find_in_hand(hand: Array, card_id: StringName) -> MailCard:
	for card in hand:
		if card.id == card_id:
			return card
	return null


# Generic cards are inexhaustible (always in hand, every turn); everything else
# is consumed once played. The UI uses this to decide what to remove after send.
static func is_generic(card_id: StringName) -> bool:
	for def in GENERIC_CARDS:
		if def[0] == card_id:
			return true
	return false


# Derives Hannes' state from the current bars using the existing thresholds. The
# order matters: a suspicious target stays suspicious regardless of pressure;
# only with suspicion in the safe zone does pressure decide interest vs the bite.
static func hannes_state(suspicion: int, pressure: int) -> HannesState:
	if suspicion > SUSPICION_TARGET:
		return HannesState.MISSTRAUISCH
	if pressure >= PRESSURE_TARGET:
		return HannesState.ANGEBISSEN
	if pressure > PRESSURE_START:
		return HannesState.INTERESSIERT
	return HannesState.NEUTRAL


static func _legendary_unlocked(leg: Dictionary, collected: Array, probe_done: bool) -> bool:
	for need in leg["needs"]:
		if not collected.has(need):
			return false
	if leg.has("needs_any"):
		var any_ok := false
		for alt in leg["needs_any"]:
			if alt == &"__probe__":
				if probe_done:
					any_ok = true
			elif collected.has(alt):
				any_ok = true
		if not any_ok:
			return false
	return true
