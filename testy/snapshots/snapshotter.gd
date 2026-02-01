class_name Snapshotter extends Node

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
	"transform",
	"transform3D",
	"matrix",
	"process_priority",
	"process_thread_group", 
	"camera_attributes",
	"script"
]

const skipped_signals = []

func snapshot(root: Node) -> Snapshot:
	serialized_data = {}
	current_root = root
	
	var root_id: int = _snapshot_object(root)
	
	var snapshot := Snapshot.new()
	snapshot.root_id = root_id
	snapshot.node_data = serialized_data
	
	return snapshot

func _snapshot_signals(o: Object) -> Dictionary:
	var signals_data = {}
	for s: Dictionary in o.get_signal_list():
		var signal_name = s.get("name")
		if signal_name in skipped_signals: continue
		
		var connections: Array[Dictionary] = o.get_signal_connection_list(signal_name)
		if connections.is_empty(): continue
			
		var serialized_connections = []
		for c in connections:
			var callable: Callable = c["callable"]
			var target = callable.get_object()
			
			if not is_instance_valid(target): continue
			
			var target_ref = _snapshot_variant(target)
			
			#  Drop connection if target is not serialized
			if typeof(target_ref) == TYPE_DICTIONARY:
				var ref_id = target_ref.get("@obj_ref")
				if ref_id == -1: 
					continue

			serialized_connections.append({
				"target": target_ref,
				"method": callable.get_method(),
				"flags": c.get("flags")
			})
	
		if serialized_connections.size() > 0:
			signals_data[signal_name] = serialized_connections
	
	return signals_data
		
func _snapshot_object(o: Object) -> int:
	if o == null or not is_instance_valid(o):
		return -1
	
	if not o is Resource and not o is Node: 
		var c = o.get_class()
		if ClassDB.class_exists(c) and not ClassDB.can_instantiate(c):
			return -1
	
	if o is Node:
		if o != current_root and not current_root.is_ancestor_of(o):
			return -1 
			
		if o != current_root and o.get_parent():
			# used to filter out internal nodes, that may be detected via signals
			# (internal nodes are not shown via get_children, only via get_children(true))
			if not o in o.get_parent().get_children():
				return -1 
	
	if o.get_meta("testy_ignore", false) == true:
		return -1

	var id := o.get_instance_id()
	if id in serialized_data:
		return id
		
	var payload = {}
	serialized_data[id] = payload
	
	if "name" in o: payload["@name"] = o.get("name")
	
	var script = o.get_script()
	if script and script is Script and script.resource_path:
		payload["@script_path"] = script.resource_path
	 
	if o is Node: 
		var n := o as Node
		if n.scene_file_path: 
			payload["@scene_path"] = o.scene_file_path
		else: payload["@class"] = o.get_class()
		
		payload["@process_mode"] = n.process_mode
		if n.is_processing(): payload["@is_processing"] = true
		if n.is_physics_processing(): payload["@is_physics_processing"] = true
		if n.is_processing_input(): payload["@is_processing_input"] = true
		if n.is_processing_unhandled_input(): payload["@is_processing_unhandled_input"] = true
		if n.is_processing_unhandled_key_input(): payload["@is_processing_unhandled_key_input"] = true
	else:
		payload["@class"] = o.get_class()
	
	if o is Resource and o.resource_path:
		payload["@resource_path"] = o.resource_path

	var signals = _snapshot_signals(o)
	if not signals.is_empty(): payload["@signals"] = signals
	
	var properties = {}
	for p: Dictionary in o.get_property_list():
		var usage: int = p.get("usage")
		if not (usage & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE)): continue
		if usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP) != 0: continue
		
		var name: String = p.get("name")
		if name in skipped_properties: continue
		if name.begins_with("cache/"): continue
		
		var val = o.get(name)
		properties[name] = _snapshot_variant(val)
	
	if not properties.is_empty(): payload["@properties"] = properties
	
	if o is AnimatedSprite2D or o is AnimatedSprite3D or o is AnimationPlayer:
		payload["@is_playing"] = true
	if o is Timer:
		properties["$is_stopped"] = _snapshot_variant(o.is_stopped())
	
	if o is Node:
		var node = o as Node
		var child_ids: Array[int] = []
		
		for c: Node in node.get_children():
			var cid = _snapshot_object(c)
			if cid != -1:
				child_ids.append(cid)
		
		if not child_ids.is_empty():
			payload["@children"] = child_ids
	
	return id

func _snapshot_variant(variant: Variant):
	match typeof(variant):
		TYPE_OBJECT:
			if variant == null:
				return null
				
			var ref = weakref(variant).get_ref()
			if ref == null:
				return null
			
			var o = ref as Object
			
			var o_id = _snapshot_object(o)
			
			return { 
				"@obj_ref": o_id, 
				"@class": o.get_class(), 
				"@is_resource": o is Resource 
			}
		
		TYPE_NIL:
			return null
		TYPE_DICTIONARY:
			var dict = variant as Dictionary
			var d = {}
			for key in dict: d[key] = _snapshot_variant(dict[key])
			return d
		TYPE_ARRAY:
			var a = []
			for item in variant: a.append(_snapshot_variant(item))
			return a
		_:
			return variant
