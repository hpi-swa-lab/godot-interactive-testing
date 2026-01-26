class_name InputRecorder2
extends Node

var is_recording: bool = false
var current_tick: int = 0
var current_recording: InputRecording2

func _ready() -> void:
	self.set_meta("testy_ignore", true)
	set_physics_process(false)

func start_recording() -> void:
	current_recording = InputRecording2.new()
	current_tick = 0
	is_recording = true
	set_physics_process(true)

func stop_recording() -> void:
	is_recording = false
	set_physics_process(false)
	current_recording.duration = current_tick

func _physics_process(_delta: float) -> void:
	if is_recording:
		current_tick += 1

func _input(event: InputEvent) -> void:
	if is_recording:
		current_recording.add_event(current_tick, event.duplicate())

func get_recording() -> InputRecording2:
	return current_recording
