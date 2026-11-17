class_name CardFlow extends RefCounted
## Server only. Drawing cards, the green-question hand-off, equipment and
## protection. Part of MatchServer (`s`); see docs/CARDS.md for the rules.

var s: MatchServer


func _init(server: MatchServer) -> void:
	s = server


## A player draws a card (location action, or a card effect).
func draw_for(player_id: int, card_type: String) -> void:
	var card := s.state.draw_card(card_type)
	if card.is_empty():
		return
	MatchNet.deck_count.rpc(card_type, s.state.deck[card_type].size())

	if card.kind == "question":
		# Green: secret. Only the drawer sees it, then picks who to ask.
		var waiting: Dictionary = s.turn.pending_question
		if not waiting.is_empty():
			s.state.discard(waiting.card)  # never lose a card from the deck
		s.turn.pending_question = {"card": card, "from": player_id, "to": 0}
		s.tell(player_id, &"question_drawn", [card])
		MatchNet.card_drawn_secretly.rpc(player_id, card_type)
		return

	# Red/blue: read aloud. Everyone sees it.
	MatchNet.card_revealed.rpc(player_id, card)
	if card.kind == "equipment":
		s.state.players[player_id].equipment.append(card)
		MatchNet.set_equipment.rpc(player_id, s.state.players[player_id].equipment)
		return
	# Events: "must" ones happen; the others the player may decline.
	if not card.get("must", false):
		var use = await s.ask(player_id, Msg.make("prompt.use_now", {"card": Msg.named(card)}),
			[{"value": "use", "label": Msg.make("option.use_it"), "color": Global.CARD_COLORS[card.deck].color}],
			true, {"card": card})
		if use == null:
			s.state.discard(card)
			return
	await s.resolve(card, {"actor": player_id})
	s.state.discard(card)


## The drawer hands their green card to another player.
func give_question(sender: int, target_id: int) -> void:
	var q: Dictionary = s.turn.pending_question
	if q.is_empty() or q.from != sender or q.to != 0:
		return
	if target_id == sender or not s.state.players.has(target_id) or s.state.players[target_id].dead:
		return
	q.to = target_id
	s.tell(target_id, &"question_asked", [sender, q.card])
	MatchNet.question_passed.rpc(sender, target_id)


## The asked player has read the card; the server applies it. The server
## knows everyone's species, so the answer is always truthful.
func answer_question(sender: int) -> void:
	var q: Dictionary = s.turn.pending_question
	if q.is_empty() or q.to == 0 or sender != q.to or q.get("answering", false):
		return
	q.answering = true
	await s.resolve(q.card, {"actor": q.to, "receiver": q.to, "asker": q.from})
	s.state.discard(q.card)
	s.turn.pending_question = {}
	MatchNet.question_answered.rpc(q.from, q.to)
	s.observe("question_answered", q.from, q.to)
	s.after_resolution()


func transfer_equipment(from_id: int, to_id: int, uid) -> void:
	var from_list: Array = s.state.players[from_id].equipment
	for i in from_list.size():
		if from_list[i].uid == uid:
			var card: Dictionary = from_list.pop_at(i)
			s.state.players[to_id].equipment.append(card)
			MatchNet.set_equipment.rpc(from_id, from_list)
			MatchNet.set_equipment.rpc(to_id, s.state.players[to_id].equipment)
			s.notice(Msg.make("notice.takes_from", {"taker": s.state.name_of(to_id), "card": Msg.named(card),
				"from": s.state.name_of(from_id)}))
			return


## `chooser` picks one of `owner`'s equipment cards; returns its uid (or null).
func pick_equipment(chooser: int, owner: int, prompt: Dictionary, allow_skip: bool):
	var equipment: Array = s.state.players[owner].equipment
	if equipment.size() == 1 and not allow_skip:
		return equipment[0].uid
	var options := equipment.map(func(card): return {"value": card.uid, "label": Msg.named(card),
		"color": Global.CARD_COLORS[card.deck].color})
	return await s.ask(chooser, prompt, options, allow_skip)


## Guardian Spirit: can't be attacked until their next turn.
func set_protected(player_id: int, on: bool) -> void:
	s.state.players[player_id].protected = on
	MatchNet.set_protected.rpc(player_id, on)
	if on:
		s.notice(Msg.make("notice.protected", {"player": s.state.name_of(player_id)}))
