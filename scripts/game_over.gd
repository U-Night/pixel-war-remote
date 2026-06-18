extends Control

## GameOver — Écran de fin (élimination ou victoire)

# ──── Configuration ────
var is_victory: bool = false

# ──── Animation ────
var _time: float = 0.0
var _particles: Array = []
const PARTICLE_COUNT: int = 40

# ──── Références UI ────
var _title_label: Label
var _subtitle_label: Label
var _back_button: Button
var _bg_rect: ColorRect
var _emoji_container: Control

func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	get_window().content_scale_size = Vector2(1280, 720)

	# Déterminer le type depuis le NetworkManager
	is_victory = (NetworkManager.game_over_type == "victory")

	# Récupérer les références
	_title_label = $VBoxContainer/Title
	_subtitle_label = $VBoxContainer/Subtitle
	_back_button = $VBoxContainer/BackButton
	_bg_rect = $Background
	_emoji_container = $EmojiParticles

	# Configurer le visuel selon le contexte
	_setup_visuals()

	# Générer les particules
	_generate_particles()

	# Animation d'entrée du titre
	_title_label.modulate.a = 0.0
	_subtitle_label.modulate.a = 0.0
	_back_button.modulate.a = 0.0

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_title_label, "modulate:a", 1.0, 0.6)
	tween.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.3, 0.3))
	tween.parallel().tween_property(_subtitle_label, "modulate:a", 1.0, 0.8)
	tween.tween_property(_back_button, "modulate:a", 1.0, 0.5)


func _setup_visuals() -> void:
	if is_victory:
		# ── Victoire : fond doré / chaud ──
		_bg_rect.color = Color(0.12, 0.10, 0.02, 1.0)
		_title_label.text = "VICTOIRE !"
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_subtitle_label.text = "Votre équipe a gagné !"
		_subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.6))
		_back_button.add_theme_color_override("font_color", Color(0.1, 0.08, 0.0))
	else:
		# ── Élimination : fond rouge sombre ──
		_bg_rect.color = Color(0.15, 0.02, 0.02, 1.0)
		_title_label.text = "ÉLIMINÉ"
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
		_subtitle_label.text = "Votre équipe a été éliminée..."
		_subtitle_label.add_theme_color_override("font_color", Color(0.85, 0.5, 0.5))
		_back_button.add_theme_color_override("font_color", Color(0.1, 0.0, 0.0))


func _generate_particles() -> void:
	_particles.clear()
	for i in PARTICLE_COUNT:
		var p = {
			"x": randf() * 1280.0,
			"y": randf() * 720.0,
			"vx": randf_range(-30.0, 30.0),
			"vy": randf_range(-60.0, -15.0) if is_victory else randf_range(10.0, 40.0),
			"size": randf_range(4.0, 14.0),
			"alpha": randf_range(0.3, 0.9),
			"phase": randf() * TAU,
			"emoji_idx": randi() % 5
		}
		_particles.append(p)


func _process(delta: float) -> void:
	_time += delta

	# Animer les particules
	for p in _particles:
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["x"] += sin(_time * 2.0 + p["phase"]) * 20.0 * delta

		# Wrap autour de l'écran
		if p["y"] < -20.0:
			p["y"] = 740.0
		elif p["y"] > 740.0:
			p["y"] = -20.0
		if p["x"] < -20.0:
			p["x"] = 1300.0
		elif p["x"] > 1300.0:
			p["x"] = -20.0

	# Animation pulsation du titre
	if _title_label:
		var pulse = 1.0 + sin(_time * 3.0) * 0.04
		_title_label.scale = Vector2(pulse, pulse)

	# Redessiner les particules
	_emoji_container.queue_redraw()


# ──── Dessin des particules ────

func _draw_particles() -> void:
	var victory_colors = [
		Color(1.0, 0.85, 0.1), # Or
		Color(1.0, 0.6, 0.0), # Orange doré
		Color(1.0, 0.95, 0.5), # Jaune clair
		Color(0.9, 0.75, 0.2), # Or foncé
		Color(1.0, 1.0, 0.8), # Blanc chaud
	]
	var eliminated_colors = [
		Color(1.0, 0.2, 0.15), # Rouge vif
		Color(0.8, 0.1, 0.05), # Rouge foncé
		Color(1.0, 0.4, 0.3), # Rouge clair
		Color(0.5, 0.05, 0.0), # Bordeaux
		Color(0.3, 0.02, 0.0), # Très sombre
	]

	var colors = victory_colors if is_victory else eliminated_colors

	for p in _particles:
		var col = colors[p["emoji_idx"]]
		col.a = p["alpha"] * (0.6 + 0.4 * sin(_time * 2.5 + p["phase"]))
		var s = p["size"]
		# Dessiner un losange / diamant pour la victoire, des croix pour l'élimination
		if is_victory:
			# Étoile simplifiée (losange)
			var center = Vector2(p["x"], p["y"])
			var points = PackedVector2Array([
				center + Vector2(0, -s),
				center + Vector2(s * 0.6, 0),
				center + Vector2(0, s),
				center + Vector2(-s * 0.6, 0),
			])
			_emoji_container.draw_colored_polygon(points, col)
		else:
			# Croix / X
			var cx = p["x"]
			var cy = p["y"]
			var hs = s * 0.3
			_emoji_container.draw_rect(Rect2(cx - s, cy - hs, s * 2, hs * 2), col)
			_emoji_container.draw_rect(Rect2(cx - hs, cy - s, hs * 2, s * 2), col)


# ──── Bouton retour ────

func _on_back_button_pressed() -> void:
	# Fermer proprement la connexion
	NetworkManager.disconnect_from_server()
	NetworkManager.game_over_type = ""
	# Retour au menu
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
