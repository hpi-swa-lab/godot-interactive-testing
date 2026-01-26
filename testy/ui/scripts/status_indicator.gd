extends MarginContainer

@onready var recording_label: Label = $RecordingIndicator
@onready var playback_label: Label = $PlaybackIndicator

var _blink_tween: Tween

func _ready() -> void:
	hide_all()

func show_recording() -> void:
	visible = true
	
	recording_label.visible = true
	playback_label.visible = false
	
	modulate = Color(1, 0, 0) 
	
	_start_blinking()

func show_playback() -> void:
	visible = true
	
	recording_label.visible = false
	playback_label.visible = true
	
	modulate = Color(0, 1, 0) 
	

func hide_all() -> void:
	visible = false
	_stop_blinking()

func _start_blinking() -> void:
	if _blink_tween: _blink_tween.kill()
	
	_blink_tween = create_tween().set_loops()
	_blink_tween.set_trans(Tween.TRANS_SINE)
	_blink_tween.set_ease(Tween.EASE_IN_OUT)
	
	_blink_tween.tween_property(self, "modulate:a", 0.3, 1.0)
	_blink_tween.tween_property(self, "modulate:a", 1.0, 1.0)

func _stop_blinking() -> void:
	if _blink_tween: _blink_tween.kill()
	modulate.a = 1.0
