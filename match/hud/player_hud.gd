class_name PlayerHud extends Panel

## The portrait area in the HUD (screen pixels). Any art is scaled to fit.
const PORTRAIT_BOX := Vector2(170, 194)

@onready var player_name: Label = $PlayerName
@onready var player_scpecies: Label = $PlayerScpecies
@onready var player_goal: Label = $PlayerGoal
@onready var player_ability: Label = $PlayerAbility
@onready var player_health: Label = $Panel/PlayerHealth
@onready var player_damage: Label = $Panel/PlayerDamage
@onready var character_sprite: AnimatedSprite2D = $CharacterSprite

var _breath: Tween
var _portrait_home: Vector2
## Animations you can click through for your species (classic art has
## several old variants, e.g. vampire, vampire_rain, vampire_piskel...).
var _portraits: Array[String] = []
var _portrait_index := 0
var _portrait_button: Control


func _ready() -> void:
	_portrait_home = character_sprite.position


func init(pl_name, species, goal, ability, health, damage):
	player_name.text = pl_name
	player_scpecies.text = Global.species_name(species)
	player_goal.text = goal
	player_ability.text = ability
	for label in [player_goal, player_ability]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.78))
	player_health.text = str(health)
	player_damage.text = str(damage)

	# Classic art: the original animated portraits, when there is one for
	# this species (there was never an old human, so humans keep theirs).
	if Global.classic_art:
		var classic: SpriteFrames = load(Global.CLASSIC_PORTRAITS)
		if classic and classic.has_animation(species):
			character_sprite.sprite_frames = classic

	# Portrait animations are named after the species.
	if not character_sprite.sprite_frames.has_animation(species):
		return
	_portraits.clear()
	_portraits.append(species)
	var variants: Array[String] = []
	for anim in character_sprite.sprite_frames.get_animation_names():
		if anim.begins_with(species + "_"):
			variants.append(anim)
	variants.sort()
	_portraits.append_array(variants)
	_portrait_index = 0
	_show_portrait(species)
	_setup_portrait_button()


func _show_portrait(anim: String) -> void:
	character_sprite.play(anim)
	var frame_size := character_sprite.sprite_frames.get_frame_texture(anim, 0).get_size()
	var fit := minf(PORTRAIT_BOX.x / frame_size.x, PORTRAIT_BOX.y / frame_size.y)
	var pixel_art := frame_size.x <= 64
	if pixel_art:
		fit = maxf(1.0, roundf(fit))  # whole-number scale keeps pixels square
	character_sprite.position = _portrait_home
	character_sprite.scale = Vector2(fit, fit)
	character_sprite.texture_filter = TEXTURE_FILTER_NEAREST if pixel_art else TEXTURE_FILTER_LINEAR
	_breathe(fit, pixel_art)


## Click the portrait to flip through the other animations for your species.
func _setup_portrait_button() -> void:
	if _portrait_button:
		_portrait_button.queue_free()
		_portrait_button = null
	if _portraits.size() < 2:
		return
	_portrait_button = Control.new()
	_portrait_button.name = "PortraitButton"
	_portrait_button.position = _portrait_home - PORTRAIT_BOX / 2.0
	_portrait_button.size = PORTRAIT_BOX
	_portrait_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_portrait_button.tooltip_text = "Click for the other portraits"
	_portrait_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_portrait_index = (_portrait_index + 1) % _portraits.size()
			_show_portrait(_portraits[_portrait_index])
			_portrait_button.tooltip_text = "%s  (click for the next one)" % _portraits[_portrait_index])
	add_child(_portrait_button)


## A slow, subtle "breathing" so still portraits feel alive. Pixel art bobs
## by whole pixels instead of scaling (scaling would make pixels shimmer).
func _breathe(fit: float, pixel_art: bool) -> void:
	if _breath:
		_breath.kill()
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if pixel_art:
		var base_y := _portrait_home.y
		_breath.tween_property(character_sprite, "position:y", base_y - fit, 1.6)
		_breath.tween_property(character_sprite, "position:y", base_y, 1.6)
	else:
		var base := Vector2(fit, fit)
		_breath.tween_property(character_sprite, "scale", base * 1.02, 1.8)
		_breath.tween_property(character_sprite, "scale", base, 1.8)
