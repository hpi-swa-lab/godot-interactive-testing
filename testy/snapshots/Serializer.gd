class_name Serializier extends Node

var serializer_data: Dictionary = {}

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
	# temp fix, to not serialize ourselfes...
	"serializer_data",
	"data"
	
]

const skipped_signals = []

func serialize(root: Node):
	serializer_data.clear()
	var res = {}
	var root_id: int = _serialize_object(root)
	res = {
		"root_id": root_id,
		"serializer_data": serializer_data
	}
	var bytes : PackedByteArray = var_to_bytes(res)	
	return bytes

func _serialize_signals(o: Object) -> Dictionary:
	var signals_data = {}
  # loop over all signals, emitted by o
	for s: Dictionary in o.get_signal_list():
		var signal_name = s.get("name")
		if signal_name in skipped_signals:
			continue
		# get all connections from other objects to the signal s
		var connections: Array[Dictionary] = o.get_signal_connection_list(signal_name)
 	   # no connection from other objects -> nothing to be saved!
		if connections.is_empty():
			continue
		var serialized_connections = []
		for c in connections:
			var callable: Callable = c["callable"]
			var target = callable.get_object()
			# target may be null, if it has been freed
			if not is_instance_valid(target):
				continue
			
			var method_name = callable.get_method()
			var flags = c.get("flags")
			var target_id = _serialize_object(target)
	  
		  # skip flags that are defined in the editor
			#if flags & CONNECT_PERSIST:
				#continue
	  
			serialized_connections.append({
				"target_id": target_id,
				"method": method_name,
				"flags": flags
			})
	
		if serialized_connections.size() > 0:
			signals_data[signal_name] = serialized_connections
	
	return signals_data
		
func _serialize_object(o: Object) -> int:
	if o == null:
		return 0
	
	var id := o.get_instance_id()
	if id in serializer_data:
		return id
		
		
	var payload = {}
	serializer_data[id] = payload
	
	if "name" in o:
		payload["@name"] = o.get("name")
	 
	if o is Resource and o.resource_path:
		payload["@resource_path"] = o.resource_path
		return id
	
	if o is Node and o.scene_file_path:
		payload["@scene_path"] = o.scene_file_path
	else:
		payload["@class"] = o.get_class()
	
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
		
		if name == "is_card_in_slot":
			print("Test")
			
		var type: int = p.get("type")
		var val = o.get(name)
		
		properties[name] = _serialize_variant(val)
	
	payload["@properties"] = properties
	
	if "is_card_in_slot" in properties:
		print("Found is_card_in_slot")
	 
	if o is AnimatedSprite2D or o is AnimatedSprite3D or o is AnimationPlayer:
		payload["@is_playing"] = true
	if o is Timer:
		properties["$is_stopped"] = _serialize_variant(o.is_stopped())
	
	if o is Node:
		var child_ids: Array[int] = []
		
		for c: Node in o.get_children():
			child_ids.append(_serialize_object(c))
		
		payload["@children"] = child_ids
	
	return id

func _serialize_variant(variant: Variant):
	match typeof(variant):
		TYPE_OBJECT:
			return _serialize_object(variant as Object)
		TYPE_NIL:
			return null
		TYPE_DICTIONARY:
			# Must recursively serialize dictionaries in case
			# they contain Object references
			var d = {}
			for key in variant:
				d[key] = _serialize_variant(variant[key])
			return d
		TYPE_ARRAY:
			# Must recursively serialize arrays in case
			# they contain Object references
			var a = []
			for item in variant:
				a.append(_serialize_variant(item))
			return a
		_:
			# Default: serialize as is
			return variant
