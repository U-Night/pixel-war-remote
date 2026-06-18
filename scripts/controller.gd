extends Control

## Controller — Gère l'interface de la manette et l'envoi réseau

# ──── Références UI ────
var joystick: VirtualJoystick
var player_id_label: Label

# ──── Throttle envoi joystick ────
const SEND_INTERVAL: float = 0.05 # 20Hz
var _send_timer: float = 0.0
var _last_joystick_output: Vector2 = Vector2.ZERO

func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	get_window().content_scale_size = Vector2(1280, 720)

	# Récupérer les références UI par chemin direct (plus fiable que % lors des changements de scène)
	joystick = $virtualJoystick
	player_id_label = $playerId

	# Écouter les signaux réseau
	NetworkManager.connected.connect(_on_network_connected)
	NetworkManager.disconnected.connect(_on_network_disconnected)
	NetworkManager.packet_received.connect(_on_packet_received)

	# La connexion est deja etablie par le menu, afficher l'ID recu
	if NetworkManager.player_id >= 0:
		player_id_label.text = str(NetworkManager.player_id)
	else:
		player_id_label.text = "..."


func _process(delta: float) -> void:
	if not NetworkManager.server_connected:
		return

	# Throttle l'envoi du joystick à 20Hz
	_send_timer += delta
	if _send_timer >= SEND_INTERVAL:
		_send_timer = 0.0
		_send_joystick()


func _send_joystick() -> void:
	var output = joystick.output
	# Envoyer seulement si la valeur a changé (éviter le spam quand immobile)
	if output.distance_to(_last_joystick_output) > 0.01 or (output != Vector2.ZERO):
		_last_joystick_output = output
		
		# Récupérer la Node C# qu'on a ajoutée dans l'arbre pour l'UDP
		var udp_node = get_node_or_null("UDPClient")
	
		if udp_node != null:
			# On appelle la méthode C# directement depuis GDScript !
			udp_node.SendInputFromGDScript(output.x, output.y, NetworkManager.player_id)
		else:
			print("[Controller] Node UDPClient introuvable, impossible d'envoyer le joystick")
		

# ──── Callbacks boutons ────

func _on_power_up_pressed() -> void:
	print("PowerUp pressé !")
	if NetworkManager.server_connected:
		var data = JSON.stringify({
			"type": "button",
			"name": "powerup",
			"pressed": true
		})
		NetworkManager.send_packet(NetworkManager.PacketType.Message, data)


func _on_ping_pressed() -> void:
	print("Ping pressé !")
	if NetworkManager.server_connected:
		var data = JSON.stringify({
			"type": "button",
			"name": "ping",
			"pressed": true
		})
		NetworkManager.send_packet(NetworkManager.PacketType.Message, data)


# ──── Callbacks réseau ────

func _on_network_connected(pid: int) -> void:
	player_id_label.text = str(pid)
	print("[Controller] Connecté! Player ID: ", pid)


func _on_network_disconnected() -> void:
	print("[Controller] Déconnecté du serveur")
	NetworkManager.pending_error = "Connexion au serveur perdue."
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _on_packet_received(type: int, data: String) -> void:
	print("[Controller] Packet reçu: ", type, " -> ", data)
	
	# Détecter les messages d'élimination / victoire
	if type == NetworkManager.PacketType.Message and data != "":
		var json = JSON.parse_string(data)
		if json is Dictionary:
			var msg_type = json.get("type", "")
			if msg_type == "eliminated" or msg_type == "victory":
				NetworkManager.game_over_type = msg_type
				_going_to_game_over = true
				get_tree().change_scene_to_file("res://scenes/game_over.tscn")


# ──── DEBUG : à retirer avant la release ────
var _going_to_game_over: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			NetworkManager.game_over_type = "eliminated"
			_going_to_game_over = true
			get_tree().change_scene_to_file("res://scenes/game_over.tscn")
		elif event.keycode == KEY_V:
			NetworkManager.game_over_type = "victory"
			_going_to_game_over = true
			get_tree().change_scene_to_file("res://scenes/game_over.tscn")


# ──── Nettoyage ────

func _exit_tree() -> void:
	# Ne pas déconnecter si on va vers l'écran game_over (il gère sa propre déconnexion)
	if not _going_to_game_over:
		NetworkManager.disconnect_from_server()
