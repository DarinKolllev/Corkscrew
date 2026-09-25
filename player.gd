extends CharacterBody3D

# --- Tunables ---
@export var walk_speed := 5.5
@export var sprint_speed := 9.5
@export var crouch_speed := 3.0
@export var jump_force := 6.5
@export var gravity := 22.0
@export var air_control := 4.0
@export var ground_friction := 8.0
@export var mouse_sensitivity := 0.003

@export var slide_speed := 11.0
@export var slide_duration := 0.85
@export var wall_run_speed := 8.5
@export var wall_run_max_time := 1.2
@export var wall_jump_force := 6.5
@export var vault_side_impulse := 5.0
@export var mantle_height := 1.6

@export var fov_default := 90.0
@export var fov_sprint := 100.0
@export var tilt_max_deg := 8.0
@export var coyote_time := 0.14
@export var jump_buffer := 0.18

@export var hang_reach_height := 2.2      
@export var hang_grip_offset := 0.35        
@export var hang_head_below_ledge := 0.4    
@export var hang_climb_duration := 0.35     
@export var shimmy_speed := 1.8  

@export var bob_amplitude := 0.055
@export var bob_frequency := 9.0
@export var land_dip_threshold := 6.0     
@export var land_dip_max := 0.25          
@export var fov_kick_slide := 12.0
@export var fov_kick_vault := 8.0

# --- State ---
var is_sliding := false
var slide_timer := 0.0
var is_wall_running := false
var wall_normal := Vector3.ZERO
var wall_run_timer := 0.0
var _coyote := 0.0
var _jump_buffer_t := 0.0
var _tilt_target := 0.0
var is_hanging := false
var _hang_normal := Vector3.ZERO
var _hang_climbing := false 
var _grab_cooldown := 0.0

var _bob_time := 0.0
var _land_dip := 0.0
var _fov_kick := 0.0
var _recoil_pitch := 0.0
var _prev_velocity_y := 0.0
var _prev_on_floor := true
var _base_cam_pos := Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var _capsule: CapsuleShape3D = collision.shape

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = fov_default
	_base_cam_pos = camera.position

func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-e.relative.x * mouse_sensitivity)
		head.rotate_x(-e.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI/2 + 0.01, PI/2 - 0.01)
	if e.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED)
	if e.is_action_pressed("jump"):
		_jump_buffer_t = jump_buffer

func _physics_process(delta: float) -> void:
	_jump_buffer_t = max(_jump_buffer_t - delta, 0.0)
	_grab_cooldown = max(_grab_cooldown - delta, 0.0)
	if is_hanging:
		_process_hang(delta)
		move_and_slide()
		return

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = coyote_time
		wall_run_timer = 0.0
	else:
		_coyote = max(_coyote - delta, 0.0)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and input_dir.y < 0.0 and not is_sliding

	# Gravity (unless wall-running clamps it)
	if not is_wall_running:
		velocity.y -= gravity * delta

	# Ground movement
	if on_floor and not is_sliding:
		var target_speed := sprint_speed if sprinting else walk_speed
		var target := wish * target_speed
		velocity.x = lerp(velocity.x, target.x, ground_friction * delta)
		velocity.z = lerp(velocity.z, target.z, ground_friction * delta)

	# Air control (preserve momentum, gentle nudge)
	elif not on_floor and not is_wall_running:
		if wish.length() > 0.01:
			var hv := Vector3(velocity.x, 0, velocity.z)
			var target := wish * maxf(hv.length(), sprint_speed)
			hv = hv.lerp(target, air_control * delta)
			velocity.x = hv.x; velocity.z = hv.z
			# Try to grab a ledge whenever airborne (and not wall-running)
	if not on_floor and not is_wall_running and not is_hanging:
		_try_ledge_grab()

	# Jump / vault / walljump
	if _jump_buffer_t > 0.0:
		if is_wall_running:
			velocity = wall_normal * wall_jump_force + Vector3.UP * jump_force
			is_wall_running = false
			_jump_buffer_t = 0.0
		elif _coyote > 0.0:
			if _try_vault():
				pass
			else:
				velocity.y = jump_force
			_coyote = 0.0
			_jump_buffer_t = 0.0

	# Slide start
	if Input.is_action_just_pressed("slide") and on_floor and sprinting and not is_sliding:
		_start_slide()

	# Sliding physics
	if is_sliding:
		slide_timer -= delta
		# gentle decay so slide feels weighty
		velocity.x = lerp(velocity.x, 0.0, 0.5 * delta)
		velocity.z = lerp(velocity.z, 0.0, 0.5 * delta)
		if slide_timer <= 0.0 or not Input.is_action_pressed("slide"):
			_end_slide()

	# Wall run
	if not on_floor and not is_sliding:
		_update_wall_run(delta)
	elif is_wall_running:
		is_wall_running = false
		_tilt_target = 0.0

	# Camera juice: FOV kick + wall-run tilt
	update_camera_juice(delta, on_floor, sprinting)

	move_and_slide()

# ---- Helpers ----
func _start_slide() -> void:
	is_sliding = true
	slide_timer = slide_duration
	var f := -transform.basis.z
	velocity.x = f.x * slide_speed
	velocity.z = f.z * slide_speed
	_capsule.height = 1.0
	collision.position.y = -0.4
	head.position.y = 0.25
	_fov_kick = fov_kick_slide
	_recoil_pitch = deg_to_rad(-2.5)

func _end_slide() -> void:
	is_sliding = false
	_capsule.height = 1.8
	collision.position.y = 0.0
	head.position.y = 0.7

func _update_wall_run(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var found := false
	for dir in [transform.basis.x, -transform.basis.x]:
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + dir * 0.7)
		q.exclude = [self]
		var hit := space.intersect_ray(q)
		if hit and Vector3(velocity.x, 0, velocity.z).length() > 3.0:
			wall_normal = hit.normal
			is_wall_running = true
			if wall_run_timer < 0.05:
				_fov_kick = 6.0
			wall_run_timer += delta
			if wall_run_timer > wall_run_max_time:
				is_wall_running = false
				_tilt_target = 0.0
				return
			velocity.y = max(velocity.y - 4.0 * delta, -2.0)
			var along := wall_normal.cross(Vector3.UP).normalized()
			if along.dot(-transform.basis.z) < 0:
				along = -along
			velocity.x = along.x * wall_run_speed
			velocity.z = along.z * wall_run_speed
			# tilt: right-wall = tilt left, and vice versa
			_tilt_target = -tilt_max_deg if wall_normal.dot(transform.basis.x) > 0 else tilt_max_deg
			found = true
			return
	if not found:
		is_wall_running = false
		_tilt_target = 0.0

func _try_vault() -> bool:
	# If facing a low obstacle within mantle_height, hop onto it. Side input adds lateral impulse.
	var space := get_world_3d().direct_space_state
	var forward := -transform.basis.z
	# 1) is something in front?
	var q1 := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.4,
		global_position + Vector3.UP * 0.4 + forward * 0.9)
	q1.exclude = [self]
	if space.intersect_ray(q1).is_empty():
		return false
	# 2) is the top within reach?
	var top_probe := global_position + Vector3.UP * mantle_height + forward * 0.9
	var q2 := PhysicsRayQueryParameters3D.create(top_probe, top_probe + Vector3.DOWN * (mantle_height + 0.1))
	q2.exclude = [self]
	var hit := space.intersect_ray(q2)
	if hit.is_empty():
		return false
	var top: Vector3 = hit.position + Vector3.UP * 0.05
	# If the ledge is high enough to hang from, don't vault — let the ledge-grab handle it
	if top.y - global_position.y > 1.2:
		return false 
	# Do a smooth hop via velocity, so physics stays clean
	velocity.y = jump_force * 1.05
	var side_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if abs(side_x) > 0.5:
		velocity += transform.basis.x * sign(side_x) * vault_side_impulse
		_fov_kick = fov_kick_vault
	_recoil_pitch = deg_to_rad(-3.0)
	return true
	
	# ---------------- LEDGE HANG ----------------
func _try_ledge_grab() -> bool:
	if _grab_cooldown > 0.0:
		return false
	if velocity.y > 8.0:
		return false


	var space := get_world_3d().direct_space_state
	var forward := -transform.basis.z

	# High probe: is there NO wall at very top of reach? (means ledge top is below reach)
	var high_from := global_position + Vector3.UP * hang_reach_height
	var high_to   := high_from + forward * 0.9
	var q_high := PhysicsRayQueryParameters3D.create(high_from, high_to)
	q_high.exclude = [self]
	if not space.intersect_ray(q_high).is_empty():
		return false  # wall is too tall — can't reach over it

	# Chest probe: is there a wall at grab height? (means something IS in front of us)
	var chest_from := global_position + Vector3.UP * (hang_reach_height - 0.5)
	var chest_to   := chest_from + forward * 0.9
	var q_chest := PhysicsRayQueryParameters3D.create(chest_from, chest_to)
	q_chest.exclude = [self]
	var chest_hit := space.intersect_ray(q_chest)
	if chest_hit.is_empty():
		return false

	# Downward probe: find the top of that wall from just past the high probe
	var down_from := high_from + forward * 0.7
	var down_to   := down_from + Vector3.DOWN * 0.8
	var q_down := PhysicsRayQueryParameters3D.create(down_from, down_to)
	q_down.exclude = [self]
	var top_hit := space.intersect_ray(q_down)
	if top_hit.is_empty():
		return false
	# Reject slopes: only grab near-flat ledges
	if (top_hit.normal as Vector3).dot(Vector3.UP) < 0.7:
		return false

	# Snap player to grip position
	var ledge_top: Vector3 = top_hit.position
	var wall_normal: Vector3 = chest_hit.normal
	_hang_normal = wall_normal
	is_hanging = true
	velocity = Vector3.ZERO

	# Position: head sits `hang_head_below_ledge` below top, body pushed off wall by grip_offset
	# Head is at global_position + Vector3.UP * 0.7 (from your scene), so player origin needs adjust.
	var head_local_y := 0.7  # matches Head node position in player.tscn
	var target_pos := ledge_top \
		+ wall_normal * hang_grip_offset \
		- Vector3.UP * (head_local_y + hang_head_below_ledge - (ledge_top.y - ledge_top.y)) \
		+ Vector3.UP * (-hang_head_below_ledge)
	# Simpler & correct: put player origin so that (origin.y + head_local_y) == ledge_top.y - hang_head_below_ledge
	target_pos = Vector3(
		ledge_top.x + wall_normal.x * hang_grip_offset,
		ledge_top.y - hang_head_below_ledge - head_local_y,
		ledge_top.z + wall_normal.z * hang_grip_offset
	)
	global_position = target_pos

	# Face the wall
	var look_dir := -Vector3(wall_normal.x, 0, wall_normal.z).normalized()
	if look_dir.length() > 0.01:
		var yaw := atan2(look_dir.x, look_dir.z) + PI
		rotation.y = yaw

	return true

func _process_hang(delta: float) -> void:
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_forward"):
		_climb_up()
		return

	# Stick in place, ignore gravity
	velocity = Vector3.ZERO

	# Shimmy left/right along the ledge (perpendicular to wall normal, on XZ plane)
	var side := Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	if abs(side) > 0.1:
		var along := _hang_normal.cross(Vector3.UP).normalized()
		var move_vec := along * side * shimmy_speed
		# Test if there's still a wall to grab in the new spot; if not, stop
		if _wall_still_there(move_vec * delta):
			global_position += move_vec * delta
		# else: silently block movement (edge of the ledge)

	# Climb up: W or Space
	if Input.is_action_just_pressed("jump") or Input.is_action_pressed("move_forward"):
		_climb_up()
		return

	# Drop off: Ctrl/slide or S
	if Input.is_action_just_pressed("slide") or Input.is_action_pressed("move_backward"):
		_drop_hang()

func _wall_still_there(offset: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var forward := -_hang_normal
	# Probe from head height (0.7 above origin), slightly below the ledge top
	var from := global_position + offset + Vector3.UP * 0.7 + Vector3.DOWN * (hang_head_below_ledge + 0.1)
	var to   := from + forward * 0.8
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [self]
	return not space.intersect_ray(q).is_empty()

func _climb_up() -> void:
	_hang_climbing = true
	_recoil_pitch = deg_to_rad(-4.0)
	var forward := -_hang_normal
	# Head sits at origin.y + 0.7, and we snapped so head is (hang_head_below_ledge) below top.
	# So the ledge top's world Y is:
	var ledge_top_y := global_position.y + 0.7 + hang_head_below_ledge
	# Capsule half-height is 0.9 → feet touch ledge_top when origin.y = ledge_top_y + 0.9
	var final_y := ledge_top_y + 0.95
	# Mid-point: straight up above current XZ, so we clear the lip first
	var mid := Vector3(global_position.x, final_y, global_position.z)
	# Then forward by ~0.7 to plant feet on top of the ledge
	var target := mid + forward * 0.7

	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "global_position", mid, hang_climb_duration * 0.5)
	tw.tween_property(self, "global_position", target, hang_climb_duration * 0.5)
	tw.tween_callback(func():
		is_hanging = false
		_hang_climbing = false
		velocity = Vector3.ZERO
		_grab_cooldown = 0.4)   # prevent instant re-grab

func _drop_hang() -> void:
	is_hanging = false
	_hang_climbing = false
	# Small backwards nudge so you don't instantly re-grab
	velocity = _hang_normal * 2.0 + Vector3.DOWN * 1.0
	
	# ---------------- CAMERA JUICE ----------------
func update_camera_juice(delta: float, on_floor: bool, sprinting: bool) -> void:
	var horiz_speed := Vector3(velocity.x, 0, velocity.z).length()

	# --- Head bob (only when grounded, moving, not sliding) ---
	var bob_target := Vector3.ZERO
	if on_floor and horiz_speed > 0.5 and not is_sliding and not is_hanging:
		var speed_ratio := clampf(horiz_speed / sprint_speed, 0.0, 1.2)
		var amp := bob_amplitude * speed_ratio
		var freq := bob_frequency * (0.7 + 0.5 * speed_ratio)
		_bob_time += delta * freq
		bob_target = Vector3(
			cos(_bob_time) * amp * 0.5,       # subtle side sway
			sin(_bob_time * 2.0) * amp,       # vertical bob (2x freq)
			0.0
		)
	else:
		_bob_time = lerp(_bob_time, 0.0, 4.0 * delta)

	# --- Landing dip (spring-back) ---
	# Detect landing frame: was airborne, now on floor, was falling fast
	if on_floor and not _prev_on_floor and _prev_velocity_y < -land_dip_threshold:
		var dip := absf(_prev_velocity_y) * 0.025
		_land_dip = clampf(dip, 0.05, land_dip_max)
		# Big landing = extra FOV punch (feels heavy)
		if dip > 0.15:
			_fov_kick = max(_fov_kick, 6.0)
	_land_dip = lerp(_land_dip, 0.0, 8.0 * delta)

	# --- Apply position offsets ---
	camera.position = _base_cam_pos + bob_target + Vector3(0, -_land_dip, 0)

	# --- Wall-run tilt (roll) ---
	camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(_tilt_target), 10.0 * delta)

	# --- Recoil pitch (vault / climb / hard land) ---
	camera.rotation.x = lerp(camera.rotation.x, _recoil_pitch, 10.0 * delta)
	_recoil_pitch = lerp(_recoil_pitch, 0.0, 6.0 * delta)

	# --- FOV: base + sprint + transient kicks ---
	var fov_target := fov_sprint if sprinting else fov_default
	fov_target += _fov_kick
	camera.fov = lerp(camera.fov, fov_target, 6.0 * delta)
	_fov_kick = lerp(_fov_kick, 0.0, 5.0 * delta)

	# --- Bookkeeping for next frame ---
	_prev_velocity_y = velocity.y
	_prev_on_floor = on_floor
