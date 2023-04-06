extends Node3D


var fullscreen_mat


# Called when the node enters the scene tree for the first time.
func _ready():
	fullscreen_mat = $CameraRotate/Camera3D/FullscreenQuad.get_active_material(0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	fullscreen_mat.set_shader_parameter("light_position", $LightRotate/DirectionalLight3D.global_position);
	pass
