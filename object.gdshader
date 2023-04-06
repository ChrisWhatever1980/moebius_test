shader_type spatial;
render_mode unshaded;

void fragment()
{
	vec4 world_normal = vec4(NORMAL, 1.0) * VIEW_MATRIX;
	world_normal = normalize((world_normal + 1.0) * 0.5);
	ALBEDO = world_normal.xyz;
}
