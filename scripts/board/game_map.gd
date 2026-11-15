class_name GameMap extends Node2D
## Places the location tiles on the forest trail (see ForestBoard).

@onready var location_scn : PackedScene = preload("res://scenes/location_sprite.tscn")

## Art for each location type. All chapels for now: draw the others later!
@onready var locations = {
	"old_chapel": preload("res://assets/background/chappel2.png"),
	"cabin": preload("res://assets/background/chappel2.png"),
	"cemetery": preload("res://assets/background/chappel2.png"),
	"fountain": preload("res://assets/background/chappel2.png"),
	"stone_circle": preload("res://assets/background/chappel2.png"),
	"forest": preload("res://assets/background/chappel2.png")
}


func locations_spawn():
	var index := 1
	for loc in GameState.locations:
		var new_loc : LocationSprite = location_scn.instantiate()
		add_child(new_loc)
		new_loc.set_location(locations[loc.name], loc.label, index)
		new_loc.position = ForestBoard.location_position(index)
		index += 1
