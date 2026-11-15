extends Node2D

enum PhaseState { BREAK, SPAWNING, CLEARING, GAME_OVER }
const POWERUP = preload("res://scripts/powerup.gd")

@export var enemy_scene: PackedScene
@export var enemy2_scene: PackedScene
@export var minimum_spawn_distance: float = 160.0
@export var first_phase_enemies: int = 3
@export var extra_enemies_per_phase: int = 2
@export var phase_break_seconds: float = 3.0
@export var spawn_interval: float = 1.2


var spawn_second_enemy := false
var phase := 0
var phase_state := PhaseState.BREAK
var enemies_to_spawn := 0
var living_enemies := 0
var _shutting_down := false
var phase_label: Label
var sword_label: Label
var coop_mode := false
var fallen_players: Array[int] = []
var active_powerup: Node2D

@onready var spawn_location: PathFollow2D = $Path2D/SpawnLocation
@onready var timer: Timer = $Timer


func _ready() -> void:
	_build_hud()
	coop_mode = get_node("/root/GameSession").player_count == 2
	$Player1.configure_controls(1, coop_mode)
	if coop_mode:
		$Player1.position = Vector2(450, 330)
		var second_player = load("res://main_character.tscn").instantiate()
		second_player.name = "Player2"
		second_player.player_id = 2
		second_player.coop_mode = true
		second_player.position = Vector2(700, 330)
		add_child(second_player)
	for player in get_tree().get_nodes_in_group("player"):
		player.died.connect(_on_player_died.bind(player.player_id))
	timer.one_shot = true
	timer.start(phase_break_seconds)


func _exit_tree() -> void:
	_shutting_down = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://main_menu.tscn")
	elif phase_state == PhaseState.GAME_OVER and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	if phase_state == PhaseState.GAME_OVER:
		phase_label.text = "Game over  /  R to retry  /  Esc for menu"
	elif phase_state == PhaseState.BREAK:
		phase_label.text = "Phase %d in %d" % [phase + 1, ceili(timer.time_left)]
	else:
		phase_label.text = "Phase %d   /   %d left" % [phase, living_enemies + enemies_to_spawn]
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		sword_label.text = ""
		return
	if coop_mode:
		var statuses: PackedStringArray = []
		for knight in live_players():
			if not knight.has_sword:
				statuses.append("P%d: retrieve sword" % knight.player_id)
			if knight.explosive_time > 0:
				statuses.append("P%d blast %ds" % [knight.player_id, ceili(knight.explosive_time)])
		for id in fallen_players:
			statuses.append("P%d returns after phase" % id)
		sword_label.text = "    ".join(statuses)
		return
	if player.charging:
		sword_label.text = "Charging"
	elif player.has_sword:
		sword_label.text = ""
	elif is_instance_valid(player.active_sword) and player.active_sword.state == 2:
		sword_label.text = "Retrieve your sword"
	else:
		sword_label.text = "Sword in flight"
	if player.explosive_time > 0:
		var status := "Blast %ds" % ceili(player.explosive_time)
		sword_label.text = status if sword_label.text.is_empty() else sword_label.text + "  /  " + status


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var overlay := Control.new()
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_label = Label.new()
	overlay.add_child(phase_label)
	phase_label.anchor_left = 0.5
	phase_label.anchor_right = 0.5
	phase_label.offset_left = -220
	phase_label.offset_right = 220
	phase_label.offset_top = 22
	phase_label.offset_bottom = 54
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_label.add_theme_font_size_override("font_size", 23)
	phase_label.add_theme_color_override("font_color", Color(0.93, 0.9, 0.78))
	phase_label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	phase_label.add_theme_constant_override("outline_size", 6)
	sword_label = Label.new()
	overlay.add_child(sword_label)
	sword_label.anchor_top = 1.0
	sword_label.anchor_bottom = 1.0
	sword_label.offset_left = 28
	sword_label.offset_right = 300
	sword_label.offset_top = -50
	sword_label.offset_bottom = -26
	sword_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sword_label.add_theme_font_size_override("font_size", 16)
	sword_label.add_theme_color_override("font_color", Color(0.93, 0.9, 0.78))
	sword_label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	sword_label.add_theme_constant_override("outline_size", 5)


func _on_timer_timeout() -> void:
	if phase_state == PhaseState.GAME_OVER:
		return
	if phase_state == PhaseState.BREAK:
		phase += 1
		_spawn_powerup()
		enemies_to_spawn = first_phase_enemies + extra_enemies_per_phase * (phase - 1)
		if coop_mode:
			enemies_to_spawn *= 2
		phase_state = PhaseState.SPAWNING
	if phase_state == PhaseState.SPAWNING:
		if _spawn_enemy():
			enemies_to_spawn -= 1
		if enemies_to_spawn > 0:
			var interval := maxf(0.35, spawn_interval - (phase - 1) * 0.08)
			timer.start(interval * 0.75 if coop_mode else interval)
		else:
			phase_state = PhaseState.CLEARING
			_check_phase_clear()


func _check_phase_clear() -> void:
	if phase_state == PhaseState.CLEARING and living_enemies == 0:
		phase_state = PhaseState.BREAK
		if coop_mode and not fallen_players.is_empty():
			_revive_players()
		timer.start(phase_break_seconds)


func _on_enemy_removed() -> void:
	if _shutting_down or not is_inside_tree():
		return
	living_enemies = maxi(0, living_enemies - 1)
	_check_phase_clear()


func _on_game_over() -> void:
	phase_state = PhaseState.GAME_OVER
	timer.stop()


func live_players() -> Array[Node]:
	var players: Array[Node] = []
	for player in get_tree().get_nodes_in_group("player"):
		if player.health > 0 and not player.is_queued_for_deletion():
			players.append(player)
	return players


func _on_player_died(id: int) -> void:
	if coop_mode and not fallen_players.has(id):
		fallen_players.append(id)
	if live_players().is_empty():
		_on_game_over()


func _revive_players() -> void:
	# Let queued player nodes leave before reusing their names.
	await get_tree().process_frame
	if not is_inside_tree() or phase_state == PhaseState.GAME_OVER or live_players().is_empty():
		return
	for id in fallen_players:
		var player = load("res://main_character.tscn").instantiate()
		player.name = "Player%d" % id
		player.player_id = id
		player.coop_mode = true
		var partner: Vector2 = live_players()[0].position
		var offset := Vector2(-110, 0) if id == 1 else Vector2(110, 0)
		player.position = (partner + offset).clamp(Vector2(100, 100), Vector2(1050, 550))
		add_child(player)
		player.died.connect(_on_player_died.bind(id))
	fallen_players.clear()


func _spawn_powerup() -> void:
	if is_instance_valid(active_powerup):
		active_powerup.queue_free()
	var point := Vector2(575, 400)
	for attempt in range(16):
		point = Vector2(randf_range(240, 900), randf_range(180, 480))
		var near_player := false
		for player in live_players():
			if player.global_position.distance_to(to_global(point)) < 100:
				near_player = true
				break
		if not near_player:
			break
	active_powerup = POWERUP.new()
	active_powerup.position = point
	add_child(active_powerup)


func _spawn_enemy() -> bool:
	var players := live_players()
	if players.is_empty():
		return false

	var scene := enemy2_scene if spawn_second_enemy else enemy_scene
	if scene == null:
		scene = enemy_scene if spawn_second_enemy else enemy2_scene
	if scene == null:
		return false

	for attempt in range(16):
		spawn_location.progress_ratio = randf()
		var near_player := false
		for player in players:
			if spawn_location.global_position.distance_to(player.global_position) < minimum_spawn_distance:
				near_player = true
				break
		if near_player:
			continue
		var enemy := scene.instantiate() as Node2D
		if coop_mode:
			enemy.speed_multiplier = 1.15
		# _ready needs the spawn position, so set it before add_child.
		enemy.position = to_local(spawn_location.global_position)
		enemy.tree_exited.connect(_on_enemy_removed)
		living_enemies += 1
		add_child(enemy)
		spawn_second_enemy = not spawn_second_enemy
		return true
	return false
