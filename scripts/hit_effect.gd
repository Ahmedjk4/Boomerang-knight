extends Node2D

var explosion := false
var age := 0.0
var duration := 0.18
var radius := 96.0


func _ready() -> void:
	add_to_group("hit_effects")
	z_index = 8
	if explosion:
		duration = 0.4


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var progress := age / duration
	var count := 12 if explosion else 6
	var distance := lerpf(8.0, radius if explosion else 28.0, progress)
	var size := 8.0 if explosion else 3.0
	for i in range(count):
		var angle := TAU * i / count + 0.3
		var point := (Vector2.from_angle(angle) * distance).snapped(Vector2(2, 2))
		var color := Color(1.0, 0.65, 0.2, 1.0 - progress)
		if i % 2 == 0:
			color = Color(1.0, 0.92, 0.68, 1.0 - progress)
		draw_rect(Rect2(point - Vector2.ONE * size / 2, Vector2.ONE * size), color)
	if explosion and progress < 0.4:
		draw_rect(Rect2(-12, -12, 24, 24), Color(1.0, 0.8, 0.4, 1.0 - progress))
