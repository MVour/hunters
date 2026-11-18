class_name DeathFx extends Node2D
## A death everyone notices (SignalBus.player_died, any cause):
## 1. the pawn flashes white, falls over and greys (PawnLayer);
## 2. a pale ghost of the pawn rises out of the body, swaying, trailing
##    wisps, and fades into the night;
## 3. a dark band across the screen: "{name} has fallen", who they were
##    (now public) and who struck them down.
## A killing blow also hits harder on the board (AttackFx, `lethal`).
## Pure visuals.

const GHOST := Color(0.75, 0.92, 1.0)
const SPECIES_COLOURS := {"vampire": "e06a6a", "werewolf": "e0a84c", "human": "8fb8e0"}
const BANNER_SECONDS := 3.6

var pawn_layer: PawnLayer


func setup(pawns: PawnLayer) -> void:
	pawn_layer = pawns
	z_index = 30
	SignalBus.player_died.connect(_on_player_died)


func _on_player_died(player_id: int, killer_id: int) -> void:
	_banner(player_id, killer_id)
	var pawn: Sprite2D = pawn_layer.pawns.get(player_id)
	if pawn == null:
		return
	await get_tree().create_timer(0.9).timeout  # after the blow and the fall
	if is_instance_valid(pawn):
		_ghost(pawn)


## A pale copy of the pawn floats up out of the body and fades.
func _ghost(pawn: Sprite2D) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = pawn.texture
	ghost.texture_filter = pawn.texture_filter
	ghost.offset = pawn.offset
	ghost.scale = Vector2.ONE * PawnLayer.PAWN_SCALE
	var start := pawn_layer.to_global(pawn.position)
	ghost.global_position = start
	ghost.modulate = Color(GHOST.r * 1.4, GHOST.g * 1.4, GHOST.b * 1.6, 0.0)
	ghost.material = _ghost_material()
	add_child(ghost)
	var rise := 2.6
	var t := create_tween().set_parallel(true)
	t.tween_property(ghost, "modulate:a", 0.75, 0.4)
	t.tween_method(func(k: float):
		ghost.global_position = start + Vector2(sin(k * TAU * 1.5) * 14.0, -150.0 * k)
		ghost.rotation = sin(k * TAU * 1.5) * 0.12, 0.0, 1.0, rise).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(ghost, "scale", ghost.scale * 1.25, rise)
	t.tween_property(ghost, "modulate:a", 0.0, 1.2).set_delay(rise - 1.2)
	t.chain().tween_callback(ghost.queue_free)
	# Wisps trailing behind it.
	for i in 9:
		var wisp := Wisp.new()
		wisp.global_position = start + Vector2(randf_range(-18, 18), randf_range(-30, 0))
		wisp.modulate.a = 0.0
		add_child(wisp)
		var w := create_tween()
		w.tween_interval(i * 0.18)
		w.tween_property(wisp, "modulate:a", 0.8, 0.2)
		w.parallel().tween_property(wisp, "global_position", wisp.global_position + Vector2(randf_range(-30, 30), -randf_range(70, 130)), 1.4) \
			.set_ease(Tween.EASE_OUT)
		w.tween_property(wisp, "modulate:a", 0.0, 0.5)
		w.tween_callback(wisp.queue_free)


## Additive light, so the ghost glows instead of covering the board.
func _ghost_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


class Wisp extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 7.0, Color(0.75, 0.92, 1.0, 0.25))
		draw_circle(Vector2.ZERO, 3.0, Color(0.9, 0.97, 1.0, 0.8))


## The announcement across the screen.
func _banner(player_id: int, killer_id: int) -> void:
	var p: Dictionary = GameState.players.get(player_id, {})
	if p.is_empty():
		return
	var band := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.0, 0.0, 0.82)
	style.border_color = Color(0.55, 0.06, 0.05)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	band.add_theme_stylebox_override("panel", style)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.custom_minimum_size = Vector2(1920, 0)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	band.add_child(column)

	var me := player_id == GameState.local_id
	var title := _line(Global.text("death.you") if me else Global.text("death.title") % p.get("name", "?"),
		52, Color("ff5a4a"))
	column.add_child(title)
	var character: Dictionary = p.get("character", {})
	if not character.is_empty():
		var species: String = character.get("species", "")
		var was := _line(Global.text("death.was") % [Global.field(character, "name"), Global.species_name(species)],
			26, Color(SPECIES_COLOURS.get(species, "dddddd")))
		column.add_child(was)
	if killer_id != 0 and killer_id != player_id and GameState.players.has(killer_id):
		column.add_child(_line(Global.text("death.by") % GameState.players[killer_id].name, 20, Color(0.8, 0.78, 0.75)))

	add_child(band)
	band.position = Vector2(0, 330)
	band.modulate.a = 0.0
	title.scale = Vector2.ONE * 1.6
	title.pivot_offset = Vector2(960, 30)
	var t := create_tween()
	t.tween_interval(0.35)  # the blow lands first
	t.tween_property(band, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(BANNER_SECONDS)
	t.tween_property(band, "modulate:a", 0.0, 0.6)
	t.tween_callback(band.queue_free)


func _line(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
