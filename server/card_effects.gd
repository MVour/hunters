class_name CardEffects extends RefCounted
## Server-side interpreter for card effects (see "Effect steps" in
## docs/CARDS.md). A card's "effect" is a list of steps like
##   {"do": "damage", "amount": 2, "target": "chosen", "if_species": ["vampire"]}
## run in order. Steps that need a decision ask the player through
## GameManager.ask(), so running an effect is a coroutine: always `await` it.
##
## ctx keys: actor (who plays the card), receiver / asker (green questions),
## card, chosen (targets picked so far, reused by later steps).

var gm: GameManager


func _init(manager: GameManager) -> void:
	gm = manager


# --- Queries -----------------------------------------------------------------

## Living players in turn order.
func alive() -> Array:
	return GameState.game_info.players_turn.filter(func(id): return not GameState.players[id].dead)


func species(id: int) -> String:
	return GameState.players[id].character.get("species", "")


## All of a player's equipment modifiers combined: numbers add up, flags OR.
func mods(id: int) -> Dictionary:
	var total := {}
	for card in GameState.players[id].equipment:
		for key in card.get("mods", {}):
			var value = card.mods[key]
			if value is bool:
				total[key] = total.get(key, false) or value
			else:
				total[key] = total.get(key, 0) + value
	return total


## Can `attacker` reach `target`? Same location or the next one clockwise,
## widened by equipment (Hunter's Crossbow, Widow's Lantern).
func in_reach(attacker: int, target: int) -> bool:
	var from: String = GameState.players[attacker].location
	var to: String = GameState.players[target].location
	var m := mods(attacker)
	if m.get("ignore_reach", false):
		return true
	if from == to:
		return true
	if GameState.can_reach(from, to):
		return true
	return m.get("reach_back", false) and GameState.can_reach(to, from)


func _next_location(location_id: String) -> String:
	var i := GameState.location_index(location_id)
	if i == -1:
		return ""
	return GameState.locations[(i + 1) % GameState.locations.size()].id


func _player_option(id: int) -> Dictionary:
	var p: Dictionary = GameState.players[id]
	return {"value": id, "label": p.name, "color": Global.pawns.get(p.pawn, {}).get("hex", "ffffff")}


func _card_title(ctx: Dictionary) -> String:
	return ctx.get("card", {}).get("name", "")


# --- Running effects ---------------------------------------------------------

## Returns false if it stopped early (no target, or the player backed out).
func run(card: Dictionary, ctx: Dictionary) -> bool:
	ctx.card = card
	ctx.chosen = {}
	for step in card.get("effect", []):
		var keep_going: bool = await _step(step, ctx)
		if not keep_going:
			return false
	return true


## Returns false to stop the rest of the effect (e.g. no valid target).
func _step(step: Dictionary, ctx: Dictionary) -> bool:
	var actor: int = ctx.actor
	match step.do:
		"damage", "heal":
			var targets = await _targets(step.get("target", "self"), ctx)
			if targets == null:
				return false
			for t in targets:
				if not _condition(step, t):
					continue
				if step.do == "heal":
					gm.heal(t, step.amount)
				elif _blocked_by_amulet(t, ctx):
					gm.notice.rpc("%s's Holy Amulet blocks the damage." % GameState.players[t].name)
				else:
					gm.apply_damage(t, step.amount, actor)

		"give_equipment_or_damage":
			var t: int = ctx.receiver
			if not _condition(step, t):
				return true
			if GameState.players[t].equipment.is_empty():
				gm.apply_damage(t, step.amount, ctx.asker)
			else:
				var uid = await _pick_equipment(t, t, "Give one of your equipment cards to %s" % GameState.players[ctx.asker].name, false)
				gm.transfer_equipment(t, ctx.asker, uid)

		"show_character_to_asker":
			if _condition(step, ctx.receiver):
				gm.private_character.rpc_id(ctx.asker, ctx.receiver, GameState.players[ctx.receiver].character)

		"tell_health_to_asker":
			var p: Dictionary = GameState.players[ctx.receiver]
			gm.private_info.rpc_id(ctx.asker, _card_title(ctx),
				"%s's character starts with %d health." % [p.name, p.character.get("health", 0)])

		"steal_equipment", "take_from_dead":
			var from_dead: bool = step.do == "take_from_dead"
			var victims := []
			for id in GameState.game_info.players_turn:
				var p: Dictionary = GameState.players[id]
				if id != actor and p.dead == from_dead and not p.equipment.is_empty():
					victims.append(_player_option(id))
			if victims.is_empty():
				gm.notice.rpc("%s: there's no equipment to take." % _card_title(ctx))
				return false
			var victim = await gm.ask(actor, "%s: take equipment from whom?" % _card_title(ctx), victims)
			if victim == null:
				return false
			var uid = await _pick_equipment(actor, victim, "Which one?", false)
			gm.transfer_equipment(victim, actor, uid)

		"protect":
			gm.set_protected(actor, true)

		"move_anywhere":
			var here: String = GameState.players[actor].location
			var options := []
			for loc in GameState.locations:
				if loc.id != here:
					options.append({"value": loc.id, "label": loc.label})
			var dest = await gm.ask(actor, "%s: where do you go?" % _card_title(ctx), options)
			if dest == null:
				return false
			gm.move_pawn.rpc(actor, dest)

		"peek_character":
			var others := alive().filter(func(id): return id != actor).map(_player_option)
			var t = await gm.ask(actor, "%s: whose character do you look at?" % _card_title(ctx), others)
			if t == null:
				return false
			gm.private_character.rpc_id(actor, t, GameState.players[t].character)

		"draw_any":
			var colors := []
			for card_type in Global.CARD_TYPES:
				colors.append({"value": card_type, "label": "Draw %s" % Global.CARD_COLORS[card_type].label,
					"color": Global.CARD_COLORS[card_type].color})
			var card_type = await gm.ask(actor, "%s: which deck?" % _card_title(ctx), colors)
			if card_type == null:
				return false
			await gm.draw_for(actor, card_type)

		"give_equipment_and_heal":
			if GameState.players[actor].equipment.is_empty():
				gm.notice.rpc("%s: you have no equipment to give." % _card_title(ctx))
				return false
			var uid = await _pick_equipment(actor, actor, "Which equipment do you give away?", true)
			if uid == null:
				return false
			var others := alive().filter(func(id): return id != actor).map(_player_option)
			var t = await gm.ask(actor, "Give it to whom?", others)
			if t == null:
				return false
			gm.transfer_equipment(actor, t, uid)
			gm.heal(actor, 1)
			gm.heal(t, 1)

		_:
			push_warning("Unknown effect step: %s" % step.do)
	return true


## Who a step applies to. Returns null when a chosen target is missing or
## the player backed out (stops the effect).
func _targets(target: String, ctx: Dictionary):
	var actor: int = ctx.actor
	match target:
		"self":
			return [actor]
		"receiver":
			return [ctx.receiver]
		"asker":
			return [ctx.asker]
		"others":
			return alive().filter(func(id): return id != actor)
		"here":
			var here: String = GameState.players[actor].location
			return alive().filter(func(id): return GameState.players[id].location == here)
		"here_and_next":
			var here: String = GameState.players[actor].location
			var next := _next_location(here)
			return alive().filter(func(id):
				var loc: String = GameState.players[id].location
				return loc == here or (next != "" and loc == next))
		"chosen", "chosen_any", "chosen_in_reach":
			if ctx.chosen.has(target):
				return [ctx.chosen[target]]
			var candidates := alive().filter(func(id):
				if target == "chosen_any":
					return true
				if id == actor:
					return false
				return target != "chosen_in_reach" or in_reach(actor, id))
			if candidates.is_empty():
				gm.notice.rpc("%s: nobody to target." % _card_title(ctx))
				return null
			var pick = await gm.ask(actor, "%s: choose a player" % _card_title(ctx), candidates.map(_player_option))
			if pick == null:
				return null
			ctx.chosen[target] = pick
			return [pick]
	push_warning("Unknown target: %s" % target)
	return []


func _condition(step: Dictionary, target: int) -> bool:
	var s := species(target)
	if step.has("if_species") and not s in step.if_species:
		return false
	if step.has("unless_species") and s in step.unless_species:
		return false
	var dmg: int = GameState.players[target].dmg
	if step.has("if_damage_at_least") and dmg < step.if_damage_at_least:
		return false
	if step.has("if_damage_below") and dmg >= step.if_damage_below:
		return false
	return true


func _blocked_by_amulet(target: int, ctx: Dictionary) -> bool:
	var card: Dictionary = ctx.get("card", {})
	return card.get("deck", "") == "red_cards" and card.get("kind", "") == "event" \
		and mods(target).get("immune_red_events", false)


## `chooser` picks one of `owner`'s equipment cards; returns its uid.
func _pick_equipment(chooser: int, owner: int, prompt: String, allow_skip: bool):
	var equipment: Array = GameState.players[owner].equipment
	if equipment.size() == 1 and not allow_skip:
		return equipment[0].uid
	var options := equipment.map(func(card): return {"value": card.uid, "label": card.name,
		"color": Global.CARD_COLORS[card.deck].color})
	return await gm.ask(chooser, prompt, options, allow_skip)
