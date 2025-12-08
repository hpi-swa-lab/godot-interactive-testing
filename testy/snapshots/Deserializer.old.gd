class_name DeserializerOld extends Node

var loaded_data: Dictionary = {}
var deserialized_objects: Dictionary = {}


func restore(bytes: PackedByteArray) -> Node:
	loaded_data.clear()
	deserialized_objects.clear()
	
	loaded_data = bytes_to_var(bytes)
	
	if not loaded_data or typeof(loaded_data) != TYPE_DICTIONARY:
		push_error("Restore failed: Save data is corrupt or not a Dictionary.")
		return null
		
	var root_id = loaded_data.get("root_id")
	var object_data = loaded_data.get("serializer_data")
	
	if not root_id or not object_data:
		push_error("Restore failed: Save data is missing root_id or serializer_data.")
		return null

	var root_node = _deserialize_object(root_id, object_data)
	
	if root_node:
		_recursive_set_process_mode(root_node, Node.PROCESS_MODE_INHERIT)
		
	loaded_data.clear()
	deserialized_objects.clear()
	
	return root_node


func _recursive_set_process_mode(node: Node, mode: int):
	node.process_mode = mode
	
	for child in node.get_children():
		_recursive_set_process_mode(child, mode)


func _deserialize_object(id: int, object_data: Dictionary) -> Object:
	if id == 0:
		return null
		
	if id in deserialized_objects:
		return deserialized_objects[id]
		
	if not id in object_data:
		push_error("Restore failed: Missing object ID " + str(id))
		return null
		
	var payload: Dictionary = object_data[id]
	
	var new_obj: Object
	
	if payload.has("@resource_path"):
		new_obj = load(payload["@resource_path"])
		if new_obj == null:
			push_error("Failed to load resource: " + payload["@resource_path"])
			return null
			
		deserialized_objects[id] = new_obj
		
		if (new_obj is Resource) and payload.has("@name"):
			new_obj.set_name(payload["@name"])
		return new_obj
		
	elif payload.has("@scene_path"):
		var scene = load(payload["@scene_path"])
		if scene:
			new_obj = scene.instantiate()
			
			# If the node to be added is a scene, it probably comes with static nodes
			# These static nodes are also backed up -> restore newly initiated ones, to prevent duplicates
			for child in new_obj.get_children():
				new_obj.remove_child(child)
				child.free()
		else:
			push_error("Failed to load scene: " + payload["@scene_path"])
			return null
	
	elif payload.has("@class"):
		var c_name = payload["@class"]
		new_obj = ClassDB.instantiate(c_name)
		
		if new_obj is Node:
			new_obj.process_mode = Node.PROCESS_MODE_DISABLED
			
		if new_obj == null:
			push_error("Failed to instantiate class: " + c_name)
			return null
			
	else:
		push_error("Object payload has no @resource_path, @scene_path, or @class.")
		return null

	deserialized_objects[id] = new_obj

	if (new_obj is Node or new_obj is Resource) and payload.has("@name"):
		new_obj.set_name(payload["@name"])

	var properties: Dictionary = payload.get("@properties", {})
	for key in properties:
		var value_payload = properties[key]
		var deserialized_value = _deserialize_variant(value_payload, object_data)
		new_obj.set(key, deserialized_value)
	
	if (new_obj is AnimatedSprite2D or new_obj is AnimationPlayer) and payload.has("@is_playing"):
		new_obj.set("is_playing", payload.get("@is_playinger"))
	
	if payload.has("@signals"):
		_deserialize_signals(new_obj, payload["@signals"], object_data)	

	if new_obj is Node and payload.has("@children"):
		var child_ids: Array = payload["@children"]
		for child_id in child_ids:
			var child_obj = _deserialize_object(child_id, object_data)
			if child_obj:
				new_obj.add_child(child_obj)

	return new_obj

func _deserialize_signals(obj: Object, signals_data: Dictionary, object_data: Dictionary):
	for signal_name: String in signals_data:
		# Ensure the object actually still has this signal (code might have changed)
		if not obj.has_signal(signal_name):
			continue
			
		var connections: Array = signals_data[signal_name]
		
		for conn_info: Dictionary in connections:
			var target_id: int = conn_info.get("target_id")
			var method_name: String = conn_info.get("method")
			var flags: int = conn_info.get("flags", 0)
			
			# Recursively resolve the target object using your existing system
			var target_obj = _deserialize_object(target_id, object_data)
			
			# Validity checks
			if not is_instance_valid(target_obj):
				push_warning("Signal restore failed: Target object missing for signal " + signal_name)
				continue
			
			# Create the callable
			var callable = Callable(target_obj, method_name)
			
			# Avoid duplicates:
			# 1. If the connection persists (from scene), we shouldn't duplicate it.
			# 2. If we already processed this logic.
			if not obj.is_connected(signal_name, callable):
				obj.connect(signal_name, callable, flags)

func _deserialize_variant(payload: Variant, object_data: Dictionary) -> Variant:
	match typeof(payload):
		TYPE_INT:
			if payload in object_data:
				return _deserialize_object(payload, object_data)
			else:
				return payload

		TYPE_DICTIONARY:
			var d = {}
			for key in payload:
				d[key] = _deserialize_variant(payload[key], object_data)
			return d
			
		TYPE_ARRAY:
			var a = []
			for item in payload:
				a.append(_deserialize_variant(item, object_data))
			return a

		_:
			return payload
