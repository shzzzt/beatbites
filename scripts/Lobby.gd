extends Control
# Online lobby: host or join by IP. Status text goes into the host/join panels;
# problems (can't connect, opponent left) appear in the pink error panel (R8).

@onready var join_timeout: Timer = $JoinTimeout # Limits connection waiting.
@onready var level_pick: OptionButton = %LevelPick # Host's level choice.


func _ready() -> void:
	# Fill the picker; item id = level number (1-5).
	for i in GameState.MEALS.size():
		level_pick.add_item("%d  %s" % [i + 1, GameState.MEALS[i]["name"]], i + 1)
	level_pick.select(0) # Breakfast by default.

	# Explain why we came back here (e.g. the opponent left mid-match).
	if Net.lobby_message != "":
		show_error("MATCH ENDED", Net.lobby_message)
		Net.lobby_message = ""

	%Back.pressed.connect(_on_back_pressed)
	%BackToModes.pressed.connect(_on_back_pressed)
	%Host.pressed.connect(_on_host_pressed)
	%Join.pressed.connect(_on_join_pressed)
	%Address.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	Net.opponent_joined.connect(_on_opponent_joined)
	# Reuse our existing failure handler when time runs out.
	join_timeout.timeout.connect(_on_connection_failed)

	# Handle departures after Godot finishes its current network events.
	multiplayer.peer_disconnected.connect(_on_peer_left, CONNECT_DEFERRED)
	multiplayer.server_disconnected.connect(_on_opponent_left, CONNECT_DEFERRED)

	%Start.pressed.connect(_on_start_pressed)
	Net.match_prepared.connect(_on_match_prepared)


# --- Small helpers that change what the screen shows ------------------------

func show_error(title: String, message: String) -> void:
	%ErrorTitle.text = "! " + title
	%ErrorText.text = message
	%ErrorPanel.show()


func show_join_status(message: String) -> void:
	%JoinStatus.text = message
	%JoinStatus.visible = message != ""


# Back to the starting layout: both panels, nothing pressed yet.
func reset_lobby() -> void:
	%Host.show()
	%Host.disabled = false
	%Join.disabled = false
	%HostInfo.hide()
	level_pick.hide()
	%Start.hide()
	%Start.disabled = true
	%JoinPanel.show()
	show_join_status("")


# --- Buttons and network events ---------------------------------------------

func _on_back_pressed() -> void:
	join_timeout.stop() # Cancel the connection deadline.
	Net.leave_game() # Release the connection and hosting port.
	# Return to the Offline / Online choice.
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")


func _on_host_pressed() -> void:
	%ErrorPanel.hide()
	var error: Error = Net.host_game() # Ask Net to create the server.
	if error != OK:
		show_error("CAN'T HOST", "Could not host: %s. Try again." % error_string(error))
		return # Keep the lobby available for another attempt.

	# Hosting: swap the HOST button for the IP box, level picker and START.
	%Host.hide()
	%JoinPanel.hide() # Hosting and joining are separate roles.
	%HostInfo.show()
	%HostStatus.text = "Waiting for player 2 …"
	level_pick.show() # Only the host chooses the meal.
	%Start.show()
	%Start.disabled = true
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

	%HostIP.text = "\n".join(addresses)
	if addresses.is_empty():
		%HostIP.text = "No Wi-Fi address found"


func _on_join_pressed() -> void:
	%ErrorPanel.hide()
	var address: String = %Address.text.strip_edges()
	if not address.is_valid_ip_address():
		show_join_status("Enter a valid host IP address.")
		return # Reject empty or incorrectly formatted addresses.

	var error: Error = Net.join_game(address)
	if error != OK:
		show_error("CAN'T JOIN", "Could not join: %s." % error_string(error))
		return

	%Host.disabled = true # Prevent overlapping connection attempts.
	%Join.disabled = true
	show_join_status("Connecting...")
	join_timeout.start() # Begin the eight-second limit.


func _on_connected() -> void:
	join_timeout.stop() # Cancel the connection deadline.
	show_join_status("Connected! Waiting for the host to start...")


func _on_connection_failed() -> void:
	join_timeout.stop() # Cancel the connection deadline.
	Net.leave_game() # Clean up the failed connection.
	reset_lobby()
	show_error("CAN'T REACH HOST",
		"Check that both phones are on the same Wi-Fi, then try again.")


func _on_opponent_joined(_peer_id: int) -> void:
	if Net.is_host:
		%HostStatus.text = "Player 2 connected! Pick a meal and start."
		%Start.disabled = false # Only the host can start.


func _on_peer_left(_peer_id: int) -> void:
	_on_opponent_left() # Either player's departure uses the same cleanup.


func _on_opponent_left() -> void:
	if Net.opponent_id == 0:
		return # Ignore duplicate notifications or our own cleanup.

	join_timeout.stop() # Cancel any remaining connection deadline.
	Net.leave_game() # Close the old session and clear the opponent.
	reset_lobby()
	show_error("OPPONENT LEFT", "You can host or join again.")


func _on_start_pressed() -> void:
	if not Net.is_host or Net.opponent_id == 0:
		return # Starting requires the host and a connected opponent.

	%Start.disabled = true # Prevent repeated presses.
	# Send one seed and the chosen level to both phones.
	Net.prepare_match.rpc(randi(), level_pick.get_selected_id())


func _on_match_prepared() -> void:
	GameState.mode = "online" # Tell the level to wait for a network start.
	var level_path: String = "res://scenes/levels/level_%02d.tscn" % Net.match_level
	# Load after the current network callback finishes.
	get_tree().call_deferred("change_scene_to_file", level_path)
