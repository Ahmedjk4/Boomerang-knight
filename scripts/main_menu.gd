extends Control

@onready var play_button: Button = $Layout/Buttons/Play
@onready var controls: VBoxContainer = $Controls


func _ready() -> void:
	play_button.grab_focus()
	$Layout/Buttons/Play.pressed.connect(_on_play_pressed)
	$Layout/Buttons/Coop.pressed.connect(_on_coop_pressed)
	$Layout/Buttons/Controls.pressed.connect(_on_controls_pressed)
	$Layout/Buttons/Quit.pressed.connect(_on_quit_pressed)
	$Controls/Back.pressed.connect(_on_controls_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if controls.visible and event.is_action_pressed("ui_cancel"):
		_on_controls_pressed()


func _on_play_pressed() -> void:
	start_game(1)


func _on_coop_pressed() -> void:
	start_game(2)


func start_game(players: int) -> void:
	get_node("/root/GameSession").player_count = players
	for button in $Layout/Buttons.get_children():
		button.disabled = true
	get_tree().change_scene_to_file("res://main.tscn")


func _on_controls_pressed() -> void:
	controls.visible = not controls.visible
	$Layout.visible = not controls.visible
	if controls.visible:
		$Controls/Back.grab_focus()
	else:
		$Layout/Buttons/Controls.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
