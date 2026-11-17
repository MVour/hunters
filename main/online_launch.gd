class_name OnlineLaunch extends RefCounted
## The browser build, opened from the lobby page (online/lobby-ui) as
## `/game/#room=K7QX9P&ticket=…`: join that room straight away, and go back
## to the lobby page when the game is left. The ticket is removed from the
## address bar at once (single-use, and it shouldn't end up in bookmarks).


## The room link to join, or "" when not started from the lobby page.
static func link_from_page() -> String:
	if not OS.has_feature("web"):
		return ""
	var hash := str(JavaScriptBridge.eval("window.location.hash", true))
	JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname)", true)
	var room := ""
	var ticket := ""
	for part in hash.trim_prefix("#").split("&", false):
		var kv := part.split("=")
		if kv.size() != 2:
			continue
		if kv[0] == "room":
			room = kv[1]
		elif kv[0] == "ticket":
			ticket = kv[1]
	if not _only(room, "ABCDEFGHJKLMNPQRSTUVWXYZ23456789") or room.length() > 16:
		return ""
	if not _only(ticket, "0123456789abcdef.") or ticket.length() > 1024:
		return ""
	var secure := str(JavaScriptBridge.eval("window.location.protocol", true)) == "https:"
	var host := str(JavaScriptBridge.eval("window.location.host", true))
	return "%s://%s/play/%s/%s" % ["wss" if secure else "ws", host, room, ticket]


static func back_to_lobby() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = '/'", true)


static func _only(s: String, allowed: String) -> bool:
	if s.is_empty():
		return false
	for c in s:
		if not c in allowed:
			return false
	return true
