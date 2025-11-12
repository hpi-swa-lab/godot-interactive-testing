@tool
extends EditorPlugin

var panel: Control = null
var status_label: Label = null
const KEY_R = 75 # Restore the KEY_R constant for clarity if needed, though Godot's built-in is fine

var INPUT_RECORDER_NODE_NAME = "InputRecorder"
var INPUT_RECORDER_PATH = "res://addons/testy/input_recorder.gd"
var INPUT_RECORDER: Node = null

func _add_input_recorder():
	add_autoload_singleton(INPUT_RECORDER_NODE_NAME, INPUT_RECORDER_PATH)

func _remove_input_recorder():
	remove_autoload_singleton(INPUT_RECORDER_NODE_NAME)

func _enable_plugin() -> void:
	pass


func _disable_plugin() -> void:
	pass
	
func _process(delta: float) -> void:
	_update_status()
	
func _update_status():
	var playing: bool = EditorInterface.is_playing_scene()
	if playing:
		status_label.text = "Game is currently running!"
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "Game is not running!"
		status_label.modulate = Color.WHITE

func _enter_tree() -> void:
	panel = Control.new()
	panel.name = "TestyPanel"
	panel.custom_minimum_size = Vector2(0, 300)
	
	var v_box := VBoxContainer.new()
	v_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(v_box)
	
	var header_label = Label.new()
	header_label.text = "INTEGRATION TESTER"
	header_label.theme_type_variation = "HeaderSmall"
	v_box.add_child(header_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.size_flags_horizontal = Control.SIZE_EXPAND
	status_label.size_flags_vertical = Control.SIZE_EXPAND
	v_box.add_child(status_label)
	
	add_control_to_bottom_panel(panel, "Testy Panel")
	
	_add_input_recorder()


func _exit_tree() -> void:
	if panel:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
	
	_remove_input_recorder()	
