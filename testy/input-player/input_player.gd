class_name InputPlayer2
extends Node

signal playback_started
signal playback_finished

var is_playing: bool = false
var current_tick: int = 0
var active_recording: InputRecording2
var sandbox: Sandbox

func _ready() -> void:
	self.set_meta("testy_ignore", true)
	set_physics_process(false)

func play(recording: InputRecording2, active_sandbox: Sandbox) -> void:
	if not recording: return
	active_recording = recording
	sandbox = active_sandbox
	current_tick = 0
	is_playing = true
	set_physics_process(true)
	playback_started.emit()
	

func _stop() -> void:
	if not is_playing: return
	is_playing = false
	set_physics_process(false)
	playback_finished.emit()

func _physics_process(_delta: float) -> void:
	if not is_playing: return
	current_tick += 1
	
	var events = active_recording.get_events_at(current_tick)
	for event in events:
		if event is InputEventMouse:
			sandbox.forward_mouse_event(event)
		else:
			Input.parse_input_event(event)
		
	if current_tick > active_recording.duration:
		_stop()
