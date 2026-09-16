extends CharacterBody3D

# Movement settings
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_force := 12.0
@export var mouse_sensitivity := 0.003

# Parkour settings
@export var slide_speed := 10.0
@export var slide_duration := 0.8
@export var wall_run_speed := 7.0
@export var wall_jump_force := 6.0
@export var wall_run_max_time := 1.2

# Physics
var gravity := 20.0
var current_speed := walk_speed
var is_sliding := false
var slide_timer := 0.0
var is_wall_running := false
var wall_normal := Vector3.ZERO
var grounded := false
var jump_cooldown := 0.0
var wall_run_timer := 0.0

# Node references
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)
	
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# Update jump cooldown
	if jump_cooldown > 0:
		jump_cooldown -= delta
		grounded = false
	else:
		grounded = is_on_floor()
	
	# Apply gravity when not grounded
	if not grounded and not is_wall_running:
		velocity.y -= gravity * delta
	
	# Sprint check
	current_speed = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	
	# Jump
	if Input.is_action_just_pressed("jump"):
		if grounded:
			velocity.y = jump_force
			jump_cooldown = 0.15
			grounded = false
		elif is_wall_running:
			velocity = wall_normal * wall_jump_force + Vector3.UP * jump_force
			is_wall_running = false
			jump_cooldown = 0.15
	
	# Movement input
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if not is_sliding:
		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed * delta * 6.0)
			velocity.z = move_toward(velocity.z, 0, current_speed * delta * 6.0)

	

	
	# Slide
	if Input.is_action_just_pressed("slide") and grounded and not is_sliding:
		start_slide()
	
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			end_slide()
	
	# Wall run detection (only when in air and not sliding)
	if not grounded and not is_sliding:
		check_wall_run()
	elif is_wall_running:
		is_wall_running = false
	
	# Apply movement
	move_and_slide()

func start_slide() -> void:
	is_sliding = true
	slide_timer = slide_duration
	var forward := -transform.basis.z
	velocity.x = forward.x * slide_speed
	velocity.z = forward.z * slide_speed
	
	# Shrink collision and lower camera
	collision.scale.y = 0.5
	collision.position.y = -0.45
	head.position.y = -0.3  # Lower the camera

func end_slide() -> void:
	is_sliding = false
	collision.scale.y = 1.0
	collision.position.y = 0
	head.position.y = 0.7  # Back to normal eye level

func check_wall_run() -> void:
	var space_state := get_world_3d().direct_space_state

	
	# Check left and right for walls
	for dir in [transform.basis.x, -transform.basis.x]:
		var query := PhysicsRayQueryParameters3D.create(
			global_position,
			global_position + dir * 0.7
		)
		query.exclude = [self]
		var result := space_state.intersect_ray(query)
		
		
		# Need some speed to wall run
		if result and velocity.length() > 3.0:
		
			wall_normal = result.normal
			is_wall_running = true
			wall_run_timer += get_physics_process_delta_time()
			if wall_run_timer > wall_run_max_time:
				is_wall_running = false
				return
			velocity.y = -1.0  # Slow fall during wall run
			
			
			# Move along wall
			var wall_forward := wall_normal.cross(Vector3.UP).normalized()
			if wall_forward.dot(-transform.basis.z) < 0:
				wall_forward = -wall_forward
			velocity.x = wall_forward.x * wall_run_speed
			velocity.z = wall_forward.z * wall_run_speed
			return
	is_wall_running = false
