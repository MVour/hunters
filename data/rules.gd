class_name Rules extends RefCounted
## Game rules that both the server and the client need, written once so
## they can't disagree: the server uses them to decide, the UI uses them to
## grey out buttons the server would refuse anyway.
## Pure functions over player dicts (see GameState.new_player()).


## All of a player's equipment modifiers combined: numbers add up, flags OR.
static func mods(player: Dictionary) -> Dictionary:
	var total := {}
	for card in player.get("equipment", []):
		for key in card.get("mods", {}):
			var value = card.mods[key]
			if value is bool:
				total[key] = total.get(key, false) or value
			else:
				total[key] = total.get(key, 0) + value
	return total


## Can `attacker` reach `target`? Same location or the next one clockwise,
## widened by equipment (Hunter's Crossbow, Widow's Lantern).
static func in_reach(players: Dictionary, locations: Array, attacker: int, target: int) -> bool:
	var from: String = players[attacker].location
	var to: String = players[target].location
	var m := mods(players[attacker])
	if m.get("ignore_reach", false) or from == to:
		return true
	if Board.can_reach(locations, from, to):
		return true
	return m.get("reach_back", false) and Board.can_reach(locations, to, from)


## Who `attacker` may attack right now: alive, in reach, not protected.
static func attack_targets(players: Dictionary, locations: Array, order: Array, attacker: int) -> Array:
	return order.filter(func(id):
		var p: Dictionary = players[id]
		return id != attacker and not p.dead and not p.get("protected", false) \
			and in_reach(players, locations, attacker, id))
