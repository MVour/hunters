class_name PawnLayer extends Node2D
## Every player's pawn on the board. Pawns start around the campfire and
## hop to the standing spots in front of their location when they move.
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

	await get_tree().create_timer(0.7).timeout  # let the dice land first
	_hop(pawns[player_id], spot(location_id, occupants[location_id].find(player_id)))
	_reflow(from, true)  # the others close the gap


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


## Jump in an arc to the target, then a little squash on landing.
func _hop(pawn: Sprite2D, target: Vector2) -> void:
	var start := pawn.position
	var duration := clampf(start.distance_to(target) / 650.0, 0.45, 1.0)
	var base := Vector2.ONE * PAWN_SCALE
	var tween := create_tween()
	tween.tween_method(func(t: float):
		pawn.position = start.lerp(target, t) + Vector2(0, -sin(t * PI) * HOP_HEIGHT),
		0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pawn, "scale", Vector2(base.x * 1.2, base.y * 0.8), 0.07)
	tween.tween_property(pawn, "scale", base, 0.12)


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
	label.text = "-%d" % damage if damage > 0 else "miss"
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
