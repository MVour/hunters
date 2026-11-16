class_name Board extends RefCounted
## Board rules that both the client store (GameState) and the server
## (ServerState) need. Pure functions over a list of locations
## (each {"id", "label", "rolls", "action"}), in board order.


## Which location a dice total sends you to ("" for 7 = your choice).
static func location_for_total(locations: Array, total: int) -> String:
	for loc in locations:
		if total in loc.rolls:
			return loc.id
	return ""


## Board position (0-5) of a location, or -1 if unknown.
static func location_index(locations: Array, location_id: String) -> int:
	for i in locations.size():
		if locations[i].id == location_id:
			return i
	return -1


static func location_label(locations: Array, location_id: String) -> String:
	var i := location_index(locations, location_id)
	return locations[i].label if i != -1 else "?"


## Reach: every location is grouped with the next one clockwise
## (1->2, 2->3, ... 6->1). From a location you reach players there and at
## the next location. Attacks use this; equipment may extend it.
static func can_reach(locations: Array, from_id: String, to_id: String) -> bool:
	var from := location_index(locations, from_id)
	var to := location_index(locations, to_id)
	if from == -1 or to == -1:
		return false
	return to == from or to == (from + 1) % locations.size()


static func next_location(locations: Array, location_id: String) -> String:
	var i := location_index(locations, location_id)
	if i == -1:
		return ""
	return locations[(i + 1) % locations.size()].id
