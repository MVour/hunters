class_name RainLayer extends Node2D
## Rain over the board (above pawns, below the HUD): falling streaks, small
## splashes where they land, a darker, bluer night, and the odd lightning
## flash. Follows Audio.rain_level, so it comes and goes with the rain sound.
## Purely visual and local; it never catches clicks.

const SCREEN := Vector2(1920, 1080)
const MAX_DROPS := 320
const WIND := Vector2(-0.18, 1.0)        # falling direction (slightly left)
const DROP_SPEED := Vector2(1100, 1600)  # px/s, min..max
const DROP_LENGTH := Vector2(18, 34)
const DROP_COLOR := Color(0.72, 0.82, 1.0, 0.33)
const SPLASH_COLOR := Color(0.78, 0.86, 1.0, 0.45)
const SPLASH_TIME := 0.18
const TINT := Color(0.03, 0.05, 0.12, 0.26)   # at full rain
const PIXEL := 4.0                             # matches the forest's art pixels

## Each drop: [position, speed, length, ground y]. Drops land anywhere on the
## board (it's seen from above), each at its own random "ground" height.
var _drops: Array = []
## Each splash: [position, age].
var _splashes: Array = []
var _flash := 0.0


func _ready() -> void:
	z_index = 0
	for i in MAX_DROPS:
		_drops.append(_new_drop(true))
	Audio.lightning.connect(_on_lightning)


func _process(delta: float) -> void:
	var level := Audio.rain_level
	var active := int(MAX_DROPS * level)
	for i in _drops.size():
		var d: Array = _drops[i]
		d[0] += WIND * d[1] * delta
		if d[0].y >= d[3]:
			if i < active and _splashes.size() < 120:
				_splashes.append([Vector2(d[0].x, d[3]), 0.0])
			_drops[i] = _new_drop(false)
	for s in _splashes:
		s[1] += delta
	_splashes = _splashes.filter(func(s): return s[1] < SPLASH_TIME)
	_flash = maxf(_flash - delta * 2.4, 0.0)
	if level > 0.0 or _flash > 0.0 or not _splashes.is_empty():
		queue_redraw()
	elif visible:
		queue_redraw()  # one last clear frame


func _draw() -> void:
	var level := Audio.rain_level
	if level <= 0.0 and _flash <= 0.0 and _splashes.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(TINT, TINT.a * level))
	var active := int(MAX_DROPS * level)
	for i in active:
		var d: Array = _drops[i]
		var head: Vector2 = d[0]
		var tail: Vector2 = head - WIND * d[2]
		draw_line(_snap(tail), _snap(head), DROP_COLOR, 2.0)
	for s in _splashes:
		var t: float = s[1] / SPLASH_TIME
		var r := lerpf(PIXEL, PIXEL * 3.0, t)
		var c := Color(SPLASH_COLOR, SPLASH_COLOR.a * (1.0 - t))
		var p: Vector2 = _snap(s[0])
		var px := Vector2(PIXEL * 0.5, PIXEL * 0.5)
		for offset in [Vector2(-r, 0), Vector2(r, 0), Vector2(0, -r * 0.5), Vector2(0, r * 0.5)]:
			draw_rect(Rect2(p + offset - px * 0.5, px), c)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.85, 0.9, 1.0, 0.28 * _flash))


func _new_drop(anywhere: bool) -> Array:
	var ground := randf_range(40.0, SCREEN.y)
	var start := Vector2(randf_range(0.0, SCREEN.x + 300.0), -randf_range(0.0, 200.0))
	if anywhere:
		start.y = randf_range(-200.0, ground)
	return [start, randf_range(DROP_SPEED.x, DROP_SPEED.y), randf_range(DROP_LENGTH.x, DROP_LENGTH.y), ground]


func _snap(p: Vector2) -> Vector2:
	return (p / 2.0).round() * 2.0


## A double flicker, like real lightning.
func _on_lightning() -> void:
	_flash = 1.0
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func(): _flash = 0.3)
	tween.tween_interval(0.08)
	tween.tween_callback(func(): _flash = 0.9)
