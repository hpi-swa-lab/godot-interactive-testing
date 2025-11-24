# addons/testy/input_recorder.gd
# This Autoload runs in the game process and handles its own UI pop-up.

@tool
extends Node

# Signal for runtime persistence completion
signal recording_finished()
# Signal for real-time UI state updates
signal state_changed(is_recording: bool)

var is_recording: bool = false
var recorded_events: Array = []
var state_inspector_window: Window = null 
var stop_recording_window: Window = null
const TEST_DIR = "res://tests/" 

# --- Core Game Loop Input Capture / Recording Logic (Unchanged) ---

func _ready():
	add_to_group("state_inspector")
	if not Engine.is_editor_hint():
		set_process_input(true)
		print("Input Recorder initialized in Game Runtime. Ctrl+R toggles recording.")

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

	if is_recording:
		var event_data = {
			"type": event.get_class(),
			"data": event.to_string()
		}
		recorded_events.append(event_data)
		
# --- Persistence Method (Unchanged) ---

func _save_event_recording(events: Array):
	# (File saving logic remains here, unchanged)
	var dir = DirAccess.open("res://")
	if dir and not dir.dir_exists("tests/"):
		var error = dir.make_dir("tests/")
		if error != OK:
			print("ERROR: Could not create tests directory: %s" % error)
			return

	var timestamp = Time.get_unix_time_from_system()
	var file_path = TEST_DIR + "recording_" + str(timestamp).split(".")[0] + ".json"

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(events, "\t")
		file.store_string(json_string)
		file.close()
		print("RUNTIME PERSISTENCE: Recording saved successfully to: %s" % file_path)
	else:
		print("ERROR: Could not open file for saving: %s" % file_path)

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
	
func _show_stop_recording_menu():
	var scene := load("res://addons/testy/scenes/stop_recording_menu.tscn")
	stop_recording_window = scene.instantiate()
	stop_recording_window.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(stop_recording_window)
	stop_recording_window.popup_centered()
	
func _close_stop_recording_menu():
	if stop_recording_window:
		stop_recording_window.queue_free()
		stop_recording_window = null
		
func _save_recording_async():
	await get_tree().create_timer(0.1).timeout
	_save_event_recording(recorded_events)
	
	
func _on_start_recording_from_window(nodes: Array):
	print("Start recording with nodes ", nodes)
	
	# TODO
	
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
	
	_show_stop_recording_menu()
	
	await get_tree().process_frame
	await _save_recording_async()
	
	_close_stop_recording_menu()
	
	# _save_event_recording(recorded_events)
	
	recording_finished.emit()
	state_changed.emit(is_recording)

func unpause_game():
	get_tree().set_pause(false)
	print("Game unpaused by Runtime logic.")
