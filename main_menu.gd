extends Control

@export var level_scene: PackedScene   # drag world.tscn here in Inspector

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	$VBox/PlayBtn.pressed.connect(_play)
	$VBox/ContinueBtn.pressed.connect(_play)   # same for now; later: last-played level
	$VBox/SettingsBtn.pressed.connect(func(): print("Settings panel TODO"))
	$VBox/QuitBtn.pressed.connect(func(): get_tree().quit())

	var rec: Dictionary = SaveManager.get_level_record("tutorial")
	if rec.completed:
		$BestTime.text = "Tutorial  —  best %.2fs   score %d" % [rec.best_time, rec.best_score]
	else:
		$BestTime.text = "Tutorial  —  not completed"
	$VBox/ContinueBtn.disabled = not rec.completed

func _play() -> void:
	get_tree().change_scene_to_packed(level_scene)
