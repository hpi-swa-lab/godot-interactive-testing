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
					start_recording()
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
		
	var scene := load("res://addons/testy/scenes/selection_menu.tscn")
	
	state_inspector_window = scene.instantiate()
	state_inspector_window.add_to_group("state_inspector")
	state_inspector_window.process_mode = Node.PROCESS_MODE_ALWAYS
	state_inspector_window.close_requested.connect(_on_state_inspector_closed)

	get_tree().root.add_child(state_inspector_window)
	state_inspector_window.popup_centered()
	return

func _on_state_inspector_closed():
	if state_inspector_window:
		state_inspector_window.queue_free()
		state_inspector_window = null
	unpause_game()

# --- Public API for Recording and Persistence ---

func start_recording():
	is_recording = true
	recorded_events.clear()
	print("Recording started.")
	
	get_tree().set_pause(true)
	_create_state_inspector()
	
	state_changed.emit(is_recording)

func stop_recording():
	is_recording = false
	print("Recording stopped. Events recorded: %d" % recorded_events.size())
	
	_save_event_recording(recorded_events)
	
	recording_finished.emit()
	state_changed.emit(is_recording)

func unpause_game():
	get_tree().set_pause(false)
	print("Game unpaused by Runtime logic.")
