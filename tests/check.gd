# Minimale Pruef-Hilfe fuer die headless Tests in tests/.
#
# Ersetzt das bisherige Muster
#     print("label (expect 4): ", wert)
# das den Soll-Wert nur als Text mitdruckte und niemals fehlschlagen konnte,
# durch einen echten Vergleich.
#
# Verwendung in einem SceneTree-Skript:
#
#     const Check := preload("res://tests/check.gd")
#     var c := Check.new()
#     ...
#     c.eq("start suspicion", 4, run.suspicion)
#     ...
#     c.finish()   # druckt die Zusammenfassung und setzt den Exit-Code
#
# Semantik bewusst gleich wie check() in tools/test_analyze.py, damit die
# GDScript- und die Python-Seite dieselbe Konvention haben.

extends RefCounted

var _passed: int = 0
var _failed: int = 0


# Vergleicht Soll und Ist und protokolliert das Ergebnis.
func eq(label: String, expected: Variant, actual: Variant) -> bool:
	var ok: bool = _equal(expected, actual)
	if ok:
		_passed += 1
		print("ok   %s (expect %s): %s" % [label, _fmt(expected), _fmt(actual)])
	else:
		_failed += 1
		print("FAIL %s (expect %s): %s" % [label, _fmt(expected), _fmt(actual)])
	return ok


# Fuer Faelle, in denen nur eine Bedingung gilt und es keinen Soll-Wert gibt,
# etwa "mindestens ein Event wurde emittiert".
func ok(label: String, condition: bool) -> bool:
	return eq(label, true, condition)


# Anzahl der bisher fehlgeschlagenen Pruefungen.
func failures() -> int:
	return _failed


# Druckt die Zusammenfassung und setzt den Exit-Code des Prozesses.
# 0 = alles gruen, 1 = mindestens eine Pruefung ist fehlgeschlagen.
func finish() -> int:
	print("")
	if _failed > 0:
		print("%d CHECK(S) FAILED (%d passed)" % [_failed, _passed])
	else:
		print("TEST DONE (%d checks passed)" % _passed)
	# quit() liegt beim SceneTree, nicht hier -- der Aufrufer beendet sich
	# selbst. Wir liefern nur den Code, den er weiterreichen soll.
	return 1 if _failed > 0 else 0


# Arrays und Dictionaries vergleichen sich in GDScript per Referenz, sobald sie
# als Variant durchgereicht werden. Der Inhaltsvergleich muss darum explizit
# sein, sonst waere jede Array-Pruefung immer rot.
func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		# int/float mischen sich in GDScript haeufig unbeabsichtigt.
		if (a is int or a is float) and (b is int or b is float):
			return is_equal_approx(float(a), float(b))
		return false
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _equal(a[i], b[i]):
				return false
		return true
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k in a.keys():
			if not b.has(k):
				return false
			if not _equal(a[k], b[k]):
				return false
		return true
	return a == b


func _fmt(v: Variant) -> String:
	if v == null:
		return "null"
	if v is String or v is StringName:
		return "\"%s\"" % v
	return str(v)
