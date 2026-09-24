extends Node3D

@onready var menu: Control = $HUD/Menu
@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/CameraRig/Camera3D

var mobile_controls: Control
var mobile_buttons: Dictionary = {}

func _ready() -> void:
    camera.current = true
    camera.look_at(Vector3(0.0, 2.2, -8.0), Vector3.UP)
    $HUD/Menu/Panel/Start.pressed.connect(_start_game)
    _build_mobile_controls()

func _build_mobile_controls() -> void:
    mobile_controls = Control.new()
    mobile_controls.name = "MobileControls"
    mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $HUD.add_child(mobile_controls)

    var labels := {"forward": "▲", "back": "▼", "left": "◀", "right": "▶"}
    var positions := {
        "forward": Vector2(92, 610),
        "back": Vector2(92, 680),
        "left": Vector2(22, 680),
        "right": Vector2(162, 680)
    }

    for action in labels:
        var button := Button.new()
        button.name = action.capitalize()
        button.text = labels[action]
        button.position = positions[action]
        button.size = Vector2(64, 58)
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_filter = Control.MOUSE_FILTER_PASS
        button.add_theme_font_size_override("font_size", 26)
        button.modulate = Color(1, 1, 1, 0.86)
        mobile_controls.add_child(button)
        mobile_buttons[action] = button
        button.button_down.connect(func(): player.set_mobile_direction(action, true))
        button.button_up.connect(func(): player.set_mobile_direction(action, false))

    mobile_controls.visible = false

func _start_game() -> void:
    menu.visible = false
    mobile_controls.visible = true
    player.set_physics_process(true)
    camera.current = true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        menu.visible = true
        mobile_controls.visible = false
        player.clear_mobile_input()
        player.set_physics_process(false)
