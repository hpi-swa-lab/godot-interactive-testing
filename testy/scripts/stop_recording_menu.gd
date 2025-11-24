extends Window

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
var progress := 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	progress_bar.value = 0
	set_process(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	progress = min (progress + delta * 20, 100)
	progress_bar.value = progress
