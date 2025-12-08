class_name Serializier extends Node

var serialized_data: Dictionary = {}
var current_root: Node 

const skipped_properties = [
	"owner",
	"scene_file_path",
	"global_position",
	"global_rotation",
	"global_rotation_degrees",
	"global_scale",
	"global_skew",
	"global_transform",
	"resource_path",
]

const skipped_signals = []

func serialize(root: Node):
	serialized_data.clear()
	current_root = root
	var res = {}
	var root_id: int = _serialize_object(root)
	res = {
		"root_id": root_id,
		"node_data": serialized_data
	}
	var bytes : PackedByteArray = var_to_bytes(res)	
	return bytes

func _serialize_signals(o: Object) -> Dictionary:
	var signals_data = {}
	for s: Dictionary in o.get_signal_list():
		var signal_name = s.get("name")
		if signal_name in skipped_signals:
			continue
		
		var connections: Array[Dictionary] = o.get_signal_connection_list(signal_name)
		if connections.is_empty():
			continue
			
		var serialized_connections = []
		for c in connections:
			var flags = c.get("flags")
			
			# skip signals that are setup by the editor itself
			#if flags & CONNECT_PERSIST:
			#continue
			
			var callable: Callable = c["callable"]
			var target = callable.get_object()
			
			if not is_instance_valid(target):
				continue
			
			var target_ref = _serialize_variant(target)
			
			if target_ref == null:
				continue

			var method_name = callable.get_method()
	  
			serialized_connections.append({
				"target": target_ref,
				"method": method_name,
				"flags": flags
			})
	
		if serialized_connections.size() > 0:
			signals_data[signal_name] = serialized_connections
	
	return signals_data
		
func _serialize_object(o: Object) -> int:
	if o == null:
		return 0
	
	var ignore = o.get_meta("testy_ignore", false)
	if ignore == true:
		return 0
	
	var id := o.get_instance_id()
	if id in serialized_data:
		return id
		
	var payload = {}
	serialized_data[id] = payload
	
	if "name" in o:
		payload["@name"] = o.get("name")
	 
	if o is Resource and o.resource_path:
		payload["@resource_path"] = o.resource_path
	if o is Node: 
		var n := o as Node
		
		if n != current_root and not current_root.is_ancestor_of(n):
			return 0
		
		if n.scene_file_path:
			# the node is a scene itself!
			payload["@scene_path"] = o.scene_file_path
		else:
			payload["@class"] = o.get_class()
		
		payload["@process_mode"] = n.process_mode

		if n.is_processing(): payload["@is_processing"] = true
		if n.is_physics_processing(): payload["@is_physics_processing"] = true
		if n.is_processing_input(): payload["@is_processing_input"] = true
		if n.is_processing_unhandled_input(): payload["@is_processing_unhandled_input"] = true
		if n.is_processing_unhandled_key_input(): payload["@is_processing_unhandled_key_input"] = true
	else:
		payload["@class"] = o.get_class()
	
	var signals = _serialize_signals(o)
	if not signals.is_empty():
		payload["@signals"] = signals
	
	var properties = {}
	for p: Dictionary in o.get_property_list():
		var usage: int = p.get("usage")
		
		if not (usage & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE)):
			continue

		if usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP) != 0:
			continue
		
		var name: String = p.get("name")
		if name in skipped_properties:
			continue
		
		var type: int = p.get("type")
		var val = o.get(name)
		
		properties[name] = _serialize_variant(val)
	
	if not properties.is_empty():
		payload["@properties"] = properties
	
	if o is AnimatedSprite2D or o is AnimatedSprite3D or o is AnimationPlayer:
		payload["@is_playing"] = true
	if o is Timer:
		properties["$is_stopped"] = _serialize_variant(o.is_stopped())
	
	if o is Node:
		var node = o as Node
		var child_ids: Array[int] = []
		
		for c: Node in node.get_children():
			child_ids.append(_serialize_object(c))
		
		if not child_ids.is_empty():
			payload["@children"] = child_ids
	
	return id

func _serialize_variant(variant: Variant):
	match typeof(variant):
		TYPE_OBJECT:
			var o = variant as Object
			var o_id = _serialize_object(o)
			
			return {
				"@obj_ref": o_id
			}
		TYPE_NIL:
			return null
		TYPE_DICTIONARY:
			var dict = variant as Dictionary
			var d = {}
			for key in dict:
				d[key] = _serialize_variant(dict[key])
				
			return d
		TYPE_ARRAY:
			var a = []
			for item in variant:
				a.append(_serialize_variant(item))
			return a
		_:
			return variant
