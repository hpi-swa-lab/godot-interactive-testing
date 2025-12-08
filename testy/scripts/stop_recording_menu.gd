extends Window

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var label_added: Label = $VBoxContainer/Label_Added
@onready var label_removed: Label = $VBoxContainer/Label_Removed
@onready var label_changed: Label = $VBoxContainer/Label_Changed

@onready var item_list_added: ItemList = $VBoxContainer/HBoxContainer/VBoxContainer/AddedNodes/ItemListAdded
@onready var item_list_removed: ItemList = $VBoxContainer/HBoxContainer/VBoxContainer2/RemovedNodes/ItemListRemoved
@onready var item_list_changed: ItemList = $VBoxContainer/ChangedNodes/ItemListChanged
@onready var props_changes: Label = $VBoxContainer/ChangedNodes/ScrollContainer/PropsChanges


var diff_data: Dictionary = {}

func _ready() -> void:
	item_list_changed.item_clicked.connect(_on_item_selected_changed)
	
func set_diff(diff: Dictionary) -> void:
	diff_data = diff
	_update_diff_ui()
	
func _update_diff_ui():
	for node_name in diff_data.get("added_nodes", {}).keys():
		item_list_added.add_item(node_name)

	for node_name in diff_data.get("removed_nodes", {}).keys():
		item_list_removed.add_item(node_name)

	var changed_lines := []
	for node_name in diff_data.get("changed_nodes", {}).keys():
		
		item_list_changed.add_item(node_name)
		
		changed_lines.append(node_name + ":")
		var props = diff_data["changed_nodes"][node_name]
		for key in props.keys():
			var old_val = str(props[key]["old"])
			if old_val.length() > 30:
				old_val = old_val.substr(0, 30) + "..."
			var new_val = str(props[key]["new"])
			if new_val.length() > 30:
				new_val = new_val.substr(0, 30) + "..."
			changed_lines.append("    %s: %s -> %s" % [key, old_val, new_val])

func _on_item_selected_changed(index: int, at_position: Vector2, mouse_button_index: int):
	var node_name = item_list_changed.get_item_text(index)
	
	var props = diff_data["changed_nodes"][node_name]
	var prop_lines: Array = []
	for key in props.keys():
		var old_val = str(props[key]["old"])
		if old_val.length() > 30:
			old_val = old_val.substr(0, 30) + "..."
		var new_val = str(props[key]["new"])
		if new_val.length() > 30:
			new_val = new_val.substr(0, 30) + "..."
		prop_lines.append("%s: %s -> %s" % [key, old_val, new_val])
	props_changes.text = "\n".join(prop_lines)
