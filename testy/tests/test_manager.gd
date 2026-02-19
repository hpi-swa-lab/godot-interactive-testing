class_name TestManager
extends Object

const TESTS_DIR := "res://tests/"

func add_test(name: String, seed: int, snapshot_a: Snapshot, snapshot_b: Snapshot, input_recording: Resource, assertions: Array) -> TestCase:
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var safe_name = name.validate_node_name() 
	var folder_name = "%s_%s" % [timestamp, safe_name]
	var test_dir = TESTS_DIR.path_join(folder_name)
	
	if not _ensure_directory_exists(test_dir):
		return null

	var test_case := TestCase.new()
	test_case.name = name
	test_case.path = test_dir
	test_case.seed = seed
	
	if not _save_resource(snapshot_a, test_dir.path_join(TestCase.FILE_SNAPSHOT_A)): return null
	if not _save_resource(snapshot_b, test_dir.path_join(TestCase.FILE_SNAPSHOT_B)): return null
	if not _save_resource(input_recording, test_dir.path_join(TestCase.FILE_INPUT)): return null

	if not _save_assertions_binary(assertions, test_dir.path_join(TestCase.FILE_ASSERTIONS)):
		return null

	var final_path = test_dir.path_join("test_case.tres")
	var err = ResourceSaver.save(test_case, final_path)
	
	if err != OK:
		push_error("TestManager: Failed to save final test_case.tres. Error: %s" % error_string(err))
		return null

	print("✅ Test Case '%s' created successfully at: %s" % [name, test_dir])
	return test_case

func get_tests() -> Array[TestCase]:
	var found_tests: Array[TestCase] = []
	
	var dir = DirAccess.open(TESTS_DIR)
	if not dir:
		push_warning("TestManager: Could not open tests directory: %s" % TESTS_DIR)
		return []

	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		if dir.current_is_dir() and folder_name != "." and folder_name != "..":
			var potential_path = TESTS_DIR.path_join(folder_name).path_join("test_case.tres")
			
			if FileAccess.file_exists(potential_path):
				var loaded_case = ResourceLoader.load(potential_path, "", ResourceLoader.CACHE_MODE_REPLACE)
				
				if loaded_case is TestCase:
					found_tests.append(loaded_case)
				else:
					push_warning("TestManager: Resource at %s is not a TestCase." % potential_path)
		
		folder_name = dir.get_next()
	
	dir.list_dir_end()
	
	found_tests.sort_custom(func(a, b): return a.created_at > b.created_at)
	
	return found_tests

func delete(test: TestCase) -> bool:
	var path := test.path
	if not DirAccess.dir_exists_absolute(path):
		push_error("TestManager: Cannot delete test. Directory does not exist: %s" % path)
		return false
		
	if not path.begins_with(TESTS_DIR):
		push_error("TestManager: Safety Block. Attempted to delete outside of tests directory: %s" % path)
		return false
		
	print("TestManager: Deleting test case at: %s" % path)
	return _recursive_delete_dir(path)

func _recursive_delete_dir(path: String) -> bool:
	var dir = DirAccess.open(path)
	if not dir:
		push_error("TestManager: Failed to open directory for deletion: " + path)
		return false

	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				if not _recursive_delete_dir(path.path_join(file_name)):
					return false
		else:
			var err = dir.remove(file_name)
			if err != OK:
				push_error("TestManager: Failed to remove file: %s. Error: %s" % [file_name, error_string(err)])
				return false
				
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	var err = DirAccess.remove_absolute(path)
	if err != OK:
		push_error("TestManager: Failed to remove directory: %s. Error: %s" % [path, error_string(err)])
		return false
		
	return true

func get_test_case(path: String) -> TestCase:
	path = path + "/test_case.tres"
	if not FileAccess.file_exists(path):
		push_error("TestManager: Test case not found at path: %s" % path)
		return null
		
	var res = ResourceLoader.load(path)
	if res is TestCase:
		return res
		
	push_error("TestManager: Resource at %s is valid but not a TestCase." % path)
	return null

func _ensure_directory_exists(path: String) -> bool:
	var dir_access = DirAccess.open("res://")
	if not dir_access.dir_exists(path):
		var err = dir_access.make_dir_recursive(path)
		if err != OK:
			push_error("TestManager: Failed to create directory '%s'. Error: %s" % [path, error_string(err)])
			return false
	return true

func _save_resource(res: Resource, path: String) -> bool:
	var err = ResourceSaver.save(res, path)
	if err != OK:
		push_error("TestManager: Failed to save resource to '%s'. Error: %s" % [path, error_string(err)])
		return false
	return true

func _save_assertions_binary(assertions: Array, path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var buffer = var_to_bytes(assertions)
		file.store_buffer(buffer)
		file.close()
		return true
	else:
		push_error("TestManager: Failed to open assertions file for writing: %s" % path)
		return false
