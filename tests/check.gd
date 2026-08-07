# The check helper every headless test in tests/ runs on. The tests are plain
# SceneTree scripts with no framework; this file is all the shared machinery
# there is. It replaces the older pattern
#     print("label (expect 4): ", value)
# which printed the expected value as text and could never actually fail.
#
# Usage from a SceneTree script:
#
#     const Check := preload("res://tests/check.gd")
#     var c := Check.new()
#     c.eq("start suspicion", 4, run.suspicion)
#     ...
#     get_tree().quit(c.finish())
#
# Every check prints "ok" or "FAIL" with the expected and the actual value. A run
# ends on TEST DONE and exit code 0 when all of them passed, otherwise on the
# failure count and exit code 1 — that exit code is what makes the suite usable
# from a script.
#
# Same semantics as check() in tools/test_analyze.py, so the GDScript and the
# Python side follow one convention.

extends RefCounted

var _passed: int = 0
var _failed: int = 0


# Compares expected against actual and logs the result.
func eq(label: String, expected: Variant, actual: Variant) -> bool:
	var ok: bool = _equal(expected, actual)
	if ok:
		_passed += 1
		print("ok   %s (expect %s): %s" % [label, _fmt(expected), _fmt(actual)])
	else:
		_failed += 1
		print("FAIL %s (expect %s): %s" % [label, _fmt(expected), _fmt(actual)])
	return ok


# For conditions without an expected value, e.g. "at least one event fired".
func ok(label: String, condition: bool) -> bool:
	return eq(label, true, condition)


# Failed checks so far.
func failures() -> int:
	return _failed


# Prints the summary and returns the process exit code: 0 all green, 1 if at
# least one check failed.
func finish() -> int:
	print("")
	if _failed > 0:
		print("%d CHECK(S) FAILED (%d passed)" % [_failed, _passed])
	else:
		print("TEST DONE (%d checks passed)" % _passed)
	# quit() belongs to the SceneTree, not here: the caller ends itself and this
	# only supplies the code to pass on.
	return 1 if _failed > 0 else 0


# Passed around as Variant, arrays and dictionaries compare by REFERENCE in
# GDScript. Without an explicit deep compare every array check would be red.
func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		# int and float mix unintentionally all the time in GDScript.
		if (a is int or a is float) and (b is int or b is float):
			return is_equal_approx(float(a), float(b))
		# String and StringName are distinct types carrying the same value.
		# node.bus, node.name and Enum.keys() each return one or the other, so
		# without this branch those checks would go red for nothing.
		if (a is String or a is StringName) and (b is String or b is StringName):
			return String(a) == String(b)
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
