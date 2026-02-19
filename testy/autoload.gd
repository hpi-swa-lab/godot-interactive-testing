extends Node

const STATUS_INDICATOR: String = "uid://noni74g8ie6"
const FINALIZE_TEST_WINDOW: String = "uid://bb85tfua2qjj3"
const TEST_REPORT_WINDOW: String = "uid://obeiwemye4e8"
var OVERVIEW_WINDOW: String = "uid://b736y3igeimkq"

var sandbox: Sandbox
var test_manager: TestManager

var recorder: InputRecorder
var player: InputPlayer

var is_recording: bool = false
var is_playing: bool = false

var snapshotter: Snapshotter
var snapshot_loader: SnapshotLoader

var _is_test_run: bool = false
var node_map: Dictionary
var selected_test_case: TestCase

var seed: int
var snapshot_a: Snapshot
var snapshot_b: Snapshot

var input_recording: InputRecording

var status_indicator_layer: CanvasLayer
var status_ui_instance: Control

var overview_window: OverviewWindow
var finalize_test_window: FinalizeTestWindow
var test_report_window: TestReportWindow

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	sandbox = Sandbox.new()
	test_manager = TestManager.new()
	recorder = InputRecorder.new()
	player = InputPlayer.new()
	snapshotter = Snapshotter.new()
	snapshot_loader = SnapshotLoader.new()
	
	_spawn_status_indicator()
	
	add_child(sandbox)
	add_child(recorder)
	add_child(player)
	add_child(snapshotter)
	add_child(snapshot_loader)
	add_child(status_indicator_layer)
	
	if !player.is_connected("playback_finished", _on_playback_finished):
		player.playback_finished.connect(_on_playback_finished)
	
	_parse_cmd_args()
	
	sandbox.scene_sandboxed.connect(_on_initial_scene_sandboxed)
	call_deferred("_init_sandbox")

func _parse_cmd_args():
	var args = OS.get_cmdline_user_args()
	
	for i in args.size():
		if args[i] == "--test-case" and i + 1 < args.size():
			var folder_path = args[i + 1]
			selected_test_case = test_manager.get_test_case(folder_path)
			_is_test_run = true
			break

func _init_sandbox():
	sandbox.setup()
	sandbox._on_scene_changed()

func _on_initial_scene_sandboxed():
	if sandbox.scene_sandboxed.is_connected(_on_initial_scene_sandboxed):
		sandbox.scene_sandboxed.disconnect(_on_initial_scene_sandboxed)
	
	if _is_test_run:
		call_deferred("_run_test", selected_test_case)

func _input(event: InputEvent) -> void:
	if is_playing:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and event.ctrl_pressed:
			get_viewport().set_input_as_handled()
			
			if is_recording: _stop_recording()
			else: _spawn_overview_window()
			
			return
	
	if sandbox and event is InputEventMouse:
		sandbox.forward_mouse_event(event)

func _spawn_overview_window():
	pause()
	
	overview_window = load(OVERVIEW_WINDOW).instantiate()
	add_child(overview_window)
	overview_window.popup_centered()
			
	overview_window.set_tests(test_manager.get_tests())
			
	overview_window.close_requested.connect(_on_overview_window_close_requested)
	overview_window.run_test.connect(_on_run_test)
	overview_window.delete_test.connect(_on_delete_test)
	overview_window.start_recording.connect(_on_start_recording)
	overview_window.reload_tests.connect(_on_reload_tests)

func _close_overview_window():
	overview_window.hide()
	overview_window.queue_free()
	overview_window = null

func _on_overview_window_close_requested():
	_close_overview_window()	
	unpause()

func _on_run_test(test: TestCase):
	_close_overview_window()
	_run_test(test)

func _on_delete_test(test: TestCase):
	test_manager.delete(test)
	overview_window.set_tests(test_manager.get_tests())

func _on_start_recording():
	_close_overview_window()
	unpause()
	_start_recording()

func _on_reload_tests():
	overview_window.set_tests(test_manager.get_tests())

func _stop_recording():
	if not is_recording or is_playing:
		return
	
	if status_ui_instance:
		status_ui_instance.hide_all()
			
	pause()
		
	recorder.stop_recording()
	
	input_recording = recorder.get_recording()
	
	is_recording = false
		
	snapshot_b = snapshotter.snapshot(sandbox.current_scene)
		
	var comparison = SnapshotComparator.compare(snapshot_a, snapshot_b)
	_spawn_finalize_test_window(comparison)	

func _spawn_finalize_test_window(comparison: SnapshotComparator.SnapshotComparison):
	finalize_test_window = load(FINALIZE_TEST_WINDOW).instantiate()
	finalize_test_window.create_test.connect(_on_create_test)
	finalize_test_window.cancel_test.connect(_on_cancel_test)
	add_child(finalize_test_window)
	finalize_test_window.popup_centered()
	finalize_test_window.display(comparison)

func _close_finalize_test_window():
	finalize_test_window.hide()
	finalize_test_window.queue_free()
	finalize_test_window = null

func _on_create_test(name: String, assertions: Array):
	_close_finalize_test_window()	
	
	test_manager.add_test(name, seed, snapshot_a, snapshot_b, input_recording, assertions)
	print(">>> Test saved to disk.")
	unpause()

func _on_cancel_test():
	finalize_test_window.hide()
	finalize_test_window.queue_free()
	finalize_test_window = null
	
	snapshot_a = null
	snapshot_b = null
	input_recording = null
	
	print(">>> Test canceled.")
	
	unpause()

func _start_recording():
	if is_playing: return
		
	is_recording = true
		
	if status_ui_instance:
		status_ui_instance.show_recording()
		
	pause()
		
	seed = randi()
	seed(seed)
	await get_tree().process_frame
		
	snapshot_a = snapshotter.snapshot(sandbox.current_scene)
		
	unpause()
		
	recorder.start_recording()
	print(">>> Recording Started...")

func _run_test(test_case: TestCase):
	if is_playing or is_recording: return
	selected_test_case = test_case
	
	test_case = test_case
	
	pause()
	
	var snapshot: Snapshot = test_case.get_snapshot_a()
	if not snapshot:
		push_error("Snapshot not found!")
		unpause()
		return
		
	var tree = get_tree()
	var root = tree.root
	
	seed(test_case.seed)
	
	await tree.process_frame
	
	var restored_scene = snapshot_loader.load_snapshot(snapshot)
	
	root.add_child(restored_scene)
	tree.current_scene = restored_scene
	sandbox.sandbox(restored_scene)
	
	snapshot_loader.restore_properties()
	
	node_map = snapshot_loader.get_node_map()
	
	snapshot_a = snapshotter.snapshot(sandbox.current_scene)
	
	is_playing = true
	
	if status_ui_instance:
		status_ui_instance.show_playback()
		
	var recording: InputRecording = test_case.get_input_recording()
	if not recording:
		push_error("Input recording not found!")
		unpause()
		return

	player.play(recording, sandbox)
	print(">>> Playback Started...")
	
	unpause()

func _stop_playback_manual():
	player.stop()
	_on_playback_finished()

func _on_playback_finished():
	is_playing = false
	
	if status_ui_instance:
		status_ui_instance.hide_all() 
		
	print(">>> Playback finished")
	pause()
	
	snapshot_b = snapshotter.snapshot(sandbox.current_scene)
	var diff = SnapshotComparator.compare(snapshot_a, snapshot_b)
	
	var original_snapshot_b: Snapshot = selected_test_case.get_snapshot_b()
	var assertions = selected_test_case.get_assertions()
	
	var id_map := SnapshotComparator.map_ids(original_snapshot_b, snapshot_b)
	for old_id in node_map:
		if not old_id in id_map:
			id_map[old_id] = node_map[old_id]
	
	var report: TestReport = TestValidator.validate(assertions, id_map, diff)
	
	selected_test_case.save_run_result(report)
	
	if _is_test_run:
		print(">>> Test Run Complete. Exiting.") 
		get_tree().quit(0)
	else:
		_spawn_test_report_window(report)

func _spawn_test_report_window(report: TestReport):
	test_report_window = load(TEST_REPORT_WINDOW).instantiate()
	test_report_window.tree_exited.connect(unpause)
	add_child(test_report_window)
	test_report_window.popup_centered()
	test_report_window.display_report(report)
		
func _spawn_status_indicator() -> void:
	status_indicator_layer = CanvasLayer.new()
	status_indicator_layer.visible = true
	status_ui_instance = load(STATUS_INDICATOR).instantiate()
	status_indicator_layer.add_child(status_ui_instance)

func pause():
	var tree := get_tree()
	if tree:
		tree.paused = true

func unpause():
	var tree := get_tree()
	if tree:
		tree.paused = false
