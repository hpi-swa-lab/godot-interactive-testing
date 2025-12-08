class_name Deserializer extends Node

var _object_registry: Dictionary = {} 
var _save_id_to_instance: Dictionary = {}
var _instance_to_save_id: Dictionary = {}
var _restored_objects: Array[Object] = []

func restore(bytes: PackedByteArray, scene_tree: SceneTree) -> bool:
	_reset_state()
	
	var save_state = bytes_to_var(bytes)
	if not save_state: return false
	
	var root_id = save_state.get("root_id")
	_object_registry = save_state.get("node_data", {})

	var current_scene = scene_tree.get_current_scene()
	var parent = current_scene.get_parent()
	parent.remove_child(current_scene)
	current_scene.queue_free()

	var root_node = _reconstruct_object(root_id)
	
	for id in _object_registry:
		if not id in _save_id_to_instance:
			_reconstruct_object(id)

	parent.add_child(root_node)
	scene_tree.current_scene = root_node

	for obj in _restored_objects:
		if obj is Node:
			_prune_ghost_nodes(obj)
			
		_apply_properties(obj)
		_restore_signals(obj)
		
		if obj is Node:
			_restore_processing_state(obj)
			
	return true

func _reset_state():
	_object_registry.clear()
	_save_id_to_instance.clear()
	_instance_to_save_id.clear()
	_restored_objects.clear()


func _reconstruct_object(id: int) -> Object:
	if id in _save_id_to_instance:
		return _save_id_to_instance[id]

	var payload = _object_registry.get(id)
	if not payload:
		push_error("Missing data for ID: %s" % id)
		return null

	var instance = _factory_create(payload)
	if not instance: return null

	var instance_id = instance.get_instance_id()
	_save_id_to_instance[id] = instance
	_instance_to_save_id[instance_id] = id
	_restored_objects.append(instance)

	if instance is Node and payload.has("@children"):
		for child_id in payload["@children"]:
			var child = _reconstruct_object(child_id)
			if child:
				instance.add_child(child)
	
	return instance

func _factory_create(payload: Dictionary) -> Object:
	if payload.has("@scene_path"):
		var scn = load(payload["@scene_path"])
		return scn.instantiate() if scn else null
		
	elif payload.has("@resource_path"):
		return load(payload["@resource_path"])
		
	elif payload.has("@class"):
		return ClassDB.instantiate(payload["@class"])
		
	push_error("Unknown object type in save data.")
	return null

func _prune_ghost_nodes(node: Node):
	# Remove nodes spawned by _ready() (particles, default items) 
	# that do not exist in the save file.
	for child in node.get_children().duplicate():
		if not child.get_instance_id() in _instance_to_save_id:
			node.remove_child(child)
			child.queue_free()

func _apply_properties(obj: Object):
	var payload = _get_payload(obj)
	if not payload: return

	if payload.has("@name"):
		obj.name = payload["@name"]

	var props = payload.get("@properties", {})
	for prop_name in props:
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
	return _object_registry.get(save_id, {}) if save_id else {}

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
