class_name Runner
extends Object

signal finished(test: TestCase)

const MAX_CONCURRENT_TASKS = 2 

var _pending_queue: Array[TestCase] = []
var _active_threads: Array[Thread] = []

func run_test(test: TestCase):
	_pending_queue.append(test)
	print(">>> Queued test: %s" % test.name)    
	_process_queue()

func _process_queue():
	if _pending_queue.is_empty(): return
	if _active_threads.size() >= MAX_CONCURRENT_TASKS: return

	var test: TestCase = _pending_queue.pop_front()
	var thread = Thread.new()
	_active_threads.append(thread)
	
	thread.start(_thread_task.bind(thread, test))

func _thread_task(thread_ref: Thread, test: TestCase):
	var exe_path = OS.get_executable_path()
	
	var args = [
		"--path", ProjectSettings.globalize_path("res://"),
		"--", 
		"--test-case", test.path
	]
	
	var output = []
	
	OS.execute(exe_path, args, output, true)
	
	call_deferred("_on_task_completed", thread_ref, output, test)

func _on_task_completed(thread_ref: Thread, output: Array, test: TestCase):
	thread_ref.wait_to_finish()
	_active_threads.erase(thread_ref)
	
	finished.emit(test)
	print(">>> Finished test: %s" % test.name)
	
	_process_queue()
