## TestRunner — collects all test nodes and reports a final pass/fail.
## Open tests/TestRunner.tscn and press F6 to run all tests.
extends Node

var _total_failures: int = 0
var _suites_remaining: int = 0


func _ready() -> void:
	# Connect to all child test nodes' all_done signal.
	for child: Node in get_children():
		if child.has_signal("all_done"):
			_suites_remaining += 1
			child.all_done.connect(_on_suite_done)


func _on_suite_done(failed_count: int) -> void:
	_total_failures += failed_count
	_suites_remaining -= 1
	if _suites_remaining == 0:
		_finish()


func _finish() -> void:
	print("\n" + "=".repeat(40))
	if _total_failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("TOTAL FAILURES: %d" % _total_failures)
	print("=".repeat(40))
