extends Node
## Static game data that never changes while playing: sprites, defaults,
## and the master card lists. Never modify these at runtime; the server
## copies them into GameState.deck for each match.

const CARD_TYPES := ["red_cards", "green_cards", "blue_cards"]

var colors_sprites = {
	"white": preload("res://assets/white.png"),
	"blue": preload("res://assets/blue.png"),
	"red": preload("res://assets/red.png"),
	"green": preload("res://assets/green.png"),
	"light_blue": preload("res://assets/light_blue.png"),
	"yellow": preload("res://assets/yellow.png"),
	"purple": preload("res://assets/purple.png"),
	"orange": preload("res://assets/orange.png"),
}

var game_settings_default = {
	"players" : {
		2 : {"vampires_count": 1, "werewolves_count": 1, "humans_count": 0},
		3 : {"vampires_count": 1, "werewolves_count": 1, "humans_count": 1},
		4 : {"vampires_count": 2, "werewolves_count": 2, "humans_count": 0},
		5 : {"vampires_count": 2, "werewolves_count": 2, "humans_count": 1},
		6 : {"vampires_count": 2, "werewolves_count": 2, "humans_count": 2},
		7 : {"vampires_count": 2, "werewolves_count": 2, "humans_count": 3},
		8 : {"vampires_count": 3, "werewolves_count": 3, "humans_count": 2}
	},
	## Seats around the clearing, clockwise from you (slot1, bottom-left):
	## slot2 left (under the life track), slot3-5 top, slot6-8 right.
	"chairs_config" : {
		2 : ["slot1", "slot4"],
		3 : ["slot1", "slot3", "slot5"],
		4 : ["slot1", "slot3", "slot5", "slot7"],
		5 : ["slot1", "slot3", "slot4", "slot5", "slot7"],
		6 : ["slot1", "slot2", "slot3", "slot4", "slot5", "slot7"],
		7 : ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "slot8"],
		8 : ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "slot7", "slot8"],
	}
}

## Rolling this total lets you move to any location except your current one.
## Full rules: docs/RULES.md
const ROLL_ANY_LOCATION := 7

## What each location lets you do: badge colour, icon, and hover text.
const LOCATION_ACTIONS := {
	"draw_green": {"color": "4fd08a", "icon": "res://assets/icons/icon_draw_green.png", "text": "Draw a green card."},
	"draw_blue": {"color": "6a9af0", "icon": "res://assets/icons/icon_draw_blue.png", "text": "Draw a blue card."},
	"draw_red": {"color": "e8402e", "icon": "res://assets/icons/icon_draw_red.png", "text": "Draw a red card."},
	"draw_any": {"color": "e8c060", "icon": "res://assets/icons/icon_draw_any.png", "text": "Draw a card of any colour."},
	"steal_equipment": {"color": "b07ae8", "icon": "res://assets/icons/icon_steal_equipment.png", "text": "Steal an equipment card from any player."},
	"heal_or_damage": {"color": "4fe0d0", "icon": "res://assets/icons/icon_heal_or_damage.png", "text": "Heal 1 health on any player (yourself included), or deal 2 damage to any player."},
}

## Maps the lobby's settings keys to character lists and species names.
const SPECIES := {
	"vampires_count": {"list": "vampires", "species": "vampire"},
	"werewolves_count": {"list": "werewolves", "species": "werewolf"},
	"humans_count": {"list": "humans", "species": "human"},
}


var deck = {
	# Character data lives in scripts/characters.gd.
	"characters": {
		"humans" : Characters.HUMANS.duplicate(true),
		"vampires": Characters.VAMPIRES.duplicate(true),
		"werewolves": Characters.WEREWOLVES.duplicate(true),
	},
	## Shuffled around the board every game. "rolls" = the dice totals
	## (d6 + d4) that send you here; "action" keys into LOCATION_ACTIONS.
	"locations" : [
		{"id": "lone_cabin", "name": "lone_cabin", "label": "Lone Cabin", "rolls": [2, 3], "action": "draw_green"},
		{"id": "widows_river", "name": "widows_river", "label": "Widow's River", "rolls": [4, 5], "action": "draw_any"},
		{"id": "old_chapel", "name": "old_chapel", "label": "Old Chapel", "rolls": [6], "action": "draw_blue"},
		{"id": "cemetery", "name": "cemetery", "label": "Cemetery", "rolls": [8], "action": "draw_red"},
		{"id": "magic_forest", "name": "magic_forest", "label": "Magic Forest", "rolls": [9], "action": "heal_or_damage"},
		{"id": "stone_circle", "name": "stone_circle", "label": "Stone Circle", "rolls": [10], "action": "steal_equipment"},
	],
	# The card designs live in scripts/cards.gd (see docs/CARDS.md).
	"green_cards" : Cards.build(Cards.GREEN),
	"red_cards" : Cards.build(Cards.RED),
	"blue_cards" : Cards.build(Cards.BLUE),
}

## Display info per deck.
const CARD_COLORS := {
	"green_cards": {"label": "green", "label_el": "Πράσινη", "color": "44b052"},
	"red_cards": {"label": "red", "label_el": "Κόκκινη", "color": "d83a42"},
	"blue_cards": {"label": "blue", "label_el": "Μπλε", "color": "3a7ae0"},
}


## Who owns which pawn is tracked in GameState.players, not here.
var pawns = {
	"white": {"color": "white", "hex": "d8dde3", "sprite": preload("res://assets/white.png")},
	"blue": {"color": "blue", "hex": "3a6ae0", "sprite": preload("res://assets/blue.png")},
	"red": {"color": "red", "hex": "d83a42", "sprite": preload("res://assets/red.png")},
	"green": {"color": "green", "hex": "44b052", "sprite": preload("res://assets/green.png")},
	"light_blue": {"color": "light_blue", "hex": "5cc4f0", "sprite": preload("res://assets/light_blue.png")},
	"yellow": {"color": "yellow", "hex": "f0c840", "sprite": preload("res://assets/yellow.png")},
	"purple": {"color": "purple", "hex": "9a5ad8", "sprite": preload("res://assets/purple.png")},
	"orange": {"color": "orange", "hex": "f08030", "sprite": preload("res://assets/orange.png")},
}
