extends Node3D

@export var day_length_seconds := 240.0
@export var start_time := 0.30
@export var sun_path: NodePath
@export var env_path: NodePath

var sun: DirectionalLight3D
var env: WorldEnvironment
var t := 0.0

func _ready() -> void:
	t = start_time
	sun = get_node_or_null(sun_path) as DirectionalLight3D
	env = get_node_or_null(env_path) as WorldEnvironment
	if sun == null:
		push_error("DayNight: sun_path not set or doesn't point to a DirectionalLight3D (got: %s)" % sun_path)
		set_process(false); return
	if env == null:
		push_error("DayNight: env_path not set or doesn't point to a WorldEnvironment (got: %s)" % env_path)
		set_process(false); return

var sun_c   := [Color(1,0.65,0.45), Color(1,0.96,0.88), Color(1,0.55,0.30), Color(0.25,0.35,0.55)]
var sky_top := [Color(0.35,0.45,0.7), Color(0.35,0.55,0.85), Color(0.35,0.25,0.45), Color(0.02,0.03,0.08)]
var sky_hor := [Color(1,0.75,0.55), Color(0.85,0.9,1), Color(1,0.5,0.35), Color(0.05,0.06,0.12)]
var amb     := [0.35, 0.55, 0.35, 0.10]

func _process(dt: float) -> void:
	t = fposmod(t + dt / day_length_seconds, 1.0)
	sun.rotation = Vector3(-(t * TAU - PI*0.5), deg_to_rad(35), 0)
	var p := _phase()
	sun.light_color  = sun_c[p[0]].lerp(sun_c[p[1]], p[2])
	sun.light_energy = clamp(sin(t*TAU - PI*0.5)*1.2 + 0.4, 0.05, 1.4)
	var sky := env.environment.sky.sky_material as ProceduralSkyMaterial
	if sky:
		sky.sky_top_color        = sky_top[p[0]].lerp(sky_top[p[1]], p[2])
		sky.sky_horizon_color    = sky_hor[p[0]].lerp(sky_hor[p[1]], p[2])
		sky.ground_horizon_color = sky.sky_horizon_color.darkened(0.4)
	env.environment.ambient_light_energy = lerp(amb[p[0]], amb[p[1]], p[2])

func _phase() -> Array:
	if t < 0.20:  return [3,3,0.0]
	if t < 0.35:  return [3,0,(t-0.20)/0.15]
	if t < 0.50:  return [0,1,(t-0.35)/0.15]
	if t < 0.65:  return [1,1,0.0]
	if t < 0.80:  return [1,2,(t-0.65)/0.15]
	if t < 0.90:  return [2,3,(t-0.80)/0.10]
	return [3,3,0.0]
