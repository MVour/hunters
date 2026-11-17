class_name RoomTicket extends RefCounted
## Checks a join ticket made by the lobby service (online/lobby-service,
## tickets.js). Format: `<payload hex>.<HMAC-SHA256 hex>`, signed with the
## room's own secret (given to this process in an environment variable).
## Payload (JSON): {"r": room, "n": player name, "o": owner?, "e": expiry
## (unix seconds), "j": nonce}. Each nonce works once.

var _secret := PackedByteArray()
var _room := ""
var _used := {}


func _init(secret: String, room: String) -> void:
	_secret = secret.to_utf8_buffer()
	_room = room


## The ticket's identity {"name", "owner"}, or {} if it's forged, expired,
## for another room, or already used.
func verify(ticket: String) -> Dictionary:
	if _secret.is_empty() or ticket.length() > 1024:
		return {}
	var parts := ticket.split(".")
	if parts.size() != 2 or not _is_hex(parts[0]) or not _is_hex(parts[1]):
		return {}
	var ctx := HMACContext.new()
	if ctx.start(HashingContext.HASH_SHA256, _secret) != OK:
		return {}
	ctx.update(parts[0].to_utf8_buffer())
	if not _same(ctx.finish().hex_encode(), parts[1].to_lower()):
		return {}
	var data = JSON.parse_string(parts[0].hex_decode().get_string_from_utf8())
	if not data is Dictionary:
		return {}
	if str(data.get("r", "")) != _room:
		return {}
	if float(data.get("e", 0)) < Time.get_unix_time_from_system():
		return {}
	var nonce := str(data.get("j", ""))
	if nonce == "" or _used.has(nonce):
		return {}
	_used[nonce] = true
	var player_name := str(data.get("n", "")).strip_edges().left(16)
	if player_name == "":
		return {}
	return {"name": player_name, "owner": data.get("o", false) == true}


static func _is_hex(s: String) -> bool:
	if s.is_empty() or s.length() % 2 != 0:
		return false
	for c in s:
		if not c in "0123456789abcdefABCDEF":
			return false
	return true


## Compare without leaking where the first difference is.
static func _same(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var diff := 0
	for i in a.length():
		diff |= a.unicode_at(i) ^ b.unicode_at(i)
	return diff == 0
