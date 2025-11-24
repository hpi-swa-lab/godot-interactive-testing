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
const TEST_DIR = "res://tests/" 

# --- NEW: Save Game Constants ---
const SAVE_DIR = "user://saves/"
const SAVE_FILE_NAME = "savegame.bin"
# ------------------------------

var serializer = Serializier.new()
var deserializer = Deserializer.new()

# --- Core Game Loop Input Capture / Recording Logic (Unchanged) ---

func _ready():
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
					start_recording()
				return
				
			# --- UPDATED: CTRL+S ---
			if event.ctrl_pressed and event.keycode == KEY_S:
				get_viewport().set_input_as_handled()
				save_game_state()
				return

			# --- NEW: CTRL+O ---
			if event.ctrl_pressed and event.keycode == KEY_O:
				get_viewport().set_input_as_handled()
				load_game_state()
				return

	if is_recording:
		var event_data = {
			"type": event.get_class(),
			"data": event.to_string()
		}
		recorded_events.append(event_data)
		
# --- NEW: Save/Load Functions ---

func save_game_state():
	if is_restoring:
		print("Cannot save while restoring.")
		return

	print("Saving game state...")
	var current_scene = get_tree().get_current_scene()
	if not current_scene:
		push_error("Cannot save: No current scene.")
		return
		
	var serialized: PackedByteArray = serializer.serialize(current_scene)
	
	var save_path = SAVE_DIR.path_join(SAVE_FILE_NAME)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_buffer(serialized)
		file.close()
		print("Game state saved successfully to: %s" % save_path)
	else:
		push_error("Failed to open save file for writing at: %s" % save_path)

func load_game_state():
	if is_recording:
		print("Cannot load while recording.")
		return
		
	var save_path = SAVE_DIR.path_join(SAVE_FILE_NAME)
	
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

	# --- This is your restore logic from before ---
	var current_scene = get_tree().get_current_scene()
	var index = current_scene.get_index()
	var parent = current_scene.get_parent()
	parent.remove_child(current_scene)

	# --- HERE IS THE PAUSE ---
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

	state_inspector_window = Window.new()
	
	# FIX IS HERE: Force this control to process input/updates even when paused.
	state_inspector_window.process_mode = Node.PROCESS_MODE_ALWAYS
	
	state_inspector_window.title = "Runtime State Inspector (Paused)"
	state_inspector_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	state_inspector_window.size = Vector2(800, 600)
	state_inspector_window.min_size = Vector2(400, 300)
	
	state_inspector_window.close_requested.connect(_on_state_inspector_closed)
	
	var v_box = VBoxContainer.new()
	v_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	v_box.add_theme_constant_override("separation", 10) 
	state_inspector_window.add_child(v_box)
	
	var info_label = Label.new()
	info_label.text = "Select nodes to decide which properties to save at the start state."
	v_box.add_child(info_label)
	
	var tree = Tree.new()
	# Ensure Tree fills the space and has scrollbars if content overflows
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	tree.allow_reselect = true
	v_box.add_child(tree)
	
	var root_node = get_tree().get_root()
	if root_node:
		_populate_node_tree(root_node, tree)
	
	get_tree().get_root().add_child(state_inspector_window)
	state_inspector_window.popup_centered()

func _populate_node_tree(current_node: Node, tree_control: Tree, parent_item: TreeItem = null):
	var item: TreeItem
	if parent_item == null:
		item = tree_control.create_item()
		tree_control.set_hide_root(true)
	else:
		item = tree_control.create_item(parent_item)
	
	tree_control.set_columns(1)
	item.set_text(0, "[%s] %s" % [current_node.get_class(), current_node.name])
	item.set_meta("node_path", current_node.get_path())

	for child in current_node.get_children():
		# Skip the state inspector window and the Autoload itself
		if child == state_inspector_window or child.name == name:
			continue
			
		# This print(prop) is very spammy, you may want to remove it
		# for prop in child.get_property_list():
		# 	print(prop)
		_populate_node_tree(child, tree_control, item)

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
