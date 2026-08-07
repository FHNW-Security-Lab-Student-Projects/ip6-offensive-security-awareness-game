# Reads the CSV translation tables at startup, one Translation per locale.
# Deliberately not the editor's csv_translation importer: a runtime load keeps
# the CSVs the single source of truth.
#
# Format: keys,de[,en,...] — one file per topic, merged by locale column.
# New language = new column. New table = new path in CONTENT_CSVS.
extends Node

const STRINGS_CSV: String = "res://resources/i18n/strings.csv"
const CONTENT_CSVS: Array[String] = [
	"res://resources/i18n/recon_content.csv",
	"res://resources/i18n/mail_content.csv",
	"res://resources/i18n/resolve_content.csv",
	"res://resources/i18n/bad_usb_content.csv",
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

# Fills the shared locale->Translation map from one file and returns the row
# count. Reuses an existing Translation so several files feed the same locale.
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
