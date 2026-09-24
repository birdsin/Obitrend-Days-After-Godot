extends Node3D

@onready var menu: Control = $HUD/Menu
@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/CameraRig/Camera3D
@onready var camera_rig: Node3D = $Player/CameraRig

var mobile_controls: Control
var mobile_buttons: Dictionary = {}
var camera_touch_id := -1
var camera_pitch := -0.18
var camera_yaw := 0.0
var camera_sensitivity := 0.008

func _ready() -> void:
    camera.current = true
    camera_rig.rotation.x = camera_pitch
    camera_rig.rotation.y = camera_yaw
    $HUD/Menu/Panel/Start.pressed.connect(_start_game)
    _build_city_collisions()
    _build_mobile_controls()

func _build_city_collisions() -> void:
    var buildings := [
        [$City/BuildingLeft, Vector3(9, 14, 9)],
        [$City/BuildingCenter, Vector3(8, 20, 8)],
        [$City/BuildingRight, Vector3(9, 14, 9)],
        [$City/TowerFar, Vector3(12, 28, 10)]
    ]
    for item in buildings:
        var mesh_node: MeshInstance3D = item[0]
        var size: Vector3 = item[1]
        _add_box_collider(mesh_node.global_position, size, "BuildingCollision")

func _add_box_collider(pos: Vector3, size: Vector3, collider_name: String) -> void:
    var body := StaticBody3D.new()
    body.name = collider_name
    body.position = pos
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    $City.add_child(body)

func _build_mobile_controls() -> void:
    mobile_controls = Control.new()
    mobile_controls.name = "MobileControls"
    mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $HUD.add_child(mobile_controls)

    var labels := {"forward": "▲", "back": "▼", "left": "◀", "right": "▶", "sprint": "RUN"}
    for action in labels:
        var button := Button.new()
        button.name = action.capitalize()
        button.text = labels[action]
        button.size = Vector2(64, 58) if action != "sprint" else Vector2(82, 58)
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_filter = Control.MOUSE_FILTER_PASS
        button.add_theme_font_size_override("font_size", 26 if action != "sprint" else 18)
        button.modulate = Color(1, 1, 1, 0.86)
        mobile_controls.add_child(button)
        mobile_buttons[action] = button
        button.button_down.connect(func(): player.set_mobile_direction(action, true))
        button.button_up.connect(func(): player.set_mobile_direction(action, false))

    _layout_mobile_controls()
    get_viewport().size_changed.connect(_layout_mobile_controls)
    mobile_controls.visible = false

func _layout_mobile_controls() -> void:
    if mobile_buttons.is_empty():
        return

    var size := get_viewport().get_visible_rect().size
    var margin := 24.0
    var button_size := Vector2(64, 58)
    var gap := 6.0
    var bottom := size.y - margin - button_size.y

    mobile_buttons["back"].position = Vector2(margin + button_size.x + gap, bottom)
    mobile_buttons["left"].position = Vector2(margin, bottom)
    mobile_buttons["right"].position = Vector2(margin + (button_size.x + gap) * 2.0, bottom)
    mobile_buttons["forward"].position = Vector2(margin + button_size.x + gap, bottom - button_size.y - gap)
    mobile_buttons["sprint"].position = Vector2(size.x - margin - 82.0, bottom)

func _start_game() -> void:
    menu.visible = false
    mobile_controls.visible = true
    player.clear_mobile_input()
    player.set_physics_process(true)
    camera.current = true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _stop_game()
        return

    if not menu.visible and event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x > get_viewport().get_visible_rect().size.x * 0.38:
                camera_touch_id = event.index
        elif event.index == camera_touch_id:
            camera_touch_id = -1
        return

    if not menu.visible and event is InputEventScreenDrag:
        if event.index == camera_touch_id:
            _rotate_camera(event.relative)

func _rotate_camera(relative: Vector2) -> void:
    camera_yaw -= relative.x * camera_sensitivity
    camera_pitch = clamp(camera_pitch - relative.y * camera_sensitivity, -0.70, 0.25)
    camera_rig.rotation.x = camera_pitch
    camera_rig.rotation.y = camera_yaw

func _stop_game() -> void:
    menu.visible = true
    mobile_controls.visible = false
    player.clear_mobile_input()
    player.set_physics_process(false)
    camera_touch_id = -1
