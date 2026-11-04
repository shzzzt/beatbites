extends Node
signal opponent_joined(peer_id: int) # Notify the lobby of a new opponent.

signal match_prepared # Tell the lobby that match settings arrived.
var match_seed: int = 0 # Both phones will store the same number.
const PORT: int = 24567 # Both devices must use the same network port.
var is_host: bool = false # Whether this device created the match.
var opponent_id: int = 0 # Zero means no opponent is connected.
signal both_players_loaded # Both levels are ready.
var loaded_players: Dictionary = {} # Track each player's report once.

func _ready() -> void:
	# Listen throughout the app, including across scene changes.
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(peer_id: int) -> void:
	opponent_id = peer_id # Remember the other device's network ID.
	opponent_joined.emit(peer_id) # Tell interested screens.

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
	opponent_id = 0 # Clear the previous opponent when leaving.
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

@rpc("authority", "call_local", "reliable")
func prepare_match(new_seed: int) -> void:
	match_seed = new_seed # Store the host's chosen seed.
	loaded_players.clear() # Start this match with no loading reports.
	match_prepared.emit() # Ask this phone's lobby to update.


@rpc("any_peer", "call_local", "reliable")
func report_level_loaded() -> void:
	if not is_host:
		return # Only the host collects loading reports.

	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id() # The host reported locally.

	if sender != 1 and sender != opponent_id:
		return # Accept only the host or its connected opponent.
	if loaded_players.has(sender):
		return # Count each phone once.

	loaded_players[sender] = true
	if loaded_players.has(1) and loaded_players.has(opponent_id):
		confirm_both_loaded.rpc() # Notify both phones.


@rpc("authority", "call_local", "reliable")
func confirm_both_loaded() -> void:
	both_players_loaded.emit() # Let this phone's level update its HUD.
