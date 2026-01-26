class_name TestReportEntry
extends Resource

@export var node_id: int = -1
@export var node_name: String = "Unknown"
@export var node_type: String = "Unknown"
@export var is_passed: bool = true
@export var failure_reason: String = ""

@export var checks: Array = [] 

func fail(reason: String) -> void:
	is_passed = false
	if failure_reason.is_empty():
		failure_reason = reason
