extends Control


func _ready() -> void:
	$Content/Back.pressed.connect(_on_back_pressed)
	$Content/Host.pressed.connect(_on_host_pressed)
	$Content/Join.pressed.connect(_on_join_pressed)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)


func _on_back_pressed() -> void:
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

func _on_connected() -> void:
	$Content/Status.text = "Connected to host. Waiting for match..."


func _on_connection_failed() -> void:
	Net.leave_game() # Clean up the failed connection.
	$Content/Host.disabled = false # Allow another attempt.
	$Content/Join.disabled = false
	$Content/Status.text = "Can't reach host. Check Wi-Fi and the IP address."
