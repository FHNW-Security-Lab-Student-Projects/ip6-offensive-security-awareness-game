# Lightweight runtime loader for the game's CSV translation tables.
#
# Why not the editor's csv_translation importer: that pipeline puts
# generated .translation files in .godot/imported (gitignored), or
# requires hand-rolled .import sidecar files. A direct runtime load
# keeps the CSVs as the single source of truth, no import dance.
#
# Two tables, merged by locale into one set of Translations:
#   - strings.csv        UI microcopy (bars, buttons, dialog labels)
#   - recon_content.csv  Recon find content (titles, authors, post bodies)
# Splitting content from microcopy keeps long paragraphs out of the UI table.
# Each file has its own locale columns; a locale present in several files
# accumulates all its messages. Add a language = add a column (no code change);
# add a content table = add a path to CONTENT_CSVS.
#
# CSV format:
#   keys,de[,en[,fr...]]
#   <KEY>,<german>[,<english>[,<french>...]]
extends Node

const STRINGS_CSV: String = "res://resources/i18n/strings.csv"
const CONTENT_CSVS: Array[String] = [
	"res://resources/i18n/recon_content.csv",
]
const DEFAULT_LOCALE: String = "de"

func _ready() -> void:
	_load_translations()
	TranslationServer.set_locale(DEFAULT_LOCALE)

func _load_translations() -> void:
	var translations: Dictionary = {}  # locale (String) -> Translation
	var total: int = _load_csv(STRINGS_CSV, translations)
	for path in CONTENT_CSVS:
		total += _load_csv(path, translations)
	for t in translations.values():
		TranslationServer.add_translation(t)
	print("I18n: loaded %d keys across %d locale(s)" % [total, translations.size()])

# Loads one CSV table into the shared locale->Translation map and returns the
# number of key rows read. Reuses an existing Translation for a locale so the
# same locale can be filled from several files.
func _load_csv(path: String, translations: Dictionary) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("I18n: cannot open %s" % path)
		return 0
	var header: PackedStringArray = file.get_csv_line()
	if header.size() < 2 or header[0] != "keys":
		push_error("I18n: malformed header in %s (got %s)" % [path, header])
		return 0
	for i in range(1, header.size()):
		var locale: String = header[i]
		if not translations.has(locale):
			var t: Translation = Translation.new()
			t.locale = locale
			translations[locale] = t
	var row_count: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		var key: String = row[0]
		for i in range(1, header.size()):
			if i < row.size() and not row[i].is_empty():
				(translations[header[i]] as Translation).add_message(key, row[i])
		row_count += 1
	return row_count
