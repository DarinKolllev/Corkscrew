extends CanvasLayer

@onready var _title: Label = $Panel/VBox/Title
@onready var _time_lbl: Label = $Panel/VBox/TimeLabel
@onready var _score_lbl: Label = $Panel/VBox/ScoreLabel
@onready var _record_lbl: Label = $Panel/VBox/RecordLabel
@onready var _restart_btn: Button = $Panel/VBox/RestartBtn
@onready var _menu_btn: Button = $Panel/VBox/MenuBtn

var _next_scene := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_restart_btn.pressed.connect(_restart)
	_menu_btn.pressed.connect(_menu)

func setup(r: Dictionary, next_scene_path: String) -> void:
	_next_scene = next_scene_path
	_time_lbl.text = "Time:  %.2fs" % r.final_time
	_score_lbl.text = "Score: %d  (bonus +%d)" % [r.final_score, r.time_bonus]
	var msg := ""
	if r.get("new_best_time", false): msg += "NEW BEST TIME!  "
	if r.get("new_best_score", false): msg += "NEW HIGH SCORE!"
	_record_lbl.text = msg if msg != "" else ""
	_record_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")
