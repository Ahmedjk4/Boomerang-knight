extends CharacterBody2D

signal died

const SWORD_SCRIPT = preload("res://scripts/boomerang_sword.gd")
const KNIGHT_SHADER = preload("res://shaders/knight.gdshader")
const SPEED := 200.0
const CHARGE_SECONDS := 1.2
const MAX_STAMINA := 100.0
const RUSH_COST := 35.0
const RUSH_SPEED := 650.0
const RUSH_DURATION := 0.18
const STAMINA_REGEN := 24.0
const REGEN_DELAY := 0.8
const MAX_HEALTH := 100.0
const HEALTH_REGEN := 4.0
const HEALTH_REGEN_DELAY := 4.0

@export var player_id := 1
@export var coop_mode := false

var health := MAX_HEALTH
var health_regen_delay := 0.0
var throw_action: StringName = &"throw_sword"
var rush_action: StringName = &"rush"
var last_direction := "down"
var aim_direction := Vector2.DOWN
var mouse_viewport_position := Vector2.ZERO
var has_sword := true
var charging := false
var charge_time := 0.0
var active_sword: Node2D
var stamina := MAX_STAMINA
var rush_time := 0.0
var rush_direction := Vector2.ZERO
var regen_delay := 0.0
var explosive_time := 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var stamina_bar: ProgressBar = $StaminaBar


func _ready() -> void:
	add_to_group("player")
	configure_controls(player_id, coop_mode)
	var material := ShaderMaterial.new()
	material.shader = KNIGHT_SHADER
	anim.material = material
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim.frame_changed.connect(_sync_sword_sprite)
	mouse_viewport_position = get_viewport().get_mouse_position()
	health_bar.max_value = MAX_HEALTH
	health_bar.value = health
	stamina_bar.max_value = MAX_STAMINA
	stamina_bar.value = stamina


func _input(event: InputEvent) -> void:
	if player_id == 1 and event is InputEventMouseMotion:
		mouse_viewport_position = event.position
		_update_aim()
		queue_redraw()


func configure_controls(id: int, coop: bool) -> void:
	player_id = id
	coop_mode = coop
	throw_action = &"p2_throw" if id == 2 else &"throw_sword"
	rush_action = &"p2_rush" if id == 2 else &"rush"
	if coop and not has_node("PlayerNumber"):
		var number := Label.new()
		number.name = "PlayerNumber"
		number.text = "P%d" % id
		number.position = Vector2(-10, -104)
		number.add_theme_font_size_override("font_size", 14)
		number.add_theme_color_override("font_color", Color(0.7, 0.85, 1) if id == 1 else Color(1, 0.77, 0.5))
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_constant_override("outline_size", 4)
		add_child(number)


func get_movement() -> Vector2:
	if not coop_mode:
		return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var prefix := "p1_" if player_id == 1 else "p2_"
	return Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")


func regenerate_health(delta: float) -> void:
	if health <= 0.0:
		return
	var healing_time := maxf(0.0, delta - health_regen_delay)
	health_regen_delay = maxf(0.0, health_regen_delay - delta)
	health = minf(MAX_HEALTH, health + HEALTH_REGEN * healing_time)
	health_bar.value = health


func activate_explosive(duration: float = 15.0) -> void:
	if health > 0:
		explosive_time = duration


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(rush_action):
		start_rush()
	elif event.is_action_pressed(throw_action):
		start_charge()
	elif event.is_action_released(throw_action):
		release_throw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		charging = false
		charge_time = 0.0


func start_rush() -> bool:
	if health <= 0 or rush_time > 0.0 or stamina < RUSH_COST:
		return false
	var movement := get_movement()
	_update_aim()
	rush_direction = movement.normalized() if not movement.is_zero_approx() else aim_direction
	rush_time = RUSH_DURATION
	stamina -= RUSH_COST
	regen_delay = REGEN_DELAY
	stamina_bar.value = stamina
	return true


func start_charge() -> void:
	if has_sword and health > 0 and not charging:
		charging = true
		charge_time = 0.0


func release_throw() -> void:
	if not charging or not has_sword or health <= 0:
		return
	_update_aim()
	charging = false
	var sword := Node2D.new()
	sword.set_script(SWORD_SCRIPT)
	get_parent().add_child(sword)
	active_sword = sword
	has_sword = false
	_sync_sword_sprite()
	sword.launch(self, aim_direction, get_charge_ratio())
	charge_time = 0.0
	queue_redraw()


func get_charge_ratio() -> float:
	return clampf(charge_time / CHARGE_SECONDS, 0.0, 1.0)


func recover_sword(sword: Node2D) -> bool:
	if health <= 0 or has_sword or sword != active_sword:
		return false
	has_sword = true
	_sync_sword_sprite()
	active_sword = null
	queue_redraw()
	return true


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxf(0.0, health - amount)
	health_regen_delay = HEALTH_REGEN_DELAY
	health_bar.value = health
	if health <= 0:
		charging = false
		if is_instance_valid(active_sword):
			active_sword.queue_free()
		died.emit()
		queue_free()


func _physics_process(delta: float) -> void:
	var input_vector := get_movement()
	explosive_time = maxf(0.0, explosive_time - delta)
	regenerate_health(delta)
	if charging:
		charge_time = minf(charge_time + delta, CHARGE_SECONDS)
	regen_delay = maxf(0.0, regen_delay - delta)
	var rushing := rush_time > 0.0
	if rushing:
		rush_time = maxf(0.0, rush_time - delta)
		velocity = rush_direction * RUSH_SPEED
	else:
		velocity = input_vector * SPEED
		if regen_delay <= 0.0:
			stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
	stamina_bar.value = stamina
	move_and_slide()
	_update_aim()

	update_animation(rush_direction if rushing else input_vector)
	anim.speed_scale = 1.8 if rushing else 1.0
	queue_redraw()


func _sync_sword_sprite() -> void:
	anim.material.set_shader_parameter("unarmed", not has_sword)
	anim.material.set_shader_parameter("walk_frame", anim.frame)


func _update_aim() -> void:
	if player_id == 2:
		var input := get_movement()
		if not input.is_zero_approx():
			aim_direction = input.normalized()
		return
	var mouse_world := get_viewport().get_canvas_transform().affine_inverse() * mouse_viewport_position
	var offset := mouse_world - global_position
	if not offset.is_zero_approx():
		aim_direction = offset.normalized()


func _draw() -> void:
	if charging:
		var power := get_charge_ratio()
		var tip := aim_direction * (65.0 + power * 50.0)
		draw_line(aim_direction * 45.0, tip, Color(1, 0.8, 0.2), 4.0)
		draw_line(tip, tip - aim_direction.rotated(0.6) * 15, Color(1, 0.8, 0.2), 4.0)
		draw_line(tip, tip - aim_direction.rotated(-0.6) * 15, Color(1, 0.8, 0.2), 4.0)
		draw_rect(Rect2(-35, -82, 70, 7), Color(0.1, 0.1, 0.15, 0.9))
		draw_rect(Rect2(-35, -82, 70 * power, 7), Color(1, 0.8, 0.2))
	elif has_sword:
		var marker := aim_direction * 64.0
		draw_circle(marker, 3.0, Color(1.0, 0.85, 0.45, 0.8))


func update_animation(direction: Vector2) -> void:
	if direction.is_zero_approx():
		anim.play("idle_" + last_direction)
		anim.stop()
		return

	if abs(direction.x) > abs(direction.y):
		last_direction = "side"
		anim.flip_h = direction.x < 0
	elif direction.y < 0:
		last_direction = "up"
	else:
		last_direction = "down"

	anim.play("walk_" + last_direction)
