class_name EnetTransport extends NetworkTransport
## Direct connection: one player hosts, the others connect to the host's IP.
##
## The invite code is simply "address:port". Leave it blank to join a game on
## the same computer. For playing over the internet, the host needs a
## reachable address, e.g. via Tailscale/ZeroTier or port forwarding.

const DEFAULT_PORT := 8080
const MAX_CLIENTS := 7  # plus the host = 8 players

var port := DEFAULT_PORT


func create_host_peer(options: Dictionary) -> MultiplayerPeer:
	port = options.get("port", DEFAULT_PORT)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, options.get("max_clients", MAX_CLIENTS))
	if err != OK:
		last_error = "Couldn't host on port %d (%s). Is another game already hosting?" % [port, error_string(err)]
		return null
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	return peer


func create_client_peer(invite_code: String) -> MultiplayerPeer:
	var address := "127.0.0.1"
	var target_port := DEFAULT_PORT
	var code := invite_code.strip_edges()
	if code != "":
		var parts := code.split(":")
		address = parts[0]
		if parts.size() > 1:
			if not parts[1].is_valid_int():
				last_error = "'%s' isn't a valid port." % parts[1]
				return null
			target_port = parts[1].to_int()

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, target_port)
	if err != OK:
		last_error = "Couldn't connect to %s:%d (%s)." % [address, target_port, error_string(err)]
		return null
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	return peer


func get_invite_code() -> String:
	var best := "127.0.0.1"
	var best_rank := 100
	for address in IP.get_local_addresses():
		var rank := _address_rank(address)
		if rank < best_rank:
			best = address
			best_rank = rank
	return "%s:%d" % [best, port]


## Lower is better: which of this computer's addresses friends can most
## likely reach.
func _address_rank(address: String) -> int:
	if address.contains(":"):
		return 99  # IPv6, skip for now
	if address.begins_with("100."):
		return 0  # Tailscale
	if address.begins_with("192.168.") or address.begins_with("10."):
		return 1  # home network
	if address.begins_with("172."):
		return 2  # often virtual adapters (WSL, Docker), sometimes LAN
	if address.begins_with("127.") or address.begins_with("169.254."):
		return 50
	return 10
