extends CharacterBody2D

@export var SPEED: float = 300.0
@onready var animated_sprite = $AnimatedSprite2D 

func _physics_process(_delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	
	# Reference your AnimatedSprite2D
	# Assuming 'Player' has a child 'AnimatedSprite2D'
	var anim_sprite = $AnimatedSprite2D 

	if direction:
		velocity.x = direction * SPEED
		# Trigger the walk animation
		anim_sprite.play("walk")
		# Handle flipping
		anim_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		# Trigger idle when standing still
		anim_sprite.play("idle")

	move_and_slide()
