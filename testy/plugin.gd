@tool
extends EditorPlugin

const AUTOLOAD_NAME = "testy"
const AUTOLOAD_PATH = "res://addons/testy/autoload.gd"
const EDITOR_PANEL_SCENE = preload("uid://trage80n575f")

var editor_panel: EditorPanel
var runner: Runner 
var test_manager: TestManager

func _enter_tree() -> void:
	_add_autoload()
	_init_runner()
	
	test_manager = TestManager.new()
	
	_setup_ui()
	
	call_deferred("_refresh_tests_data")

func _exit_tree() -> void:
	_remove_autoload()
	_remove_ui()
	_free_runner()

func _enable_plugin() -> void:
	_add_autoload()

func _disable_plugin() -> void:
	_remove_autoload()

func _init_runner() -> void:
	if not runner:
		runner = Runner.new()
		runner.finished.connect(_on_test_finished)

func _free_runner() -> void:
	if runner:
		runner.free()
		runner = null

func _add_autoload():
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _remove_autoload():
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)

func _setup_ui():
	editor_panel = EDITOR_PANEL_SCENE.instantiate()
	
	if editor_panel:
		editor_panel.run_test.connect(_on_run_test_requested)
		editor_panel.delete_test.connect(_on_delete_test_requested)
		editor_panel.refresh_requested.connect(_refresh_tests_data)
		
		add_control_to_bottom_panel(editor_panel, "testy")

func _remove_ui():
	if editor_panel:
		remove_control_from_bottom_panel(editor_panel)
		editor_panel.queue_free()
		editor_panel = null

func _refresh_tests_data() -> void:
	if not editor_panel: return

	var tests = test_manager.get_tests()
	editor_panel.set_tests(tests)

func _on_run_test_requested(test: TestCase):
	if runner:
		runner.run_test(test)

func _on_delete_test_requested(test: TestCase):
	test_manager.delete(test)
	_refresh_tests_data()

func _on_test_finished(test: TestCase):
	call_deferred("_refresh_tests_data")
