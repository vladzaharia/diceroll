extends RefCounted
## Base class for tests. Assertions record failures instead of aborting,
## so one test method can report several problems at once.

var failures: Array[String] = []

func assert_true(cond: bool, msg := "expected true") -> void:
	if not cond:
		failures.append(msg)

func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s expected <%s> got <%s>" % [msg, str(expected), str(actual)])

func assert_near(actual: float, expected: float, eps := 0.0001, msg := "") -> void:
	if absf(actual - expected) > eps:
		failures.append("%s expected ~%f got %f" % [msg, expected, actual])
