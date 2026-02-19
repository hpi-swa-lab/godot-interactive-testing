class_name SnapshotComparator
extends RefCounted

const STATUS_UNCHANGED = "unchanged"
const STATUS_ADDED = "added"
const STATUS_REMOVED = "removed"
const STATUS_MODIFIED = "modified"

class SnapshotComparison extends RefCounted:
	var root_id: int
	var node_deltas: Array[NodeDelta] = []

class NodeDelta extends RefCounted:
	var node_id: int
	var node_name: String
	var node_type: String
	var children: Array[int] = []

	var status: String

	var properties: Dictionary = {}

class PropertyDelta extends RefCounted:
	var old_value: Variant
	var new_value: Variant
	
func _ready() -> void:
	self.set_meta("testy_ignore", true)

static func compare(snapshot_a: Snapshot, snapshot_b: Snapshot) -> SnapshotComparison:
	var comparison = SnapshotComparison.new()
	
	var nodes_a = snapshot_a.node_data
	var nodes_b = snapshot_b.node_data 
	
	comparison.root_id = snapshot_b.root_id
	
	var all_ids = {}
	for id in nodes_a: 
		all_ids[id] = true
	for id in nodes_b: all_ids[id] = true
	
	for node_id in all_ids:
		var data_a = nodes_a.get(node_id)
		var data_b = nodes_b.get(node_id)
		
		var check_data = data_b if data_b != null else data_a
		if not _is_node(check_data):
			continue
		
		var delta = NodeDelta.new()
		delta.node_id = node_id
		
		var a_props: Dictionary = {}
		var b_props: Dictionary = {}
		
		if data_a == null:
			delta.status = STATUS_ADDED
			delta.node_type = _resolve_node_type(data_b)
			delta.node_name = data_b.get("@name", "??")
			var children_raw = data_b.get("@children", [])
			delta.children.assign(children_raw)
			b_props = data_b.get("@properties", {})
			
		elif data_b == null:
			delta.status = STATUS_REMOVED
			delta.node_type = _resolve_node_type(data_a)
			delta.node_name = data_a.get("@name", "??")
			var children_raw = data_a.get("@children", [])
			delta.children.assign(children_raw)
			a_props = data_a.get("@properties", {})
		else:
			delta.status = STATUS_UNCHANGED
			delta.node_type = _resolve_node_type(data_b)
			delta.node_name = data_b.get("@name", "??")
			var children_raw = data_b.get("@children", [])
			delta.children.assign(children_raw)
			a_props = data_a.get("@properties", {})
			b_props = data_b.get("@properties", {})
		
		_fill_properties(delta, a_props, b_props)
		
		comparison.node_deltas.append(delta)
	
	return comparison

static func _resolve_node_type(data: Dictionary) -> String:
	if data.has("@class"):
		return data["@class"]
	if data.has("@scene_path") or data.has("@scene_file_path"):
		return "Scene"
	return "Unknown"

static func _is_node(data: Dictionary) -> bool:
	if data.has("@scene_path") or data.has("@scene_file_path"):
		return true
		
	if data.has("@class"):
		var cls = data["@class"]
		if cls == "Node" or ClassDB.is_parent_class(cls, "Node"):
			return true
			
	return false

static func _fill_properties(delta: NodeDelta, props_a: Dictionary, props_b: Dictionary):
	var all_keys = {}
	for k in props_a: all_keys[k] = true
	for k in props_b: all_keys[k] = true
	
	for key in all_keys:
		var val_a = props_a.get(key)
		var val_b = props_b.get(key)
		
		if _is_non_node_reference(val_a) or _is_non_node_reference(val_b):
			continue
			
		if delta.status == STATUS_ADDED:
			delta.properties[key] = val_b
			continue

		if delta.status == STATUS_REMOVED:
			delta.properties[key] = val_a
			continue

		var is_modified = str(val_a) != str(val_b)
		
		if is_modified:
			if delta.status == STATUS_UNCHANGED:
				delta.status = STATUS_MODIFIED
			
			var prop_delta = PropertyDelta.new()
			prop_delta.old_value = val_a
			prop_delta.new_value = val_b
			
			delta.properties[key] = prop_delta
		else:
			delta.properties[key] = val_b
		
static func _is_non_node_reference(val) -> bool:
	if typeof(val) == TYPE_DICTIONARY and val.has("@obj_ref"):
		if val.has("@is_resource"): return val["@is_resource"] == true
		if val.has("@class"):
			var cls = val["@class"]
			return ClassDB.class_exists(cls) and not ClassDB.is_parent_class(cls, "Node")
		return false
	if typeof(val) == TYPE_DICTIONARY:
		for k in val:
			if _is_non_node_reference(val[k]): return true
		return false
	if typeof(val) == TYPE_ARRAY:
		for item in val:
			if _is_non_node_reference(item): return true
		return false
	return false

static func map_ids(old: Snapshot, new: Snapshot) -> Dictionary:
	var map = {}
	
	var old_root_id = old.root_id
	var new_root_id = new.root_id
	
	if old_root_id == null or new_root_id == null:
		return {}
	
	var old_nodes = old.node_data
	var new_nodes = new.node_data
	
	var stack = [[old_root_id, new_root_id]]
	
	while not stack.is_empty():
		var pair = stack.pop_back()
		
		var old_id = pair[0]
		var new_id = pair[1]
		
		map[old_id] = new_id
		
		var old_children = old_nodes.get(old_id, {}).get("@children", [])
		var new_children = new_nodes.get(new_id, {}).get("@children", [])
		
		var limit = min(old_children.size(), new_children.size())
		
		for i in range(limit):
			var old_child_id = old_children[i]
			var new_child_id = new_children[i]
			
			var old_node_data = old_nodes.get(old_child_id, {})
			var new_node_data = new_nodes.get(new_child_id, {})
			
			var old_type = _resolve_node_type(old_node_data)
			var new_type = _resolve_node_type(new_node_data)
			
			if old_type == new_type:
				stack.push_back([old_child_id, new_child_id])
			else:
				pass

	return map
