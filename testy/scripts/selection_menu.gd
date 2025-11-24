extends Window

@onready var tree: Tree = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/Tree
@onready var search_bar: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/SearchBar
@onready var start_button: Button = $MarginContainer/VBoxContainer/HBoxContainer2/StartButton
@onready var select_all_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/SelectAll
@onready var select_none_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/SelectNone

@onready var titel_prop_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/TitelPropLabel
@onready var search_bar_prop: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/SearchBarProp
@onready var props_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/ScrollContainer/PropsLabel


signal start_recording_with_nodes(nodes: Array)

var current_selected_node: Node = null
var current_prop_search_term: String = ""

func _ready() -> void:
	var root_node = get_tree().get_root()
	if root_node:
		_populate_node_tree(root_node, tree)
		
	search_bar.text_changed.connect(_on_search_changed)
	select_all_button.pressed.connect(_on_select_all)
	select_none_button.pressed.connect(_on_unselect_all)
	
	search_bar_prop.text_changed.connect(_on_prop_search_changed)
	start_button.pressed.connect(_on_start_button_pressed)

func _populate_node_tree(current_node: Node, tree_control: Tree, parent_item: TreeItem = null) -> void:
	var item: TreeItem
	if parent_item == null:
		item = tree_control.create_item()
		tree_control.set_hide_root(true)
	else:
		item = tree_control.create_item(parent_item)
	
	tree_control.set_columns(2)
	tree.set_column_expand(1, false)
	tree.item_selected.connect(_on_tree_item_selected)
	
	item.set_text(0, "[%s] %s" % [current_node.get_class(), current_node.name])
	
	item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	item.set_checked(1, true)
	item.set_editable(1, true)
	
	item.set_meta("node", current_node)
	item.set_meta("node_path", current_node.get_path())
	# item.set_tooltip_text(0, "%s" % [current_node.get_property_list()])
	# print(current_node.get_property_list())
	# var props := []
	# for p in current_node.get_property_list():
	#	var value = str(current_node.get(p.name))
	#	if value.length() > 50:
	#		value = value.substr(0, 50) + "..."
	#	props.append("%s: %s" % [p.name, value])
	#item.set_tooltip_text(0, "\n".join(props))

	for child in current_node.get_children():
		# Skip the state inspector window and the Autoload itself
		if child.is_in_group("state_inspector"):
			continue
		_populate_node_tree(child, tree_control, item)

func _on_search_changed(search_term: String) -> void:
	search_term = search_term.to_lower()
	var root_item = tree.get_root()
	if root_item:
		_filter_tree(root_item, search_term)
		
func _filter_tree(item: TreeItem, search_term: String) -> bool:
	var matches := search_term == "" or item.get_text(0).to_lower().find(search_term) != -1
	var child_matches := false
	
	var child := item.get_first_child()
	while child:
		if _filter_tree(child, search_term):
			child_matches = true
		child = child.get_next()
		
	var visible := matches or child_matches
	item.set_visible(visible)
	
	return visible
	
func _on_select_all() -> void:
	var root_item = tree.get_root()
	if root_item:
		_set_all_checked(root_item, true)

func _on_unselect_all() -> void:
	var root_item = tree.get_root()
	if root_item:
		_set_all_checked(root_item, false)
		
func _set_all_checked(item: TreeItem, checked: bool) -> void:
	item.set_checked(1, checked)
	
	var child = item.get_first_child()
	while child:
		_set_all_checked(child, checked)
		child = child.get_next()
	
func _on_start_button_pressed() -> void:
	var checked_nodes = get_checked_nodes()
	
	start_recording_with_nodes.emit(checked_nodes)
	
	print("Values are stored for")
	for node in checked_nodes:
		print("[%s] %s" % [node.get_class(), node.name])
		
	self.hide()
	queue_free()
	
func get_checked_nodes() -> Array:
	var checked_nodes = []
	var checked_items = get_checked_items(tree.get_root())
	for item in checked_items:
		checked_nodes.append(item.get_meta("node"))
		
	print(checked_nodes)
	return checked_nodes
	
func get_checked_items(item: TreeItem, results:Array = []) -> Array:
	if item.is_checked(1):
		results.append(item)
	var child := item.get_first_child()
	while child:
		get_checked_items(child, results)
		child = child.get_next()
	return results
	
func _on_tree_item_selected() -> void:
	var item = tree.get_selected()
	if item:
		current_selected_node = item.get_meta("node")
		if current_selected_node:
			titel_prop_label.text = "Properties of " + current_selected_node.name
			_show_props(current_selected_node, current_prop_search_term)
			
func _show_props(node: Node, filter: String = "") -> void:
	var props := []
	filter = filter.to_lower()
	
	for p in node.get_property_list():
		var name = p.name.to_lower()
		
		if filter != "" and name.find(filter) == -1:
			continue
		
		var value = str(node.get(p.name))
		if value.length() > 50:
			value = value.substr(0, 50) + "..."
		props.append("%s: %s" % [p.name, value])
	props_label.text = "\n".join(props)
	
func _on_prop_search_changed(text: String) -> void:
	current_prop_search_term = text
	if current_selected_node:
		_show_props(current_selected_node, text)
