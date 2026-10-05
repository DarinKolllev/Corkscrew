extends Node
## JSON save file at user://save.json
## Access via SaveManager.data (dictionary)

const SAVE_PATH := "user://save.json"

var data: Dictionary = {
	"version": 1,
	"unlocked_moves": ["run", "jump", "sprint", "slide"],
	"levels": {},   # { "tutorial": {"completed": true, "best_time": 42.1, "best_score": 1200} }
	"settings": {
		"mouse_sensitivity": 0.003,
		"fov": 90.0,
		"master_volume": 1.0,
		"music_volume": 0.7,
		"sfx_volume": 1.0,
	},
	"stats": {
		"total_playtime": 0.0,
		"moves_performed": {},   # { "vault_right": 12, "wallrun": 7, ... }
	},
}

func _ready() -> void:
	print("SaveManager loading from: ", ProjectSettings.globalize_path(SAVE_PATH))
	_load()
	print("SaveManager loaded. Levels in save: ", data.levels.keys())

# ---------- Public API ----------
func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func unlock_move(move_id: String) -> void:
	if move_id not in data.unlocked_moves:
		data.unlocked_moves.append(move_id)
		save()

func has_move(move_id: String) -> bool:
	return move_id in data.unlocked_moves

func record_run(level_id: String, time: float, score: int) -> Dictionary:
	# Returns {"new_best_time": bool, "new_best_score": bool}
	if time < 2.0:
		return {"new_best_time": false, "new_best_score": false, "rejected": true}
	var lv: Dictionary = data.levels.get(level_id, {
		"completed": false, "best_time": 99999.0, "best_score": 0
	})
	var new_time = time < lv.best_time
	var new_score = score > lv.best_score
	lv.completed = true
	if new_time:  lv.best_time = time
	if new_score: lv.best_score = score
	data.levels[level_id] = lv
	save()
	return {"new_best_time": new_time, "new_best_score": new_score}

func get_level_record(level_id: String) -> Dictionary:
	return data.levels.get(level_id, {"completed": false, "best_time": 0.0, "best_score": 0})

func count_move(move_id: String) -> void:
	var m: Dictionary = data.stats.moves_performed
	m[move_id] = int(m.get(move_id, 0)) + 1
	# don't save on every move — too much disk I/O

func reset_progress() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	_load()

# ---------- Internal ----------
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save(); return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f: return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_merge(data, parsed)

func _merge(base: Dictionary, other: Dictionary) -> void:
	# Keep new default keys when loading older saves
	for k in other.keys():
		if base.has(k) and typeof(base[k]) == TYPE_DICTIONARY and typeof(other[k]) == TYPE_DICTIONARY:
			_merge(base[k], other[k])
		else:
			base[k] = other[k]
