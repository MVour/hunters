class_name FocusMarks extends RefCounted
## The marks PawnLayer puts on pawns to show who matters right now:
## - Spotlight: a golden pool of light at the turn player's feet;
## - Chevron: a bobbing arrow over a head (gold: whose turn; orange: you
##   can pick them);
## - ReachMark: a turning red dashed ring: you can attack them now.
## Each is a child of the pawn sprite (pawn-local units, before PAWN_SCALE).

const GOLD := Color("e8c060")
const PICK := Color("ff7a5a")
const REACH := Color("e8402e")


class Spotlight extends Node2D:
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var beat := 0.5 + 0.5 * sin(_time * 2.4)
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(1, 0.38))
		for i in 4:
			draw_circle(Vector2.ZERO, 92.0 - i * 18.0, Color(GOLD, 0.07 + i * 0.05))
		draw_arc(Vector2.ZERO, 78.0 + beat * 6.0, 0.0, TAU, 56, Color(GOLD, 0.55 + 0.35 * beat), 5.0, true)


class Chevron extends Node2D:
	var color := GOLD
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		position.y = -150.0 + sin(_time * 4.0) * 8.0
		queue_redraw()

	func _draw() -> void:
		# A dark edge, the arrow, a light core.
		draw_colored_polygon(PackedVector2Array([Vector2(0, 21), Vector2(-27, -16), Vector2(27, -16)]), Color(0, 0, 0, 0.6))
		draw_colored_polygon(PackedVector2Array([Vector2(0, 16), Vector2(-20, -12), Vector2(20, -12)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 6), Vector2(-9, -8), Vector2(9, -8)]), color.lightened(0.45))


class ReachMark extends Node2D:
	## Brighter and faster while you hover the Attack button.
	var hot := false
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta * (2.5 if hot else 1.0)
		queue_redraw()

	func _draw() -> void:
		var beat := 0.5 + 0.5 * sin(_time * 3.0)
		var alpha := (0.75 + 0.25 * beat) if hot else (0.45 + 0.3 * beat)
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(1, 0.4))
		var radius := 62.0 + (6.0 * beat if hot else 0.0)
		for i in 12:
			var start := _time * 0.8 + i * TAU / 12.0
			draw_arc(Vector2.ZERO, radius, start, start + TAU / 24.0, 6, Color(REACH, alpha), 7.0 if hot else 5.0, true)
		if hot:
			draw_circle(Vector2.ZERO, radius - 8.0, Color(REACH, 0.15))
