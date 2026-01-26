class_name OverviewWindow
extends Window

signal run_test(test: TestCase)
signal delete_test(test: TestCase)
signal start_recording()
signal reload_tests()

var confirm_delete_popup: AcceptDialog
var _test_to_delete: TestCase = null 

var tests: Array[TestCase]
@onready var test_selection_table: TestSelectionTable = %TestSelection
@onready var start_recording_button: Button = %StartRecording

func _ready() -> void:
	test_selection_table.run_test.connect(run_test.emit)
	test_selection_table.delete_test.connect(_on_delete_requested)
	test_selection_table.refresh_requested.connect(reload_tests.emit)
	start_recording_button.pressed.connect(start_recording.emit)
	close_requested.connect(queue_free)

func set_tests(tests: Array[TestCase]):
	self.tests = tests
	if test_selection_table:
		test_selection_table.set_tests(tests)

func _on_delete_requested(test: TestCase):
	_test_to_delete = test
	_spawn_confirm_delete()

func _spawn_confirm_delete():
	if confirm_delete_popup: confirm_delete_popup.queue_free()

	# Use ConfirmationDialog (standard for Yes/No)
	confirm_delete_popup = ConfirmationDialog.new() 
	confirm_delete_popup.title = "Delete Test Case?"
	
	add_child(confirm_delete_popup)
	
	confirm_delete_popup.transient = true
	confirm_delete_popup.exclusive = true
	confirm_delete_popup.always_on_top = true
	
	confirm_delete_popup.size = Vector2(350, 100)
	
	confirm_delete_popup.dialog_text = "Are you sure you want to delete '%s'?\nThis action cannot be undone." % _test_to_delete.name
	
	confirm_delete_popup.confirmed.connect(_on_delete_confirmed)
	confirm_delete_popup.canceled.connect(_on_delete_canceled)
	
	confirm_delete_popup.popup_centered()

func _on_delete_confirmed():
	if _test_to_delete:
		delete_test.emit(_test_to_delete)
		_test_to_delete = null
	
	if confirm_delete_popup:
		confirm_delete_popup.queue_free()

func _on_delete_canceled():
	_test_to_delete = null
	if confirm_delete_popup:
		confirm_delete_popup.queue_free()
