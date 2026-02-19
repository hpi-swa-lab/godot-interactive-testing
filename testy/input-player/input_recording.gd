class_name InputRecording
extends Resource

@export var recorded_data: Dictionary = {}
@export var duration: int

func add_event(tick: int, event: InputEvent) -> void:
	if not tick in recorded_data:
		recorded_data[tick] = []
	recorded_data[tick].append(event)

func get_events_at(tick: int) -> Array:
	return recorded_data.get(tick, [])

func clear() -> void:
	recorded_data.clear()

func save(path: String) -> Error:
	return ResourceSaver.save(self, path)
