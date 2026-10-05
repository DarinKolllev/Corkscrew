extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameState.start_run("tutorial")
	print(">>> Run started on level: ", GameState.current_level_id)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
