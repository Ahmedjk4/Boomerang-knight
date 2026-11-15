extends Node2D

const DURATION := 15.0
const PICKUP_DISTANCE := 44.0

var collected := false
var age := 0.0


func _ready() -> void:
	add_to_group("powerups")
	z_index = 4


func _physics_process(delta: float) -> void:
	if collected:
		return
	age += delta
	for player in get_tree().get_nodes_in_group("player"):
		if player.health <= 0 or player.is_queued_for_deletion():
			continue
		if global_position.distance_to(player.global_position) <= PICKUP_DISTANCE:
			player.activate_explosive(DURATION)
			collected = true
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var bob := roundf(sin(age * 3.0) * 2.0)
	draw_rect(Rect2(-13, 14, 26, 4), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, bob))
	draw_rect(Rect2(-10, -8, 20, 20), Color(0.15, 0.12, 0.14))
	draw_rect(Rect2(-7, -11, 14, 26), Color(0.15, 0.12, 0.14))
	draw_rect(Rect2(-6, -6, 12, 14), Color(0.55, 0.25, 0.12))
	draw_rect(Rect2(-2, -15, 5, 6), Color(0.65, 0.58, 0.4))
	draw_rect(Rect2(2, -18, 4, 4), Color(1, 0.7, 0.25))
	draw_string(ThemeDB.fallback_font, Vector2(-17, 32), "Blast", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.8, 0.45))
