class_name CharacterCard extends HBoxContainer
## A character as a card: portrait framed in the species' colour, name and
## species, goal, ability, a life bar with "n of m left". Used by the player
## hub (your own, with your buttons under the life bar: `side`) and as a
## popup when someone's character is shown to you or revealed (`popup`).
## Pure view.

const PORTRAIT_BOX := Vector2(150, 176)
const GOLD := Color("c8a85a")
const BG := Color(0.04, 0.05, 0.08, 0.95)
const SPECIES_COLOURS := {"vampire": "e06a6a", "werewolf": "e0a84c", "human": "8fb8e0"}
## Popup on screen, high up (the dialogs sit low, over the hub).
const POPUP_Y := 200.0
const POPUP_WIDTH := 900.0

## The right column, under the life bar: the hub adds its buttons here.
var side: VBoxContainer

var _portrait_style: StyleBoxFlat
var _portrait: AnimatedSprite2D
var _breath: Tween
var _name_label: Label
var _species_label: Label
var _goal_heading: Label
var _goal: RichTextLabel
var _ability_heading: Label
var _ability: RichTextLabel
var _life_heading: Label
var _life_bar: LifeBar
var _life_text: Label
var _health := 0
var _dmg := 0


## Damage taken out of health, as one segment per life point.
class LifeBar extends Control:
	var health := 10
	var dmg := 0

	func _draw() -> void:
		if health <= 0:
			return
		var gap := 2.0
		var w := (size.x - gap * (health - 1)) / health
		for i in health:
			var r := Rect2(i * (w + gap), 0, w, size.y)
			var taken := i >= health - dmg  # damage fills from the right
			draw_rect(r, Color(0.75, 0.12, 0.1) if taken else Color(0.25, 0.62, 0.35))
			draw_rect(r, Color(0, 0, 0, 0.5), false, 1.0)


func _init() -> void:
	add_theme_constant_override("separation", 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := PanelContainer.new()
	_portrait_style = StyleBoxFlat.new()
	_portrait_style.bg_color = Color(0.02, 0.02, 0.03)
	_portrait_style.border_color = GOLD
	_portrait_style.set_border_width_all(3)
	_portrait_style.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", _portrait_style)
	frame.custom_minimum_size = PORTRAIT_BOX + Vector2(6, 6)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.custom_minimum_size = PORTRAIT_BOX
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	_portrait = AnimatedSprite2D.new()
	_portrait.position = PORTRAIT_BOX / 2.0
	holder.add_child(_portrait)
	add_child(frame)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 3)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_color_override("font_color", Color("ffe2a8"))
	title_row.add_child(_name_label)
	_species_label = Label.new()
	_species_label.add_theme_font_size_override("font_size", 18)
	_species_label.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(_species_label)
	middle.add_child(title_row)
	_goal_heading = _heading()
	middle.add_child(_goal_heading)
	_goal = Keywords.label("", 15)
	middle.add_child(_goal)
	_ability_heading = _heading()
	middle.add_child(_ability_heading)
	_ability = Keywords.label("", 15)
	middle.add_child(_ability)
	add_child(middle)

	side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(230, 0)
	side.add_theme_constant_override("separation", 6)
	_life_heading = _heading()
	side.add_child(_life_heading)
	_life_bar = LifeBar.new()
	_life_bar.custom_minimum_size = Vector2(230, 18)
	side.add_child(_life_bar)
	_life_text = Label.new()
	_life_text.add_theme_font_size_override("font_size", 20)
	side.add_child(_life_text)
	add_child(side)
	apply_language()


func _heading() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("e8c060"))
	return label


func set_character(character: Dictionary, dmg: int) -> void:
	_show_known(true)
	var species: String = character.get("species", "")
	var colour := Color(SPECIES_COLOURS.get(species, "c8a85a"))
	_name_label.text = Global.field(character, "name")
	_species_label.text = Global.species_name(species)
	_species_label.add_theme_color_override("font_color", colour)
	_portrait_style.border_color = colour
	Keywords.set_text(_goal, Global.field(character, "goal"), 15)
	Keywords.set_text(_ability, Global.field(character, "ability"), 15)
	_health = int(character.get("health", 0))
	set_damage(dmg)
	_show_portrait(species)


func set_damage(dmg: int) -> void:
	_dmg = dmg
	_life_bar.health = maxi(_health, 1)
	_life_bar.dmg = dmg
	_life_bar.queue_redraw()
	_life_text.text = Global.text("hub.life") % [maxi(_health - dmg, 0), _health]
	_life_text.add_theme_color_override("font_color",
		Color("ff7a6a") if _health > 0 and _health - dmg <= 3 else Color(0.9, 0.88, 0.84))


## A player whose character you don't know: their hooded pawn, their name,
## "unknown character", and only the damage they've taken (all public).
func set_unknown(player: Dictionary) -> void:
	_show_known(false)
	_name_label.text = player.get("name", "?")
	_species_label.text = Global.text("card.unknown")
	_species_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.66))
	var pawn_info: Dictionary = Global.pawns.get(player.get("pawn", ""), {})
	_portrait_style.border_color = Color(pawn_info.get("hex", "c8a85a"))
	_life_text.text = Global.text("card.damage_taken") % int(player.get("dmg", 0))
	_life_text.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	var sprite: Texture2D = pawn_info.get("sprite")
	if sprite == null:
		return
	if _breath:
		_breath.kill()
	var frames := SpriteFrames.new()
	frames.add_frame("default", sprite)
	_portrait.sprite_frames = frames
	_portrait.play("default")
	var fit := minf(PORTRAIT_BOX.x / sprite.get_width(), PORTRAIT_BOX.y / sprite.get_height())
	fit = maxf(1.0, floorf(fit * 0.8))  # whole pixels, a little room around it
	_portrait.scale = Vector2(fit, fit)
	_portrait.texture_filter = TEXTURE_FILTER_NEAREST
	_portrait.position = PORTRAIT_BOX / 2.0


## Goal, ability and the life bar only make sense for a known character.
func _show_known(on: bool) -> void:
	for node in [_goal_heading, _goal, _ability_heading, _ability, _life_bar]:
		node.visible = on
	_life_heading.text = Global.text("hub.life_heading").to_upper() if on \
		else Global.text("card.damage_heading").to_upper()


func apply_language() -> void:
	_goal_heading.text = Global.text("hub.goal").to_upper()
	_ability_heading.text = Global.text("hub.ability").to_upper()
	_life_heading.text = Global.text("hub.life_heading").to_upper()
	_life_text.text = Global.text("hub.life") % [maxi(_health - _dmg, 0), _health]


## Portrait art: the classic animated ones if that art is on (when there's
## one for the species), else the current portraits. Scaled to fit the box.
func _show_portrait(species: String) -> void:
	var frames := _portrait_frames()
	if Global.classic_art:
		var classic: SpriteFrames = load(Global.CLASSIC_PORTRAITS)
		if classic and classic.has_animation(species):
			frames = classic
	if not frames.has_animation(species):
		return
	_portrait.sprite_frames = frames
	_portrait.play(species)
	var frame_size := frames.get_frame_texture(species, 0).get_size()
	var fit := minf(PORTRAIT_BOX.x / frame_size.x, PORTRAIT_BOX.y / frame_size.y)
	var pixel_art := frame_size.x <= 80
	if pixel_art:
		# whole-number scale keeps pixels square (a pixel or two over the box is fine)
		fit = maxf(1.0, floorf(fit + 0.05))
	_portrait.scale = Vector2(fit, fit)
	_portrait.texture_filter = TEXTURE_FILTER_NEAREST if pixel_art else TEXTURE_FILTER_LINEAR
	# A slow breath: whole pixels up and down.
	if _breath:
		_breath.kill()
	var base_y := PORTRAIT_BOX.y / 2.0
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(_portrait, "position:y", base_y - fit, 1.6)
	_breath.tween_property(_portrait, "position:y", base_y, 1.6)


## The current portraits: 6-frame loops in a 2x3 sheet (tools/make_portraits.gd).
const PORTRAIT_FRAME := {
	"human": Vector2(76, 76), "vampire": Vector2(76, 76), "werewolf": Vector2(57, 65),
}


static func _portrait_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for species in PORTRAIT_FRAME:
		var sheet: Texture2D = load("res://assets/portraits/%s.png" % species)
		var size: Vector2 = PORTRAIT_FRAME[species]
		frames.add_animation(species)
		frames.set_animation_speed(species, 5.0)
		for i in 6:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(i % 2, i / 2) * size, size)
			frames.add_frame(species, atlas)
	return frames


## A character card over the board with a heading ("Only you see Fern's
## character"), closed by OK or a click on it. `auto_close` > 0 (public
## reveals): no OK, clicks go through it to the board, and it fades by
## itself after that many seconds. Nobody has to wait or dismiss it.
## `character` empty: you don't know it; `player` is shown instead (pawn,
## name, damage). `equipment`: shown under the card as micro cards with
## what each does (equipment is public).
## Returns the popup (a PanelContainer added to `parent`).
static func popup(parent: Node, heading: String, character: Dictionary, dmg: int,
		auto_close := 0.0, equipment = null, player := {}) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = Color(SPECIES_COLOURS.get(character.get("species", ""), "c8a85a"))
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 24  # just under the dialogs (25): those you must answer
	panel.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ffd27a"))
	column.add_child(title)
	var card := CharacterCard.new()
	column.add_child(card)
	if character.is_empty():
		card.set_unknown(player)
	else:
		card.set_character(character, dmg)
	if equipment is Array:
		var heading_label := card._heading()
		heading_label.text = "%s (%d)" % [Global.text("hub.tab_equipment").to_upper(), equipment.size()]
		column.add_child(heading_label)
		var strip := EquipmentStrip.new(Vector2(64, 98), 14)
		column.add_child(strip)
		strip.set_cards(equipment)
	var ok := Button.new()
	ok.text = Global.text("option.ok")
	ok.custom_minimum_size = Vector2(140, 42)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.focus_mode = Control.FOCUS_NONE
	ok.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ok.add_theme_font_size_override("font_size", 18)
	ok.add_theme_color_override("font_color", Color("ffe2a8"))
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(9)
		s.set_border_width_all(2)
		s.bg_color = Color(0.2, 0.15, 0.05).lightened(0.15 if state == "hover" else 0.0)
		s.border_color = GOLD.lightened(0.25) if state == "hover" else GOLD
		ok.add_theme_stylebox_override(state, s)
	card.side.add_child(Control.new())
	card.side.get_child(-1).size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.side.add_child(ok)
	if auto_close > 0.0:
		ok.hide()
		_ignore_mouse(panel)
	parent.add_child(panel)

	var close := func():
		if is_instance_valid(panel) and not panel.is_queued_for_deletion():
			var fade := panel.create_tween()
			fade.tween_property(panel, "modulate:a", 0.0, 0.2)
			fade.tween_callback(panel.queue_free)
	ok.pressed.connect(close)
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close.call())
	# Centred across the screen; grows in. Wrapped text measures tall until
	# the first layout, so fit the height again once it's laid out.
	title.custom_minimum_size = Vector2(POPUP_WIDTH - 36, 0)
	panel.reset_size()
	panel.get_tree().process_frame.connect(panel.reset_size, CONNECT_ONE_SHOT)
	var screen := Vector2(1920, 1080)
	panel.position = Vector2((screen.x - POPUP_WIDTH) / 2.0, POPUP_Y)
	panel.pivot_offset = Vector2(POPUP_WIDTH / 2.0, 120)
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var grow := panel.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(panel, "scale", Vector2.ONE, 0.3)
	grow.tween_property(panel, "modulate:a", 1.0, 0.2)
	if auto_close > 0.0:
		panel.get_tree().create_timer(auto_close).timeout.connect(close)
	return panel


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
