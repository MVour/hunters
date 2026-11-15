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
	"chairs_config" : {
		2 : ["slot1", "slot4"],
		3 : ["slot1", "slot4", "slot7"],
		4 : ["slot1", "slot2", "slot4", "slot7"],
		5 : ["slot1", "slot2", "slot4", "slot6", "slot8"],
		6 : ["slot1", "slot2", "slot4", "slot5", "slot6", "slot8"],
		7 : ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "slot8"],
		8 : ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "slot7", "slot8"],
	}
}

## Maps the lobby's settings keys to character lists and species names.
const SPECIES := {
	"vampires_count": {"list": "vampires", "species": "vampire"},
	"werewolves_count": {"list": "werewolves", "species": "werewolf"},
	"humans_count": {"list": "humans", "species": "human"},
}


var deck = {
	"characters": {
		"humans" : [
			{"id": "h1", "species": "human", "name": "Ada", "health": 8, "ability_code": "G:H/++", "ability": "Once per game can restore full health", "goal": "Survive until the end."},
			{"id": "h2", "species": "human", "name": "Hope", "health": 8, "ability_code": "G:W/LP", "ability": "Once per game can change the winning condition: from supporting the right player, to supporting the left player", "goal": "Wins if the player on the RIGHT wins"},
		],
		"vampires": [
			{"id": "v1", "species": "vampire", "name": "Volco", "health": 13, "ability_code": "A:H/+2", "ability": "Heal +2 when you successfully attack!", "goal": "No werewolves standing" },
			{"id": "v2", "species": "vampire", "name": "Mel", "health": 14, "ability_code": "D:A", "ability": "When attacked you can return the attack! (Can be used even when it's not your turn. Can't return the attack that killed you)", "goal": "No werewolves standing"}
		],
		"werewolves": [
			{"id": "w1", "species": "werewolf", "name": "Frederick", "health": 12, "ability_code": "G:A/6Z", "ability": "Once per game can choose to attack with the 6 sided dice.", "goal": "No vampires standing"},
			{"id": "w2", "species": "werewolf", "name": "Gregor", "health": 14, "ability_code": "G:A/4Z", "ability": "Once per game can choose to attack with the 4 sided dice.", "goal": "No vampires standing"}
		]
	},
	"locations" : [
		{"id": "l1", "name": "old_chapel", "label": "Old Chapel", "effect": "Draw: Red, Blue", "position": 0, "players": []},
		{"id": "l2", "name": "old_chapel", "label": "Old Chapel", "effect": "Draw: Red, Blue", "position": 0, "players": []},
		{"id": "l3", "name": "old_chapel", "label": "Old Chapel", "effect": "Draw: Red, Blue", "position": 0, "players": []},
		{"id": "l4", "name": "old_chapel", "label": "Old Chapel", "effect": "Draw: Red, Blue", "position": 0, "players": []},
		{"id": "l5", "name": "old_chapel", "label": "Old Chapel", "effect": "Draw: Red, Blue", "position": 0, "players": []},
		{"id": "l6", "name": "old_chapel", "label": "Old Chapel", "effect": "Draw: Red, Blue", "position": 0, "players": []},
	],
	"blue_cards" : [
		{"id": "bc1", "title": "Some Blue Card", "text": "Some BlueCard Text"},
		{"id": "bc2", "title": "Some Blue Card", "text": "Some BlueCard Text"},
		{"id": "bc3", "title": "Some Blue Card", "text": "Some BlueCard Text"},
		{"id": "bc4", "title": "Some Blue Card", "text": "Some BlueCard Text"},
		{"id": "bc5", "title": "Some Blue Card", "text": "Some BlueCard Text"}
	],
	"green_cards" : [
		{"id": "gc1", "title": "Some Green Card", "text": "Some GreenCard Text"},
		{"id": "gc2", "title": "Some Green Card", "text": "Some GreenCard Text"},
		{"id": "gc3", "title": "Some Green Card", "text": "Some GreenCard Text"},
		{"id": "gc4", "title": "Some Green Card", "text": "Some GreenCard Text"},
		{"id": "gc5", "title": "Some Green Card", "text": "Some GreenCard Text"}
	],
	"red_cards" : [
		{"id": "rc1", "title": "Some Red Card", "text": "Some RedCard Text"},
		{"id": "rc2", "title": "Some Red Card", "text": "Some RedCard Text"},
		{"id": "rc3", "title": "Some Red Card", "text": "Some RedCard Text"},
		{"id": "rc4", "title": "Some Red Card", "text": "Some RedCard Text"},
		{"id": "rc5", "title": "Some Red Card", "text": "Some RedCard Text"}
	]
}


## Who owns which pawn is tracked in GameState.players, not here.
var pawns = {
	"white": {"color": "white", "sprite": preload("res://assets/white.png")},
	"blue": {"color": "blue", "sprite": preload("res://assets/blue.png")},
	"red": {"color": "red", "sprite": preload("res://assets/red.png")},
	"green": {"color": "green", "sprite": preload("res://assets/green.png")},
	"light_blue": {"color": "light_blue", "sprite": preload("res://assets/light_blue.png")},
	"yellow": {"color": "yellow", "sprite": preload("res://assets/yellow.png")},
	"purple": {"color": "purple", "sprite": preload("res://assets/purple.png")},
	"orange": {"color": "orange", "sprite": preload("res://assets/orange.png")},
}
