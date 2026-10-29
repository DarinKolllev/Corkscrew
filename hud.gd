extends CanvasLayer

@onready var _timer: Label = $Timer
@onready var _score: Label = $Score
@onready var _combo_mult: Label = $ComboBox/ComboMult
@onready var _combo_count: Label = $ComboBox/ComboCount
@onready var _speed: Label = $Speed
@onready var _popup_layer: Control = $PopupLayer

@export var player_path: NodePath   # drag your player node here

var _player: CharacterBody3D

func _ready() -> void:
	_player = get_node_or_null(player_path)
	GameState.move_scored.connect(_on_move_scored)
	GameState.combo_changed.connect(_on_combo_changed)
	_combo_mult.text = ""
	_combo_count.text = ""

func _process(_dt: float) -> void:
	_timer.text = "%.2fs" % GameState.elapsed()
	_score.text = str(GameState.score)
	if _player:
		var s := Vector3(_player.velocity.x, 0, _player.velocity.z).length()
		_speed.text = "%.1f m/s" % s

func _on_combo_changed(count: int, mult: float) -> void:
	if count <= 1:
		_combo_mult.text = ""
		_combo_count.text = ""
	else:
		_combo_mult.text = "x%.2f" % mult
		_combo_count.text = "%d chain" % count
		# Little pop animation
		_combo_mult.scale = Vector2(1.4, 1.4)
		var tw := create_tween()
		tw.tween_property(_combo_mult, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

func _on_move_scored(move_id: String, points: int, mult: float) -> void:
	var popup := Label.new()
	popup.text = "+%d  %s" % [points, move_id.replace("_", " ").to_upper()]
	popup.add_theme_font_size_override("font_size", 28)
	popup.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	popup.position = Vector2(
		get_viewport().get_visible_rect().size.x * 0.5 - 120 + randf_range(-20, 20),
		get_viewport().get_visible_rect().size.y * 0.5 + 40
	)
	popup.modulate.a = 0.0
	_popup_layer.add_child(popup)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(popup, "modulate:a", 1.0, 0.15)
	tw.tween_property(popup, "position:y", popup.position.y - 80.0, 1.0)
	tw.chain().tween_property(popup, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(popup.queue_free)
