class_name InspectorRow
extends PanelContainer

@onready var toggle_button: Button = %ToggleButton
@onready var prop_name: Label = %PropName
@onready var prop_value: Label = %PropValue
@onready var checkbox: CheckBox = %Checkbox
@onready var detail: MarginContainer = %Details
@onready var old_value: LineEdit = %OldValue
@onready var new_value: LineEdit = %NewValue

var _full_val_text: String = ""
var _key_name: String = ""

func _ready() -> void:
	detail.visible = false
	toggle_button.focus_mode = Control.FOCUS_NONE
	
	if not toggle_button.pressed.is_connected(_on_toggle_button_pressed):
		toggle_button.pressed.connect(_on_toggle_button_pressed)

func setup(key: String, val: Variant, is_checked: bool, on_toggled: Callable, is_selectable: bool = true):
	_key_name = key
	prop_name.text = key
	
	checkbox.visible = true
	checkbox.button_pressed = is_checked
	
	if checkbox.toggled.is_connected(on_toggled):
		checkbox.toggled.disconnect(on_toggled)
		
	if is_selectable:
		checkbox.modulate = Color.WHITE
		checkbox.disabled = false
		checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
		checkbox.toggled.connect(on_toggled)
	else:
		checkbox.modulate = Color(0, 0, 0, 0)
		checkbox.disabled = true
		checkbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var display_str = ""
	var old_str = ""
	var new_str = ""
	var is_modified = false
	
	if val is SnapshotComparator.PropertyDelta:
		old_str = str(val.old_value)
		new_str = str(val.new_value)
		display_str = new_str
		is_modified = true
		
		prop_value.modulate = Color.ORANGE
		prop_name.modulate = Color.ORANGE
		
		toggle_button.disabled = false
		toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
		toggle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		display_str = str(val)
		new_str = display_str
		
		prop_value.modulate = Color(1, 1, 1, 0.6)
		prop_name.modulate = Color(1, 1, 1, 0.6)
		
		toggle_button.disabled = true
		toggle_button.mouse_filter = Control.MOUSE_FILTER_PASS
		toggle_button.mouse_default_cursor_shape = Control.CURSOR_ARROW

	prop_value.text = display_str
	old_value.text = old_str
	new_value.text = new_str
	
	if is_modified:
		old_value.modulate = Color(1, 0.6, 0.6)
		new_value.modulate = Color(0.6, 1, 0.6)
	else:
		old_value.modulate = Color.WHITE
		new_value.modulate = Color.WHITE

	_full_val_text = display_str
	var tooltip_str = "%s: %s" % [key, display_str]
	prop_name.tooltip_text = tooltip_str
	prop_value.tooltip_text = tooltip_str
	toggle_button.tooltip_text = tooltip_str
	old_value.tooltip_text = old_str
	new_value.tooltip_text = new_str

func _on_toggle_button_pressed() -> void:
	detail.visible = not detail.visible

func matches_search(query: String) -> bool:
	if query.is_empty(): return true
	var q = query.to_lower()
	return q in _key_name.to_lower() or q in _full_val_text.to_lower()
