extends Node

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music := AudioStreamPlayer.new()
var _library: Dictionary = {}

func _ready() -> void:
	add_child(_music)
	_music.bus = "Music"
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_preload_all("res://audio/sfx/")
	_apply_volumes()

func _preload_all(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null: return
	for f in dir.get_files():
		if f.ends_with(".wav") or f.ends_with(".ogg") or f.ends_with(".mp3"):
			var key := f.get_basename()
			_library[key] = load(dir_path + f)

func sfx(name: String, pitch_variation := 0.08, volume_db := 0.0) -> void:
	if not _library.has(name): return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = _library[name]
			p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
			p.volume_db = volume_db
			p.play()
			return

func play_music(path: String, volume_db := -6.0) -> void:
	var s := load(path)
	if s == null: return
	_music.stream = s
	_music.volume_db = volume_db
	_music.play()

func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(SaveManager.data.settings.master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),  linear_to_db(SaveManager.data.settings.music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),    linear_to_db(SaveManager.data.settings.sfx_volume))
