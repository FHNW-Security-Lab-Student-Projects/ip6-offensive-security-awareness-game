# Append-only JSONL writer. Subscribes to EventBus.generic_event and
# persists every payload as one JSON object per line under
# user://logs/session_{uuid}.jsonl. Stamps timestamp_ms and session_uuid
# on every event so the logs are self-describing.
extends Node

const LOG_DIR: String = "user://logs"

var _log_path: String = ""

func _ready() -> void:
	var err: int = DirAccess.make_dir_recursive_absolute(LOG_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("Telemetry: could not create %s (err=%d)" % [LOG_DIR, err])
		return
	_log_path = "%s/session_%s.jsonl" % [LOG_DIR, GameState.session_uuid]
	# Print resolved absolute path once per run so the researcher can
	# locate logs on disk without guessing the user:// mount point.
	print("Telemetry: writing to ", ProjectSettings.globalize_path(_log_path))
	EventBus.generic_event.connect(_on_event)

func _on_event(payload: Dictionary) -> void:
	if _log_path.is_empty():
		return
	var enriched: Dictionary = payload.duplicate()
	enriched["timestamp_ms"] = Time.get_unix_time_from_system() * 1000.0
	enriched["session_uuid"] = GameState.session_uuid
	var file: FileAccess = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		# READ_WRITE fails if the file does not yet exist; create it.
		file = FileAccess.open(_log_path, FileAccess.WRITE)
	if file == null:
		push_error("Telemetry: cannot open %s (err=%d)" % [_log_path, FileAccess.get_open_error()])
		return
	file.seek_end()
	file.store_line(JSON.stringify(enriched))
	file.close()
