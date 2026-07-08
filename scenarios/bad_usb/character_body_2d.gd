extends CharacterBody2D

@export var SPEED: float = 300.00
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Get input for left and right movement
	var direction = Input.get_axis("move_left", "move_right")
	
	# Apply speed based on direction
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
