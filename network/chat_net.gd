extends Node
## ChatNet autoload: the session chat (lobby and match). Same pattern as
## LobbyNet / MatchNet: UI calls say(), the server checks who's talking and
## sends the line to everyone, the UI listens to SignalBus.chat_message.

const MAX_LENGTH := 200
const KEEP := 60  # lines remembered on this computer

## This session's chat so far: [{"from": id, "name": String, "text": String}].
var messages := []


func _ready() -> void:
	Network.session_closed.connect(func(): messages = [])
	Network.host_disconnected.connect(func(): messages = [])


# --- Action (any computer) -----------------------------------------------------

func say(text: String) -> void:
	text = text.strip_edges()
	if text != "":
		request_say.rpc_id(1, text.left(MAX_LENGTH))


# --- Request (server) ------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_say(text: String) -> void:
	if not multiplayer.is_server():
		return
	var id := Network.sender_id()
	var player: Dictionary = LobbyNet.server_player(id)
	text = text.strip_edges().left(MAX_LENGTH)
	if player.is_empty() or text == "":
		return
	said.rpc(id, player.name, text)


## Server: a newcomer gets what was said before they joined.
func send_history(player_id: int) -> void:
	if multiplayer.is_server() and not messages.is_empty():
		history.rpc_id(player_id, messages)


# --- Messages (everyone / one player) -------------------------------------------

## Only to a player who just joined.
@rpc("authority", "call_local", "reliable")
func history(lines: Array) -> void:
	for m in lines:
		said(m.from, m.name, m.text)



@rpc("authority", "call_local", "reliable")
func said(player_id: int, player_name: String, text: String) -> void:
	messages.append({"from": player_id, "name": player_name, "text": text})
	if messages.size() > KEEP:
		messages.pop_front()
	SignalBus.chat_message.emit(player_id, player_name, text)
