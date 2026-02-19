class_name TestReportWindow
extends Window

const COLOR_PASS = Color(0.2, 0.7, 0.35)
const COLOR_FAIL = Color(0.85, 0.3, 0.3)
const COLOR_MUTED = Color(0.6, 0.6, 0.6)

@onready var tree: Tree = %Tree
@onready var lbl_total: Label = %TotalTests
@onready var lbl_passed: Label = %PassedTests
@onready var lbl_failed: Label = %FailedTests
@onready var search_bar: LineEdit = %Searchbar

@onready var btn_all: Button = %ShowAll
@onready var btn_pass: Button = %ShowPassed
@onready var btn_fail: Button = %ShowFailed

var current_report: TestReport
var _filter_text: String = ""
var _filter_mode: String = "all"  

var icon_pass: Texture2D = load("uid://kj1ntmlawmfi")
var icon_fail: Texture2D = load("uid://jieyta3tx1p4")

func _ready() -> void:
	close_requested.connect(queue_free)
	
	_setup_tree_columns()
	
	if search_bar:
		search_bar.text_changed.connect(_on_search_text_changed)
		
	if btn_all: 
		btn_all.pressed.connect(func(): _set_filter_mode("all"))
		btn_all.button_pressed = true
		
	if btn_pass: 
		btn_pass.pressed.connect(func(): _set_filter_mode("passed"))
		
	if btn_fail: 
		btn_fail.pressed.connect(func(): _set_filter_mode("failed"))
	
func display_report(report: TestReport) -> void:
	current_report = report
	
	lbl_total.text = str(report.total_checks)
	lbl_passed.text = str(report.passed_count)
	lbl_failed.text = str(report.failed_count)
	
	lbl_passed.add_theme_color_override("font_color", COLOR_PASS)
	lbl_failed.add_theme_color_override("font_color", COLOR_FAIL if report.failed_count > 0 else COLOR_MUTED)
	
	_refresh_tree()
	
	popup_centered()

func _setup_tree_columns() -> void:
	tree.clear()
	tree.columns = 3
	tree.column_titles_visible = true
	
	tree.set_column_title(0, "Node / Check")
	tree.set_column_title(1, "Status")
	tree.set_column_title(2, "Details")
	
	tree.set_column_expand(0, true)
	tree.set_column_custom_minimum_width(0, 250)
	
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 80)
	
	tree.set_column_expand(2, true)
	tree.set_column_custom_minimum_width(2, 200)
	
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW

func _on_search_text_changed(new_text: String) -> void:
	_filter_text = new_text.to_lower()
	_refresh_tree()

func _set_filter_mode(mode: String) -> void:
	_filter_mode = mode
	_refresh_tree()

func _refresh_tree() -> void:
	tree.clear()
	if not current_report: return
	
	var root = tree.create_item() 
	
	for entry in current_report.results:
		if _filter_mode == "passed" and not entry.is_passed: continue
		if _filter_mode == "failed" and entry.is_passed: continue
		
		var show_entire_node = false
		var visible_checks = []
		
		if _filter_text.is_empty():
			show_entire_node = true
			visible_checks = entry.checks
		else:
			var parent_search_source = (entry.node_name + " " + entry.node_type).to_lower()
			
			if _filter_text in parent_search_source:
				show_entire_node = true
				visible_checks = entry.checks
			else:
				for check in entry.checks:
					var c_name = check.get("name", "").to_lower()
					
					if _filter_text in c_name:
						visible_checks.append(check)
				
				if not visible_checks.is_empty():
					show_entire_node = true

		if not show_entire_node:
			continue
		
		var node_item = tree.create_item(root)
		
		node_item.set_text(0, "%s (%s)" % [entry.node_name, entry.node_type])
		node_item.set_tooltip_text(0, "Node ID: %d" % entry.node_id)
		
		if entry.is_passed:
			node_item.set_text(1, "PASS")
			node_item.set_custom_color(1, COLOR_PASS)
			if icon_pass: node_item.set_icon(1, icon_pass)
			
			node_item.collapsed = _filter_text.is_empty() 
		else:
			node_item.set_text(1, "FAIL")
			node_item.set_custom_color(1, COLOR_FAIL)
			if icon_fail: node_item.set_icon(1, icon_fail)
			node_item.collapsed = false 
		
		if not entry.is_passed and not entry.failure_reason.is_empty():
			node_item.set_text(2, entry.failure_reason)
			node_item.set_custom_color(2, COLOR_FAIL)
		
		for check in visible_checks:
			var check_item = tree.create_item(node_item)
			
			var c_name = check.get("name", "Unknown")
			var c_passed = check.get("passed", false)
			var c_expected = check.get("expected", "N/A")
			var c_actual = check.get("actual", "N/A")
			var c_type = check.get("type", "property")
			
			if c_type == "status":
				check_item.set_text(0, "Node Status Check")
			else:
				check_item.set_text(0, "Property: " + c_name)
			
			if c_passed:
				check_item.set_text(1, "OK")
				check_item.set_custom_color(1, COLOR_PASS)
			else:
				check_item.set_text(1, "FAIL")
				check_item.set_custom_color(1, COLOR_FAIL)
			
			# Details
			if c_passed:
				check_item.set_text(2, str(c_actual))
				check_item.set_custom_color(2, COLOR_MUTED)
			else:
				check_item.set_text(2, "Exp: %s | Got: %s" % [str(c_expected), str(c_actual)])
				check_item.set_custom_color(2, COLOR_FAIL)
