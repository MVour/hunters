class_name PlayerSlotInfo extends Button

@export var player_sitting = null

@onready var name_label: Label = $NameLabel
@onready var player_pawn: Sprite2D = $PlayerPawn
@onready var damage: Label = $DamageLabel/Damage
@onready var species: Label = $SpeciesLabel/Species



func _ready():
	SignalBus.begin_turn.connect(_on_begin)
	SignalBus.end_turn.connect(_on_end)

func sit(player):
	name_label.text = player.name
	player_pawn.texture = Global.pawns[player.pawn].sprite
	damage.text = str(player.dmg)
	species.text = _species_text(player)
	player_sitting = player


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

func _on_begin(pl_id):
	if player_sitting.id == pl_id:
		self.grab_focus()
		
func _on_end(pl_id):
	if player_sitting.id == pl_id:
		self.release_focus()
	
