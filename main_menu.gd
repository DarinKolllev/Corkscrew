extends Control

@export var level_scene: PackedScene   # drag world.tscn here in Inspector

func _ready() -> void:
	print(">>> Script running on node: ", name, " (type: ", get_class(), ")")
	print(">>> Direct children: ", get_children().map(func(c): return c.name))
	var vb := get_node_or_null("VBox")
	if vb:
		print(">>> VBox children: ", vb.get_children().map(func(c): return c.name))
	else:
		print(">>> VBox NOT FOUND")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_wire("VBox/PlayBtn", _play)
	_wire("VBox/ContinueBtn", _play)
	_wire("VBox/SettingsBtn", func(): print("Settings TODO"))
	_wire("VBox/QuitBtn", func(): get_tree().quit())

	var best := get_node_or_null("BestTime") as Label
	if best:
		var rec: Dictionary = SaveManager.get_level_record("tutorial")
		if rec.completed:
			best.text = "Tutorial  —  best %.2fs   score %d" % [rec.best_time, rec.best_score]
		else:
			best.text = "Tutorial  —  not completed"
		var cont := get_node_or_null("VBox/ContinueBtn") as Button
		if cont: cont.disabled = not rec.completed

func _wire(path: String, cb: Callable) -> void:
	var btn := get_node_or_null(path) as Button
	if btn:
		btn.pressed.connect(cb)
	else:
		push_warning("MainMenu: node not found at " + path)

func _play() -> void:
	print(">>> Play clicked, loading world.tscn")
	get_tree().change_scene_to_file("res://world.tscn")
