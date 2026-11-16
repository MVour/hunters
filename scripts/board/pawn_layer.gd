class_name PawnLayer extends Node2D
## Every player's pawn on the board. Pawns start around the campfire and
## hop to the standing spots in front of their location when they move.
## Pure visuals: where everyone is lives in GameState (set by the server).

const PAWN_SCALE := 0.65
const FEET_OFFSET := Vector2(0, -28)  # pawn art: feet ~28px below centre
const HOP_HEIGHT := 70.0
const CAMPFIRE := ""                  # "location" id of the starting spot

var game_map: GameMap
var pawns := {}       # player id -> Sprite2D
var occupants := {}   # location id -> [player ids], in standing order


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
		var at: String = players[id].get("location", CAMPFIRE)
		if not occupants.has(at):
			occupants[at] = []
		occupants[at].append(id)
	for loc in occupants:
		_reflow(loc, false)
	SignalBus.pawn_moved.connect(_on_pawn_moved)


## Where the n-th pawn at a location stands.
func spot(location_id: String, n: int) -> Vector2:
	if location_id == CAMPFIRE:
		var angle := deg_to_rad(lerpf(200.0, 340.0, n / 7.0))
		return ForestBoard.FIRE_POS + Vector2(cos(angle) * 130.0, sin(angle) * 50.0 + 30.0)
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
