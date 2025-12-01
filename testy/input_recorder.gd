# addons/testy/input_recorder.gd
# This Autoload runs in the game process and handles its own UI pop-up.

@tool
extends Node

var is_restoring = false

# Signal for runtime persistence completion
signal recording_finished()
# Signal for real-time UI state updates
signal state_changed(is_recording: bool)

var is_recording: bool = false
var recorded_events: Array = []
var state_inspector_window: Window = null 
var stop_recording_window: Window = null
var tests_inspector_window: Window = null
const TEST_DIR = "res://tests/" 

# --- NEW: Save Game Constants ---
const SAVE_DIR = "user://saves/"
const SAVE_FILE_NAME = "savegame.bin"
# ------------------------------

var serializer = Serializier.new()
var deserializer = Deserializer.new()
var compare_snapshots = load("res://addons/testy/snapshots/compare_snapshots.gd").new()

var current_test_dir: String = ""
var current_timestamp := ""

# --- Core Game Loop Input Capture / Recording Logic (Unchanged) ---

func _ready():
	add_to_group("state_inspector")
	if not Engine.is_editor_hint():
		set_process_input(true)
		print("Input Recorder initialized. Ctrl+R toggles recording. Ctrl+S to save. Ctrl+O to load.")
		
		# Ensure the save directory exists
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _input(event: InputEvent):
	if not Engine.is_editor_hint():
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.ctrl_pressed and event.keycode == KEY_R:
				get_viewport().set_input_as_handled()
				if is_recording:
					stop_recording()
				else:
					# start_recording()
					_create_state_inspector()
				return
				
			# --- UPDATED: CTRL+S ---
			if event.ctrl_pressed and event.keycode == KEY_S:
				get_viewport().set_input_as_handled()
				save_game_state()
				return

			# --- NEW: CTRL+O ---
			if event.ctrl_pressed and event.keycode == KEY_O:
				get_viewport().set_input_as_handled()
				load_game_state("")
				return
				
			if event.ctrl_pressed and event.keycode == KEY_T:
				get_viewport().set_input_as_handled()
				_create_tests_inspector()
				#_play_last_test_recording()
				return

	if is_recording:
		var event_data = {
			"type": event.get_class(),
			"data": event.to_string()
		}
		recorded_events.append(event_data)
		
# --- Save/Load Functions ---

func save_game_state(name = "tmp"):
	if is_restoring:
		print("Cannot save while restoring.")
		return

	print("Saving game state...")
	var current_scene = get_tree().get_current_scene()
	if not current_scene:
		push_error("Cannot save: No current scene.")
		return
		
	var serialized: PackedByteArray = serializer.serialize(current_scene)
	
	var save_path: String
	if current_test_dir != "":
		save_path = current_test_dir.path_join(name + ".bin")
	else:
		save_path = SAVE_DIR.path_join(SAVE_FILE_NAME)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_buffer(serialized)
		file.close()
		print("Game state saved successfully to: %s" % save_path)
	else:
		push_error("Failed to open save file for writing at: %s" % save_path)

func load_game_state(save_path: String):
	if is_recording:
		print("Cannot load while recording.")
		return
	
	if not FileAccess.file_exists(save_path):
		push_error("Cannot load: Save file not found at: %s" % save_path)
		return
		
	print("Loading game state from: %s" % save_path)
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to open save file for reading.")
		return
		
	var serialized: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	if serialized.is_empty():
		push_error("Cannot load: Save file is empty.")
		return

	var current_scene = get_tree().get_current_scene()
	var index = current_scene.get_index()
	var parent = current_scene.get_parent()
	parent.remove_child(current_scene)

	get_tree().set_pause(true)
	self.is_restoring = true

	var restored_scene: Node = deserializer.restore(serialized)
	
	if not restored_scene:
		push_error("CRITICAL: Deserialization failed. Restoring original scene.")
		parent.add_child(current_scene)
		parent.move_child(current_scene, index)
		self.is_restoring = false
		get_tree().set_pause(false)
		return

	parent.add_child(restored_scene)
	parent.move_child(restored_scene, index)

	current_scene.queue_free()
	get_tree().current_scene = restored_scene

	# --- AND UNPAUSE ---
	self.is_restoring = false
	get_tree().set_pause(false) # Re-enable processing for the now-restored tree
	print("Game state loaded successfully.")

func _save_event_recording(events: Array):
	if current_test_dir == "":
		push_error("Cannot save recording: No test directory set.")
		return

	var file_path = current_test_dir.path_join("recording.json")


	var timestamp = Time.get_unix_time_from_system()
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(events, "\t")
		file.store_string(json_string)
		file.close()
		print("RUNTIME PERSISTENCE: Recording saved successfully to: %s" % file_path)
	else:
		print("ERROR: Could not open file for saving: %s" % file_path)
		
func _play_recording(dir_name: String):
	var dir = DirAccess.open(TEST_DIR)
	if not dir:
		push_error("Cannot open TEST_DIR: %s" % TEST_DIR)
		return

	var test_path = TEST_DIR + dir_name + "/"
	print("Playing test recording from: %s" % test_path)
	current_test_dir = test_path

	var save_file_path = current_test_dir.path_join("savegame-A.bin")
	if not FileAccess.file_exists(save_file_path):
		push_error("Start save not found: %s" % save_file_path)
		return

	print("Loading start savegame...")
	await load_game_state(save_file_path)
	await save_game_state("test-A")

	var rec_path = current_test_dir.path_join("recording.json")
	if not FileAccess.file_exists(rec_path):
		push_error("Recording file not found: %s" % rec_path)
		return

	var rec_file = FileAccess.open(rec_path, FileAccess.READ)
	var json_data = rec_file.get_as_text()
	rec_file.close()

	var events = JSON.parse_string(json_data)
	if events == null:
		push_error("Failed to parse recording JSON")
		return

	print("Replaying %d events..." % events.size())

	await _replay_events(events)
	
	await save_game_state("test-B")
	
	if current_test_dir != "":
		var start_path = current_test_dir.path_join("savegame-A.bin")
		var end_path = current_test_dir.path_join("savegame-B.bin")
		var savegame_result = compare_snapshots.show_diff(start_path, end_path)
		
		var test_A_path = current_test_dir.path_join("test-A.bin")
		var test_B_path = current_test_dir.path_join("test-B.bin")
		var test_result = compare_snapshots.show_diff(test_A_path, test_B_path)
		save_diff(test_result, "test")
		
		var result = compare_snapshots.diff_diff(savegame_result, test_result)
		
		_show_stop_recording_menu(result)
	
func _replay_events(events: Array) -> void:
	for e in events:
		if e["type"] == "InputEventMouseButton":
			var pos = e["data"].split("position=((")[1].split("))")[0].split(",")
			print(pos)
			if pos:
				var x = float(pos[0])
				var y = float(pos[1])
				get_viewport().warp_mouse(Vector2(x, y))
			var a = InputEventMouseButton.new()
			a.set_button_index(MOUSE_BUTTON_LEFT)
			a.button_mask = MOUSE_BUTTON_MASK_LEFT
			a.set_pressed(e["data"].find("pressed=true") != -1)
			print(a)
			Input.parse_input_event(a)
			await get_tree().create_timer(1).timeout

# --- UI Creation and Management (FIX: PROCESS_MODE_ALWAYS) ---

func _create_state_inspector():
	if state_inspector_window:
		return
		
	get_tree().set_pause(true)
		
	var scene := load("res://addons/testy/scenes/selection_menu.tscn")
	
	state_inspector_window = scene.instantiate()
	state_inspector_window.add_to_group("state_inspector")
	state_inspector_window.process_mode = Node.PROCESS_MODE_ALWAYS
	state_inspector_window.close_requested.connect(_on_state_inspector_closed)
	
	state_inspector_window.start_recording_with_nodes.connect(_on_start_recording_from_window)

	get_tree().root.add_child(state_inspector_window)
	state_inspector_window.popup_centered()
	return
	
func _on_state_inspector_closed():
	if state_inspector_window:
		state_inspector_window.queue_free()
		state_inspector_window = null
	unpause_game()
	
func _create_tests_inspector():
	if tests_inspector_window:
		return
		
	get_tree().set_pause(true)
		
	var scene := load("res://addons/testy/scenes/tests_menu.tscn")
	
	tests_inspector_window = scene.instantiate()
	tests_inspector_window.add_to_group("state_inspector")
	tests_inspector_window.process_mode = Node.PROCESS_MODE_ALWAYS
	tests_inspector_window.close_requested.connect(_on_tests_inspector_closed)
	
	tests_inspector_window.test_selected.connect(_play_recording)

	get_tree().root.add_child(tests_inspector_window)
	tests_inspector_window.popup_centered()
	return

func _on_tests_inspector_closed():
	if tests_inspector_window:
		tests_inspector_window.queue_free()
		tests_inspector_window = null
	unpause_game()
	
func _show_stop_recording_menu(diff: Dictionary):
	var scene := load("res://addons/testy/scenes/stop_recording_menu.tscn")
	stop_recording_window = scene.instantiate()
	stop_recording_window.process_mode = Node.PROCESS_MODE_ALWAYS
	
	stop_recording_window.close_requested.connect(_close_stop_recording_menu)
	
	get_tree().root.add_child(stop_recording_window)
	stop_recording_window.popup_centered()
	stop_recording_window.call_deferred("set_diff", diff)
	
func _close_stop_recording_menu():
	if stop_recording_window:
		stop_recording_window.queue_free()
		stop_recording_window = null
		
func _save_recording_async():
	await get_tree().create_timer(0.1).timeout
	_save_event_recording(recorded_events)
	
	
func _on_start_recording_from_window(nodes: Array):
	current_timestamp = str(Time.get_datetime_string_from_system().replace(":", "").replace("T", "_"))
	current_test_dir = TEST_DIR + "test_" + current_timestamp + "/"
	DirAccess.make_dir_recursive_absolute(current_test_dir)
	
	save_game_state("savegame-A")
	start_recording()

# --- Public API for Recording and Persistence ---

func start_recording():
	is_recording = true
	recorded_events.clear()
	print("Recording started.")
	
	unpause_game()
	
	state_changed.emit(is_recording)

func stop_recording():
	is_recording = false
	print("Recording stopped. Events recorded: %d" % recorded_events.size())
	
	save_game_state("savegame-B")
	
	if current_test_dir != "":
		var start_path = current_test_dir.path_join("savegame-A.bin")
		var end_path = current_test_dir.path_join("savegame-B.bin")
		var result = compare_snapshots.show_diff(start_path, end_path)
		save_diff(result)
		_show_stop_recording_menu(result)
	else:
		_show_stop_recording_menu({})
	
	await get_tree().process_frame
	await _save_recording_async()
	
	# _close_stop_recording_menu()
	
	# _save_event_recording(recorded_events)
	
	recording_finished.emit()
	state_changed.emit(is_recording)
	
func save_diff(diff: Dictionary, suffix = ""):
	var save_path: String
	if current_test_dir != "":
		save_path = current_test_dir.path_join("diff" + suffix + ".json")
	else:
		save_path = SAVE_DIR.path_join(SAVE_FILE_NAME)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(diff, "\t")
		file.store_string(json_string)
		file.close()
	else:
		push_error("Failed to open save file for writing at: %s" % save_path)
	

func unpause_game():
	get_tree().set_pause(false)
	print("Game unpaused by Runtime logic.")
