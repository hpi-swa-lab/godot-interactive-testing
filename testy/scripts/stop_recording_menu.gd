extends Window

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var label_added: Label = $VBoxContainer/Label_Added
@onready var label_removed: Label = $VBoxContainer/Label_Removed
@onready var label_changed: Label = $VBoxContainer/Label_Changed


var diff_data: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
func set_diff(diff: Dictionary) -> void:
	diff_data = diff
	_update_diff_ui()
	
func _update_diff_ui():
	if not (label_added and label_removed and label_changed):
		return

	var added_lines := []
	for node_name in diff_data.get("added_nodes", {}).keys():
		added_lines.append(node_name)
		label_added.text = "Added Nodes:\n" + "\n".join(added_lines)

	var removed_lines := []
	for node_name in diff_data.get("removed_nodes", {}).keys():
		removed_lines.append(node_name)
		label_removed.text = "Removed Nodes:\n" + "\n".join(removed_lines)

	var changed_lines := []
	for node_name in diff_data.get("changed_nodes", {}).keys():
		changed_lines.append(node_name + ":")
		var props = diff_data["changed_nodes"][node_name]
		for key in props.keys():
			var old_val = str(props[key]["old"])
			if old_val.length() > 50:
				old_val = old_val.substr(0, 50) + "..."
			var new_val = str(props[key]["new"])
			if new_val.length() > 50:
				new_val = new_val.substr(0, 50) + "..."
			changed_lines.append("    %s: %s -> %s" % [key, old_val, new_val])
		label_changed.text = "Changed Nodes:\n" + "\n".join(changed_lines)
