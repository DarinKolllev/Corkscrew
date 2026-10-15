extends CanvasLayer

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while tree is paused
	$Panel/VBox/ResumeBtn.pressed.connect(_resume)
	$Panel/VBox/RestartBtn.pressed.connect(_restart)
	$Panel/VBox/MenuBtn.pressed.connect(_main_menu)
	$Panel/VBox/QuitBtn.pressed.connect(func(): get_tree().quit())

func open() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")
