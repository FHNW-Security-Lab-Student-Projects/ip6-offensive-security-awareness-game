extends CharacterBody2D

@export var SPEED: float = 300.0
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
		_sprite.play("walk")
		_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		_sprite.play("idle")

	move_and_slide()
