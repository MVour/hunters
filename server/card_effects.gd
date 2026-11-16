class_name CardEffects extends RefCounted
## Server-side interpreter for card effects (see "Effect steps" in
## docs/CARDS.md). A card's "effect" is a list of steps like
##   {"do": "damage", "amount": 2, "target": "chosen", "if_species": ["vampire"]}
## run in order. Steps that need a decision ask the player through
## MatchServer.ask(), so running an effect is a coroutine: always `await` it.
##
## ctx keys: actor (who plays the card), receiver / asker (green questions),
## card, chosen (targets picked so far, reused by later steps).

var s: MatchServer


func _init(server: MatchServer) -> void:
	s = server


# --- Queries -----------------------------------------------------------------

func species(id: int) -> String:
	return s.state.players[id].character.get("species", "")


## All of a player's equipment modifiers combined: numbers add up, flags OR.
func mods(id: int) -> Dictionary:
	var total := {}
	for card in s.state.players[id].equipment:
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
	var from: String = s.state.players[attacker].location
	var to: String = s.state.players[target].location
	var m := mods(attacker)
	if m.get("ignore_reach", false):
		return true
	if from == to:
		return true
	if s.state.can_reach(from, to):
		return true
	return m.get("reach_back", false) and s.state.can_reach(to, from)


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
					s.combat.heal(t, step.amount)
				elif _blocked_by_amulet(t, ctx):
					s.notice("%s's Holy Amulet blocks the damage." % s.state.players[t].name)
				else:
					s.combat.apply_damage(t, step.amount, actor)

		"give_equipment_or_damage":
			var t: int = ctx.receiver
			if not _condition(step, t):
				return true
			if s.state.players[t].equipment.is_empty():
				s.combat.apply_damage(t, step.amount, ctx.asker)
			else:
				var uid = await s.cards.pick_equipment(t, t, "Give one of your equipment cards to %s" % s.state.players[ctx.asker].name, false)
				s.cards.transfer_equipment(t, ctx.asker, uid)

		"show_character_to_asker":
			if _condition(step, ctx.receiver):
				MatchNet.private_character.rpc_id(ctx.asker, ctx.receiver, s.state.players[ctx.receiver].character)

		"tell_health_to_asker":
			var p: Dictionary = s.state.players[ctx.receiver]
			s.private_info(ctx.asker, _card_title(ctx),
				"%s's character starts with %d health." % [p.name, p.character.get("health", 0)])

		"steal_equipment", "take_from_dead":
			var from_dead: bool = step.do == "take_from_dead"
			var victims := []
			for id in s.state.turn_order:
				var p: Dictionary = s.state.players[id]
				if id != actor and p.dead == from_dead and not p.equipment.is_empty():
					victims.append(s.player_option(id))
			if victims.is_empty():
				s.notice("%s: there's no equipment to take." % _card_title(ctx))
				return false
			var victim = await s.ask(actor, "%s: take equipment from whom?" % _card_title(ctx), victims)
			if victim == null:
				return false
			var uid = await s.cards.pick_equipment(actor, victim, "Which one?", false)
			s.cards.transfer_equipment(victim, actor, uid)

		"protect":
			s.cards.set_protected(actor, true)

		"move_anywhere":
			var here: String = s.state.players[actor].location
			var options := []
			for loc in s.state.locations:
				if loc.id != here:
					options.append({"value": loc.id, "label": loc.label})
			var dest = await s.ask(actor, "%s: where do you go?" % _card_title(ctx), options)
			if dest == null:
				return false
			s.move_pawn(actor, dest)

		"peek_character":
			var others := s.alive().filter(func(id): return id != actor).map(s.player_option)
			var t = await s.ask(actor, "%s: whose character do you look at?" % _card_title(ctx), others)
			if t == null:
				return false
			MatchNet.private_character.rpc_id(actor, t, s.state.players[t].character)

		"draw_any":
			var colors := []
			for card_type in Global.CARD_TYPES:
				colors.append({"value": card_type, "label": "Draw %s" % Global.CARD_COLORS[card_type].label,
					"color": Global.CARD_COLORS[card_type].color})
			var card_type = await s.ask(actor, "%s: which deck?" % _card_title(ctx), colors)
			if card_type == null:
				return false
			await s.cards.draw_for(actor, card_type)

		"give_equipment_and_heal":
			if s.state.players[actor].equipment.is_empty():
				s.notice("%s: you have no equipment to give." % _card_title(ctx))
				return false
			var uid = await s.cards.pick_equipment(actor, actor, "Which equipment do you give away?", true)
			if uid == null:
				return false
			var others := s.alive().filter(func(id): return id != actor).map(s.player_option)
			var t = await s.ask(actor, "Give it to whom?", others)
			if t == null:
				return false
			s.cards.transfer_equipment(actor, t, uid)
			s.combat.heal(actor, 1)
			s.combat.heal(t, 1)

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
			return s.alive().filter(func(id): return id != actor)
		"here":
			var here: String = s.state.players[actor].location
			return s.alive().filter(func(id): return s.state.players[id].location == here)
		"here_and_next":
			var here: String = s.state.players[actor].location
			var next := s.state.next_location(here)
			return s.alive().filter(func(id):
				var loc: String = s.state.players[id].location
				return loc == here or (next != "" and loc == next))
		"chosen", "chosen_any", "chosen_in_reach":
			if ctx.chosen.has(target):
				return [ctx.chosen[target]]
			var candidates := s.alive().filter(func(id):
				if target == "chosen_any":
					return true
				if id == actor:
					return false
				return target != "chosen_in_reach" or in_reach(actor, id))
			if candidates.is_empty():
				s.notice("%s: nobody to target." % _card_title(ctx))
				return null
			var pick = await s.ask(actor, "%s: choose a player" % _card_title(ctx), candidates.map(s.player_option))
			if pick == null:
				return null
			ctx.chosen[target] = pick
			return [pick]
	push_warning("Unknown target: %s" % target)
	return []


func _condition(step: Dictionary, target: int) -> bool:
	var sp := species(target)
	if step.has("if_species") and not sp in step.if_species:
		return false
	if step.has("unless_species") and sp in step.unless_species:
		return false
	var dmg: int = s.state.players[target].dmg
	if step.has("if_damage_at_least") and dmg < step.if_damage_at_least:
		return false
	if step.has("if_damage_below") and dmg >= step.if_damage_below:
		return false
	return true


func _blocked_by_amulet(target: int, ctx: Dictionary) -> bool:
	var card: Dictionary = ctx.get("card", {})
	return card.get("deck", "") == "red_cards" and card.get("kind", "") == "event" \
		and mods(target).get("immune_red_events", false)
