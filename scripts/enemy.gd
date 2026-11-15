extends CharacterBody2D

const SPEED := 100.0
const DAMAGE := 20
const HIT_EFFECT = preload("res://scripts/hit_effect.gd")

@export var max_health := 60
@export var speed_multiplier := 1.0
var health: int
var damage_cooldown := 0.0
var player: CharacterBody2D
var hit_flash := 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	player = get_tree().get_first_node_in_group("player")


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	var effect = HIT_EFFECT.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	hit_flash = 0.08
	health = maxi(0, health - amount)
	if health == 0:
		queue_free()


func _process(delta: float) -> void:
	hit_flash = maxf(0.0, hit_flash - delta)
	anim.modulate = Color(2.5, 2.5, 2.5) if hit_flash > 0 else Color.WHITE


func _physics_process(delta: float) -> void:
	damage_cooldown = maxf(0.0, damage_cooldown - delta)
	player = nearest_player()
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		anim.stop()
		return

	var direction := global_position.direction_to(player.global_position)
	velocity = direction * SPEED * speed_multiplier
	if not is_zero_approx(direction.x):
		anim.flip_h = direction.x < 0
	anim.play("default")
	move_and_slide()
	for area in $Hitbox.get_overlapping_areas():
		_on_hitbox_area_entered(area)


func nearest_player() -> CharacterBody2D:
	var nearest: CharacterBody2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate.health <= 0 or candidate.is_queued_for_deletion():
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


func _on_hitbox_area_entered(area: Area2D) -> void:
	var body := area.get_parent()
	if body.is_in_group("player") and damage_cooldown <= 0.0 and health > 0:
		body.take_damage(DAMAGE)
		damage_cooldown = 0.8
