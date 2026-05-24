# Lightweight runtime loader for resources/i18n/strings.csv.
#
# Why not the editor's csv_translation importer: that pipeline puts
# generated .translation files in .godot/imported (gitignored), or
# requires hand-rolled .import sidecar files. A direct runtime load
# keeps the CSV as the single source of truth, no import dance.
#
# CSV format:
#   keys,de[,en[,fr...]]
#   <KEY>,<german>[,<english>[,<french>...]]
#
# To add a language: add a column. Nothing else changes.
extends Node

const STRINGS_CSV: String = "res://resources/i18n/strings.csv"
const DEFAULT_LOCALE: String = "de"

func _ready() -> void:
	_load_translations()
	TranslationServer.set_locale(DEFAULT_LOCALE)

func _load_translations() -> void:
	var file: FileAccess = FileAccess.open(STRINGS_CSV, FileAccess.READ)
	if file == null:
		push_error("I18n: cannot open %s" % STRINGS_CSV)
		return
	var header: PackedStringArray = file.get_csv_line()
	if header.size() < 2 or header[0] != "keys":
		push_error("I18n: malformed header in %s (got %s)" % [STRINGS_CSV, header])
		return
	var translations: Dictionary = {}  # locale (String) -> Translation
	for i in range(1, header.size()):
		var t: Translation = Translation.new()
		t.locale = header[i]
		translations[header[i]] = t
	var row_count: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		var key: String = row[0]
		for i in range(1, header.size()):
			if i < row.size() and not row[i].is_empty():
				translations[header[i]].add_message(key, row[i])
		row_count += 1
	for t in translations.values():
		TranslationServer.add_translation(t)
	print("I18n: loaded %d keys across %d locale(s)" % [row_count, translations.size()])
