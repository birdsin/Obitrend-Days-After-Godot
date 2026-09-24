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
var interact_label: Label
var objective_label: Label
var inventory_label: Label
var interaction_target: String = ""
var inside_building := false
var exterior_player_position := Vector3.ZERO
var exterior_camera_yaw := 0.0
var exterior_camera_pitch := -0.18
var interior_root: Node3D
var transition_label: Label
var search_completed := false
var supplies_count := 0

func _ready() -> void:
    camera.current = true
    camera_rig.rotation.x = camera_pitch
    camera_rig.rotation.y = camera_yaw
    $HUD/Menu/Panel/Start.pressed.connect(_start_game)
    _build_city_collisions()
    _build_mobile_controls()
    _build_interaction_hud()
    _build_survival_hud()

func _build_city_collisions() -> void:
    var buildings := [
        [$City/BuildingLeft, Vector3(9, 14, 9)],
        [$City/BuildingCenter, Vector3(8, 20, 8)],
        [$City/BuildingRight, Vector3(9, 14, 9)],
        [$City/TowerFar, Vector3(12, 28, 10)]
    ]
    for item in buildings:
        _add_box_collider(item[0].global_position, item[1], "BuildingCollision")

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

func _build_interaction_hud() -> void:
    interact_label = Label.new()
    interact_label.name = "InteractionHint"
    interact_label.position = Vector2(0, 0)
    interact_label.size = Vector2(1280, 70)
    interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    interact_label.add_theme_font_size_override("font_size", 20)
    interact_label.modulate = Color(0.9, 0.75, 0.36, 1)
    interact_label.visible = false
    $HUD.add_child(interact_label)

    var button := Button.new()
    button.name = "Interact"
    button.text = "INTERACT"
    button.size = Vector2(120, 58)
    button.focus_mode = Control.FOCUS_NONE
    button.position = Vector2(0, 0)
    button.pressed.connect(_interact)
    $HUD.add_child(button)
    mobile_buttons["interact"] = button
    button.visible = false

    transition_label = Label.new()
    transition_label.name = "TransitionMessage"
    transition_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    transition_label.add_theme_font_size_override("font_size", 28)
    transition_label.modulate = Color(0.95, 0.8, 0.45, 1)
    transition_label.visible = false
    transition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $HUD.add_child(transition_label)

func _build_survival_hud() -> void:
    objective_label = Label.new()
    objective_label.name = "Objective"
    objective_label.position = Vector2(24, 24)
    objective_label.size = Vector2(520, 42)
    objective_label.add_theme_font_size_override("font_size", 18)
    objective_label.modulate = Color(0.92, 0.92, 0.92, 1)
    objective_label.text = "OBJECTIVE  •  Find supplies"
    objective_label.visible = false
    $HUD.add_child(objective_label)

    inventory_label = Label.new()
    inventory_label.name = "Inventory"
    inventory_label.position = Vector2(24, 66)
    inventory_label.size = Vector2(360, 42)
    inventory_label.add_theme_font_size_override("font_size", 17)
    inventory_label.modulate = Color(0.9, 0.75, 0.36, 1)
    inventory_label.text = "SUPPLIES  0 / 1"
    inventory_label.visible = false
    $HUD.add_child(inventory_label)

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
    if mobile_buttons.has("interact"):
        mobile_buttons["interact"].position = Vector2(size.x - margin - 120.0, bottom - 72.0)

func _start_game() -> void:
    menu.visible = false
    mobile_controls.visible = true
    objective_label.visible = true
    inventory_label.visible = true
    player.clear_mobile_input()
    player.set_physics_process(true)
    camera.current = true
    transition_label.visible = false
    _update_survival_hud()

func _update_survival_hud() -> void:
    inventory_label.text = "SUPPLIES  %d / 1" % supplies_count
    if supplies_count >= 1:
        objective_label.text = "OBJECTIVE  •  Supplies secured"
    else:
        objective_label.text = "OBJECTIVE  •  Find supplies"

func _process(_delta: float) -> void:
    if menu.visible:
        return
    if inside_building:
        _update_interior_interaction()
    else:
        _update_interaction_target()

func _update_interaction_target() -> void:
    var from := camera.global_position
    var to := from + -camera.global_transform.basis.z * 5.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [player.get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)

    interaction_target = ""
    mobile_buttons["interact"].visible = false
    interact_label.visible = false

    if hit.is_empty():
        return

    var collider = hit.get("collider")
    if collider is StaticBody3D and collider.name == "BuildingCollision":
        interaction_target = "BUILDING"
        interact_label.text = "Building entrance • Tap INTERACT"
        interact_label.visible = true
        mobile_buttons["interact"].visible = true

func _update_interior_interaction() -> void:
    var from := camera.global_position
    var to := from + -camera.global_transform.basis.z * 4.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [player.get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)

    interaction_target = ""
    mobile_buttons["interact"].visible = false
    interact_label.visible = false

    if not hit.is_empty():
        var collider = hit.get("collider")
        if collider is StaticBody3D and collider.name == "SearchObject" and supplies_count < 1:
            interaction_target = "SEARCH"
            interact_label.text = "Search desk • Tap INTERACT"
            interact_label.visible = true
            mobile_buttons["interact"].visible = true
            return

    if player.global_position.z > 6.5:
        interaction_target = "EXIT"
        interact_label.text = "Exit building • Tap INTERACT"
        interact_label.visible = true
        mobile_buttons["interact"].visible = true

func _interact() -> void:
    if interaction_target == "BUILDING" and not inside_building:
        _enter_building()
    elif interaction_target == "EXIT" and inside_building:
        _exit_building()
    elif interaction_target == "SEARCH" and inside_building:
        _search_desk()

func _search_desk() -> void:
    if supplies_count >= 1:
        return
    supplies_count = 1
    search_completed = true
    interaction_target = ""
    mobile_buttons["interact"].visible = false
    _update_survival_hud()
    interact_label.text = "Supplies secured • PHASE 1"
    interact_label.visible = true
    transition_label.text = "SUPPLIES FOUND"
    transition_label.visible = true
    var search_mesh := interior_root.get_node_or_null("SearchMesh")
    if is_instance_valid(search_mesh):
        search_mesh.visible = false
    var search_body := interior_root.get_node_or_null("SearchObject")
    if is_instance_valid(search_body):
        search_body.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
        var collision := search_body.get_node_or_null("CollisionShape3D")
        if is_instance_valid(collision):
            collision.set_deferred("disabled", true)
    await get_tree().create_timer(1.2).timeout
    transition_label.visible = false

func _enter_building() -> void:
    exterior_player_position = player.global_position
    exterior_camera_yaw = camera_yaw
    exterior_camera_pitch = camera_pitch
    inside_building = true
    player.clear_mobile_input()
    _create_interior()
    player.global_position = Vector3(0, 1.0, 0)
    camera_yaw = 0.0
    camera_pitch = -0.12
    camera_rig.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
    transition_label.text = "ENTERED BUILDING"
    transition_label.visible = true
    await get_tree().create_timer(0.8).timeout
    transition_label.visible = false

func _exit_building() -> void:
    inside_building = false
    player.clear_mobile_input()
    if is_instance_valid(interior_root):
        interior_root.queue_free()
        interior_root = null
    player.global_position = exterior_player_position + Vector3(0, 0, 2.2)
    camera_yaw = exterior_camera_yaw
    camera_pitch = exterior_camera_pitch
    camera_rig.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
    interact_label.visible = false
    transition_label.text = "LEFT BUILDING"
    transition_label.visible = true
    await get_tree().create_timer(0.8).timeout
    transition_label.visible = false

func _create_interior() -> void:
    if is_instance_valid(interior_root):
        interior_root.queue_free()

    interior_root = Node3D.new()
    interior_root.name = "BuildingInterior"
    add_child(interior_root)

    _add_interior_box(Vector3(0, -0.12, 0), Vector3(18, 0.25, 18), Color(0.10, 0.10, 0.11))
    _add_interior_box(Vector3(0, 6.0, 0), Vector3(18, 0.25, 18), Color(0.07, 0.07, 0.08))
    _add_interior_box(Vector3(-9, 3.0, 0), Vector3(0.25, 6, 18), Color(0.14, 0.14, 0.16))
    _add_interior_box(Vector3(9, 3.0, 0), Vector3(0.25, 6, 18), Color(0.14, 0.14, 0.16))
    _add_interior_box(Vector3(0, 3.0, -9), Vector3(18, 6, 0.25), Color(0.14, 0.14, 0.16))
    _add_interior_box(Vector3(0, 3.0, 9), Vector3(18, 6, 0.25), Color(0.14, 0.14, 0.16))

    _add_interior_box(Vector3(-4.5, 1.2, -2.5), Vector3(3.5, 0.35, 2.0), Color(0.20, 0.16, 0.11))
    _add_interior_box(Vector3(4.5, 1.2, -2.5), Vector3(3.5, 0.35, 2.0), Color(0.20, 0.16, 0.11))
    _add_interior_box(Vector3(0, 1.0, -6.0), Vector3(7.0, 0.25, 0.25), Color(0.75, 0.58, 0.20))

    var search := MeshInstance3D.new()
    search.name = "SearchMesh"
    var search_mesh := BoxMesh.new()
    search_mesh.size = Vector3(2.4, 0.7, 1.1)
    search.mesh = search_mesh
    search.position = Vector3(0, 0.65, -3.8)
    var search_material := StandardMaterial3D.new()
    search_material.albedo_color = Color(0.32, 0.22, 0.10)
    search_material.roughness = 0.65
    search.material_override = search_material
    interior_root.add_child(search)

    var search_body := StaticBody3D.new()
    search_body.name = "SearchObject"
    search_body.position = Vector3(0, 0.65, -3.8)
    var search_collision := CollisionShape3D.new()
    var search_shape := BoxShape3D.new()
    search_shape.size = Vector3(2.4, 0.7, 1.1)
    search_collision.shape = search_shape
    search_body.add_child(search_collision)
    interior_root.add_child(search_body)

    var light := OmniLight3D.new()
    light.name = "InteriorLight"
    light.position = Vector3(0, 5.0, 0)
    light.light_energy = 2.0
    light.omni_range = 16.0
    light.light_color = Color(1.0, 0.86, 0.62)
    interior_root.add_child(light)

func _add_interior_box(pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.72
    mesh_instance.material_override = material
    interior_root.add_child(mesh_instance)

    var body := StaticBody3D.new()
    body.position = pos
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    interior_root.add_child(body)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            _stop_game()
            return
        if event.keycode == KEY_E:
            _interact()
            return

    if not menu.visible and event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x > get_viewport().get_visible_rect().size.x * 0.38:
                camera_touch_id = event.index
        elif event.index == camera_touch_id:
            camera_touch_id = -1
        return

    if not menu.visible and event is InputEventScreenDrag and event.index == camera_touch_id:
        _rotate_camera(event.relative)

func _rotate_camera(relative: Vector2) -> void:
    camera_yaw -= relative.x * camera_sensitivity
    camera_pitch = clamp(camera_pitch - relative.y * camera_sensitivity, -0.70, 0.25)
    camera_rig.rotation.x = camera_pitch
    camera_rig.rotation.y = camera_yaw

func _stop_game() -> void:
    if inside_building:
        inside_building = false
        if is_instance_valid(interior_root):
            interior_root.queue_free()
            interior_root = null
        player.global_position = exterior_player_position
    menu.visible = true
    mobile_controls.visible = false
    objective_label.visible = false
    inventory_label.visible = false
    player.clear_mobile_input()
    player.set_physics_process(false)
    camera_touch_id = -1
    interaction_target = ""
    interact_label.visible = false
    transition_label.visible = false
