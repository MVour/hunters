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


## Equipment modifiers / reach: shared with the UI, see data/rules.gd.
func mods(id: int) -> Dictionary:
	return Rules.mods(s.state.players[id])


func in_reach(attacker: int, target: int) -> bool:
	return Rules.in_reach(s.state.players, s.state.locations, attacker, target)


## The card (or location / ability) an effect comes from, as a name the
## client shows in its own language.
func _card_title(ctx: Dictionary) -> Dictionary:
	return Msg.named(ctx.get("card", {}))


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
			var target: String = step.get("target", "self")
			var targets = await _targets(target, ctx, {"intent": "help" if step.do == "heal" else "harm",
				"amount": step.amount})
			if targets == null:
				return false
			for t in targets:
				if not _condition(step, t):
					continue
				if target.begins_with("chosen"):  # a pick everyone saw: bots learn from it
					s.observe("help" if step.do == "heal" else "harm", actor, t, step.amount)
				if step.do == "heal":
					s.combat.heal(t, step.amount)
				elif _blocked_by_amulet(t, ctx):
					s.notice(Msg.make("notice.amulet_blocks", {"player": s.state.name_of(t)}))
				else:
					s.combat.apply_damage(t, step.amount, actor)

		"give_equipment_or_damage":
			var t: int = ctx.receiver
			if not _condition(step, t):
				return true
			if s.state.players[t].equipment.is_empty():
				s.combat.apply_damage(t, step.amount, ctx.asker)
			else:
				var uid = await s.cards.pick_equipment(t, t, Msg.make("prompt.give_equipment_to", {"player": s.state.name_of(ctx.asker)}), false)
				s.cards.transfer_equipment(t, ctx.asker, uid)

		"show_character_to_asker":
			if _condition(step, ctx.receiver):
				s.tell(ctx.asker, &"private_character", [ctx.receiver, s.state.players[ctx.receiver].character])

		"tell_health_to_asker":
			var p: Dictionary = s.state.players[ctx.receiver]
			s.private_info(ctx.asker, _card_title(ctx),
				Msg.make("info.starts_with_health", {"player": p.name, "health": p.character.get("health", 0)}))

		"steal_equipment", "take_from_dead":
			var from_dead: bool = step.do == "take_from_dead"
			var victims := []
			for id in s.state.turn_order:
				var p: Dictionary = s.state.players[id]
				if id != actor and p.dead == from_dead and not p.equipment.is_empty():
					victims.append(s.player_option(id))
			if victims.is_empty():
				s.notice(Msg.make("notice.no_equipment_to_take", {"card": _card_title(ctx)}))
				return false
			var victim = await s.ask(actor, Msg.make("prompt.take_from_whom", {"card": _card_title(ctx)}), victims)
			if victim == null:
				return false
			var uid = await s.cards.pick_equipment(actor, victim, Msg.make("prompt.which_one"), false)
			s.cards.transfer_equipment(victim, actor, uid)

		"protect":
			s.cards.set_protected(actor, true)

		"move_anywhere":
			var here: String = s.state.players[actor].location
			var options := []
			for loc in s.state.locations:
				if loc.id != here:
					options.append({"value": loc.id, "label": Msg.named(loc)})
			var dest = await s.ask(actor, Msg.make("prompt.where_go", {"card": _card_title(ctx)}), options)
			if dest == null:
				return false
			s.move_pawn(actor, dest)

		"peek_character":
			var others := s.alive().filter(func(id): return id != actor).map(s.player_option)
			var t = await s.ask(actor, Msg.make("prompt.peek_whom", {"card": _card_title(ctx)}), others)
			if t == null:
				return false
			s.tell(actor, &"private_character", [t, s.state.players[t].character])

		"draw_any":
			var colors := []
			for card_type in Global.CARD_TYPES:
				colors.append({"value": card_type, "label": Msg.make("option.draw_deck", {"deck": Msg.named(Global.CARD_COLORS[card_type])}),
					"color": Global.CARD_COLORS[card_type].color})
			var card_type = await s.ask(actor, Msg.make("prompt.which_deck", {"card": _card_title(ctx)}), colors)
			if card_type == null:
				return false
			await s.cards.draw_for(actor, card_type)

		"give_equipment_and_heal":
			if s.state.players[actor].equipment.is_empty():
				s.notice(Msg.make("notice.no_equipment_to_give", {"card": _card_title(ctx)}))
				return false
			var uid = await s.cards.pick_equipment(actor, actor, Msg.make("prompt.which_to_give"), true)
			if uid == null:
				return false
			var others := s.alive().filter(func(id): return id != actor).map(s.player_option)
			var t = await s.ask(actor, Msg.make("prompt.give_to_whom"), others)
			if t == null:
				return false
			s.cards.transfer_equipment(actor, t, uid)
			s.observe("help", actor, t, 1)
			s.combat.heal(actor, 1)
			s.combat.heal(t, 1)

		_:
			push_warning("Unknown effect step: %s" % step.do)
	return true


## Who a step applies to. Returns null when a chosen target is missing or
## the player backed out (stops the effect).
func _targets(target: String, ctx: Dictionary, hint := {}):
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
				s.notice(Msg.make("notice.nobody_to_target", {"card": _card_title(ctx)}))
				return null
			var pick = await s.ask(actor, Msg.make("prompt.choose_player", {"card": _card_title(ctx)}),
				candidates.map(s.player_option), true, hint)
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
