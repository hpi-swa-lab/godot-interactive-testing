@tool
class_name TestSelectionTable
extends VBoxContainer

signal run_test(test: TestCase)
signal delete_test(test: TestCase)
signal selected_test(test: TestCase)
signal refresh_requested()

@onready var search_bar: LineEdit = %Searchbar
@onready var reload_button: Button = %Reload
@onready var tree: Tree = %Tree

var icon_pass: Texture2D = load("uid://kj1ntmlawmfi")
var icon_fail: Texture2D = load("uid://jieyta3tx1p4")
var icon_unknown: Texture2D = load("uid://cmjqb4lvgammq")
var icon_play: Texture2D = load("uid://cexm0m8ha0pkg")
var icon_delete: Texture2D = load("uid://bm24rlnvgxydn")

var _all_tests: Array[TestCase] = [] 
var _current_filter: String = ""
var _last_selected: TestCase = null 

func _ready() -> void:
	tree.columns = 5
	tree.column_titles_visible = true
	
	tree.set_column_title(0, "") 
	tree.set_column_title(1, "Name")
	tree.set_column_title(2, "Created")
	tree.set_column_title(3, "Last Run")
	tree.set_column_title(4, "Actions")
	
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 30)
	
	tree.set_column_expand(1, true)
	
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 90)
	
	tree.set_column_expand(3, false)
	tree.set_column_custom_minimum_width(3, 90) 
	
	tree.set_column_expand(4, false)
	tree.set_column_custom_minimum_width(4, 50)

	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	
	tree.item_selected.connect(_on_item_selected)
	tree.button_clicked.connect(_on_button_clicked)
	
	if search_bar:
		search_bar.text_changed.connect(_on_search_text_changed)
		
	if reload_button:
		reload_button.pressed.connect(func(): refresh_requested.emit())

func set_tests(tests: Array[TestCase]) -> void:
	_all_tests = tests
	_refresh_view()

func _on_search_text_changed(text: String) -> void:
	_current_filter = text.to_lower()
	_refresh_view()

func _refresh_view() -> void:
	# Preserve selection if possible
	var selected_item = tree.get_selected()
	if selected_item:
		var meta = selected_item.get_metadata(0)
		if meta: _last_selected = meta

	tree.clear()
	var root = tree.create_item()
	
	for test in _all_tests:
		if not _current_filter.is_empty() and not _current_filter in test.name.to_lower():
			continue

		var item = tree.create_item(root)
		item.set_metadata(0, test)

		var status_icon = icon_unknown
		var tooltip = "Not run yet"

		if test.run_status == TestCase.RunStatus.PASSED:
			status_icon = icon_pass
			tooltip = "Passed"
		elif test.run_status == TestCase.RunStatus.FAILED: 
			status_icon = icon_fail
			tooltip = "Failed"

		if status_icon: item.set_icon(0, status_icon)
		item.set_tooltip_text(0, tooltip)

		# Name
		item.set_text(1, test.name)
		item.set_tooltip_text(1, test.path)

		# Created
		var created_at = _format_timestamp(test.created_at)
		item.set_text(2, created_at)
		
		# Last Run
		var last_run_at = "-"
		if test.last_run_at > 0:
			last_run_at = _format_timestamp(test.last_run_at)
			
		item.set_text(3, last_run_at)

		# Actions
		if icon_play: item.add_button(4, icon_play, 0, false, "Run")
		if icon_delete: item.add_button(4, icon_delete, 1, false, "Delete")
		
		# Restore Selection
		if _last_selected and test.path == _last_selected.path:
			item.select(0)
			_last_selected = test 
			selected_test.emit.call_deferred(test)

func _on_item_selected() -> void:
	var item = tree.get_selected()
	if not item: return
	var test = item.get_metadata(0) as TestCase
	if test:
		_last_selected = test
		selected_test.emit(test)

func _on_button_clicked(item: TreeItem, column: int, id: int, mouse_idx: int) -> void:
	var test = item.get_metadata(0) as TestCase
	if not test: return

	if id == 0: 
		run_test.emit(test)
	elif id == 1: 
		delete_test.emit(test)

func _format_timestamp(unix_time: float) -> String:
	if unix_time == 0: return "-"
	var dt = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d/%02d %02d:%02d" % [dt.day, dt.month, dt.hour, dt.minute]
