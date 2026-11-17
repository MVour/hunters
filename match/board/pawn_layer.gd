class_name PawnLayer extends Node2D
## Every player's pawn on the board. Pawns start around the campfire and
## fly (a showy arc, see _travel) to the standing spots in front of their location.
## Pure visuals: where everyone is lives in GameState (set by the server).
## While you pick a player (attack, card target…), pickable pawns get a
## pulsing ring and can be clicked (set_pickable).

signal player_picked(player_id: int)

## A glowing ellipse at a pawn's feet.
class PickRing extends Node2D:
	var color := Color("ff7a5a")
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 42.0, 0.0, TAU, 48, color, 6.0, true)

const PAWN_SCALE := 0.65
const FEET_OFFSET := Vector2(0, -28)  # pawn art: feet ~28px below centre
const HOP_HEIGHT := 70.0
const CAMPFIRE := ""                  # "location" id of the starting spot

var game_map: GameMap
var pawns := {}       # player id -> Sprite2D
var occupants := {}   # location id -> [player ids], in standing order
var _pick_areas := {}  # player id -> Control over the pawn (clickable while picking)
var _rings := {}       # player id -> PickRing
var _ring_pulse: Tween


func _ready() -> void:
	y_sort_enabled = true  # pawns further down the screen draw in front


func setup(map: GameMap, players: Dictionary) -> void:
	game_map = map
	occupants[CAMPFIRE] = []
	var ids := players.keys()
	ids.sort()
	for id in ids:
		var pawn := Sprite2D.new()
		var color: String = players[id].pawn
		if Global.pawns.has(color):
			pawn.texture = Global.pawns[color].sprite
		pawn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pawn.scale = Vector2.ONE * PAWN_SCALE
		pawn.offset = FEET_OFFSET
		add_child(pawn)
		pawns[id] = pawn
		_add_pick_parts(id, pawn, players[id].name)
		var at: String = players[id].get("location", CAMPFIRE)
		if not occupants.has(at):
			occupants[at] = []
		occupants[at].append(id)
	for loc in occupants:
		_reflow(loc, false)
	SignalBus.pawn_moved.connect(_on_pawn_moved)
	SignalBus.player_died.connect(_on_player_died)


func _add_pick_parts(id: int, pawn: Sprite2D, player_name: String) -> void:
	var ring := PickRing.new()
	ring.scale = Vector2(1, 0.42)  # flat on the ground
	ring.show_behind_parent = true
	ring.visible = false
	pawn.add_child(ring)
	_rings[id] = ring

	var area := Control.new()  # pawn-local units (before PAWN_SCALE)
	area.position = Vector2(-34, -66)
	area.size = Vector2(68, 74)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.tooltip_text = player_name
	area.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			player_picked.emit(id))
	pawn.add_child(area)
	_pick_areas[id] = area


## Light up these players' pawns and let them be clicked; [] ends picking.
## Pawns that can't be picked fade a little meanwhile.
func set_pickable(ids: Array) -> void:
	var picking := not ids.is_empty()
	for id in pawns:
		var on: bool = id in ids
		_rings[id].visible = on
		_pick_areas[id].mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
		_pick_areas[id].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
		pawns[id].self_modulate = Color(1, 1, 1, 0.45) if picking and not on else Color.WHITE
	if _ring_pulse:
		_ring_pulse.kill()
		_ring_pulse = null
	if picking:
		_ring_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_ring_pulse.tween_method(_set_ring_alpha, 1.0, 0.35, 0.45)
		_ring_pulse.tween_method(_set_ring_alpha, 0.35, 1.0, 0.45)


func _set_ring_alpha(alpha: float) -> void:
	for ring in _rings.values():
		ring.modulate.a = alpha


## A dead player's pawn falls over and fades to grey.
func _on_player_died(player_id: int, _killer_id: int) -> void:
	if not pawns.has(player_id):
		return
	var pawn: Sprite2D = pawns[player_id]
	await get_tree().create_timer(0.6).timeout  # let a hit flash finish first
	var tween := create_tween().set_parallel(true)
	tween.tween_property(pawn, "rotation_degrees", 90.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(pawn, "modulate", Color(0.45, 0.45, 0.5, 0.85), 0.4)


## Where the n-th pawn at a location stands.
func spot(location_id: String, n: int) -> Vector2:
	if location_id == CAMPFIRE:
		var angle := deg_to_rad(lerpf(200.0, 340.0, n / 7.0))
		var start := ClassicBoard.START_POS if Global.classic_art else ForestBoard.FIRE_POS
		return start + Vector2(cos(angle) * 130.0, sin(angle) * 50.0 + 30.0)
	return game_map.get_location(location_id).pawn_spot(n)


func _on_pawn_moved(player_id: int, location_id: String) -> void:
	if not pawns.has(player_id):
		return
	var from := _location_of(player_id)
	if from == location_id:
		return
	occupants[from].erase(player_id)
	if not occupants.has(location_id):
		occupants[location_id] = []
	occupants[location_id].append(player_id)

	await get_tree().create_timer(1.0).timeout  # let the dice land first
	await _travel(player_id, spot(location_id, occupants[location_id].find(player_id)))
	_reflow(from, true)  # the others close the gap
	var loc: LocationSprite = game_map.get_location(location_id) if location_id != CAMPFIRE else null
	if loc:
		_bounce(loc)


func _location_of(player_id: int) -> String:
	for loc in occupants:
		if player_id in occupants[loc]:
			return loc
	return CAMPFIRE


func _reflow(location_id: String, animated: bool) -> void:
	var ids: Array = occupants.get(location_id, [])
	for n in ids.size():
		var target := spot(location_id, n)
		var pawn: Sprite2D = pawns[ids[n]]
		if animated:
			create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
				.tween_property(pawn, "position", target, 0.3)
		else:
			pawn.position = target


## A turn move, made to be watched: the pawn crouches, pops up big above
## everything with its owner's name over it, flies a high arc (a shadow
## on the ground, fading afterimages in the player's colour), and lands with
## a squash and a ring of dust.
func _travel(player_id: int, target: Vector2) -> void:
	var pawn: Sprite2D = pawns[player_id]
	var color := _pawn_color(player_id)
	var start := pawn.position
	var distance := start.distance_to(target)
	var duration := clampf(distance / 520.0, 0.9, 1.6)
	var height := clampf(distance * 0.35, HOP_HEIGHT, 220.0)
	var base := Vector2.ONE * PAWN_SCALE
	pawn.z_index = 10  # above the other pawns and the location art

	var shadow := Shadow.new()
	shadow.position = start
	add_child(shadow)
	var tag := _name_tag(player_id, color)
	pawn.add_child(tag)

	# Crouch, then pop up bigger.
	var lift := create_tween()
	lift.tween_property(pawn, "scale", Vector2(base.x * 1.25, base.y * 0.75), 0.12)
	lift.tween_property(pawn, "scale", base * 1.35, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await lift.finished

	var last_ghost := [0.0]
	var step := func(t: float) -> void:
		var ground := start.lerp(target, t)
		var up := sin(t * PI)
		pawn.position = ground + Vector2(0, -up * height)
		pawn.rotation = sin(t * TAU) * 0.12
		shadow.position = ground
		shadow.scale = Vector2.ONE * lerpf(1.0, 0.55, up)
		shadow.modulate.a = lerpf(0.45, 0.2, up)
		if t - last_ghost[0] > 0.07 and t < 0.95:
			last_ghost[0] = t
			_ghost(pawn, color)
	var flight := create_tween()
	flight.tween_method(step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await flight.finished

	# Land: squash, settle back to normal size, dust.
	pawn.rotation = 0.0
	shadow.queue_free()
	_dust(target, color)
	var land := create_tween()
	land.tween_property(pawn, "scale", Vector2(base.x * 1.4, base.y * 0.7), 0.08)
	land.tween_property(pawn, "scale", base, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	land.parallel().tween_property(tag, "modulate:a", 0.0, 0.6).set_delay(0.5)
	await land.finished
	pawn.z_index = 0
	tag.queue_free()


func _pawn_color(player_id: int) -> Color:
	var key: String = GameState.players.get(player_id, {}).get("pawn", "")
	return Color(Global.pawns.get(key, {}).get("hex", "ffffff"))


## The mover's name floating over the pawn while it travels.
func _name_tag(player_id: int, color: Color) -> Label:
	var tag := Label.new()
	tag.text = GameState.players.get(player_id, {}).get("name", "")
	tag.add_theme_font_size_override("font_size", 26)
	tag.add_theme_color_override("font_color", color.lightened(0.3))
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 8)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(240, 36)
	tag.position = Vector2(-120, -140)  # pawn-local units
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tag


## A fading copy of the pawn left behind in the air.
func _ghost(pawn: Sprite2D, color: Color) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = pawn.texture
	ghost.texture_filter = pawn.texture_filter
	ghost.offset = pawn.offset
	ghost.position = pawn.position
	ghost.rotation = pawn.rotation
	ghost.scale = pawn.scale
	ghost.z_index = pawn.z_index - 1
	ghost.modulate = Color(color.r, color.g, color.b, 0.5)
	add_child(ghost)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(ghost, "modulate:a", 0.0, 0.35)
	fade.tween_property(ghost, "scale", pawn.scale * 0.8, 0.35)
	fade.chain().tween_callback(ghost.queue_free)


## A ring of dust spreading out on the ground where a pawn lands.
func _dust(at: Vector2, color: Color) -> void:
	var ring := DustRing.new()
	ring.color = color.lightened(0.4)
	ring.position = at
	ring.scale = Vector2(0.3, 0.13)
	add_child(ring)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.6, 0.65), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)


## The location a pawn just reached gives a little bounce.
func _bounce(loc: Node2D) -> void:
	if not loc.has_meta("base_scale"):
		loc.set_meta("base_scale", loc.scale)
	var base: Vector2 = loc.get_meta("base_scale")
	var tween := create_tween()
	tween.tween_property(loc, "scale", base * 1.06, 0.1)
	tween.tween_property(loc, "scale", base, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A soft dark ellipse on the ground under a flying pawn.
class Shadow extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 1))


class DustRing extends Node2D:
	var color := Color.WHITE
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 50.0, 0.0, TAU, 40, color, 8.0, true)


## Attacker lunges at the target; the target shakes, flashes red and a
## damage number floats up.
func play_attack(attacker: int, target: int, damage: int) -> void:
	if not pawns.has(attacker) or not pawns.has(target):
		return
	var a: Sprite2D = pawns[attacker]
	var t: Sprite2D = pawns[target]
	var home := a.position
	var toward := home + (t.position - home).limit_length(60.0)
	var lunge := create_tween()
	lunge.tween_property(a, "position", toward, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge.tween_property(a, "position", home, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(0.15).timeout
	var base := t.position
	var shake := create_tween()
	for i in 4:
		shake.tween_property(t, "position", base + Vector2(6 if i % 2 == 0 else -6, 0), 0.04)
	shake.tween_property(t, "position", base, 0.04)
	if damage > 0:
		t.modulate = Color(2.0, 0.5, 0.5)
		create_tween().tween_property(t, "modulate", Color.WHITE, 0.4)

	var label := Label.new()
	label.text = "-%d" % damage if damage > 0 else Global.text("match.miss")
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("ff5a4a") if damage > 0 else Color(0.85, 0.85, 0.85))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.position = base + Vector2(-20, -90)
	label.z_index = 20
	add_child(label)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(label, "position:y", label.position.y - 50, 0.9)
	rise.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.4)
	rise.chain().tween_callback(label.queue_free)
