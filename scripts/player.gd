extends CharacterBody3D

@export var speed := 5.0
@export var sprint_speed := 7.5
@export var gravity := 18.0
@export var world_limit := 44.0

var mobile_input := Vector2.ZERO
var sprint_pressed := false
var sprint_allowed := true

func _ready() -> void:
    set_physics_process(false)

func set_mobile_direction(action: String, pressed: bool) -> void:
    var value := 1.0 if pressed else 0.0
    match action:
        "forward":
            mobile_input.y = -value
        "back":
            mobile_input.y = value
        "left":
            mobile_input.x = -value
        "right":
            mobile_input.x = value
        "sprint":
            sprint_pressed = pressed

func clear_mobile_input() -> void:
    mobile_input = Vector2.ZERO
    sprint_pressed = false

func _physics_process(delta: float) -> void:
    var keyboard_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_vec := mobile_input if mobile_input.length() > 0.01 else keyboard_input
    var direction := Vector3(input_vec.x, 0.0, input_vec.y)

    if direction.length() > 0.1:
        direction = direction.normalized()
        var current_speed := sprint_speed if sprint_allowed and (sprint_pressed or Input.is_key_pressed(KEY_SHIFT)) else speed
        velocity.x = direction.x * current_speed
        velocity.z = direction.z * current_speed
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    move_and_slide()
    global_position.x = clamp(global_position.x, -world_limit, world_limit)
    global_position.z = clamp(global_position.z, -world_limit, world_limit)
