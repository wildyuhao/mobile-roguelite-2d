extends RefCounted
class_name TestRunner

var failures: Array[String] = []

func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])

func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if abs(actual - expected) > tolerance:
		failures.append("%s Expected=%s Actual=%s Tolerance=%s" % [message, expected, actual, tolerance])

func has_failures() -> bool:
	return not failures.is_empty()

func print_failures() -> void:
	for failure in failures:
		push_error(failure)
