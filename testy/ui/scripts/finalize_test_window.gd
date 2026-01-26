class_name FinalizeTestWindow
extends Window

signal create_test(name: String, assertions: Array)
signal cancel_test()

var INSPECTOR_ROW_SCENE = load("uid://dr3srunxvrbju")

@onready var node_tree: Tree = %NodeTree
@onready var node_search_bar: LineEdit = %NodeSearchBar
@onready var meta_container: Container = %MetaContainer
@onready var prop_box: Container = %PropertiesContainer
@onready var properties_search_bar: LineEdit = %PropertiesSearchBar
@onready var save_btn: Button = %SaveButton

@onready var test_name_input: LineEdit = %TestName 

var confirm_close_popup: AcceptDialog
var warning_popup: AcceptDialog

var _node_lookup: Dictionary = {}
var assertions: Dictionary = {}
var checked_status_ids: Dictionary = {} 
var property_rows: Array[Control] = []

func _ready() -> void:
	visible = false
	close_requested.connect(_spawn_confirm_close_popup)
	
	node_tree.item_selected.connect(_select_node)
	node_search_bar.text_changed.connect(_search_node)
	properties_search_bar.text_changed.connect(_search_properties)
	
	save_btn.pressed.connect(_on_save_clicked)
	
	_show_empty_state()

func _on_save_clicked() -> void:
	if assertions.is_empty():
		_spawn_warning_popup()
		return

	var final_name = test_name_input.text.strip_edges()
	
	if final_name.is_empty():
		var dt = Time.get_datetime_dict_from_system()
		final_name = "Test_%04d-%02d-%02d_%02d-%02d-%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	
	create_test.emit(final_name, assertions.values())

func display(comparison: SnapshotComparator.SnapshotComparison) -> void:
	assertions.clear()
	checked_status_ids.clear()
	_node_lookup.clear()
	
	test_name_input.clear() 
	test_name_input.placeholder_text = _get_default_timestamp_string() 
	
	node_tree.clear()
	node_search_bar.clear()
	_show_empty_state()
	
	for delta in comparison.node_deltas:
		_node_lookup[delta.node_id] = delta
	
	var root = node_tree.create_item()
	root.set_text(0, "Snapshot Comparison")
	
	var current_root = node_tree.create_item(root)
	current_root.set_text(0, "Current State")
	
	var game_root_id = comparison.root_id
	if game_root_id != -1 and _node_lookup.has(game_root_id):
		_build_recursive(current_root, game_root_id)
	else:
		var err = node_tree.create_item(current_root)
		err.set_text(0, "No Root Node Found (ID: %s)" % game_root_id)
		err.set_custom_color(0, Color.RED)
	
	var removed_root = node_tree.create_item(root)
	removed_root.set_text(0, "Removed Nodes")
	removed_root.set_custom_color(0, Color(1, 0.4, 0.4))
	
	var removed_count = 0
	for delta in comparison.node_deltas:
		if delta.status == SnapshotComparator.STATUS_REMOVED:
			_add_tree_item(removed_root, delta)
			removed_count += 1
			
	removed_root.set_text(0, "Removed Nodes (%d)" % removed_count)
	current_root.collapsed = false
	removed_root.collapsed = false
	
	popup_centered()

func _get_default_timestamp_string() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "Test_%04d-%02d-%02d_%02d-%02d-%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]


func _spawn_warning_popup() -> void:
	if warning_popup: warning_popup.queue_free()
	
	warning_popup = AcceptDialog.new()
	warning_popup.title = "No changes selected"
	warning_popup.dialog_text = "Please select at least one node status or property to assert before saving."
	
	add_child(warning_popup)
	warning_popup.transient = true
	warning_popup.exclusive = true
	warning_popup.always_on_top = true
	
	warning_popup.popup_centered()

func _spawn_confirm_close_popup():
	if confirm_close_popup: confirm_close_popup.queue_free()

	confirm_close_popup = AcceptDialog.new()
	confirm_close_popup.title = "Do you really want to close?"
	confirm_close_popup.add_cancel_button("Cancel")
	
	add_child(confirm_close_popup)
	
	confirm_close_popup.transient = true
	confirm_close_popup.exclusive = true
	confirm_close_popup.always_on_top = true
	
	confirm_close_popup.size = Vector2(300, 100)
	
	var label := Label.new()
	label.text = "All unsaved changes will be discarded."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_close_popup.add_child(label)
	
	confirm_close_popup.confirmed.connect(_on_close_confirmed)
	confirm_close_popup.canceled.connect(_on_close_canceled)
	
	confirm_close_popup.popup_centered()

func _on_close_confirmed():
	cancel_test.emit()

func _on_close_canceled():
	confirm_close_popup.hide()
	confirm_close_popup.queue_free()
	confirm_close_popup = null

func _build_recursive(parent: TreeItem, id: int) -> void:
	var delta: SnapshotComparator.NodeDelta = _node_lookup.get(id)
	if not delta: return
	
	var item = _add_tree_item(parent, delta)
	for child_id in delta.children:
		if _node_lookup.has(child_id):
			_build_recursive(item, child_id)

func _add_tree_item(parent: TreeItem, delta: SnapshotComparator.NodeDelta) -> TreeItem:
	var item = node_tree.create_item(parent)
	item.set_metadata(0, delta)
	item.set_text(0, "%s (%s)" % [delta.node_name, delta.node_type])
	
	match delta.status:
		SnapshotComparator.STATUS_ADDED: item.set_custom_color(0, Color.GREEN)
		SnapshotComparator.STATUS_MODIFIED: item.set_custom_color(0, Color.ORANGE)
		SnapshotComparator.STATUS_REMOVED: item.set_custom_color(0, Color.RED)
		_: item.set_custom_color(0, Color(1, 1, 1, 0.5))
	return item

func _select_node():
	var node = node_tree.get_selected()
	if not node:
		_show_empty_state()
		return
	
	var data = node.get_metadata(0)
	if data and data is SnapshotComparator.NodeDelta:
		_populate_inspector(data)
	else:
		_show_empty_state()

func _populate_inspector(delta: SnapshotComparator.NodeDelta):
	_clear_inspector()
	properties_search_bar.editable = true
	
	var node_id = delta.node_id
	
	var create_row = func(container):
		var row = INSPECTOR_ROW_SCENE.instantiate()
		container.add_child(row)
		return row

	create_row.call(meta_container).setup("Name", delta.node_name, false, func(_b): pass, false)
	create_row.call(meta_container).setup("Type", delta.node_type, false, func(_b): pass, false)
	create_row.call(meta_container).setup("ID", str(node_id), false, func(_b): pass, false)
	
	var status_str = str(delta.status).to_upper()
	var status_is_checked = checked_status_ids.has(node_id)
	
	var on_status_toggle = func(active: bool):
		if active:
			checked_status_ids[node_id] = true
			_ensure_node_entry(delta)
			assertions[node_id]["node_status"] = delta.status
		else:
			checked_status_ids.erase(node_id)
			if assertions.has(node_id):
				assertions[node_id].erase("node_status")
			_cleanup_node_if_empty(node_id)
			
	create_row.call(meta_container).setup("Status", status_str, status_is_checked, on_status_toggle, true)

	var props = delta.properties
	var keys = props.keys()
	keys.sort()
	
	for key in keys:
		var val = props[key]
		var row = create_row.call(prop_box)
		property_rows.append(row)
		
		var is_checked = false
		if assertions.has(node_id) and assertions[node_id].has("properties"):
			if assertions[node_id]["properties"].has(key):
				is_checked = true
			
		var on_prop_toggle = func(active: bool):
			if active:
				_ensure_node_entry(delta)
				
				if not assertions[node_id].has("properties"):
					assertions[node_id]["properties"] = {}
				
				var value_to_save
				
				if val is SnapshotComparator.PropertyDelta:
					value_to_save = {
						"@is_property_delta": true,
						"old_value": _clone_safe(val.old_value),
						"new_value": _clone_safe(val.new_value)
					}
				else:
					value_to_save = _clone_safe(val)
				
				assertions[node_id]["properties"][key] = value_to_save
			else:
				if assertions.has(node_id) and assertions[node_id].has("properties"):
					assertions[node_id]["properties"].erase(key)
					
					if assertions[node_id]["properties"].is_empty():
						assertions[node_id].erase("properties")
						
					_cleanup_node_if_empty(node_id)
		
		row.setup(key, val, is_checked, on_prop_toggle, true)

	if not properties_search_bar.text.is_empty():
		_search_properties(properties_search_bar.text)

func _clone_safe(val):
	if typeof(val) == TYPE_DICTIONARY or typeof(val) == TYPE_ARRAY:
		return val.duplicate(true)
	return val

func _ensure_node_entry(delta: SnapshotComparator.NodeDelta):
	if assertions.has(delta.node_id): return
	
	assertions[delta.node_id] = {
		"node_id": delta.node_id,
		"node_name": delta.node_name,
		"node_type": delta.node_type
	}

func _cleanup_node_if_empty(node_id):
	if not assertions.has(node_id): return
	
	var entry = assertions[node_id]
	var has_status = entry.has("node_status")
	var has_props = entry.has("properties") and not entry["properties"].is_empty()
	
	if not has_status and not has_props:
		assertions.erase(node_id)

func _clear_inspector() -> void:
	property_rows.clear()
	for c in meta_container.get_children(): c.queue_free()
	for c in prop_box.get_children(): c.queue_free()

func _show_empty_state():
	_clear_inspector()
	properties_search_bar.editable = false
	var l = Label.new()
	l.text = "Select a node..."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate = Color(1, 1, 1, 0.5)
	prop_box.add_child(l)

func _search_node(query: String):
	var root = node_tree.get_root()
	if not root: return
	if query.strip_edges().is_empty():
		_set_visible_recursive(root, true)
	else:
		_filter_tree_recursive(root, query.to_lower())

func _filter_tree_recursive(item: TreeItem, query: String) -> bool:
	var match_self = query in item.get_text(0).to_lower()
	var match_child = false
	
	var child = item.get_first_child()
	while child:
		if _filter_tree_recursive(child, query): 
			match_child = true
		child = child.get_next()
	
	var should_show = match_self or match_child
	
	item.visible = should_show
	if should_show: item.collapsed = false 
		
	return should_show

func _set_visible_recursive(item: TreeItem, is_visible: bool):
	item.visible = is_visible
	if is_visible: item.collapsed = false
		
	var child = item.get_first_child()
	while child:
		_set_visible_recursive(child, is_visible)
		child = child.get_next()

func _search_properties(text: String):
	var query = text.to_lower()
	for row in property_rows:
		if row.has_method("matches_search"):
			row.visible = row.matches_search(query)
