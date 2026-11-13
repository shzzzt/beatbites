extends Control
# Online lobby. Hosting announces the match on the local Wi-Fi (LanDiscovery);
# joiners see it in a list and tap JOIN, Roblox-lobby style. Typing the IP is
# still possible as a fallback. Problems appear in the pink error panel (R8).

const JOIN_PINK := Color("#C23B80")

@onready var join_timeout: Timer = $JoinTimeout # Limits connection waiting.
@onready var level_pick: OptionButton = %LevelPick # Host's level choice.
var discovery: LanDiscovery


func _ready() -> void:
	# Fill the picker; item id = level number (1-5).
	for i in GameState.MEALS.size():
		level_pick.add_item("%d  %s" % [i + 1, GameState.MEALS[i]["name"]], i + 1)
	level_pick.select(0) # Breakfast by default.
	level_pick.item_selected.connect(func(_index: int) -> void: update_advert())

	# Username: saved as soon as it changes, sent to the rival when connecting.
	%NameField.text = GameState.username
	%NameField.text_changed.connect(_on_name_changed)

	# Explain why we came back here (e.g. the opponent left mid-match).
	if Net.lobby_message != "":
		show_error("MATCH ENDED", Net.lobby_message)
		Net.lobby_message = ""

	%Back.pressed.connect(_on_back_pressed)
	%BackToModes.pressed.connect(_on_back_pressed)
	%Host.pressed.connect(_on_host_pressed)
	%Join.pressed.connect(_on_manual_join_pressed)
	%Address.text_submitted.connect(func(_text: String) -> void: _on_manual_join_pressed())
	%ManualToggle.pressed.connect(_on_manual_toggle_pressed)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	Net.opponent_joined.connect(_on_opponent_joined)
	Net.opponent_named.connect(_on_opponent_named)
	# Reuse our existing failure handler when time runs out.
	join_timeout.timeout.connect(_on_connection_failed)

	# Handle departures after Godot finishes its current network events.
	multiplayer.peer_disconnected.connect(_on_peer_left, CONNECT_DEFERRED)
	multiplayer.server_disconnected.connect(_on_opponent_left, CONNECT_DEFERRED)

	%Start.pressed.connect(_on_start_pressed)
	Net.match_prepared.connect(_on_match_prepared)

	discovery = LanDiscovery.new()
	add_child(discovery) # Freed with the lobby, which also closes its sockets.
	discovery.hosts_changed.connect(_on_hosts_changed)
	start_searching()


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
	discovery.stop_advertising()
	%NameField.editable = true
	%Host.show()
	%Host.disabled = false
	%Join.disabled = false
	%HostInfo.hide()
	level_pick.hide()
	%Start.hide()
	%Start.disabled = true
	%JoinPanel.show()
	show_join_status("")
	start_searching()


func start_searching() -> void:
	var error: Error = discovery.listen()
	if error == OK:
		%Searching.text = "Looking for matches on this Wi-Fi..."
	else:
		# The port is busy (e.g. a second copy of the game on one PC).
		%Searching.text = "Can't search on this device. Use JOIN BY IP."
		%ManualRow.show()
	_on_hosts_changed([])


# Rebuild the list of match cards whenever a host appears or disappears.
func _on_hosts_changed(hosts: Array) -> void:
	for card in %MatchList.get_children():
		card.queue_free()
	%Searching.visible = hosts.is_empty() or %Searching.text.begins_with("Can't")
	for host: Dictionary in hosts.slice(0, 3): # Room for three cards.
		var card: Button = make_match_card(host)
		%MatchList.add_child(card)
		card.pressed.connect(join_address.bind(str(host["ip"])))


# One tappable card: "Ana's match / Snack" with a JOIN chip on the right.
func make_match_card(host: Dictionary) -> Button:
	var card := Button.new()
	card.theme_type_variation = &"WhiteButton"
	card.custom_minimum_size = Vector2(0, 112)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE # Taps go to the card.
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)

	var title := Label.new()
	title.theme_type_variation = &"MealName"
	title.add_theme_font_size_override("font_size", 36)
	title.text = "%s's match" % host["name"]
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)

	var meal := Label.new()
	meal.theme_type_variation = &"SmallMuted"
	meal.text = "%s · tap to join" % host["meal"]
	text.add_child(meal)

	var chip := PanelContainer.new()
	chip.theme_type_variation = &"ChipPanel"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.custom_minimum_size = Vector2(120, 64) # Room around the word JOIN.
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	var join_label := Label.new()
	join_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	join_label.theme_type_variation = &"CardTitle"
	join_label.add_theme_font_size_override("font_size", 24)
	join_label.add_theme_color_override("font_color", JOIN_PINK)
	join_label.text = "JOIN"
	chip.add_child(join_label)
	return card


# What the host announces: its name and the meal currently picked.
func advert_info() -> Dictionary:
	return {
		"name": GameState.username,
		"meal": GameState.meal_name(level_pick.get_selected_id()),
	}


func update_advert() -> void:
	discovery.update_advert(advert_info()) # Does nothing unless we're hosting.


# --- Buttons and network events ---------------------------------------------

func _on_name_changed(text: String) -> void:
	GameState.set_username(text) # Ignores empty names, keeps the old one.


func _on_manual_toggle_pressed() -> void:
	%ManualRow.visible = not %ManualRow.visible


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

	# Hosting: swap the HOST button for the info box, level picker and START.
	%NameField.editable = false # The name is announced now.
	%Host.hide()
	%JoinPanel.hide() # Hosting and joining are separate roles.
	discovery.stop_listening()
	%HostInfo.show()
	%HostStatus.text = "Hosting as %s. Waiting for player 2 …" % GameState.username
	level_pick.show() # Only the host chooses the meal.
	%Start.show()
	%Start.disabled = true
	show_host_addresses()
	discovery.advertise(advert_info()) # Nearby joiners now see this match.


func show_host_addresses() -> void:
	var addresses: PackedStringArray = []
	for address in IP.get_local_addresses():
		# Keep IPv4 addresses, excluding this-device-only and link-local ones.
		if ":" in address or address.begins_with("127."):
			continue
		if address.begins_with("169.254."):
			continue
		addresses.append(address)

	# Shown small, for friends who need to use JOIN BY IP.
	%HostIP.text = "IP: " + ", ".join(addresses)
	if addresses.is_empty():
		%HostIP.text = "No Wi-Fi address found"


func _on_manual_join_pressed() -> void:
	var address: String = %Address.text.strip_edges()
	if not address.is_valid_ip_address():
		show_join_status("Enter a valid host IP address.")
		return # Reject empty or incorrectly formatted addresses.
	join_address(address)


func join_address(address: String) -> void:
	%ErrorPanel.hide()
	var error: Error = Net.join_game(address)
	if error != OK:
		show_error("CAN'T JOIN", "Could not join: %s." % error_string(error))
		return

	%NameField.editable = false
	%Host.disabled = true # Prevent overlapping connection attempts.
	%Join.disabled = true
	discovery.stop_listening() # Hide the list while connecting.
	%Searching.hide()
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
		discovery.stop_advertising() # The match is full now.
		%HostStatus.text = "Player 2 connected! Pick a meal and start."
		%Start.disabled = false # Only the host can start.


# Their username arrived (sent right after connecting).
func _on_opponent_named(player_name: String) -> void:
	if Net.is_host:
		%HostStatus.text = "%s joined! Pick a meal and start." % player_name
	else:
		show_join_status("Joined %s's match! Waiting for them to start..." % player_name)


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
