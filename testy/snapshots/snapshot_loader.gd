class_name SnapshotLoader extends Node

var snapshot: Snapshot 
var _save_id_to_instance: Dictionary = {}
var _instance_to_save_id: Dictionary = {}
var _restored_objects: Array[Object] = []

var node_map: Dictionary = {}

func _ready() -> void:
	self.set_meta("testy_ignore", true)

func load_snapshot(s: Snapshot):
	_reset_state()
	
	snapshot = s
	
	var root_id = snapshot.root_id
	var root_node = _reconstruct_object(root_id)
	
	for id in snapshot.node_data:
		if not id in _save_id_to_instance:
			_reconstruct_object(id)
	
	for obj in _restored_objects:
		_apply_properties(obj)
		_restore_signals(obj)
	
	return root_node 

func get_node_map():
	return node_map

func restore_properties():
	for obj in _restored_objects:
		if obj is Node:
			_prune_ghost_nodes(obj) 

		_apply_properties(obj, true)
		_restore_signals(obj)
		
		if obj is Node:
			_restore_processing_state(obj)

func _reset_state():
	snapshot = null
	_save_id_to_instance.clear()
	_instance_to_save_id.clear()
	_restored_objects.clear()
	node_map.clear()

func _reconstruct_object(id: int) -> Object:
	if id in _save_id_to_instance:
		return _save_id_to_instance[id]

	var payload = snapshot.node_data.get(id)
	if not payload:
		push_error("Missing data for ID: %s" % id)
		return null

	var instance = _factory_create(payload)
	if not instance: return null
	
	if payload.has("@script_path"):
		var current_script = instance.get_script()
		var saved_script_path = payload["@script_path"]
		if not current_script or current_script.resource_path != saved_script_path:
			var script_res = load(saved_script_path)
			if script_res:
				instance.set_script(script_res)

	var instance_id = instance.get_instance_id()
	_save_id_to_instance[id] = instance
	node_map[id] = instance_id
	_instance_to_save_id[instance_id] = id
	_restored_objects.append(instance)

	if instance is Node and payload.has("@children"):
		for child_id in payload["@children"]:
			var child = _reconstruct_object(child_id)
			if child:
				if child.get_parent() != instance:
					instance.add_child(child)
	
	return instance

func _factory_create(payload: Dictionary) -> Object:
	if payload.has("@scene_path"):
		var scn = load(payload["@scene_path"])
		return scn.instantiate() if scn else null
		
	elif payload.has("@resource_path"):
		return load(payload["@resource_path"])
		
	elif payload.has("@class"):
		var c = payload["@class"]
		
		if ClassDB.class_exists(c):
			if ClassDB.can_instantiate(c):
				return ClassDB.instantiate(c)
			else:
				push_warning("Skipping deserialization of internal class: %s" % c)
				return null
		else:
			push_error("Class not found in ClassDB: %s" % c)
			return null
		
	push_error("Unknown object type in save data.")
	return null

func _prune_ghost_nodes(node: Node):
	for child in node.get_children().duplicate():
		if not child.get_instance_id() in _instance_to_save_id:
			node.remove_child(child)
			child.queue_free()

func _apply_properties(obj: Object, is_second_pass:bool = false):
	var payload = _get_payload(obj)
	if not payload: return

	if payload.has("@name"):
		obj.name = payload["@name"]
	var second_pass_blocklist = [
		"autoplay", 
		"process_priority", 
		"process_thread_group"
	]
	
	var props = payload.get("@properties", {})
	for prop_name in props:
		if is_second_pass:
			if prop_name in second_pass_blocklist:
				continue
			
		var val = _deserialize_variant(props[prop_name])
		obj.set(prop_name, val)

func _restore_processing_state(node: Node):
	var payload = _get_payload(node)
	if not payload: return

	if payload.has("@process_mode"):
		node.process_mode = payload["@process_mode"] as int
		
	var flags = {
		"@is_processing": "set_process",
		"@is_physics_processing": "set_physics_process",
		"@is_processing_input": "set_process_input",
		"@is_processing_unhandled_input": "set_process_unhandled_input",
		"@is_processing_unhandled_key_input": "set_process_unhandled_key_input"
	}
	
	for key in flags:
		if payload.get(key, false):
			node.call(flags[key], true)

func _get_payload(obj: Object) -> Dictionary:
	var save_id = _instance_to_save_id.get(obj.get_instance_id())
	return snapshot.node_data.get(save_id, {}) if save_id else {}

func _deserialize_variant(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			if v.has("@obj_ref"):
				var ref_id = v["@obj_ref"]
				return _save_id_to_instance.get(ref_id)
			
			var d = {}
			for key in v: d[key] = _deserialize_variant(v[key])
			return d
			
		TYPE_ARRAY:
			return v.map(_deserialize_variant) 
		_:
			return v

func _restore_signals(obj: Object):
	var payload = _get_payload(obj)
	if not payload: return

	var signals_data = payload.get("@signals", {})
	
	for signal_name in signals_data:
		var connections_list = signals_data[signal_name]
		
		for conn_data in connections_list:
			var target = _deserialize_variant(conn_data["target"])
			
			if not is_instance_valid(target):
				continue
			
			var method_name = conn_data["method"]
			var flags = conn_data["flags"]
			var callable = Callable(target, method_name)

			if not obj.is_connected(signal_name, callable):
				obj.connect(signal_name, callable, flags)
