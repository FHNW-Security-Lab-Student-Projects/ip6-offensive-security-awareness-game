# Autoload: player settings, persisted to user://settings.cfg and applied to the
# audio buses / window on load. Volumes are stored as 0..1 linear values (what a
# slider shows) and converted to dB for the bus, so a slider at 50% sounds like
# half volume instead of following the dB curve.
#
# Buses: Master -> Music, SFX (see default_bus_layout.tres). The music players
# route to "Music", the SFX player to "SFX", so each slider only moves its own.
extends Node

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "settings"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var fullscreen: bool = false


func _ready() -> void:
	load_settings()
	_apply_bus(&"Master", master_volume)
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)
	# The window mode is left alone at boot unless fullscreen was saved: forcing
	# it here would fight the project's own default window mode, and touching the
	# window this early errors out ("parent busy setting up children").
	if fullscreen:
		_apply_fullscreen.call_deferred()


# --- mutators (each applies immediately and saves) ----------------------------

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus(&"Master", master_volume)
	_after_change()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(MUSIC_BUS, music_volume)
	_after_change()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus(SFX_BUS, sfx_volume)
	_after_change()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	_after_change()


func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.7
	sfx_volume = 0.8
	fullscreen = false
	apply_all()
	save_settings()
	settings_changed.emit()


# --- apply / persist ----------------------------------------------------------

func apply_all() -> void:
	_apply_bus(&"Master", master_volume)
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)
	_apply_fullscreen()


# A linear 0..1 slider mapped to dB; 0 mutes the bus outright (linear_to_db(0)
# is -inf, which some drivers dislike).
func _apply_bus(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(String(bus_name))
	if idx < 0:
		return  # bus layout missing: leave the default routing alone
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
		else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _after_change() -> void:
	save_settings()
	settings_changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	var err := cfg.save(CONFIG_PATH)
	if err != OK:
		push_error("Settings: could not save %s (err=%d)" % [CONFIG_PATH, err])


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return  # no file yet: keep the defaults above
	master_volume = clampf(float(cfg.get_value(SECTION, "master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value(SECTION, "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", fullscreen))
