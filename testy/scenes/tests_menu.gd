extends Window

const TEST_DIR := "res://tests/"

signal test_selected(test_name: String)

@onready var option_button: OptionButton = $VBoxContainer/OptionButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_populate_option_button()
	option_button.item_selected.connect(_on_option_selected)


func _populate_option_button() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		push_error("Can not open %s" % TEST_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			option_button.add_item(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()


func _on_option_selected(index: int) -> void:
	var name := option_button.get_item_text(index)
	emit_signal("test_selected", name)
	print("Test SELECTED:", name)
	
	self.hide()
	queue_free()
