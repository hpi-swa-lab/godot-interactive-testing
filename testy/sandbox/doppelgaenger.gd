class_name DoppelGaenger
extends Node

var _real_target: Node

func _ready():
	self.set_meta("testy_ignore", true)

func setup(target: Node):
	_real_target = target
	
func _get(property: StringName):
	if is_instance_valid(_real_target):
		return _real_target.get(property)
	return null

func _set(property: StringName, value: Variant) -> bool:
	if is_instance_valid(_real_target):
		_real_target.set(property, value)
		return true
	return false

func _call(method: StringName, args: Array) -> Variant:
	if is_instance_valid(_real_target) and _real_target.has_method(method):
		return _real_target.callv(method, args)
	return null

func _has_method(method: StringName) -> bool:
	if is_instance_valid(_real_target):
		return _real_target.has_method(method)
	return false

func _get_property_list() -> Array:
	if is_instance_valid(_real_target):
		return _real_target.get_property_list()
	return []
