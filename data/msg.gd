class_name Msg extends RefCounted
## A translatable message, sent by the server instead of a finished
## sentence: {"k": key, "p": params}. Each computer turns it into text in
## its own language with Global.msg() (keys live in i18n/strings.csv).
##
##   Msg.make("notice.attack", {"attacker": "Bob", "target": "Ann", "dmg": 3})
##   Msg.make("prompt.use_now", {"card": Msg.named(card)})
##
## Param values can be plain values, other messages, or Msg.named(...) for
## names that exist in both languages (cards, characters, locations, decks).


static func make(key: String, params := {}) -> Dictionary:
	return {"k": key, "p": params}


## A card / character / location / deck name the client shows in its own
## language. Keeps the card's uid so the screen can tell which card a
## question is about.
static func named(data: Dictionary) -> Dictionary:
	# Locations carry both: "name" is their id, "label" the real name.
	if data.has("label"):
		return {"name": str(data.label), "name_el": str(data.get("label_el", "")), "uid": str(data.get("uid", ""))}
	return {
		"name": str(data.get("name", "")),
		"name_el": str(data.get("name_el", "")),
		"uid": str(data.get("uid", "")),
	}


static func species(species_id: String) -> Dictionary:
	return make("species." + species_id)
