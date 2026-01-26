@tool
class_name EditorPanel
extends Control

signal run_test(test: TestCase)
signal delete_test(test: TestCase)
signal refresh_requested()

@onready var test_table: TestSelectionTable = %TestSelection 
@onready var details_root: Control = %RightPanel
@onready var details_content: VBoxContainer = %Details
@onready var empty_label: Label = %NoSelection

func _ready() -> void:
	if test_table:
		test_table.run_test.connect(func(test): run_test.emit(test))
		
		test_table.delete_test.connect(_confirm_delete)
		
		test_table.selected_test.connect(_display_details)
		
		if test_table.has_signal("refresh_requested"):
			test_table.refresh_requested.connect(func(): refresh_requested.emit())


func set_tests(tests: Array[TestCase]) -> void:
	if test_table:
		test_table.set_tests(tests)

func _confirm_delete(test: TestCase):
	var confirm = ConfirmationDialog.new()
	confirm.title = "Delete Test Case?"
	confirm.dialog_text = "Are you sure you want to delete '%s'?\nThis action cannot be undone." % test.name
	
	confirm.confirmed.connect(func(): 
		delete_test.emit(test)
		confirm.queue_free()
	)
	confirm.canceled.connect(confirm.queue_free)
	
	add_child(confirm)
	confirm.popup_centered()

func _display_details(test: TestCase):
	_clear_details()
	empty_label.visible = false
	details_content.visible = true
	
	var title = Label.new()
	title.text = test.name
	title.add_theme_font_size_override("font_size", 18)
	details_content.add_child(title)
	
	var path_lbl = Label.new()
	path_lbl.text = test.path
	path_lbl.modulate = Color(1,1,1,0.5)
	details_content.add_child(path_lbl)
	
	details_content.add_child(HSeparator.new())
	
	var report: TestReport = test.get_report()
	
	if report:
		var log_box = TextEdit.new()
		log_box.editable = false
		log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		log_box.add_theme_color_override("font_readonly_color", Color(0.9, 0.9, 0.9))
		log_box.text = report.get_text()
		details_content.add_child(log_box)
	else:
		var info = Label.new()
		info.text = "No run logs available.\nRun the test to generate a report."
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.modulate = Color(1,1,1,0.5)
		details_content.add_child(info)

func _clear_details():
	for c in details_content.get_children():
		c.queue_free()
	details_content.visible = false
	empty_label.visible = true
