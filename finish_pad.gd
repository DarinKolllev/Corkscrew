extends Area3D

@export var next_scene_path := ""   # leave empty to return to main menu

@onready var _ring: MeshInstance3D = $Ring if has_node("Ring") else null
var _triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _ring:
		_ring.rotate_y(delta * 1.5)

func _on_body_entered(body: Node) -> void:
	if _triggered or not body is CharacterBody3D:
		return
	_triggered = true
	AudioManager.sfx("climb", 0.0, 2.0)   # reuse any upbeat SFX
	var r: Dictionary = GameState.finish_run()
	if r.get("ignored", false):
		_triggered = false
		return
	_show_results(r)

func _show_results(r: Dictionary) -> void:
	var results := preload("res://results_screen.tscn").instantiate()
	get_tree().current_scene.add_child(results)
	results.setup(r, next_scene_path)
