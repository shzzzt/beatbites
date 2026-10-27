extends Node

const PORT: int = 24567 # Both devices must use the same network port.
var is_host: bool = false # Whether this device created the match.


func host_game() -> Error:
	leave_game() # Close any previous connection before hosting.
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(PORT, 1) # Allow one opponent.
	if error != OK:
		return error # Let the lobby display the failure.

	multiplayer.multiplayer_peer = peer # Activate this server.
	is_host = true
	return OK


func leave_game() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close() # Close the current connection.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false # Return to local-only operation.

func join_game(address: String) -> Error:
	leave_game() # Close any previous session.
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, PORT)
	if error != OK:
		return error # Couldn't begin the connection attempt.

	multiplayer.multiplayer_peer = peer # Activate the connecting client.
	return OK # Started connecting; success is reported later.
