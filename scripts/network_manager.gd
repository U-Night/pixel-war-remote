extends Node

## Autoload singleton gérant la connexion TCP au serveur Pixel War.
## Implémente le protocole MessageFramer + Packet identique au serveur C#.

# ──── Signaux ────
signal connected(player_id: int)
signal disconnected
signal packet_received(type: String, data: String)

# ──── Configuration ────
var server_address: String = "127.0.0.1"
var server_port: int = 6967

# ──── État ────
var player_id: int = -1
var server_connected: bool = false

# ──── Internes ────
var _tcp: StreamPeerTCP = null
var _status: StreamPeerTCP.Status = StreamPeerTCP.Status.STATUS_NONE
var _handshake_done: bool = false

# Buffer de réception pour le MessageFramer
var _recv_buffer: PackedByteArray = PackedByteArray()

# ──── Packet Types (miroir du C#) ────
enum PacketType {
	Ping = 0x0001,
	Pong = 0x0002,
	Disconnect = 0x0003,
	PlayerJoin = 0x0004,
	PlayerLeave = 0x0005,
	Message = 0x0006,
}

# Map string ↔ enum pour la sérialisation (le serveur C# envoie le nom en string)
const PACKET_TYPE_NAMES: Dictionary = {
	"Ping": PacketType.Ping,
	"Pong": PacketType.Pong,
	"Disconnect": PacketType.Disconnect,
	"PlayerJoin": PacketType.PlayerJoin,
	"PlayerLeave": PacketType.PlayerLeave,
	"Message": PacketType.Message,
}

func _get_packet_type_name(type: PacketType) -> String:
	for key in PACKET_TYPE_NAMES:
		if PACKET_TYPE_NAMES[key] == type:
			return key
	return "Message"


# ══════════════════════════════════════════════════════════
# Connexion
# ══════════════════════════════════════════════════════════

func connect_to_server(address: String = "", port: int = 0) -> void:
	if address != "":
		server_address = address
	if port != 0:
		server_port = port

	print("[NetworkManager] Connexion à %s:%d..." % [server_address, server_port])

	_tcp = StreamPeerTCP.new()
	_tcp.set_big_endian(false) # Little-endian comme le serveur C# (BitConverter)
	var err = _tcp.connect_to_host(server_address, server_port)
	if err != OK:
		printerr("[NetworkManager] Erreur de connexion: ", err)
		return

	_handshake_done = false
	_recv_buffer = PackedByteArray()


func disconnect_from_server() -> void:
	if _tcp == null:
		return

	if server_connected:
		# Envoyer un packet Disconnect
		send_packet(PacketType.Disconnect, "")

	_tcp.disconnect_from_host()
	_tcp = null
	server_connected = false
	_handshake_done = false
	player_id = -1
	_recv_buffer = PackedByteArray()
	disconnected.emit()
	print("[NetworkManager] Déconnecté")


# ══════════════════════════════════════════════════════════
# Poll (appelé chaque frame)
# ══════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	if _tcp == null:
		return

	_tcp.poll()
	var new_status = _tcp.get_status()

	# Détection de connexion établie
	if _status != StreamPeerTCP.Status.STATUS_CONNECTED and new_status == StreamPeerTCP.Status.STATUS_CONNECTED:
		print("[NetworkManager] TCP connecté, attente du handshake...")

	# Détection de déconnexion
	if _status == StreamPeerTCP.Status.STATUS_CONNECTED and new_status != StreamPeerTCP.Status.STATUS_CONNECTED:
		print("[NetworkManager] Connexion perdue")
		server_connected = false
		_handshake_done = false
		disconnected.emit()

	_status = new_status

	if _status != StreamPeerTCP.Status.STATUS_CONNECTED:
		return

	# Lire les données disponibles
	var available = _tcp.get_available_bytes()
	if available > 0:
		var result = _tcp.get_data(available)
		if result[0] == OK:
			_recv_buffer.append_array(result[1])

	# Traiter les messages complets dans le buffer
	_process_buffer()


# ══════════════════════════════════════════════════════════
# MessageFramer — Protocole : [4 bytes longueur LE] + [payload UTF-8]
# ══════════════════════════════════════════════════════════

func _process_buffer() -> void:
	# Boucle tant qu'on peut extraire des messages complets
	while _recv_buffer.size() >= 4:
		# Lire la longueur (4 bytes, little-endian)
		var msg_len = _recv_buffer.decode_s32(0)

		if msg_len <= 0 or msg_len > 1048576: # 1MB max comme le serveur
			printerr("[NetworkManager] Taille de message invalide: ", msg_len)
			disconnect_from_server()
			return

		# Vérifier qu'on a le message complet
		if _recv_buffer.size() < 4 + msg_len:
			break # Attendre plus de données

		# Extraire le payload
		var payload = _recv_buffer.slice(4, 4 + msg_len)
		_recv_buffer = _recv_buffer.slice(4 + msg_len)

		var message = payload.get_string_from_utf8()

		if not _handshake_done:
			_handle_handshake_message(message)
		else:
			_handle_packet_message(payload)


func _handle_handshake_message(message: String) -> void:
	if message.begins_with("PIXELWAR"):
		# Serveur s'annonce → on répond
		print("[NetworkManager] Serveur: ", message)
		_send_framed_string("REMOTE 1.0")
	elif message.begins_with("WELCOME"):
		# Handshake terminé, extraire l'ID
		var parts = message.split(" ")
		if parts.size() >= 2:
			player_id = int(parts[1])
		_handshake_done = true
		server_connected = true
		print("[NetworkManager] Handshake réussi! Player ID: ", player_id)
		connected.emit(player_id)


func _handle_packet_message(raw_bytes: PackedByteArray) -> void:
	# Désérialiser le Packet (format identique au C#)
	# [2B type_size LE][type UTF-8][4B data_size LE][data bytes]
	if raw_bytes.size() < 6: # Minimum: 2 + 0 + 4 + 0
		printerr("[NetworkManager] Paquet trop court")
		return

	var offset = 0

	# TYPE_SIZE (2 bytes, ushort, little-endian)
	var type_size = raw_bytes.decode_u16(offset)
	offset += 2

	if raw_bytes.size() < 2 + type_size + 4:
		printerr("[NetworkManager] Paquet malformé: type tronqué")
		return

	# TYPE (string UTF-8)
	var type_bytes = raw_bytes.slice(offset, offset + type_size)
	var type_name = type_bytes.get_string_from_utf8()
	offset += type_size

	# DATA_SIZE (4 bytes, int, little-endian)
	var data_size = raw_bytes.decode_s32(offset)
	offset += 4

	if raw_bytes.size() < offset + data_size:
		printerr("[NetworkManager] Paquet malformé: données tronquées")
		return

	# DATA
	var data_bytes = raw_bytes.slice(offset, offset + data_size)
	var data_str = data_bytes.get_string_from_utf8()

	# Traitement spécial pour Ping → répondre Pong
	if type_name == "Ping":
		send_packet(PacketType.Pong, "")
		return

	packet_received.emit(type_name, data_str)


# ══════════════════════════════════════════════════════════
# Envoi
# ══════════════════════════════════════════════════════════

## Envoie une string brute avec le préfixe de longueur (pour le handshake)
func _send_framed_string(message: String) -> void:
	if _tcp == null or _status != StreamPeerTCP.Status.STATUS_CONNECTED:
		return

	var payload = message.to_utf8_buffer()
	var length_prefix = PackedByteArray()
	length_prefix.resize(4)
	length_prefix.encode_s32(0, payload.size())

	_tcp.put_data(length_prefix)
	_tcp.put_data(payload)


## Envoie un packet sérialisé avec le MessageFramer
func send_packet(type: PacketType, data: String) -> void:
	if _tcp == null or _status != StreamPeerTCP.Status.STATUS_CONNECTED:
		return

	var packet_bytes = _serialize_packet(type, data)

	# Envoyer les bytes bruts du packet avec le préfixe de longueur.
	# Le serveur C# lit [4B longueur LE] + [N bytes payload] via TcpMessageFramer,
	# puis fait Encoding.UTF8.GetBytes(message) pour reconstituer les bytes du Packet.
	# On doit donc envoyer les bytes tels quels — la conversion GDScript
	# get_string_from_utf8() corrompt les octets binaires (type_size, data_size).
	_send_framed_bytes(packet_bytes)


## Envoie des bytes bruts avec le préfixe de longueur (pour les paquets binaires)
func _send_framed_bytes(payload: PackedByteArray) -> void:
	if _tcp == null or _status != StreamPeerTCP.Status.STATUS_CONNECTED:
		return

	var length_prefix = PackedByteArray()
	length_prefix.resize(4)
	length_prefix.encode_s32(0, payload.size())

	_tcp.put_data(length_prefix)
	_tcp.put_data(payload)


## Sérialise un packet au format binaire identique au C#
## [2B type_size LE][type UTF-8][4B data_size LE][data bytes]
func _serialize_packet(type: PacketType, data: String) -> PackedByteArray:
	var type_name = _get_packet_type_name(type)
	var type_bytes = type_name.to_utf8_buffer()
	var data_bytes = data.to_utf8_buffer()

	var buffer = PackedByteArray()
	var total_size = 2 + type_bytes.size() + 4 + data_bytes.size()
	buffer.resize(total_size)

	var offset = 0

	# TYPE_SIZE (2 bytes, ushort)
	buffer.encode_u16(offset, type_bytes.size())
	offset += 2

	# TYPE (N bytes)
	for i in type_bytes.size():
		buffer[offset + i] = type_bytes[i]
	offset += type_bytes.size()

	# DATA_SIZE (4 bytes, int)
	buffer.encode_s32(offset, data_bytes.size())
	offset += 4

	# DATA (M bytes)
	for i in data_bytes.size():
		buffer[offset + i] = data_bytes[i]

	return buffer
