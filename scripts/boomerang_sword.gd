extends Node2D

enum FlightState { OUTBOUND, RETURNING, GROUNDED }

const PICKUP_RADIUS := 54.0
const HIT_RADIUS := 20.0
const SWORD_TEXTURE = preload("res://art/sword.svg")
const HIT_EFFECT = preload("res://scripts/hit_effect.gd")
const EXPLOSION_RADIUS := 96.0

var state := FlightState.OUTBOUND
var wielder: CharacterBody2D
var launch_position := Vector2.ZERO
var direction := Vector2.DOWN
var power := 0.0
var speed := 360.0
var max_distance := 140.0
var distance_flown := 0.0
var damage := 60
var spin := 0.0
var hit_enemies: Array[int] = []


func launch(player: CharacterBody2D, aim: Vector2, charge: float) -> void:
	wielder = player
	launch_position = player.global_position
	global_position = launch_position
	direction = aim.normalized() if not aim.is_zero_approx() else Vector2.DOWN
	power = clampf(charge, 0.0, 1.0)
	speed = lerpf(360.0, 720.0, power)
	max_distance = lerpf(140.0, 420.0, power)

	damage = roundi(lerpf(60.0, 90.0, power))
	add_to_group("swords")
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	if state == FlightState.GROUNDED:
		try_pickup(global_position, global_position)
		queue_redraw()
		return

	spin += delta * 22.0
	var remaining := max_distance - distance_flown
	if state == FlightState.RETURNING:
		remaining = global_position.distance_to(launch_position)
		direction = global_position.direction_to(launch_position)
	var motion := direction * minf(speed * delta, remaining)
	var next_position := global_position + motion
	# Turn back at walls so the pickup stays inside the arena.
	var wall_query := PhysicsRayQueryParameters2D.create(global_position, next_position, 1)
	var wall := get_world_2d().direct_space_state.intersect_ray(wall_query)
	if not wall.is_empty():
		next_position = wall.position - direction * 4.0
	if state == FlightState.RETURNING and try_pickup(global_position, next_position):
		return
	_hit_along_path(global_position, next_position)
	distance_flown += global_position.distance_to(next_position)
	global_position = next_position
	if not wall.is_empty() or motion.length() >= remaining - 0.01:
		if state == FlightState.OUTBOUND:
			state = FlightState.RETURNING
			hit_enemies.clear()
		else:
			land()
			try_pickup(global_position, global_position)
	queue_redraw()


func try_pickup(start: Vector2, finish: Vector2) -> bool:
	if state == FlightState.OUTBOUND or not is_instance_valid(wielder) or wielder.health <= 0:
		return false
	# Check the full step so a fast return cannot pass through the player.
	var closest := Geometry2D.get_closest_point_to_segment(wielder.global_position, start, finish)
	if closest.distance_to(wielder.global_position) > PICKUP_RADIUS:
		return false
	if not wielder.recover_sword(self):
		return false
	global_position = closest
	queue_free()
	return true


func _hit_along_path(start: Vector2, finish: Vector2) -> void:
	# Sweep the whole step to avoid missing enemies at full speed.
	var shape := CapsuleShape2D.new()
	shape.radius = HIT_RADIUS
	shape.height = start.distance_to(finish) + HIT_RADIUS * 2.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D((finish - start).angle() - PI / 2.0, (start + finish) / 2.0)
	query.collision_mask = 8
	query.collide_with_bodies = false
	query.collide_with_areas = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var enemy = hit.collider.get_parent()
		var id: int = enemy.get_instance_id()
		if enemy.has_method("take_damage") and not hit_enemies.has(id):
			hit_enemies.append(id)
			enemy.take_damage(damage)
			if is_explosive():
				explode_at(enemy.global_position)


func is_explosive() -> bool:
	return is_instance_valid(wielder) and wielder.explosive_time > 0.0


func explode_at(point: Vector2) -> void:
	var effect = HIT_EFFECT.new()
	effect.explosion = true
	effect.radius = EXPLOSION_RADIUS
	get_parent().add_child(effect)
	effect.global_position = point
	var shape := CircleShape2D.new()
	shape.radius = EXPLOSION_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, point)
	query.collision_mask = 8
	query.collide_with_bodies = false
	query.collide_with_areas = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var enemy = hit.collider.get_parent()
		var id: int = enemy.get_instance_id()
		if enemy.has_method("take_damage") and enemy.health > 0 and not hit_enemies.has(id):
			hit_enemies.append(id)
			enemy.take_damage(damage)


func land() -> void:
	state = FlightState.GROUNDED
	spin = -PI / 4.0
	queue_redraw()


func _draw() -> void:
	if state == FlightState.GROUNDED:
		draw_rect(Rect2(-15, 9, 30, 5), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, spin)
	var tint := Color(1, 0.65, 0.35) if is_explosive() else Color.WHITE
	draw_texture_rect(SWORD_TEXTURE, Rect2(-12, -24, 24, 48), false, tint)
