extends Node

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music := AudioStreamPlayer.new()
var _library: Dictionary = {}
var _loop_player := AudioStreamPlayer.new()

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	add_child(_music)
	_music.bus = "Music"
	add_child(_loop_player)
	_loop_player.bus = "SFX"
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_preload_all("res://audio/sfx/")
	_apply_volumes()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _preload_all(dir_path: String) -> void:
	for f in ResourceLoader.list_directory(dir_path):
		if f.ends_with(".wav") or f.ends_with(".ogg") or f.ends_with(".mp3"):
			_library[f.get_basename()] = load(dir_path + f)

func sfx(name: String, pitch_variation := 0.08, volume_db := 0.0) -> void:
	if not _library.has(name): return
	var p: AudioStreamPlayer = null
	for candidate in _sfx_pool:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		p = _sfx_pool[0]
		for candidate in _sfx_pool:
			if candidate.get_playback_position() > p.get_playback_position():
				p = candidate
	p.stream = _library[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.volume_db = volume_db
	p.play()

func set_loop(name: String, on: bool, volume_db := -6.0, pitch := 1.0) -> void:
	if not on or not _library.has(name):
		if _loop_player.playing: _loop_player.stop()
		return
	if _loop_player.stream != _library[name]:
		_loop_player.stream = _library[name]
	_loop_player.volume_db = volume_db
	_loop_player.pitch_scale = pitch
	if not _loop_player.playing:
		_loop_player.play()

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
