extends Control

## Controller — Gère l'interface de la manette et l'envoi réseau

# ──── Références UI ────
var joystick: VirtualJoystick
var player_id_label: Label
var power_up_icon: TextureRect

# ──── Powerup ────
var _current_powerup: String = ""
var _powerup_pending_use: bool = false

const POWERUP_TEXTURES: Dictionary = {
	"sword": preload("res://assets/controller/powerup_sword.svg"),
	"paint_bomb": preload("res://assets/controller/powerup_paint_bomb.svg"),
	"speed": preload("res://assets/controller/powerup_speed.svg"),
	"grow": preload("res://assets/controller/powerup_grow.svg"),
}

# ──── Équipe ────
var _bg_rect: ColorRect

const TEAM_COLORS: Dictionary = {
	0: Color("0A2345"),  # Blue
	1: Color("460909"),  # Red
	2: Color("00321C"),  # Green
	3: Color("968C00"),  # Yellow
}

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
	power_up_icon = $powerUp/powerUpButton/powerUpIcon
	_bg_rect = $ColorRect

	# Écouter les signaux réseau
	NetworkManager.connected.connect(_on_network_connected)
	NetworkManager.disconnected.connect(_on_network_disconnected)
	NetworkManager.packet_received.connect(_on_packet_received)

	# La connexion est deja etablie par le menu, afficher l'ID recu
	if NetworkManager.player_id >= 0:
		player_id_label.text = str(NetworkManager.player_id)
	else:
		player_id_label.text = "..."
	
	# Appliquer la couleur d'équipe si déjà assignée (le paquet arrive souvent avant le controller)
	if NetworkManager.team_id >= 0 and NetworkManager.team_id in TEAM_COLORS:
		_bg_rect.color = TEAM_COLORS[NetworkManager.team_id]

	var udp_client = get_node("UDPClient") # adapte le chemin
	udp_client.SetServerEndpoint(NetworkManager.server_address, NetworkManager.server_port)


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
	if _current_powerup == "" or _powerup_pending_use:
		return
	print("[Controller] Utilisation du powerup: ", _current_powerup)
	if NetworkManager.server_connected:
		var data = JSON.stringify({
			"action": "use"
		})
		NetworkManager.send_packet(NetworkManager.PacketType.Powerup, data)
		_powerup_pending_use = true
		# Feedback visuel : rendre l'icône semi-transparente pendant l'attente
		power_up_icon.modulate.a = 0.4
	else:
		# DEBUG : auto-confirmer quand pas connecté au serveur
		_handle_powerup_packet({"action": "used"})


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
	
	# Gérer les powerups
	if type == NetworkManager.PacketType.Powerup and data != "":
		var json = JSON.parse_string(data)
		if json is Dictionary:
			_handle_powerup_packet(json)
	
	# Gérer l'assignation d'équipe
	if type == NetworkManager.PacketType.TeamAssignment and data != "":
		_handle_team_assignment(data)


# ──── Powerup ────

func _handle_powerup_packet(json: Dictionary) -> void:
	var action = json.get("action", "")
	match action:
		"grant":
			var powerup_name = json.get("powerup", "")
			if powerup_name in POWERUP_TEXTURES:
				_current_powerup = powerup_name
				_powerup_pending_use = false
				power_up_icon.texture = POWERUP_TEXTURES[powerup_name]
				power_up_icon.modulate.a = 1.0
				power_up_icon.visible = true
				print("[Controller] Powerup reçu: ", powerup_name)
		"used":
			_current_powerup = ""
			_powerup_pending_use = false
			power_up_icon.visible = false
			power_up_icon.texture = null
			print("[Controller] Powerup utilisé et confirmé par le serveur")


# ──── Équipe ────

func _handle_team_assignment(data: String) -> void:
	# Format serveur : "TEAM_ASSIGNED:{0-3}"
	if data.begins_with("TEAM_ASSIGNED:"):
		var team_id_str = data.substr("TEAM_ASSIGNED:".length())
		if team_id_str.is_valid_int():
			var team_id = int(team_id_str)
			if team_id in TEAM_COLORS:
				_bg_rect.color = TEAM_COLORS[team_id]
				print("[Controller] Équipe assignée: ", team_id, " -> couleur mise à jour")


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
		# ── Powerup debug (pavé numérique) ──
		elif event.keycode == KEY_KP_1:
			_handle_powerup_packet({"action": "grant", "powerup": "sword"})
		elif event.keycode == KEY_KP_2:
			_handle_powerup_packet({"action": "grant", "powerup": "paint_bomb"})
		elif event.keycode == KEY_KP_3:
			_handle_powerup_packet({"action": "grant", "powerup": "speed"})
		elif event.keycode == KEY_KP_4:
			_handle_powerup_packet({"action": "grant", "powerup": "grow"})
		# ── Team debug (pavé numérique) ──
		elif event.keycode == KEY_KP_5:
			_handle_team_assignment("TEAM_ASSIGNED:0")
		elif event.keycode == KEY_KP_6:
			_handle_team_assignment("TEAM_ASSIGNED:1")
		elif event.keycode == KEY_KP_7:
			_handle_team_assignment("TEAM_ASSIGNED:2")
		elif event.keycode == KEY_KP_8:
			_handle_team_assignment("TEAM_ASSIGNED:3")


# ──── Nettoyage ────

func _exit_tree() -> void:
	# Ne pas déconnecter si on va vers l'écran game_over (il gère sa propre déconnexion)
	if not _going_to_game_over:
		NetworkManager.disconnect_from_server()
