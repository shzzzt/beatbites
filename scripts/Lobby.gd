extends Control
@onready var join_timeout: Timer = $JoinTimeout # Limits connection waiting.


func _ready() -> void:
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
		# The client already receives its connected-to-host message.
		$Content/Status.text = "Player 2 connected. Both players are ready."

func _on_peer_left(_peer_id: int) -> void:
	_on_opponent_left() # Either player's departure uses the same cleanup.


func _on_opponent_left() -> void:
	if Net.opponent_id == 0:
		return # Ignore duplicate notifications or our own cleanup.

	join_timeout.stop() # Cancel any remaining connection deadline.
	Net.leave_game() # Close the old session and clear the opponent.
	$Content/Host.disabled = false # Allow another hosting attempt.
	$Content/Join.disabled = false # Allow another joining attempt.
	$Content/Status.text = "Opponent left. You can host or join again."
