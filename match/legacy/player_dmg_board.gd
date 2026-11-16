class_name PlayerDmgBoard extends Node
@onready var player_board_sprite: Sprite2D = $PlayerBoardSprite

var color: String = "red"


func _ready():
	pass
	
func set_player_board_sprite(player_color : String):
	player_board_sprite.texture = Global.colors_sprites[player_color]
