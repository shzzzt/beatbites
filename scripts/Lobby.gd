extends Control
@onready var join_timeout: Timer = $JoinTimeout # Limits connection waiting.
@onready var level_pick: OptionButton = $Content/LevelPick # Host's level choice.

const MEAL_NAMES: Array[String] = ["Breakfast", "Lunch", "Snack", "Dinner", "Dessert"]


func _ready() -> void:
	# Fill the picker; item id = level number (1-5).
	for i in MEAL_NAMES.size():
		level_pick.add_item("%d  %s" % [i + 1, MEAL_NAMES[i]], i + 1)
	level_pick.select(0) # Breakfast by default.

	# Explain why we came back here (e.g. the opponent left mid-match).
	if Net.lobby_message != "":
		$Content/Status.text = Net.lobby_message
		Net.lobby_message = ""

	$Content/Back.pressed.connect(_on_back_pressed)
	$Content/Host.pressed.connect(_on_host_pressed)
	$Content/Join.pressed.connect(_on_join_pressed)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	Net.opponent_joined.connect(_on_opponent_joined)
	# Reuse our existing failure handler when time runs out.
	join_timeout.timeout.connect(_on_connection_failed)
	
		# Handle departures after Godot finishes its current network events.
	multiplayer.peer_disconnected.connect(
		_on_peer_left, CONNECT_DEFERRED
	)
	multiplayer.server_disconnected.connect(
		_on_opponent_left, CONNECT_DEFERRED
	)
	
	$Content/Start.pressed.connect(_on_start_pressed)
	Net.match_prepared.connect(_on_match_prepared)
	
func _on_back_pressed() -> void:
	join_timeout.stop() # Cancel the connection deadline.
	Net.leave_game() # Release the connection and hosting port.
	# Return to the Offline / Online choice.
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")

func _on_host_pressed() -> void:
	var error: Error = Net.host_game() # Ask Net to create the server.
	if error != OK:
		$Content/Status.text = "Could not host: " + error_string(error)
		return # Keep the lobby available for another attempt.

	$Content/Host.disabled = true # Already hosting.
	$Content/Join.disabled = true # Hosting and joining are separate roles.
	$Content/Status.text = "Waiting for player 2..."
	level_pick.show() # Only the host chooses the meal.
	show_host_addresses()
	
	
func show_host_addresses() -> void:
	var addresses: PackedStringArray = []
	for address in IP.get_local_addresses():
		# Keep IPv4 addresses, excluding this-device-only and link-local ones.
		if ":" in address or address.begins_with("127."):
			continue
		if address.begins_with("169.254."):
			continue
		addresses.append(address)

	$Content/HostIP.text = "Local IP addresses:\n" + "\n".join(addresses)
	if addresses.is_empty():
		$Content/HostIP.text = "No local IPv4 address found. Check Wi-Fi."

func _on_join_pressed() -> void:
	var address: String = $Content/Address.text.strip_edges()
	if not address.is_valid_ip_address():
		$Content/Status.text = "Enter a valid host IP address."
		return # Reject empty or incorrectly formatted addresses.

	var error: Error = Net.join_game(address)
	if error != OK:
		$Content/Status.text = "Could not join: " + error_string(error)
		return

	$Content/Host.disabled = true # Prevent overlapping connection attempts.
	$Content/Join.disabled = true
	$Content/Status.text = "Connecting..."
	
	join_timeout.start() # Begin the eight-second limit.

func _on_connected() -> void:
	join_timeout.stop() # Cancel the connection deadline.
	$Content/Status.text = "Connected to host. Waiting for match..."


func _on_connection_failed() -> void:
	join_timeout.stop() # Cancel the connection deadline.
	Net.leave_game() # Clean up the failed connection.
	$Content/Host.disabled = false # Allow another attempt.
	$Content/Join.disabled = false
	$Content/Status.text = "Can't reach host. Check Wi-Fi and the IP address."

func _on_opponent_joined(_peer_id: int) -> void:
	if Net.is_host:
		$Content/Status.text = "Player 2 connected. Both players are ready."
		$Content/Start.disabled = false # Only the host can start.

func _on_peer_left(_peer_id: int) -> void:
	_on_opponent_left() # Either player's departure uses the same cleanup.


func _on_opponent_left() -> void:
	if Net.opponent_id == 0:
		return # Ignore duplicate notifications or our own cleanup.

	$Content/Start.disabled = true # An opponent is required to start.
	join_timeout.stop() # Cancel any remaining connection deadline."text"
	Net.leave_game() # Close the old session and clear the opponent.
	level_pick.hide() # No longer hosting.
	$Content/Host.disabled = false # Allow another hosting attempt.
	$Content/Join.disabled = false # Allow another joining attempt.
	$Content/Status.text = "Opponent left. You can host or join again."

func _on_start_pressed() -> void:
	if not Net.is_host or Net.opponent_id == 0:
		return # Starting requires the host and a connected opponent.

	$Content/Start.disabled = true # Prevent repeated presses.
	# Send one seed and the chosen level to both phones.
	Net.prepare_match.rpc(randi(), level_pick.get_selected_id())


func _on_match_prepared() -> void:
	GameState.mode = "online" # Tell the level to wait for a network start.
	var level_path: String = "res://scenes/levels/level_%02d.tscn" % Net.match_level
	# Load after the current network callback finishes.
	get_tree().call_deferred("change_scene_to_file", level_path)
