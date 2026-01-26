@tool
class_name TestReport
extends Resource

@export var total_checks: int = 0
@export var passed_count: int = 0
@export var failed_count: int = 0

@export var results: Array[TestReportEntry] = []

func add_entry(entry: TestReportEntry) -> void:
	results.append(entry)
	total_checks += 1
	
	if entry.is_passed:
		passed_count += 1
	else:
		failed_count += 1

func is_successful() -> bool:
	return failed_count == 0

func get_text() -> String:
	var txt = "--- TEST REPORT ---\n"
	txt += "Total Checks: %d | Passed: %d | Failed: %d\n\n" % [total_checks, passed_count, failed_count]
	
	txt += "--- RESULTS ---\n"
	for entry in results:
		var status = "[PASS]" if entry.is_passed else "[FAIL]"
		
		txt += "%s %s (%s) [ID:%d]\n" % [status, entry.node_name, entry.node_type, entry.node_id]
		
		if not entry.is_passed and not entry.failure_reason.is_empty():
			txt += "  Error: %s\n" % entry.failure_reason
			
		for check in entry.checks:
			var check_mark = "✔" if check.passed else "✘"
			txt += "    %s %s: Expected '%s', Got '%s'\n" % [check_mark, check.name, check.expected, check.actual]
			
		txt += "\n"
		
	return txt
