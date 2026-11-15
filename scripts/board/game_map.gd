class_name GameMap extends Node2D
## Places the location tiles on the forest trail (see ForestBoard). The
## server shuffles their order every game.

@onready var location_scn : PackedScene = preload("res://scenes/location_sprite.tscn")

## Art for each location, keyed by the "name" in Global.deck.locations.
const TEXTURES := {
	"lone_cabin": preload("res://assets/locations/lone_cabin.png"),
	"old_chapel": preload("res://assets/locations/old_chapel.png"),
	"cemetery": preload("res://assets/locations/cemetery.png"),
	"widows_river": preload("res://assets/locations/widows_river.png"),
	"stone_circle": preload("res://assets/locations/stone_circle.png"),
	"magic_forest": preload("res://assets/locations/magic_forest.png"),
}


func locations_spawn():
	var index := 1
	for loc in GameState.locations:
		var new_loc : LocationSprite = location_scn.instantiate()
		add_child(new_loc)
		new_loc.set_location(loc, TEXTURES[loc.name])
		new_loc.position = ForestBoard.location_position(index)
		index += 1
