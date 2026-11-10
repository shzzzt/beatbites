extends Node
signal opponent_joined(peer_id: int) # Notify the lobby of a new opponent.

signal opponent_stats_updated(new_score: int, new_lives: int)
signal match_prepared # Tell the lobby that match settings arrived.
var match_seed: int = 0 # Both phones will store the same number.
const PORT: int = 24567 # Both devices must use the same network port.
var is_host: bool = false # Whether this device created the match.
var opponent_id: int = 0 # Zero means no opponent is connected.
signal both_players_loaded # Both levels are ready.
var loaded_players: Dictionary = {} # Track each player's report once.

signal clock_sampled # A clock measurement has arrived.
var clock_roundtrip_ms: int = 0 # Time for the message's journey and reply.
var host_clock_offset_ms: float = 0.0 # Add this to client time to estimate host time.
signal online_match_finished
var finished_players: Dictionary = {} # Final reports received by the host.
var clock_samples_received: int = 0
var best_clock_roundtrip_ms: int = -1 # No sample chosen yet.

signal client_clock_ready # The joining phone finished its clock check.
signal start_scheduled(host_music_start_ms: int)

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
	finished_players.clear()
	
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
	finished_players.clear() # Forget the previous match's reports.
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


@rpc("any_peer", "call_remote", "reliable")
func request_clock(client_sent_ms: int) -> void:
	if not is_host:
		return # Only the host answers clock requests.

	var sender: int = multiplayer.get_remote_sender_id()
	if sender != opponent_id:
		return # Answer only our connected opponent.

	# Return the original timestamp and the host's current time.
	receive_clock.rpc_id(sender, client_sent_ms, Time.get_ticks_msec())


@rpc("authority", "call_remote", "reliable")
func receive_clock(client_sent_ms: int, host_ms: int) -> void:
	var received_ms: int = Time.get_ticks_msec()
	var roundtrip_ms: int = received_ms - client_sent_ms
	var midpoint_ms: float = (float(client_sent_ms) + received_ms) / 2.0
	var offset_ms: float = float(host_ms) - midpoint_ms

	# Keep the offset belonging to the fastest reply.
	if best_clock_roundtrip_ms == -1 or roundtrip_ms < best_clock_roundtrip_ms:
		best_clock_roundtrip_ms = roundtrip_ms
		clock_roundtrip_ms = roundtrip_ms
		host_clock_offset_ms = offset_ms

	clock_samples_received += 1

	if clock_samples_received < 5:
		request_clock.rpc_id(1, Time.get_ticks_msec())
	else:
		clock_sampled.emit() # Notify the level after all five replies.
		
func begin_clock_check() -> void:
	if is_host:
		return # Only the joining phone needs to measure the difference.

	clock_samples_received = 0
	best_clock_roundtrip_ms = -1
	host_clock_offset_ms = 0.0
	clock_roundtrip_ms = 0
	request_clock.rpc_id(1, Time.get_ticks_msec())

@rpc("any_peer", "call_remote", "reliable")
func report_clock_ready() -> void:
	if not is_host:
		return # Only the host handles this report.

	if multiplayer.get_remote_sender_id() != opponent_id:
		return # Accept only our connected opponent.

	client_clock_ready.emit()

@rpc("authority", "call_local", "reliable")
func schedule_start(host_music_start_ms: int) -> void:
	start_scheduled.emit(host_music_start_ms)

@rpc("any_peer", "call_remote", "reliable")
func receive_stats(new_score: int, new_lives: int) -> void:
	if multiplayer.get_remote_sender_id() != opponent_id:
		return # Accept updates only from our opponent.

	if new_score < 0 or new_lives < 0 or new_lives > 3:
		return # Ignore invalid values.

	opponent_stats_updated.emit(new_score, new_lives)

# Each phone sends its final numbers to the host (peer 1).
@rpc("any_peer", "call_local", "reliable")
func report_match_finished(final_score: int, final_lives: int) -> void:
	if not is_host or opponent_id == 0:
		return # Only the host collects reports, during a match.

	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id() # The host reporting to itself.

	if sender != 1 and sender != opponent_id:
		return # Ignore anyone who isn't in this match.
	if finished_players.has(sender):
		return # Accept only one report per player.
	if final_score < 0 or final_lives < 0 or final_lives > 3:
		return # Reject impossible numbers.

	finished_players[sender] = {"score": final_score, "lives": final_lives}

	# When both reports are in, tell both phones.
	if finished_players.has(1) and finished_players.has(opponent_id):
		confirm_match_finished.rpc()


# Host tells everyone (including itself) that both players finished.
@rpc("authority", "call_local", "reliable")
func confirm_match_finished() -> void:
	online_match_finished.emit()
