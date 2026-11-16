class_name PlayerSlotInfo extends Button

@export var player_sitting = null

@onready var name_label: Label = $NameLabel
@onready var player_pawn: Sprite2D = $PlayerPawn
@onready var damage: Label = $DamageLabel/Damage
@onready var species: Label = $SpeciesLabel/Species


func _ready():
	SignalBus.begin_turn.connect(_on_begin)
	SignalBus.end_turn.connect(_on_end)
	SignalBus.damage_changed.connect(_on_damage_changed)
	SignalBus.character_revealed.connect(_on_character_revealed)
	SignalBus.player_died.connect(_on_player_died)


func sit(player):
	name_label.text = player.name
	player_pawn.texture = Global.pawns[player.pawn].sprite
	damage.text = str(player.dmg)
	species.text = _species_text(player)
	player_sitting = player
	# A stripe in the player's colour ties the plate to their pawn and marker.
	var stripe := ColorRect.new()
	stripe.color = Color(Global.pawns[player.pawn].hex)
	stripe.size = Vector2(size.x, 4)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stripe)


## Hidden roles: you see your own species, everyone else is "?????" until
## revealed.
func _species_text(player) -> String:
	var is_me: bool = player.id == GameState.local_id
	if player.hidden and not is_me:
		return "?????"
	var text: String = player.character.get("species", "?")
	if player.hidden:
		text += "\n (Hidden)"
	return text


func _is_mine(pl_id) -> bool:
	return player_sitting != null and player_sitting.id == pl_id


func _on_begin(pl_id):
	if _is_mine(pl_id):
		grab_focus()


func _on_end(pl_id):
	if _is_mine(pl_id):
		release_focus()


func _on_damage_changed(pl_id, dmg):
	if _is_mine(pl_id):
		damage.text = str(dmg)
		# Flash red on a hit.
		damage.modulate = Color(1.6, 0.4, 0.4)
		create_tween().tween_property(damage, "modulate", Color.WHITE, 0.5)


func _on_character_revealed(pl_id, character):
	if _is_mine(pl_id):
		species.text = "%s\n%s" % [character.get("species", "?"), character.get("name", "")]


func _on_player_died(pl_id, _killer):
	if _is_mine(pl_id):
		modulate = Color(0.5, 0.5, 0.5)
		name_label.text = player_sitting.name + "  (DEAD)"
