extends Node

func load_serialized_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	var bytes = file.get_buffer(file.get_length())
	var dict = bytes_to_var(bytes)
	return dict
	
func diff_serialized(a: Dictionary, b: Dictionary) -> Dictionary:
	return _extract_diff(a["serializer_data"], b["serializer_data"])

func diff_diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var diff := {
		"added_nodes": {},
		"removed_nodes": {},
		"changed_nodes": {}
	}
	
	for x in ["added_nodes", "removed_nodes", "changed_nodes"]:
		var a_data = a[x]
		var b_data = b[x]
		
		diff.merge(_extract_diff(a_data, b_data))
		
	return diff

func extract_diff_from_files(first_file: String, second_file: String):
	var start_dict = load_serialized_file(first_file)
	var stop_dict  = load_serialized_file(second_file)

	var diff_dict = diff_serialized(start_dict, stop_dict)

	return diff_dict

func _node_label(node_dict):
	var name = node_dict.get("@name", "unnamed")
	var cls = node_dict.get("@class", "Object")
	return "%s (%s)" % [name, cls]
	
func _extract_diff(a_data: Dictionary, b_data: Dictionary) -> Dictionary:
	var diff := {
		"added_nodes": {},
		"removed_nodes": {},
		"changed_nodes": {}
	}
	
	for id in a_data.keys():
		if not b_data.has(id):
			diff["removed_nodes"][_node_label(a_data[id])] = a_data[id]

	for id in b_data.keys():
		if not a_data.has(id):
			diff["added_nodes"][_node_label(b_data[id])] = b_data[id]

	for id in a_data.keys():
		if not b_data.has(id):
			continue

		var node_a = a_data[id]
		var node_b = b_data[id]

		var props_a = node_a.get("@properties", {})
		var props_b = node_b.get("@properties", {})

		var changed_props := {}

		for key in props_a.keys():
			if not props_b.has(key):
				changed_props[key] = { "old": props_a[key], "new": null }
				continue

			if props_a[key] != props_b[key]:
				changed_props[key] = { "old": props_a[key], "new": props_b[key] }

		for key in props_b.keys():
			if not props_a.has(key):
				changed_props[key] = { "old": null, "new": props_b[key] }

		if changed_props.size() > 0:
			diff["changed_nodes"][_node_label(node_a)] = changed_props
	
	return diff
