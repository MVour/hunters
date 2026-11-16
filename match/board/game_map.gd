class_name GameMap extends Node2D
## Places the location tiles on the forest trail (see ForestBoard). The
## server shuffles their order every game.

signal location_chosen(location_id: String)

@onready var location_scn : PackedScene = preload("res://match/board/location_sprite.tscn")

## Art for each location, keyed by the "name" in Global.deck.locations.
const TEXTURES := {
	"lone_cabin": preload("res://assets/locations/lone_cabin.png"),
	"old_chapel": preload("res://assets/locations/old_chapel.png"),
	"cemetery": preload("res://assets/locations/cemetery.png"),
	"widows_river": preload("res://assets/locations/widows_river.png"),
	"stone_circle": preload("res://assets/locations/stone_circle.png"),
	"magic_forest": preload("res://assets/locations/magic_forest.png"),
}

var _nodes := {}  # location id -> LocationSprite


func locations_spawn():
	var index := 1
	for loc in GameState.locations:
		var new_loc : LocationSprite = location_scn.instantiate()
		add_child(new_loc)
		if Global.classic_art:
			new_loc.set_location(loc, Global.classic_location_art(loc.name))
			new_loc.position = ClassicBoard.location_position(index)
		else:
			new_loc.set_location(loc, TEXTURES[loc.name])
			new_loc.position = ForestBoard.location_position(index)
		new_loc.chosen.connect(func(id): location_chosen.emit(id))
		_nodes[loc.id] = new_loc
		index += 1


func get_location(location_id: String) -> LocationSprite:
	return _nodes.get(location_id)


## Highlight these locations and let the player click one (rolled a 7).
func set_choosable(location_ids: Array) -> void:
	for id in _nodes:
		_nodes[id].set_selectable(id in location_ids)
