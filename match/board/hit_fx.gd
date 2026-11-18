class_name HitFx extends Node2D
## Makes damage, healing and steals impossible to miss:
## - damage: a red claw slash over the pawn and over their life-track marker;
##   when it's YOU, red splatter on your screen that flashes and fades;
## - healing, in three beats: green motes gather on the pawn, a green burst,
##   then sparks rise; the marker glows green;
## - a steal, in three beats: the card pops out of the victim's pawn, flies
##   to the taker's, lands with an amber burst.
## (Attacks have their own three beats: AttackFx.)
## Pure visuals, from SignalBus events this screen already gets.

const HARM := Color("e0302a")
const HEAL := Color("4cd47a")
const STEAL := Color("e8a33c")
const SPLATTER_SECONDS := 3.5


## Three claw lines that draw themselves in, then fade.
class Slash extends Node2D:
	var color := HARM
	var size := 46.0
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _draw() -> void:
		for i in 3:
			var shift := Vector2(-14.0 + i * 14.0, 0)
			var from := Vector2(-size / 2.0, -size / 2.0) + shift
			var to := Vector2(size / 2.0, size / 2.0) + shift
			var end := from.lerp(to, progress)
			draw_line(from, end, Color(0, 0, 0, 0.55), 8.0, true)  # dark edge
			draw_line(from, end, color, 4.5, true)


## Blood drops over the whole screen (yours only): a few big blots near the
## edges with small drops around them.
class Splatter extends Control:
	var blots := []  # [centre, radius, [[offset, radius], ...]]

	func _init(amount: int) -> void:
		size = Vector2(1920, 1080)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in clampi(5 + amount * 4, 6, 22):
			var edge := randi() % 4
			var p := Vector2(randf_range(0, 1920), randf_range(0, 1080))
			match edge:
				0: p.x = randf_range(0, 260)
				1: p.x = randf_range(1660, 1920)
				2: p.y = randf_range(0, 200)
				3: p.y = randf_range(880, 1080)
			var r := randf_range(10, 34)
			var drops := []
			for j in randi_range(2, 6):
				drops.append([Vector2.from_angle(randf() * TAU) * randf_range(r * 1.1, r * 2.6), randf_range(2, r * 0.35)])
			blots.append([p, r, drops])

	func _draw() -> void:
		for blot in blots:
			draw_circle(blot[0], blot[1], Color(0.55, 0.02, 0.03, 0.85))
			draw_circle(blot[0] + Vector2(-blot[1] * 0.25, -blot[1] * 0.25), blot[1] * 0.45, Color(0.8, 0.1, 0.08, 0.5))
			for drop in blot[2]:
				draw_circle(blot[0] + drop[0], drop[1], Color(0.55, 0.02, 0.03, 0.8))


var pawn_layer: PawnLayer
var damage_board: DamageBoard
var _dmg := {}


func setup(pawns: PawnLayer, board: DamageBoard) -> void:
	pawn_layer = pawns
	damage_board = board
	z_index = 18
	for id in GameState.players:
		_dmg[id] = GameState.players[id].dmg
	SignalBus.damage_changed.connect(_on_damage_changed)
	SignalBus.notice.connect(_on_notice)


func _on_damage_changed(id: int, dmg: int) -> void:
	var before: int = _dmg.get(id, 0)
	_dmg[id] = dmg
	if dmg > before:
		_slash_pawn(id, dmg - before)
		_mark_track(id, HARM)
		if id == GameState.local_id:
			_splatter(dmg - before)
	elif dmg < before:
		_heal_sparks(id)
		_mark_track(id, HEAL)


## "{taker} takes {card} from {from}": the card flies between their pawns.
func _on_notice(message) -> void:
	if not (message is Dictionary and message.get("k", "") == "notice.takes_from"):
		return
	var p: Dictionary = message.get("p", {})
	var taker := _id_named(str(p.get("taker", "")))
	var victim := _id_named(str(p.get("from", "")))
	if taker != 0 and victim != 0:
		_fly_card(victim, taker)


func _id_named(player_name: String) -> int:
	for id in GameState.players:
		if GameState.players[id].name == player_name:
			return id
	return 0


func _pawn_at(id: int) -> Vector2:
	var pawn: Sprite2D = pawn_layer.pawns.get(id)
	return pawn.global_position + PawnLayer.FEET_OFFSET * PawnLayer.PAWN_SCALE if pawn else Vector2(-1, -1)


func _slash_pawn(id: int, amount: int) -> void:
	var at := _pawn_at(id)
	if at.x < 0:
		return
	await get_tree().create_timer(0.15).timeout  # with the attack's lunge (AttackFx)
	var slash := Slash.new()
	slash.size = 40.0 + amount * 6.0
	slash.global_position = at
	slash.rotation = randf_range(-0.3, 0.3)
	add_child(slash)
	var t := create_tween()
	t.tween_property(slash, "progress", 1.0, 0.14).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7)
	t.tween_property(slash, "modulate:a", 0.0, 0.6)
	t.tween_callback(slash.queue_free)


## The player's marker on the life track: a small slash (harm) or a glow.
func _mark_track(id: int, color: Color) -> void:
	var marker: Control = damage_board.marker_of(id) if damage_board else null
	if marker == null:
		return
	await get_tree().process_frame  # the marker moved to its new row this frame
	if not is_instance_valid(marker):
		return
	marker.modulate = color.lightened(0.3) * 1.6
	create_tween().tween_property(marker, "modulate", Color.WHITE, 1.2)
	if color == HARM:
		var slash := Slash.new()
		slash.size = 22.0
		slash.global_position = marker.global_position + marker.size / 2.0
		add_child(slash)
		var t := create_tween()
		t.tween_property(slash, "progress", 1.0, 0.12)
		t.tween_interval(0.8)
		t.tween_property(slash, "modulate:a", 0.0, 0.6)
		t.tween_callback(slash.queue_free)


## Your screen: red drops that flash twice and fade.
func _splatter(amount: int) -> void:
	var splat := Splatter.new(amount)
	splat.z_index = 40
	splat.modulate.a = 0.0
	get_parent().add_child(splat)
	var t := create_tween()
	t.tween_property(splat, "modulate:a", 1.0, 0.08)
	t.tween_property(splat, "modulate:a", 0.55, 0.25)
	t.tween_property(splat, "modulate:a", 1.0, 0.2)
	t.tween_interval(SPLATTER_SECONDS - 1.5)
	t.tween_property(splat, "modulate:a", 0.0, 1.0)
	t.tween_callback(splat.queue_free)


func _heal_sparks(id: int) -> void:
	var at := _pawn_at(id)
	if at.x < 0:
		return
	# 1. Motes gather on the pawn.
	for i in 10:
		var mote := _dot(HEAL.lightened(0.4), randf_range(3, 5))
		mote.position = at + Vector2.from_angle(randf() * TAU) * randf_range(60, 95)
		mote.modulate.a = 0.0
		add_child(mote)
		var m := create_tween()
		m.tween_property(mote, "modulate:a", 1.0, 0.1).set_delay(i * 0.03)
		m.tween_property(mote, "position", at, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		m.tween_callback(mote.queue_free)
	await get_tree().create_timer(0.7).timeout
	# 2. A green burst; the pawn shines.
	_burst(at, HEAL, 0.8)
	_flash_pawn(id, Color(0.7, 1.8, 0.9))
	# 3. Sparks rise.
	for i in 6:
		var spark := Label.new()
		spark.text = "+"
		spark.add_theme_font_size_override("font_size", randi_range(18, 28))
		spark.add_theme_color_override("font_color", HEAL)
		spark.add_theme_color_override("font_outline_color", Color(0, 0.15, 0.05))
		spark.add_theme_constant_override("outline_size", 5)
		spark.position = at + Vector2(randf_range(-30, 22), randf_range(-10, 20))
		spark.modulate.a = 0.0
		add_child(spark)
		var t := create_tween().set_parallel(true)
		t.tween_property(spark, "modulate:a", 1.0, 0.15).set_delay(i * 0.08)
		t.tween_property(spark, "position:y", spark.position.y - randf_range(50, 80), 1.1).set_delay(i * 0.08) \
			.set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "modulate:a", 0.0, 0.5).set_delay(0.7 + i * 0.08)
		t.chain().tween_callback(spark.queue_free)


## A small glowing dot (heal motes).
func _dot(color: Color, radius: float) -> Node2D:
	var dot := Dot.new()
	dot.color = color
	dot.radius = radius
	return dot


class Dot extends Node2D:
	var color := Color.WHITE
	var radius := 4.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius * 2.0, Color(color, 0.25))
		draw_circle(Vector2.ZERO, radius, color)


## A flash and a shockwave ring (the same as an attack's impact).
func _burst(at: Vector2, color: Color, big: float) -> void:
	var burst := AttackFx.Burst.new()
	burst.color = color
	burst.big = big
	burst.position = at
	add_child(burst)
	var t := create_tween()
	t.tween_property(burst, "progress", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_callback(burst.queue_free)


## A pawn lights up in a colour, then fades back.
func _flash_pawn(id: int, tint: Color) -> void:
	var pawn: Sprite2D = pawn_layer.pawns.get(id)
	if pawn == null or GameState.players.get(id, {}).get("dead", false):
		return
	pawn.modulate = tint
	create_tween().tween_property(pawn, "modulate", Color.WHITE, 0.6)


## A small card pops out of one pawn, flies to another and lands there.
func _fly_card(from_id: int, to_id: int) -> void:
	var from := _pawn_at(from_id)
	var to := _pawn_at(to_id)
	if from.x < 0 or to.x < 0:
		return
	var card := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.05)
	style.border_color = STEAL
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(STEAL, 0.6)
	style.shadow_size = 8
	card.add_theme_stylebox_override("panel", style)
	card.size = Vector2(26, 36)
	card.pivot_offset = card.size / 2.0
	card.position = from - card.size / 2.0
	card.scale = Vector2.ZERO
	add_child(card)
	# 1. It pops out of the victim, who flickers.
	_flash_pawn(from_id, Color(1.7, 1.3, 0.6))
	var lift := Vector2(0, -40)
	var t := create_tween()
	t.tween_property(card, "scale", Vector2.ONE * 1.3, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(card, "position", card.position + lift, 0.3).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.25)
	# 2. It flies over to the taker.
	var start := from + lift
	t.tween_method(func(k: float):
		var p := start.lerp(to, k) + Vector2(0, -90) * sin(k * PI)
		card.position = p - card.size / 2.0
		card.rotation = k * TAU, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 3. It lands: an amber burst, the taker shines.
	t.tween_callback(func():
		_burst(to, STEAL, 0.7)
		_flash_pawn(to_id, Color(1.7, 1.4, 0.7)))
	t.tween_property(card, "scale", Vector2(0.2, 0.2), 0.2)
	t.parallel().tween_property(card, "modulate:a", 0.0, 0.2)
	t.tween_callback(card.queue_free)
