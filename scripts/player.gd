extends CharacterBody3D

@export var speed := 5.0
@export var sprint_speed := 7.5
@export var gravity := 18.0
@export var world_limit := 44.0

var mobile_input := Vector2.ZERO
var sprint_pressed := false
var sprint_allowed := true
var is_sprinting := false
@export var acceleration := 24.0
@export var deceleration := 30.0
@export var turn_speed := 10.0

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
    is_sprinting = false

func _physics_process(delta: float) -> void:
    var keyboard_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_vec := mobile_input if mobile_input.length() > 0.01 else keyboard_input
    var camera_node := get_node_or_null("CameraRig/Camera3D") as Camera3D
    var direction := Vector3.ZERO
    if input_vec.length() > 0.01:
        if is_instance_valid(camera_node):
            var forward := -camera_node.global_transform.basis.z
            var right := camera_node.global_transform.basis.x
            forward.y = 0.0
            right.y = 0.0
            direction = (right.normalized() * input_vec.x + forward.normalized() * -input_vec.y).normalized()
        else:
            direction = Vector3(input_vec.x, 0.0, input_vec.y).normalized()

    if direction.length() > 0.1:
        is_sprinting = sprint_allowed and (sprint_pressed or Input.is_key_pressed(KEY_SHIFT))
        var current_speed := sprint_speed if is_sprinting else speed
        velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
        velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * turn_speed)
    else:
        is_sprinting = false
        velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
        velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    move_and_slide()
    global_position.x = clamp(global_position.x, -world_limit, world_limit)
    global_position.z = clamp(global_position.z, -world_limit, world_limit)
