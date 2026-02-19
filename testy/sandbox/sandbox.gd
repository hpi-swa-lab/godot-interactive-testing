class_name Sandbox
extends Node

signal scene_sandboxed
signal initialized

var sandbox_viewport: SubViewport
var sandbox_visualizer: TextureRect 
var current_scene: Node
var current_proxy: Node

func _ready():
	self.set_meta("testy_ignore", true)

func setup():
	var window = get_window()
	var tree = get_tree()
	var root = tree.root
	
	sandbox_viewport = SubViewport.new()
	sandbox_viewport.name = "SandboxViewport"
	sandbox_viewport.set_meta("testy_ignore", true)
	
	sandbox_viewport.size = window.size
	
	sandbox_viewport.handle_input_locally = true 
	sandbox_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sandbox_viewport.physics_object_picking = true 
	
	root.add_child(sandbox_viewport)

	sandbox_visualizer = TextureRect.new()
	sandbox_visualizer.name = "SandboxVisualizer"
	sandbox_visualizer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sandbox_visualizer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sandbox_visualizer.stretch_mode = TextureRect.STRETCH_SCALE
	sandbox_visualizer.texture = sandbox_viewport.get_texture()
	sandbox_visualizer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sandbox_visualizer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sandbox_visualizer.set_meta("testy_ignore", true)
	
	sandbox_visualizer.visible = true
	root.add_child(sandbox_visualizer)
	
	tree.scene_changed.connect(_on_scene_changed)

func sandbox(scene: Node):
	_nuke()

	if is_instance_valid(current_proxy) and not current_proxy.is_queued_for_deletion():
		if current_proxy.tree_exiting.is_connected(_nuke):
			current_proxy.tree_exiting.disconnect(_nuke)
		current_proxy.queue_free()

	var scene_path = scene.scene_file_path
	
	if scene.get_parent():
		scene.reparent(sandbox_viewport)
	else:
		sandbox_viewport.add_child(scene)
	
	var proxy = DoppelGaenger.new()
	proxy.name = "SceneProxy"
	proxy.scene_file_path = scene_path 
	
	proxy.setup(scene)
	
	proxy.tree_exiting.connect(_nuke)
	
	var tree = get_tree()
	tree.root.add_child(proxy)
	tree.current_scene = proxy
	
	current_scene = scene
	current_proxy = proxy
	
	scene_sandboxed.emit()

func forward_mouse_event(event: InputEventMouse):
	if sandbox_viewport:
		sandbox_viewport.push_input(event)

func _nuke():
	for child in sandbox_viewport.get_children():
		if child.has_signal("tree_exiting") and child.is_connected("tree_exiting", _nuke):
			child.tree_exiting.disconnect(_nuke)
		
		if child.is_queued_for_deletion():
			continue

		sandbox_viewport.remove_child(child)
		child.queue_free()

func _on_scene_changed():
	var scene = get_tree().current_scene
	if not scene: return
	
	if scene.get_script() == DoppelGaenger:
		return

	sandbox.call_deferred(scene)
