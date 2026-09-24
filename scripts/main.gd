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
var status_label: Label
var interaction_target: String = ""
var inside_building := false
var exterior_player_position := Vector3.ZERO
var exterior_camera_yaw := 0.0
var exterior_camera_pitch := -0.18
var interior_root: Node3D
var transition_label: Label
var search_completed := false
var supplies_count := 0
var food_count := 0
var water_count := 0
var health := 100.0
var hunger := 100.0
var survival_elapsed := 0.0
var game_over := false
var world_time := 8.0
var day_number := 1
var day_length_seconds := 300.0
var android_perf_accumulator := 0.0
var android_pause_autosave := true
var time_label: Label
var save_elapsed := 0.0
var has_saved_game := false
var continue_button: Button
var new_game_button: Button
var enemy_root: Node3D
var enemy_active := false
var enemy_health := 100.0
var enemy_attack_cooldown := 0.0
var enemy_hit_flash := 0.0
var enemy_max_health := 100.0
var player_attack_cooldown := 0.0
var attack_feedback_time := 0.0
var stamina := 100.0
var stamina_label: Label
var safe_zone_root: Node3D
var night_survived := false
var last_world_time := 8.0
var mission_complete := false
var mission_complete_label: Label
var flashlight: SpotLight3D
var flashlight_on := false
var flashlight_flicker_time := 0.0
var performance_fps_label: Label
var performance_sample_time := 0.0
var performance_sample_frames := 0
var performance_sample_fps := 0
var performance_min_fps := 60
var performance_report_time := 0.0
var performance_hud_visible := true
var enemy_health_label: Label
var night_threat_spawned := false
var dawn_message_active := false

func _ready() -> void:
    # Android 12 GB target: keep a stable 60 FPS ceiling and avoid unnecessary
    # frame-rate spikes while preserving the current visual quality.
    Engine.max_fps = 60
    Engine.physics_ticks_per_second = 60
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
    camera.current = true
    camera_rig.rotation.x = camera_pitch
    camera_rig.rotation.y = camera_yaw
    $HUD/Menu/Panel/Start.pressed.connect(_new_game)
    $HUD/Menu/Panel/Start.text = "NEW GAME"
    _build_checkpoint_menu()
    _build_city_collisions()
    _build_mobile_controls()
    _build_interaction_hud()
    _build_survival_hud()
    _build_stamina_hud()
    _build_time_hud()
    _build_enemy_system()
    _build_safe_zone()
    _build_mission_complete_hud()
    _build_flashlight()
    _build_enemy_health_hud()
    _build_performance_hud()
    _update_world_lighting()
    has_saved_game = _load_game()
    if has_saved_game:
        _update_world_lighting()
    var original_info := $HUD/Menu/Panel.get_node_or_null("Info") as Label
    if is_instance_valid(original_info):
        original_info.visible = false
    if is_instance_valid(continue_button):
        continue_button.visible = has_saved_game
    var checkpoint_info := $HUD/Menu/Panel.get_node_or_null("CheckpointInfo") as Label
    if is_instance_valid(checkpoint_info):
        checkpoint_info.text = "CHECKPOINT AVAILABLE" if has_saved_game else "NO CHECKPOINT • NEW GAME STARTS FRESH"

func _build_performance_hud() -> void:
    performance_fps_label = Label.new()
    performance_fps_label.name = "PerformanceFPS"
    performance_fps_label.position = Vector2(18, 18)
    performance_fps_label.size = Vector2(180, 28)
    performance_fps_label.add_theme_font_size_override("font_size", 14)
    performance_fps_label.modulate = Color(0.72, 0.78, 0.86, 0.72)
    performance_fps_label.text = "FPS --"
    performance_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $HUD.add_child(performance_fps_label)

func _build_checkpoint_menu() -> void:
    continue_button = Button.new()
    continue_button.name = "Continue"
    continue_button.position = Vector2(42, 190)
    continue_button.size = Vector2(476, 70)
    continue_button.text = "CONTINUE"
    continue_button.focus_mode = Control.FOCUS_NONE
    continue_button.add_theme_font_size_override("font_size", 24)
    continue_button.pressed.connect(_continue_game)
    $HUD/Menu/Panel.add_child(continue_button)

    new_game_button = $HUD/Menu/Panel/Start
    new_game_button.position = Vector2(42, 275)
    new_game_button.size = Vector2(476, 62)
    new_game_button.add_theme_font_size_override("font_size", 22)

    var checkpoint_info := Label.new()
    checkpoint_info.name = "CheckpointInfo"
    checkpoint_info.position = Vector2(42, 345)
    checkpoint_info.size = Vector2(476, 34)
    checkpoint_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    checkpoint_info.add_theme_font_size_override("font_size", 15)
    checkpoint_info.modulate = Color(0.55, 0.58, 0.66, 1)
    checkpoint_info.text = "CHECKPOINT AVAILABLE" if has_saved_game else "NO CHECKPOINT • NEW GAME STARTS FRESH"
    $HUD/Menu/Panel.add_child(checkpoint_info)

func _continue_game() -> void:
    if not has_saved_game:
        _start_game()
        return
    if not FileAccess.file_exists("user://days_after_save.json"):
        has_saved_game = false
        _start_game()
        return
    _reset_transient_game_state()
    _start_game()

func _new_game() -> void:
    _reset_transient_game_state()
    has_saved_game = false
    supplies_count = 0
    food_count = 0
    water_count = 0
    health = 100.0
    hunger = 100.0
    survival_elapsed = 0.0
    world_time = 8.0
    day_number = 1
    stamina = 100.0
    player.global_position = Vector3(0, 1, 8)
    camera_yaw = 0.0
    camera_pitch = -0.18
    camera_rig.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
    night_survived = false
    last_world_time = 8.0
    mission_complete = false
    night_threat_spawned = false
    dawn_message_active = false
    enemy_health = enemy_max_health
    enemy_attack_cooldown = 0.0
    enemy_active = false
    flashlight_on = false
    if is_instance_valid(enemy_root):
        enemy_root.visible = false
    if is_instance_valid(flashlight):
        flashlight.visible = false
    save_elapsed = 0.0
    search_completed = false
    DirAccess.remove_absolute("user://days_after_save.json")
    _start_game()

func _build_enemy_health_hud() -> void:
    enemy_health_label = Label.new()
    enemy_health_label.name = "ThreatHealth"
    enemy_health_label.position = Vector2(0, 208)
    enemy_health_label.size = Vector2(1280, 34)
    enemy_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    enemy_health_label.add_theme_font_size_override("font_size", 18)
    enemy_health_label.modulate = Color(0.95, 0.45, 0.40, 1)
    enemy_health_label.text = "THREAT  100%"
    enemy_health_label.visible = false
    enemy_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $HUD.add_child(enemy_health_label)

func _build_flashlight() -> void:
    flashlight = SpotLight3D.new()
    flashlight.name = "Flashlight"
    flashlight.position = Vector3(0.25, 0.05, -0.35)
    flashlight.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
    flashlight.light_energy = 3.2
    flashlight.spot_range = 22.0
    flashlight.spot_angle = 32.0
    flashlight.shadow_enabled = true
    flashlight.visible = false
    camera.add_child(flashlight)

    var button := Button.new()
    button.name = "Flashlight"
    button.text = "LIGHT"
    button.size = Vector2(86, 52)
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(_toggle_flashlight)
    $HUD.add_child(button)
    mobile_buttons["flashlight"] = button
    button.visible = false

func _update_flashlight_flicker(delta: float) -> void:
    if not flashlight_on or not is_instance_valid(flashlight):
        flashlight_flicker_time = 0.0
        return
    flashlight_flicker_time += delta
    var flicker := 1.0 + sin(flashlight_flicker_time * 37.0) * 0.025
    flashlight.energy = 3.2 * flicker

func _toggle_flashlight() -> void:
    if menu.visible or game_over:
        return
    flashlight_on = not flashlight_on
    flashlight.visible = flashlight_on
    if mobile_buttons.has("flashlight"):
        mobile_buttons["flashlight"].text = "LIGHT ON" if flashlight_on else "LIGHT"
    transition_label.text = "FLASHLIGHT ON" if flashlight_on else "FLASHLIGHT OFF"
    transition_label.visible = true
    await get_tree().create_timer(0.45).timeout
    if not game_over:
        transition_label.visible = false

func _build_mission_complete_hud() -> void:
    mission_complete_label = Label.new()
    mission_complete_label.name = "MissionComplete"
    mission_complete_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mission_complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission_complete_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    mission_complete_label.add_theme_font_size_override("font_size", 34)
    mission_complete_label.modulate = Color(0.72, 1.0, 0.80, 1)
    mission_complete_label.text = "MISSION COMPLETE\nDAY'S AFTER"
    mission_complete_label.visible = false
    mission_complete_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $HUD.add_child(mission_complete_label)

func _build_safe_zone() -> void:
    safe_zone_root = Node3D.new()
    safe_zone_root.name = "SafeZone"
    safe_zone_root.position = Vector3(0, 0, 18)
    add_child(safe_zone_root)

    var marker := MeshInstance3D.new()
    marker.name = "SafeZoneMarker"
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 2.4
    cylinder.bottom_radius = 2.4
    cylinder.height = 0.08
    marker.mesh = cylinder
    marker.position = Vector3(0, 0.04, 0)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.18, 0.48, 0.30)
    material.emission_enabled = true
    material.emission = Color(0.08, 0.24, 0.14)
    material.emission_energy_multiplier = 1.6
    marker.material_override = material
    safe_zone_root.add_child(marker)

    var label := Label3D.new()
    label.name = "SafeZoneLabel"
    label.text = "SAFE ZONE"
    label.position = Vector3(0, 0.15, 0)
    label.font_size = 32
    label.modulate = Color(0.72, 1.0, 0.80, 1)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    safe_zone_root.add_child(label)

func _build_enemy_system() -> void:
    enemy_root = Node3D.new()
    enemy_root.name = "Threat"
    add_child(enemy_root)

    var mesh := MeshInstance3D.new()
    mesh.name = "EnemyMesh"
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.42
    capsule.height = 1.8
    mesh.mesh = capsule
    mesh.position = Vector3(0, 0.9, 0)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.26, 0.09, 0.08)
    material.roughness = 0.82
    mesh.material_override = material
    enemy_root.add_child(mesh)

    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    var shape := CapsuleShape3D.new()
    shape.radius = 0.42
    shape.height = 1.8
    collision.shape = shape
    collision.position = Vector3(0, 0.9, 0)
    enemy_root.add_child(collision)
    enemy_root.visible = false

func _spawn_enemy() -> void:
    if not is_instance_valid(enemy_root):
        return
    enemy_root.global_position = player.global_position + Vector3(8.0, 0.0, -10.0)
    enemy_health = enemy_max_health
    enemy_attack_cooldown = 0.0
    enemy_active = true
    enemy_root.visible = true
    transition_label.text = "THREAT DETECTED"
    transition_label.visible = true
    await get_tree().create_timer(1.0).timeout
    if not game_over:
        transition_label.visible = false

func _update_enemy(delta: float) -> void:
    if not enemy_active or not is_instance_valid(enemy_root):
        return
    if inside_building:
        return
    enemy_attack_cooldown = maxf(0.0, enemy_attack_cooldown - delta)
    if enemy_active and is_instance_valid(enemy_root) and not inside_building:
        var threat_direction := (enemy_root.global_position - player.global_position)
        threat_direction.y = 0.0
        if threat_direction.length() > 0.1:
            var facing := -camera_rig.global_transform.basis.z
            facing.y = 0.0
            if facing.length() > 0.1:
                var threat_angle := rad_to_deg(acos(clampf(facing.normalized().dot(threat_direction.normalized()), -1.0, 1.0)))
                if is_instance_valid(mobile_buttons.get("attack")):
                    mobile_buttons["attack"].modulate = Color(1.0, 0.35, 0.30, 1.0) if threat_angle < 65.0 else Color(1.0, 1.0, 1.0, 0.86)
    var target := player.global_position
    var offset := target - enemy_root.global_position
    offset.y = 0.0
    var distance := offset.length()
    if distance > 1.7:
        enemy_root.global_position += offset.normalized() * minf(2.2 * delta, distance - 1.7)
        enemy_root.look_at(Vector3(target.x, enemy_root.global_position.y, target.z), Vector3.UP)
    elif enemy_attack_cooldown <= 0.0:
        enemy_attack_cooldown = 1.25
        health = maxf(0.0, health - 8.0)
        transition_label.text = "ATTACKED  •  HEALTH -8"
        transition_label.visible = true
        await get_tree().create_timer(0.65).timeout
        if not game_over:
            transition_label.visible = false
    if distance > 35.0:
        enemy_active = false
        enemy_root.visible = false
        enemy_health_label.visible = false
        if is_instance_valid(mobile_buttons.get("attack")):
            mobile_buttons["attack"].visible = false

func _attack_enemy() -> void:
    if not enemy_active or not is_instance_valid(enemy_root) or inside_building or game_over:
        return
    if player_attack_cooldown > 0.0:
        return
    player_attack_cooldown = 0.55
    var distance := player.global_position.distance_to(enemy_root.global_position)
    if distance > 3.2:
        transition_label.text = "TOO FAR  •  MOVE CLOSER"
        transition_label.visible = true
        await get_tree().create_timer(0.45).timeout
        if not game_over:
            transition_label.visible = false
        return
    enemy_health -= 50.0
    attack_feedback_time = 0.14
    enemy_hit_flash = 0.12
    var knockback := enemy_root.global_position - player.global_position
    knockback.y = 0.0
    if knockback.length() > 0.1:
        enemy_root.global_position += knockback.normalized() * 1.25
    enemy_root.modulate = Color(1.8, 0.45, 0.45, 1.0)
    player_attack_cooldown = maxf(player_attack_cooldown, 0.55)
    if enemy_health <= 0.0:
        enemy_active = false
        enemy_root.visible = false
        transition_label.text = "THREAT ELIMINATED"
    else:
        transition_label.text = "HIT CONFIRMED  •  THREAT %d%%" % roundi((enemy_health / enemy_max_health) * 100.0)
    transition_label.visible = true
    await get_tree().create_timer(0.75).timeout
    if not game_over:
        transition_label.visible = false

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

    var use_food := Button.new()
    use_food.name = "UseFood"
    use_food.text = "EAT"
    use_food.size = Vector2(86, 52)
    use_food.focus_mode = Control.FOCUS_NONE
    use_food.pressed.connect(_consume_food)
    $HUD.add_child(use_food)
    mobile_buttons["use_food"] = use_food
    use_food.visible = false

    var attack := Button.new()
    attack.name = "Attack"
    attack.text = "ATTACK"
    attack.size = Vector2(100, 52)
    attack.focus_mode = Control.FOCUS_NONE
    attack.pressed.connect(_attack_enemy)
    $HUD.add_child(attack)
    mobile_buttons["attack"] = attack
    attack.visible = false

    var use_water := Button.new()
    use_water.name = "UseWater"
    use_water.text = "DRINK"
    use_water.size = Vector2(86, 52)
    use_water.focus_mode = Control.FOCUS_NONE
    use_water.pressed.connect(_consume_water)
    $HUD.add_child(use_water)
    mobile_buttons["use_water"] = use_water
    use_water.visible = false

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
    objective_label.size = Vector2(600, 42)
    objective_label.add_theme_font_size_override("font_size", 18)
    objective_label.modulate = Color(0.92, 0.92, 0.92, 1)
    objective_label.text = "OBJECTIVE  •  Find supplies"
    objective_label.visible = false
    $HUD.add_child(objective_label)

    inventory_label = Label.new()
    inventory_label.name = "Inventory"
    inventory_label.position = Vector2(24, 66)
    inventory_label.size = Vector2(620, 42)
    inventory_label.add_theme_font_size_override("font_size", 17)
    inventory_label.modulate = Color(0.9, 0.75, 0.36, 1)
    inventory_label.text = "SUPPLIES  0 / 1   FOOD  0   WATER  0"
    inventory_label.visible = false
    $HUD.add_child(inventory_label)

    status_label = Label.new()
    status_label.name = "Status"
    status_label.position = Vector2(24, 108)
    status_label.size = Vector2(620, 42)
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.modulate = Color(0.86, 0.86, 0.86, 1)
    status_label.text = "HEALTH  100   HUNGER  100"
    status_label.visible = false
    $HUD.add_child(status_label)

func _build_stamina_hud() -> void:
    stamina_label = Label.new()
    stamina_label.name = "Stamina"
    stamina_label.position = Vector2(24, 188)
    stamina_label.size = Vector2(300, 34)
    stamina_label.add_theme_font_size_override("font_size", 15)
    stamina_label.modulate = Color(0.72, 0.74, 0.80, 1)
    stamina_label.text = "STAMINA  100"
    stamina_label.visible = false
    $HUD.add_child(stamina_label)

func _update_stamina(delta: float) -> void:
    var sprinting: bool = player.is_sprinting
    if sprinting and stamina > 0.0:
        stamina = maxf(0.0, stamina - delta * 28.0)
    else:
        stamina = minf(100.0, stamina + delta * 18.0)
    player.sprint_allowed = stamina > 0.5
    if stamina <= 0.5 and player.is_sprinting:
        player.is_sprinting = false
    if is_instance_valid(stamina_label):
        stamina_label.text = "STAMINA  %d" % roundi(stamina)
        stamina_label.visible = not menu.visible and not game_over

func _build_time_hud() -> void:
    time_label = Label.new()
    time_label.name = "WorldTime"
    time_label.position = Vector2(24, 150)
    time_label.size = Vector2(300, 38)
    time_label.add_theme_font_size_override("font_size", 15)
    time_label.modulate = Color(0.72, 0.74, 0.80, 1)
    time_label.text = "DAY %d  •  08:00  •  MORNING" % day_number
    time_label.visible = false
    $HUD.add_child(time_label)

func _update_world_lighting() -> void:
    var sun := get_node_or_null("Sun") as DirectionalLight3D
    var environment: Environment = $WorldEnvironment.environment
    var cycle := fmod(world_time, 24.0)
    var daylight := 0.0
    if cycle >= 6.0 and cycle < 18.0:
        daylight = sin((cycle - 6.0) / 12.0 * PI)
    if is_instance_valid(sun):
        sun.rotation_degrees = Vector3(-18.0 - daylight * 52.0, -25.0, 0.0)
        sun.light_energy = 0.18 + daylight * 1.42
    if environment:
        environment.ambient_light_energy = 0.32 + daylight * 0.83
        environment.background_color = Color(0.018 + daylight * 0.045, 0.025 + daylight * 0.055, 0.045 + daylight * 0.10, 1.0)
    if is_instance_valid(time_label):
        var hour := int(floor(cycle))
        var minute := int(floor((cycle - hour) * 60.0))
        var period := "NIGHT"
        if cycle >= 6.0 and cycle < 12.0:
            period = "MORNING"
        elif cycle >= 12.0 and cycle < 18.0:
            period = "AFTERNOON"
        elif cycle >= 18.0 and cycle < 22.0:
            period = "EVENING"
        time_label.text = "DAY %d  •  %02d:%02d  •  %s" % [day_number, hour, minute, period]

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
    if mobile_buttons.has("use_food"):
        mobile_buttons["use_food"].position = Vector2(size.x - margin - 190.0, bottom - 144.0)
    if mobile_buttons.has("attack"):
        mobile_buttons["attack"].position = Vector2(size.x - margin - 100.0, bottom - 216.0)
    if mobile_buttons.has("use_water"):
        mobile_buttons["use_water"].position = Vector2(size.x - margin - 96.0, bottom - 144.0)
    if mobile_buttons.has("flashlight"):
        mobile_buttons["flashlight"].position = Vector2(size.x - margin - 96.0, bottom - 72.0)

func _reset_performance_monitor() -> void:
    performance_sample_time = 0.0
    performance_sample_frames = 0
    performance_sample_fps = 0
    performance_min_fps = 60

func _start_game() -> void:
    _reset_performance_monitor()
    game_over = false
    player.set_physics_process(true)
    mobile_controls.visible = true
    menu.visible = false
    mobile_controls.visible = true
    objective_label.visible = true
    inventory_label.visible = true
    status_label.visible = true
    time_label.visible = true
    stamina_label.visible = true
    mission_complete_label.visible = mission_complete
    mobile_buttons["flashlight"].visible = true
    player.clear_mobile_input()
    player.set_physics_process(true)
    camera.current = true
    transition_label.visible = false
    game_over = false
    if not has_saved_game:
        _reset_transient_game_state()
        health = 100.0
        hunger = 100.0
        survival_elapsed = 0.0
        supplies_count = 0
        food_count = 0
        water_count = 0
        world_time = 8.0
        day_number = 1
        stamina = 100.0
        night_survived = false
        night_threat_spawned = false
        mission_complete = false
        enemy_health = enemy_max_health
    else:
        survival_elapsed = (100.0 - hunger) / 0.45
        _update_world_lighting()
    _update_survival_hud()
    if has_saved_game:
        enemy_active = false
        enemy_root.visible = false

func _update_survival_hud() -> void:
    inventory_label.text = "SUPPLIES  %d / 1   FOOD  %d   WATER  %d" % [supplies_count, food_count, water_count]
    if supplies_count >= 1 and not night_survived and world_time >= 18.0:
        objective_label.text = "OBJECTIVE  •  Survive until dawn"
    elif supplies_count >= 1 and night_survived:
        objective_label.text = "OBJECTIVE  •  Reach the safe zone"
    elif supplies_count >= 1:
        objective_label.text = "OBJECTIVE  •  Prepare for night"
    else:
        objective_label.text = "OBJECTIVE  •  Find supplies"
    status_label.text = "HEALTH  %d   HUNGER  %d" % [roundi(health), roundi(hunger)]
    if mobile_buttons.has("use_food"):
        mobile_buttons["use_food"].visible = food_count > 0 and hunger < 99.0 and not menu.visible and not game_over
    if mobile_buttons.has("use_water"):
        mobile_buttons["use_water"].visible = water_count > 0 and hunger < 99.0 and not menu.visible and not game_over

func _process(delta: float) -> void:
    player_attack_cooldown = maxf(0.0, player_attack_cooldown - delta)
    android_perf_accumulator += delta
    if android_perf_accumulator >= 1.0:
        android_perf_accumulator = 0.0
        Engine.max_fps = 60
    attack_feedback_time = maxf(0.0, attack_feedback_time - delta)
    _update_flashlight_flicker(delta)
    performance_sample_time += delta
    performance_sample_frames += 1
    performance_report_time += delta
    if performance_sample_time >= 0.5:
        performance_sample_fps = roundi(float(performance_sample_frames) / performance_sample_time)
        performance_min_fps = mini(performance_min_fps, performance_sample_fps)
        performance_sample_time = 0.0
        performance_sample_frames = 0
    if is_instance_valid(performance_fps_label):
        performance_fps_label.visible = performance_hud_visible and not menu.visible and not game_over
        performance_fps_label.text = "FPS %d  •  LOW %d" % [performance_sample_fps, performance_min_fps]
    if enemy_hit_flash > 0.0:
        enemy_hit_flash = maxf(0.0, enemy_hit_flash - delta)
        if enemy_hit_flash <= 0.0 and is_instance_valid(enemy_root):
            enemy_root.modulate = Color.WHITE
    if menu.visible or game_over:
        return

    survival_elapsed += delta
    save_elapsed += delta
    if save_elapsed >= 10.0:
        save_elapsed = 0.0
        _save_game()
    last_world_time = world_time
    var next_world_time := world_time + delta * (24.0 / day_length_seconds)
    if next_world_time >= 24.0:
        day_number += int(floor(next_world_time / 24.0))
    world_time = fmod(next_world_time, 24.0)
    if supplies_count >= 1 and not night_survived and last_world_time >= 18.0 and world_time < 6.0:
        night_survived = true
        night_threat_spawned = false
        enemy_active = false
        enemy_root.visible = false
        dawn_message_active = true
        transition_label.text = "DAWN  •  NIGHT SURVIVED"
        transition_label.visible = true
        _save_game()
        await get_tree().create_timer(1.5).timeout
        dawn_message_active = false
        if not game_over:
            transition_label.visible = false
    _update_world_lighting()
    hunger = maxf(0.0, 100.0 - survival_elapsed * 0.45)
    if hunger <= 0.0:
        health = maxf(0.0, health - delta * 2.0)

    _update_survival_hud()
    _update_stamina(delta)

    if is_instance_valid(mobile_buttons.get("flashlight")):
        mobile_buttons["flashlight"].visible = not menu.visible and not game_over
        mobile_buttons["flashlight"].text = "LIGHT ON" if flashlight_on else "LIGHT"
        mobile_buttons["flashlight"].disabled = menu.visible or game_over
        if inside_building:
            mobile_buttons["flashlight"].modulate = Color(1.0, 0.88, 0.55, 1.0)
        else:
            mobile_buttons["flashlight"].modulate = Color(1.0, 1.0, 1.0, 0.86)

    if health <= 0.0:
        _save_game()
        _handle_game_over()
        return

    if inside_building:
        _update_interior_interaction()
    else:
        _update_interaction_target()
        if supplies_count >= 1 and night_survived and is_instance_valid(safe_zone_root):
            if player.global_position.distance_to(safe_zone_root.global_position) <= 3.0:
                objective_label.text = "OBJECTIVE COMPLETE  •  Safe zone reached"
                if not mission_complete:
                    mission_complete = true
                    mission_complete_label.visible = true
                    enemy_active = false
                    enemy_root.visible = false
                    _save_game()
                if health < 100.0:
                    health = minf(100.0, health + delta * 3.0)
                if hunger < 100.0:
                    hunger = minf(100.0, hunger + delta * 1.5)
                    _sync_survival_timer()
        _update_enemy(delta)
        if supplies_count >= 1 and not night_survived and not night_threat_spawned and world_time >= 18.0:
            night_threat_spawned = true
            _spawn_enemy()
    if mobile_buttons.has("attack"):
        mobile_buttons["attack"].visible = enemy_active and not inside_building and not game_over
        mobile_buttons["attack"].disabled = player_attack_cooldown > 0.0
        mobile_buttons["attack"].text = "ATTACK" if player_attack_cooldown <= 0.0 else "WAIT"
        if attack_feedback_time > 0.0:
            mobile_buttons["attack"].modulate = Color(1.0, 0.85, 0.30, 1.0)
    if is_instance_valid(enemy_health_label):
        enemy_health_label.visible = enemy_active and not inside_building and not game_over
        enemy_health_label.text = "THREAT  %d%%" % roundi((enemy_health / enemy_max_health) * 100.0)
    if is_instance_valid(mission_complete_label):
        mission_complete_label.visible = mission_complete and not menu.visible and not game_over
    if is_instance_valid(enemy_health_label) and not enemy_active:
        enemy_health_label.visible = false
    if is_instance_valid(mobile_buttons.get("flashlight")):
        mobile_buttons["flashlight"].text = "LIGHT ON" if flashlight_on else "LIGHT"

func _handle_game_over() -> void:
    if game_over:
        return
    game_over = true
    has_saved_game = false
    DirAccess.remove_absolute("user://days_after_save.json")
    player.clear_mobile_input()
    player.set_physics_process(false)
    mobile_controls.visible = false
    interaction_target = ""
    mobile_buttons["interact"].visible = false
    mobile_buttons["use_food"].visible = false
    mobile_buttons["use_water"].visible = false
    if is_instance_valid(continue_button):
        continue_button.visible = has_saved_game
    var checkpoint_info := $HUD/Menu/Panel.get_node_or_null("CheckpointInfo") as Label
    if is_instance_valid(checkpoint_info):
        checkpoint_info.text = "CHECKPOINT AVAILABLE" if has_saved_game else "NO CHECKPOINT • NEW GAME STARTS FRESH"
    mobile_buttons["attack"].visible = false
    interact_label.visible = false
    transition_label.text = "YOU COLLAPSED\nPRESS ESC TO RETURN"
    transition_label.visible = true
    has_saved_game = false
    DirAccess.remove_absolute("user://days_after_save.json")

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
        if collider is StaticBody3D:
            if collider.name == "SearchObject" and supplies_count < 1:
                interaction_target = "SEARCH"
                interact_label.text = "Search desk • Tap INTERACT"
                interact_label.visible = true
                mobile_buttons["interact"].visible = true
                return
            if collider.name == "FoodObject" and food_count < 1:
                interaction_target = "FOOD"
                interact_label.text = "Take food • Tap INTERACT"
                interact_label.visible = true
                mobile_buttons["interact"].visible = true
                return
            if collider.name == "WaterObject" and water_count < 1:
                interaction_target = "WATER"
                interact_label.text = "Take water • Tap INTERACT"
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
    elif interaction_target == "FOOD" and inside_building:
        _take_food()
    elif interaction_target == "WATER" and inside_building:
        _take_water()

func _search_desk() -> void:
    if supplies_count >= 1:
        return
    supplies_count = 1
    _save_game()
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

func _take_food() -> void:
    if food_count >= 1:
        return
    food_count = 1
    _save_game()
    interaction_target = ""
    mobile_buttons["interact"].visible = false
    _update_survival_hud()
    _remove_pickup("FoodMesh", "FoodObject")
    transition_label.text = "FOOD COLLECTED"
    transition_label.visible = true
    await get_tree().create_timer(0.9).timeout
    transition_label.visible = false

func _take_water() -> void:
    if water_count >= 1:
        return
    water_count = 1
    _save_game()
    interaction_target = ""
    mobile_buttons["interact"].visible = false
    _update_survival_hud()
    _remove_pickup("WaterMesh", "WaterObject")
    transition_label.text = "WATER COLLECTED"
    transition_label.visible = true
    await get_tree().create_timer(0.9).timeout
    transition_label.visible = false

func _consume_food() -> void:
    if food_count <= 0 or game_over:
        return
    food_count -= 1
    hunger = minf(100.0, hunger + 35.0)
    _sync_survival_timer()
    _save_game()
    _update_survival_hud()
    transition_label.text = "FOOD EATEN  •  HUNGER +35"
    transition_label.visible = true
    await get_tree().create_timer(0.9).timeout
    transition_label.visible = false

func _consume_water() -> void:
    if water_count <= 0 or game_over:
        return
    water_count -= 1
    hunger = minf(100.0, hunger + 20.0)
    _sync_survival_timer()
    _save_game()
    _update_survival_hud()
    transition_label.text = "WATER DRANK  •  HUNGER +20"
    transition_label.visible = true
    await get_tree().create_timer(0.9).timeout
    transition_label.visible = false

func _sync_survival_timer() -> void:
    survival_elapsed = (100.0 - hunger) / 0.45

func _remove_pickup(mesh_name: String, body_name: String) -> void:
    var mesh := interior_root.get_node_or_null(mesh_name)
    if is_instance_valid(mesh):
        mesh.visible = false
    var body := interior_root.get_node_or_null(body_name)
    if is_instance_valid(body):
        body.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
        var collision := body.get_node_or_null("CollisionShape3D")
        if is_instance_valid(collision):
            collision.set_deferred("disabled", true)

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
    if supplies_count >= 1:
        search.visible = false
        search_body.process_mode = Node.PROCESS_MODE_DISABLED
        search_collision.disabled = true

    if food_count < 1:
        _create_pickup("FoodMesh", "FoodObject", Vector3(-4.5, 0.65, -5.0), Vector3(1.0, 0.8, 1.0), Color(0.62, 0.28, 0.12))
    if water_count < 1:
        _create_pickup("WaterMesh", "WaterObject", Vector3(4.5, 0.7, -5.0), Vector3(0.75, 1.1, 0.75), Color(0.20, 0.42, 0.72))

    var light := OmniLight3D.new()
    light.name = "InteriorLight"
    light.position = Vector3(0, 5.0, 0)
    light.light_energy = 2.0
    light.omni_range = 16.0
    light.light_color = Color(1.0, 0.86, 0.62)
    interior_root.add_child(light)

func _create_pickup(mesh_name: String, body_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = mesh_name
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.position = pos
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.55
    mesh.material_override = material
    interior_root.add_child(mesh)

    var body := StaticBody3D.new()
    body.name = body_name
    body.position = pos
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    interior_root.add_child(body)

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

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if menu.visible:
            get_tree().quit()
            return
        _stop_game()
    elif what == NOTIFICATION_APPLICATION_PAUSED:
        if android_pause_autosave and not menu.visible and not game_over:
            player.clear_mobile_input()
            _save_game()
    elif what == NOTIFICATION_APPLICATION_RESUMED:
        if not menu.visible and not game_over:
            player.clear_mobile_input()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            _stop_game()
            return
        if event.keycode == KEY_E:
            _interact()
            return
        if event.keycode == KEY_F:
            _consume_food()
            return
        if event.keycode == KEY_G:
            _consume_water()
            return
        if event.keycode == KEY_H:
            _attack_enemy()
            return
        if event.keycode == KEY_L:
            _toggle_flashlight()
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

func _reset_transient_game_state() -> void:
    inside_building = false
    interaction_target = ""
    camera_touch_id = -1
    player.clear_mobile_input()
    player.sprint_allowed = true
    player.is_sprinting = false
    flashlight_on = false
    if is_instance_valid(flashlight):
        flashlight.visible = false
    if is_instance_valid(enemy_root):
        enemy_active = false
        enemy_root.visible = false
    if is_instance_valid(transition_label):
        transition_label.visible = false
    if is_instance_valid(interact_label):
        interact_label.visible = false

func _stop_game() -> void:
    if inside_building:
        inside_building = false
        if is_instance_valid(interior_root):
            interior_root.queue_free()
            interior_root = null
        player.global_position = exterior_player_position
    if not game_over:
        _save_game()
    if game_over:
        has_saved_game = false
    else:
        has_saved_game = FileAccess.file_exists("user://days_after_save.json")
    menu.visible = true
    if is_instance_valid(continue_button):
        continue_button.visible = has_saved_game
    var checkpoint_info := $HUD/Menu/Panel.get_node_or_null("CheckpointInfo") as Label
    if is_instance_valid(checkpoint_info):
        checkpoint_info.text = "CHECKPOINT AVAILABLE" if has_saved_game else "NO CHECKPOINT • NEW GAME STARTS FRESH"
    mobile_controls.visible = false
    objective_label.visible = false
    inventory_label.visible = false
    status_label.visible = false
    time_label.visible = false
    stamina_label.visible = false
    mission_complete_label.visible = false
    mobile_buttons["flashlight"].visible = false
    enemy_health_label.visible = false
    flashlight_on = false
    flashlight.visible = false
    player.clear_mobile_input()
    player.set_physics_process(false)
    camera_touch_id = -1
    interaction_target = ""
    interact_label.visible = false
    transition_label.visible = false
    mobile_buttons["use_food"].visible = false
    mobile_buttons["use_water"].visible = false


func _save_game() -> void:
    var save_position := exterior_player_position if inside_building else player.global_position
    var data := {
        "player_position": {
            "x": save_position.x,
            "y": save_position.y,
            "z": save_position.z
        },
        "health": health,
        "hunger": hunger,
        "world_time": world_time,
        "day_number": day_number,
        "stamina": stamina,
        "supplies_count": supplies_count,
        "food_count": food_count,
        "water_count": water_count,
        "search_completed": search_completed,
        "night_survived": night_survived,
        "mission_complete": mission_complete,
        "night_threat_spawned": night_threat_spawned
    }
    var file := FileAccess.open("user://days_after_save.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()
        has_saved_game = true

func _load_game() -> bool:
    if not FileAccess.file_exists("user://days_after_save.json"):
        return false
    var file := FileAccess.open("user://days_after_save.json", FileAccess.READ)
    if file == null:
        return false
    var raw := file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(raw)
    if not (parsed is Dictionary):
        return false

    health = clampf(float(parsed.get("health", 100.0)), 0.0, 100.0)
    hunger = clampf(float(parsed.get("hunger", 100.0)), 0.0, 100.0)
    world_time = fmod(float(parsed.get("world_time", 8.0)), 24.0)
    day_number = maxi(1, int(parsed.get("day_number", 1)))
    stamina = clampf(float(parsed.get("stamina", 100.0)), 0.0, 100.0)
    supplies_count = int(parsed.get("supplies_count", 0))
    food_count = int(parsed.get("food_count", 0))
    water_count = int(parsed.get("water_count", 0))
    search_completed = bool(parsed.get("search_completed", supplies_count >= 1))
    night_survived = bool(parsed.get("night_survived", false))
    mission_complete = bool(parsed.get("mission_complete", false))
    night_threat_spawned = bool(parsed.get("night_threat_spawned", world_time >= 18.0 and not night_survived))

    var saved_position = parsed.get("player_position", {})
    if saved_position is Dictionary:
        player.global_position = Vector3(
            float(saved_position.get("x", player.global_position.x)),
            float(saved_position.get("y", player.global_position.y)),
            float(saved_position.get("z", player.global_position.z))
        )

    last_world_time = world_time
    has_saved_game = true
    return true
