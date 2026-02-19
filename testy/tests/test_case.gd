@tool
class_name TestCase
extends Resource

@export_dir var path: String 

enum RunStatus { NOT_RUN = 0, PASSED = 1, FAILED = 2 }

@export var name: String
@export var created_at: float = Time.get_unix_time_from_system()
@export var last_run_at: float = 0
@export var run_status: RunStatus = RunStatus.NOT_RUN
@export var seed: int

const FILE_SNAPSHOT_A = "snapshot_a.tres"
const FILE_SNAPSHOT_B = "snapshot_b.tres"
const FILE_INPUT = "input_recording.tres"
const FILE_ASSERTIONS = "assertions.testy"
const FILE_REPORT = "test_report.tres"
const FILE_CASE = "test_case.tres"

func save_resource() -> Error:
	if path.is_empty(): return ERR_INVALID_DATA
	var save_path = path.path_join(FILE_CASE)
	return ResourceSaver.save(self, save_path)

func save_run_result(report: TestReport) -> Error:
	last_run_at = Time.get_unix_time_from_system()
	
	if report.failed_count == 0:
		run_status = RunStatus.PASSED
	else:
		run_status = RunStatus.FAILED
		
	if path.is_empty(): return ERR_INVALID_DATA
	
	var report_path = path.path_join(FILE_REPORT)
	var err = ResourceSaver.save(report, report_path)
	if err != OK:
		push_error("TestCase: Failed to save test report to %s. Error: %s" % [report_path, error_string(err)])
		return err
		
	return save_resource()

func get_report() -> TestReport:
	var report_path = path.path_join(FILE_REPORT)
	if not FileAccess.file_exists(report_path):
		return null
		
	return ResourceLoader.load(report_path, "", ResourceLoader.CACHE_MODE_IGNORE) as TestReport

func get_log_text() -> String:
	var report = get_report()
	if not report:
		return ""
	
	return report.get_formatted_text()

func get_snapshot_a() -> Snapshot:
	return _load_resource(FILE_SNAPSHOT_A) as Snapshot

func get_snapshot_b() -> Snapshot:
	return _load_resource(FILE_SNAPSHOT_B) as Snapshot

func get_input_recording() -> InputRecording:
	return _load_resource(FILE_INPUT) as InputRecording

func get_assertions() -> Array:
	var full_path = path.path_join(FILE_ASSERTIONS)
	if not FileAccess.file_exists(full_path):
		push_warning("TestCase: Assertions file missing at %s" % full_path)
		return []
		
	var file = FileAccess.open(full_path, FileAccess.READ)
	if not file: return []
	var buffer = file.get_buffer(file.get_length())
	var data = bytes_to_var(buffer)
	return data if data is Array else []

func _load_resource(filename: String) -> Resource:
	if path.is_empty(): return null
	var full_path = path.path_join(filename)
	if not FileAccess.file_exists(full_path): return null
	return load(full_path)
