extends Node
## Music, the forest bed and the rain. Local to this computer: nothing here
## goes over the network, and every player hears their own shuffle and weather.
##
## Music: a playlist per screen ("menu" = main menu + lobby, "match",
## "game_over"), shuffled. Tracks crossfade into each other (the last
## FADE_SECONDS of one fade out as the next fades in), and when the screen
## changes. A match always opens with MATCH_OPENING.
## Rain: a rain-and-thunder loop that comes and goes during a match. The
## board's RainLayer draws it from `rain_level`, so sound and picture match.
## Settings (on/off + volume for each) are saved in user://settings.cfg.

signal settings_changed
## A lightning flash during heavy rain (RainLayer flashes the board).
signal lightning

## Which tracks play where. Move a file between lists to change where it
## plays; any .ogg / .mp3 / .wav under assets/audio/music works (keep
## them Ogg ~80 kbps: browser players download every file).
const MUSIC := {
	"menu": [
		"res://assets/audio/music/theme.ogg",
		"res://assets/audio/music/oriented.ogg",
	],
	## The end screen (win or lose), repeated until you leave it.
	"game_over": [
		"res://assets/audio/music/evil_apocalypse.ogg",
	],
	"match": [
		"res://assets/audio/music/searching.ogg",
		"res://assets/audio/music/evil_catacombs.ogg",
		"res://assets/audio/music/evil_witchs_lair.ogg",
		"res://assets/audio/music/evil_whispers_from_beyond.ogg",
		"res://assets/audio/music/ghost_land.ogg",
		"res://assets/audio/music/vampires_piano.ogg",
		"res://assets/audio/music/pressure.ogg",
		"res://assets/audio/music/bleeding_out.ogg",
		"res://assets/audio/music/cold_silence.ogg",
		"res://assets/audio/music/wastelands.ogg",
		"res://assets/audio/music/trem_loading_loop.ogg",
	],
}
## Quiet night-forest sound under the menu music (follows the music switch).
## The first track of every match; the "match" list shuffles after it.
const MATCH_OPENING := "res://assets/audio/music/evil_ancient_evil_awakens.ogg"
const FOREST_BED := "res://assets/audio/ambience/forest.ogg"
const RAIN_TRACK := "res://assets/audio/ambience/rain_night.ogg"

const FADE_SECONDS := 4.0
const GAP_SECONDS := 1.0           # only if a track ends without crossfading
const FOREST_GAIN := 0.35          # forest bed loudness, relative to music
## Weather (seconds): how long it stays dry / rains, and the fade between.
const FIRST_RAIN := Vector2(12, 30)
const DRY_TIME := Vector2(45, 100)
const RAIN_TIME := Vector2(40, 90)
const RAIN_RAMP_SECONDS := 10.0
const LIGHTNING_EVERY := Vector2(14, 40)

var music_on := true
var music_volume := 0.6
var rain_on := true
var rain_volume := 0.7

## 0 = dry .. 1 = pouring. Eased; read by RainLayer every frame.
var rain_level := 0.0

var _context := ""
var _bag: Array = []               # tracks left before the playlist repeats
var _last_track := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _gap: SceneTreeTimer
var _forest: AudioStreamPlayer
var _forest_gain := 0.0
var _rain: AudioStreamPlayer
var _rain_target := 0.0
var _weather_timer := 0.0
var _lightning_timer := 0.0
var _enabled := true


func _ready() -> void:
	# A dedicated room server has no speakers.
	if RoomServer.wanted():
		_enabled = false
		set_process(false)
		return
	_load_settings()
	for i in 2:
		var p := _make_player("Music")
		p.finished.connect(_on_track_finished.bind(p))
		_players.append(p)
	_forest = _make_player("Music")
	_rain = _make_player("Rain")
	_apply_volumes()


## Which screen we're on: "menu" (menu + lobby) or "match". Same screen
## again keeps the current track playing.
func set_screen(screen: String) -> void:
	if not _enabled or screen == _context:
		return
	_context = screen
	_bag.clear()
	if screen == "match":
		_bag = [MATCH_OPENING]  # played first; the shuffle refills after it
	_weather_timer = randf_range(FIRST_RAIN.x, FIRST_RAIN.y)
	_rain_target = 0.0
	_next_track()


func set_music_on(on: bool) -> void:
	if on == music_on:
		return
	music_on = on
	if on:
		_next_track()
	else:
		for p in _players:
			_fade(p, 0.0, true)
	_changed()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_changed()


func set_rain_on(on: bool) -> void:
	if on == rain_on:
		return
	rain_on = on
	_changed()


func set_rain_volume(v: float) -> void:
	rain_volume = clampf(v, 0.0, 1.0)
	_changed()


# --- Music ----------------------------------------------------------------

func _next_track() -> void:
	_gap = null
	var list: Array = MUSIC.get(_context, [])
	if not music_on or list.is_empty():
		return
	if _bag.is_empty():
		_bag = list.duplicate()
		_bag.shuffle()
		if _bag.size() > 1 and _bag[-1] == _last_track:
			_bag.reverse()  # never the same track twice in a row
	var path: String = _bag.pop_back()
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("Audio: can't load " + path)
		return
	_last_track = path
	var old := _players[_active]
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.set_meta("ending", false)
	p.set_meta("gain", 0.0)
	p.volume_db = -80.0
	p.play()
	_fade(p, 1.0)
	if old.playing:
		_fade(old, 0.0, true)


## Near the end of the current track, start the next one: they crossfade.
func _check_track_end() -> void:
	if not music_on or _players.is_empty():
		return
	var p := _players[_active]
	if not p.playing or p.stream == null or p.get_meta("ending", false):
		return
	var length := p.stream.get_length()
	if length > FADE_SECONDS * 3.0 and length - p.get_playback_position() <= FADE_SECONDS:
		p.set_meta("ending", true)
		_next_track()


func _on_track_finished(p: AudioStreamPlayer) -> void:
	if p != _players[_active] or not music_on:
		return
	var gap := get_tree().create_timer(GAP_SECONDS)
	_gap = gap
	gap.timeout.connect(func():
		if _gap == gap:
			_next_track())


## Fades a music player's gain (0..1) on top of the Music bus volume.
func _fade(p: AudioStreamPlayer, to: float, stop_after := false) -> void:
	var previous: Tween = p.get_meta("tween") if p.has_meta("tween") else null
	if previous and previous.is_valid():
		previous.kill()  # a player reused mid fade-out: only the new fade counts
	var tween := p.create_tween()
	p.set_meta("tween", tween)
	tween.tween_method(func(g: float):
		p.set_meta("gain", g)
		p.volume_db = linear_to_db(maxf(g, 0.0001)),
		float(p.get_meta("gain", 0.0)), to, FADE_SECONDS)
	if stop_after:
		tween.tween_callback(p.stop)


# --- Forest bed and rain ----------------------------------------------------

func _process(delta: float) -> void:
	_check_track_end()
	var in_match := _context == "match"
	_update_forest(delta, _context == "menu" and music_on)
	if in_match and rain_on:
		_weather_timer -= delta
		if _weather_timer <= 0.0:
			if _rain_target > 0.0:
				_rain_target = 0.0
				_weather_timer = randf_range(DRY_TIME.x, DRY_TIME.y)
			else:
				_rain_target = randf_range(0.6, 1.0)
				_weather_timer = randf_range(RAIN_TIME.x, RAIN_TIME.y)
				_lightning_timer = randf_range(LIGHTNING_EVERY.x, LIGHTNING_EVERY.y)
	var target := _rain_target if in_match and rain_on else 0.0
	# Switched off or match over: stop within a few seconds, not ten.
	var ramp := RAIN_RAMP_SECONDS if in_match and rain_on else 3.0
	rain_level = move_toward(rain_level, target, delta / ramp)
	_update_rain_sound()
	if rain_level > 0.75:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			_lightning_timer = randf_range(LIGHTNING_EVERY.x, LIGHTNING_EVERY.y)
			lightning.emit()


func _update_forest(delta: float, wanted: bool) -> void:
	_forest_gain = move_toward(_forest_gain, FOREST_GAIN if wanted else 0.0, delta / FADE_SECONDS)
	if _forest_gain <= 0.0:
		if _forest.playing:
			_forest.stop()
		return
	if not _forest.playing:
		_forest.stream = _looping(FOREST_BED)
		if _forest.stream == null:
			return
		_forest.play(randf() * _forest.stream.get_length())
	_forest.volume_db = linear_to_db(_forest_gain)


func _update_rain_sound() -> void:
	if rain_level <= 0.0:
		if _rain.playing:
			_rain.stop()
		return
	if not _rain.playing:
		_rain.stream = _looping(RAIN_TRACK)
		if _rain.stream == null:
			return
		# Start somewhere new each time, so the thunder isn't always the same.
		_rain.play(randf() * _rain.stream.get_length())
	_rain.volume_db = linear_to_db(maxf(rain_level * rain_volume, 0.0001))


func _looping(path: String) -> AudioStream:
	var stream = load(path)
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	return stream


# --- Buses and settings -------------------------------------------------------

func _make_player(bus: String) -> AudioStreamPlayer:
	if AudioServer.get_bus_index(bus) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _apply_volumes() -> void:
	var i := AudioServer.get_bus_index("Music")
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(music_volume, 0.0001)))


func _changed() -> void:
	_save_settings()
	settings_changed.emit()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(Global.SETTINGS_PATH) != OK:
		return
	music_on = config.get_value("audio", "music_on", music_on)
	music_volume = config.get_value("audio", "music_volume", music_volume)
	rain_on = config.get_value("audio", "rain_on", rain_on)
	rain_volume = config.get_value("audio", "rain_volume", rain_volume)


func _save_settings() -> void:
	if not Global.persist_settings:
		return
	var config := ConfigFile.new()
	config.load(Global.SETTINGS_PATH)
	config.set_value("audio", "music_on", music_on)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "rain_on", rain_on)
	config.set_value("audio", "rain_volume", rain_volume)
	config.save(Global.SETTINGS_PATH)
