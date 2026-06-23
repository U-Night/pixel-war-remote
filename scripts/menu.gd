extends Control

# ──── Timeout pour la connexion ────
const CONNECTION_TIMEOUT: float = 5.0
var _connecting: bool = false
var _connect_timer: float = 0.0

func _ready() -> void:
    DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
    get_window().content_scale_size = Vector2(720, 1290)
    NetworkManager.connected.connect(_on_network_connected)
    NetworkManager.connection_failed.connect(_on_connection_failed)

    # Afficher un message d'erreur si on revient du controller apres une deconnexion
    if NetworkManager.pending_error != "":
        _show_error(NetworkManager.pending_error)
        NetworkManager.pending_error = ""


func _process(delta: float) -> void:
    if not _connecting:
        return

    _connect_timer += delta
    if _connect_timer >= CONNECTION_TIMEOUT:
        # Timeout atteint -> connexion échouée
        _connecting = false
        NetworkManager.disconnect_from_server()
        _show_error("Impossible de trouver le serveur.\nVérifiez l'adresse et réessayez.")


func _on_join_button_pressed() -> void:
    if _connecting:
        return

    # Récupérer l'adresse saisie dans le LineEdit
    var line_edit = find_child("serverAddress", true, false) as LineEdit
    var raw_address = "127.0.0.1"
    if line_edit and line_edit.text.strip_edges() != "":
        raw_address = line_edit.text.strip_edges()

    # Parser le format "host:port" si le port est inclus
    var host = raw_address
    var port = 6967
    if ":" in raw_address:
        var parts = raw_address.rsplit(":", true, 1)
        host = parts[0]
        if parts[1].is_valid_int():
            port = int(parts[1])

    # Résoudre "localhost" en IP
    if host == "localhost":
        host = "127.0.0.1"

    NetworkManager.server_address = host
    NetworkManager.server_port = port

    print("[Menu] Serveur sélectionné: %s:%d" % [NetworkManager.server_address, NetworkManager.server_port])

    # Lancer la connexion et passer en mode "attente"
    _connecting = true
    _connect_timer = 0.0
    _set_ui_connecting(true)
    _hide_error()

    NetworkManager.connect_to_server()


func _on_network_connected(_player_id: int) -> void:
    if not _connecting:
        return
    _connecting = false
    print("[Menu] Connecté au serveur! Passage à la manette...")
    # Déconnecter les signaux pour ne pas les déclencher 2 fois dans controller
    NetworkManager.connected.disconnect(_on_network_connected)
    NetworkManager.connection_failed.disconnect(_on_connection_failed)
    get_tree().change_scene_to_file("res://scenes/controller.tscn")
    DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)


func _on_connection_failed() -> void:
    _connecting = false
    _set_ui_connecting(false)
    _show_error("Impossible de se connecter au serveur.\nVérifiez l'adresse et réessayez.")


func _set_ui_connecting(is_connecting: bool) -> void:
    var join_button = find_child("joinButton", true, false) as Button
    var line_edit = find_child("serverAddress", true, false) as LineEdit
    if join_button:
        join_button.disabled = is_connecting
        join_button.text = "Connexion..." if is_connecting else "Rejoindre"
    if line_edit:
        line_edit.editable = not is_connecting


func _show_error(message: String) -> void:
    _set_ui_connecting(false)
    var error_label = find_child("errorLabel", true, false) as Label
    if error_label:
        error_label.text = message
        error_label.visible = true


func _hide_error() -> void:
    var error_label = find_child("errorLabel", true, false) as Label
    if error_label:
        error_label.visible = false
