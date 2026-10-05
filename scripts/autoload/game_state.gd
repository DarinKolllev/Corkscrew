extends Node
## Current run state: timer + combo-based score system.

signal move_scored(move_id: String, points: int, multiplier: float)
signal combo_changed(count: int, multiplier: float)
signal run_started(level_id: String)
signal run_finished(level_id: String, time: float, score: int, results: Dictionary)

# --- Score config ---
const MOVE_POINTS := {
	"jump":        10,
	"slide":       25,
	"vault_forward": 50,
	"vault_left":  60,
	"vault_right": 60,
	"mantle":      75,
	"wallrun":    100,   # per entry, not per second
	"walljump":   120,
	"ledge_grab":  80,
	"ledge_climb": 60,
	"shimmy":       5,
}
const COMBO_WINDOW := 2.5          # seconds between moves to keep combo alive
const COMBO_STEP := 0.15           # +15% multiplier per combo hit
const COMBO_MAX := 4.0             # cap multiplier at 4x

var current_level_id: String = ""
var _start_ms: int = 0
var score: int = 0
var combo: int = 0
var _last_move_ms: int = -9999
var is_running := false

# ---------- Run lifecycle ----------
func start_run(level_id: String) -> void:
	current_level_id = level_id
	_start_ms = Time.get_ticks_msec()
	score = 0
	combo = 0
	is_running = true
	run_started.emit(level_id)

func finish_run() -> Dictionary:
	print("finish_run() called by:")
	print(get_stack())
	var t := elapsed()
	if t < 2.0:
		print("finish_run ignored: elapsed only %.2f s" % t)
		return {"ignored": true}
	is_running = false
	is_running = false
	# Time bonus: faster = more points. 1000 bonus @ 30s, scales inversely.
	var time_bonus := int(max(0.0, 30.0 / max(t, 1.0) * 1000.0))
	score += time_bonus
	var results := SaveManager.record_run(current_level_id, t, score)
	results["time_bonus"] = time_bonus
	results["final_score"] = score
	results["final_time"] = t
	run_finished.emit(current_level_id, t, score, results)
	SaveManager.save()   # flush move counts too
	return results

func elapsed() -> float:
	if not is_running: return 0.0
	return (Time.get_ticks_msec() - _start_ms) / 1000.0

# ---------- Scoring ----------
func report_move(move_id: String) -> void:
	SaveManager.count_move(move_id)
	if not is_running: return
	var base: int = MOVE_POINTS.get(move_id, 10)

	# Combo logic: within window extends the chain
	var now := Time.get_ticks_msec()
	if now - _last_move_ms <= int(COMBO_WINDOW * 1000):
		combo += 1
	else:
		combo = 1
	_last_move_ms = now

	var mult := clampf(1.0 + (combo - 1) * COMBO_STEP, 1.0, COMBO_MAX)
	var points := int(round(base * mult))
	score += points

	move_scored.emit(move_id, points, mult)
	combo_changed.emit(combo, mult)

func _process(_dt: float) -> void:
	# Decay combo visually after window expires
	if combo > 0 and Time.get_ticks_msec() - _last_move_ms > int(COMBO_WINDOW * 1000):
		combo = 0
		combo_changed.emit(0, 1.0)
