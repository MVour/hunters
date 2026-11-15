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
	player_health.text = str(health)
	player_damage.text = str(damage)

	# Portrait animations are named after the species.
	if not character_sprite.sprite_frames.has_animation(species):
		return
	character_sprite.play(species)
	var frame_size := character_sprite.sprite_frames.get_frame_texture(species, 0).get_size()
	var fit := minf(PORTRAIT_BOX.x / frame_size.x, PORTRAIT_BOX.y / frame_size.y)
	character_sprite.scale = Vector2(fit, fit)
	# Small pixel art stays crisp; big painted portraits get smooth scaling.
	character_sprite.texture_filter = TEXTURE_FILTER_NEAREST if frame_size.x <= 64 else TEXTURE_FILTER_LINEAR
	_breathe(Vector2(fit, fit))


## A slow, subtle "breathing" so still portraits feel alive.
func _breathe(base_scale: Vector2) -> void:
	if _breath:
		_breath.kill()
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(character_sprite, "scale", base_scale * 1.02, 1.8)
	_breath.tween_property(character_sprite, "scale", base_scale, 1.8)
