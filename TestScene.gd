extends Node3D


func _ready() -> void:
	$Player.state_changed.connect($StateDebug.on_Player_state_changed)
