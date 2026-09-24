extends CharacterBody3D

@export var speed := 5.0
@export var gravity := 18.0

func _ready() -> void:
    set_physics_process(false)

func _physics_process(delta: float) -> void:
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := Vector3(input_vec.x, 0.0, input_vec.y)

    if direction.length() > 0.1:
        direction = direction.normalized()
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    move_and_slide()
