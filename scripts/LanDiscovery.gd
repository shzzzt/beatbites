class_name LanDiscovery
extends Node
# Finds matches on the same Wi-Fi / hotspot without typing an IP.
#
#   Host:   advertise(info) sends a small "I'm hosting" UDP broadcast every
#           second to everyone on the local network.
#   Joiner: listen() collects those broadcasts and emits hosts_changed with
#           one entry per host. A host disappears 4 s after its last message.
#
# A broadcast goes to every device on the network at once (address
# x.x.x.255 or 255.255.255.255). It never leaves the local network.
# Android drops broadcasts unless the app has the "Change Wi-Fi Multicast
# State" permission; Godot then holds the needed lock while broadcasting is
# enabled on a socket.

signal hosts_changed(hosts: Array) # Array of {ip, name, meal}, one per host.

const PORT: int = 24568 # Separate from the game port (24567).
const MAGIC: String = "beatbites-v1" # Ignore packets from other apps.
const SEND_INTERVAL: float = 1.0
const HOST_TIMEOUT_MS: int = 4000

var _advert: Dictionary = {} # What the host is announcing (empty = not hosting).
var _sender: PacketPeerUDP
var _receiver: PacketPeerUDP
var _send_timer: float = 0.0
var _hosts: Dictionary = {} # host id -> {name, meal, ips: {ip: seen_ms}, seen_ms}
var _session_id: String = "" # Random per hosting session, so copies merge.


# --- Host side --------------------------------------------------------------

func advertise(info: Dictionary) -> void:
	_session_id = "%08x" % randi()
	_advert = info.duplicate()
	if _sender == null:
		_sender = PacketPeerUDP.new()
		_sender.set_broadcast_enabled(true)
	_send_timer = 0.0 # Announce right away.


func update_advert(info: Dictionary) -> void:
	if not _advert.is_empty():
		_advert = info.duplicate()


func stop_advertising() -> void:
	_advert = {}
	if _sender:
		_sender.close()
		_sender = null


# --- Joiner side ------------------------------------------------------------

func listen() -> Error:
	stop_listening()
	_receiver = PacketPeerUDP.new()
	_receiver.set_broadcast_enabled(true) # Also makes Android accept broadcasts.
	var error: Error = _receiver.bind(PORT)
	if error != OK:
		_receiver = null
	return error


func stop_listening() -> void:
	if _receiver:
		_receiver.close()
		_receiver = null
	if not _hosts.is_empty():
		_hosts.clear()
		hosts_changed.emit([])


func get_hosts() -> Array:
	var list: Array = []
	for host: Dictionary in _hosts.values():
		list.append({"ip": _best_ip(host["ips"]), "name": host["name"], "meal": host["meal"]})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["name"] < b["name"])
	return list


# --- Every frame ------------------------------------------------------------

func _process(delta: float) -> void:
	if not _advert.is_empty():
		_send_timer -= delta
		if _send_timer <= 0.0:
			_send_timer = SEND_INTERVAL
			_broadcast()

	if _receiver:
		_read_packets()


func _broadcast() -> void:
	var message: Dictionary = _advert.duplicate()
	message["magic"] = MAGIC
	message["id"] = _session_id
	var bytes: PackedByteArray = JSON.stringify(message).to_utf8_buffer()
	for address in _broadcast_addresses():
		_sender.set_dest_address(address, PORT)
		_sender.put_packet(bytes)


# 255.255.255.255 plus "x.y.z.255" for each of our IPv4 networks. Phone
# hotspots use /24 networks, and the hotspot phone itself often needs the
# x.y.z.255 form to send on the Wi-Fi side instead of mobile data.
func _broadcast_addresses() -> PackedStringArray:
	var addresses: PackedStringArray = ["255.255.255.255"]
	for local in IP.get_local_addresses():
		if ":" in local or local.begins_with("127.") or local.begins_with("169.254."):
			continue
		var parts: PackedStringArray = local.split(".")
		if parts.size() == 4:
			var subnet: String = "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
			if not subnet in addresses:
				addresses.append(subnet)
	return addresses


func _read_packets() -> void:
	var changed: bool = false
	var now: int = Time.get_ticks_msec()

	while _receiver.get_available_packet_count() > 0:
		var bytes: PackedByteArray = _receiver.get_packet()
		var ip: String = _receiver.get_packet_ip()
		if not _advert.is_empty():
			continue # A hosting phone doesn't list other matches.
		var data = JSON.parse_string(bytes.get_string_from_utf8())
		if not (data is Dictionary) or data.get("magic", "") != MAGIC:
			continue # Not a Beat Bites match.
		# One host can reach us from several of its addresses (one per network
		# it broadcasts on), so group packets by the host's session id.
		var id: String = str(data.get("id", ip)).left(16)
		var player_name: String = GameState.clean_username(str(data.get("name", "")))
		var host_name: String = player_name if player_name != "" else "Someone"
		var meal: String = str(data.get("meal", "")).left(12)
		var host: Dictionary = _hosts.get(id, {})
		if host.is_empty() or host["name"] != host_name or host["meal"] != meal 				or not host["ips"].has(ip):
			changed = true
		var ips: Dictionary = host.get("ips", {})
		ips[ip] = now
		_hosts[id] = {"name": host_name, "meal": meal, "ips": ips, "seen_ms": now}

	# Forget hosts we haven't heard from for a while (they stopped hosting).
	for id in _hosts.keys():
		if now - int(_hosts[id]["seen_ms"]) > HOST_TIMEOUT_MS:
			_hosts.erase(id)
			changed = true

	if changed:
		hosts_changed.emit(get_hosts())


# Pick the host address that is on the same network as one of ours (same
# first three numbers, e.g. 192.168.43.x); otherwise the one heard most recently.
func _best_ip(ips: Dictionary) -> String:
	var best: String = ""
	var best_seen: int = -1
	for local in IP.get_local_addresses():
		var parts: PackedStringArray = local.split(".")
		if parts.size() != 4 or local.begins_with("127."):
			continue
		var prefix: String = "%s.%s.%s." % [parts[0], parts[1], parts[2]]
		for ip: String in ips.keys():
			if ip.begins_with(prefix):
				return ip
	for ip: String in ips.keys():
		if int(ips[ip]) > best_seen:
			best = ip
			best_seen = int(ips[ip])
	return best


func _exit_tree() -> void:
	stop_advertising()
	stop_listening() # Free the port when leaving the lobby.
