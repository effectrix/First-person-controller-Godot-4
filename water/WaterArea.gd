extends Area3D


@export var buoyancy_strength: float = 15
@export var viscosity: int = 2

var _bodies_in_water: int = 0
var _rigid_body_surface_offset: float = 0.5
@onready var surface_mesh: MeshInstance3D = $MeshInstance3D as MeshInstance3D



func _init() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var collided_bodies: Array = get_overlapping_bodies()
	for body in collided_bodies:
		if body is RigidBody3D:
			var submerged_depth: float = body.global_transform.origin.y - surface_mesh.global_transform.origin.y - _rigid_body_surface_offset
			if submerged_depth < 0.0:
				body.apply_central_force(Vector3.UP * buoyancy_strength * abs(submerged_depth))# * _buoyancy_variation[randi() % _buoyancy_variation.size()])
				body.apply_central_force(body.linear_velocity * -1 * viscosity)
				body.apply_torque(body.angular_velocity * -1 * viscosity)

		if body is Player:
			var player_head: Node3D = body.head
			var submerged_depth: float = player_head.global_transform.origin.y - surface_mesh.global_transform.origin.y
			
			if submerged_depth < 0.0:
				body.gravity_vec = lerp(body.gravity_vec, Vector3.UP * abs(submerged_depth), 2 * delta)
				body.is_underwater = true
			
			elif submerged_depth > 0.2 and submerged_depth < 1.0:
				if !body.is_in_water:
					body.is_in_water = true
				body.is_underwater = false
				body.apply_gravity(delta, body.ACCEL_IN_WATER, 0.33)
			
			elif submerged_depth > 1.0:
				body.is_underwater = false
				body.is_in_water = false


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if !is_physics_processing():
			set_physics_process(true)
		body.is_in_water = true
		_bodies_in_water += 1
	if body is RigidBody3D:
		if !is_physics_processing():
			set_physics_process(true)
		_bodies_in_water += 1


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		body.is_in_water = false
		_bodies_in_water -= 1
	if body is RigidBody3D:
		_bodies_in_water -= 1
	if _bodies_in_water <= 0:
		set_physics_process(false)
