extends Control


func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _process(_delta: float) -> void:
	pass


func _on_join_button_pressed() -> void:
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

	get_tree().change_scene_to_file("res://scenes/controller.tscn")
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
