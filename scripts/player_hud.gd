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


func init(pl_name, species, goal, ability, health, damage):
	player_name.text = pl_name
	player_scpecies.text = species
	player_goal.text = goal
	player_ability.text = ability
	for label in [player_goal, player_ability]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.78))
	player_health.text = str(health)
	player_damage.text = str(damage)

	# Portrait animations are named after the species.
	if not character_sprite.sprite_frames.has_animation(species):
		return
	character_sprite.play(species)
	var frame_size := character_sprite.sprite_frames.get_frame_texture(species, 0).get_size()
	var fit := minf(PORTRAIT_BOX.x / frame_size.x, PORTRAIT_BOX.y / frame_size.y)
	var pixel_art := frame_size.x <= 64
	if pixel_art:
		fit = maxf(1.0, roundf(fit))  # whole-number scale keeps pixels square
	character_sprite.scale = Vector2(fit, fit)
	character_sprite.texture_filter = TEXTURE_FILTER_NEAREST if pixel_art else TEXTURE_FILTER_LINEAR
	_breathe(fit, pixel_art)


## A slow, subtle "breathing" so still portraits feel alive. Pixel art bobs
## by whole pixels instead of scaling (scaling would make pixels shimmer).
func _breathe(fit: float, pixel_art: bool) -> void:
	if _breath:
		_breath.kill()
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if pixel_art:
		var base_y := character_sprite.position.y
		_breath.tween_property(character_sprite, "position:y", base_y - fit, 1.6)
		_breath.tween_property(character_sprite, "position:y", base_y, 1.6)
	else:
		var base := Vector2(fit, fit)
		_breath.tween_property(character_sprite, "scale", base * 1.02, 1.8)
		_breath.tween_property(character_sprite, "scale", base, 1.8)
