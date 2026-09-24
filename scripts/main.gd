extends Node3D

@onready var menu: Control = $HUD/Menu
@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/CameraRig/Camera3D

func _ready() -> void:
    camera.current = true
    camera.look_at(Vector3(0.0, 2.2, -8.0), Vector3.UP)
    $HUD/Menu/Panel/Start.pressed.connect(_start_game)

func _start_game() -> void:
    menu.visible = false
    player.set_physics_process(true)
    camera.current = true
    camera.look_at(Vector3(0.0, 2.2, -8.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        menu.visible = true
        player.set_physics_process(false)
