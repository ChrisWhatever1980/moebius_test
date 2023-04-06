shader_type spatial;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

uniform float noise_scale = 0.1;
uniform float noise_strength = 0.001;
uniform vec3 light_position;
uniform float line_density_vertical = 1000.0;
uniform float line_density_horizontal = 500.0;
uniform float line_density_diagonal = 500.0;

varying mat4 CAMERA;
varying vec3 LIGHTPOS;

void vertex()
{
	POSITION = vec4(VERTEX, 1.0);

	CAMERA = INV_VIEW_MATRIX;
	LIGHTPOS = light_position;
}

vec2 random(vec2 uv)
{
	uv = vec2( dot(uv, vec2(127.1,311.7) ), dot(uv, vec2(269.5,183.3) ) );
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float noise(vec2 uv, vec2 scale)
{
	vec2 uv_index = floor(uv * scale);
	vec2 uv_fract = fract(uv * scale);
	vec2 blur = smoothstep(0.0, 1.0, uv_fract);

	return mix( mix( dot( random(uv_index + vec2(0.0,0.0) ), uv_fract - vec2(0.0,0.0) ),
					dot( random(uv_index + vec2(1.0,0.0) ), uv_fract - vec2(1.0,0.0) ), blur.x),
				mix( dot( random(uv_index + vec2(0.0,1.0) ), uv_fract - vec2(0.0,1.0) ),
					dot( random(uv_index + vec2(1.0,1.0) ), uv_fract - vec2(1.0,1.0) ), blur.x), blur.y) + 0.5;
}

vec3 cross_hatch_vertical(vec2 uv, vec2 pixel_size)
{
	return vec3(step(sin(uv.x * line_density_vertical), 0.9));
}

vec3 cross_hatch_horizontal(vec2 uv, vec2 pixel_size)
{
	return vec3(step(sin(uv.y * line_density_horizontal), 0.9));
}

vec3 cross_hatch_diagonal(vec2 uv, vec2 pixel_size)
{
	return vec3(step(sin((uv.x + uv.y) * line_density_diagonal), 0.9));
}

void fragment( )
{
	vec3 normal = normalize(texture(SCREEN_TEXTURE, SCREEN_UV).xyz * 2.0 - 1.0);

	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 world = CAMERA * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world_position = world.xyz / world.w;

	// diffuse
	vec3 lightDir = normalize(world_position - LIGHTPOS);
	float diffuse = max(dot(normal, lightDir), 0.0);

	// specular
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 reflect_dir = reflect(-lightDir, normal);
	float spec = pow(max(dot(view_dir, reflect_dir), 0.0), 32);
	vec3 specular = vec3(0.2 * spec);

	// compute sobel kernel
	vec2 SCREEN_PIXEL_SIZE = 1.0 / VIEWPORT_SIZE;
	vec3 normal_pix[9];
	vec3 depth_pix[9];
	for( int y=0; y<3; y ++ ) {
		for( int x=0; x<3; x ++ ) {
			vec2 noisy_uv = SCREEN_UV + (noise(SCREEN_UV, noise_scale * VIEWPORT_SIZE) * 2.0 - 1.0) * noise_strength;
			//vec3 normal = gaussian5x5( SCREEN_TEXTURE, noisy_uv + vec2( float( x-1 ), float( y-1 ) ) * SCREEN_PIXEL_SIZE, SCREEN_PIXEL_SIZE );
			vec3 normal = texture(SCREEN_TEXTURE, noisy_uv + vec2(float(x - 1), float(y - 1)) * SCREEN_PIXEL_SIZE).xyz;
			normal_pix[y * 3 + x] = normal;// * 2.0 - 1.0;
			vec3 depth = texture(DEPTH_TEXTURE, noisy_uv + vec2(float(x - 1), float(y - 1)) * SCREEN_PIXEL_SIZE).xyz;
			depth_pix[y * 3 + x] = depth;
		}
	}

	// Apply Sobel kernel
	vec3 normal_sobel_src_x = (normal_pix[0] * -1.0 + normal_pix[3] * -2.0 + normal_pix[6] * -1.0 + normal_pix[2] * 1.0 + normal_pix[5] * 2.0 + normal_pix[8] * 1.0);
	vec3 depth_sobel_src_x = (depth_pix[0] * -1.0 + depth_pix[3] * -2.0 + depth_pix[6] * -1.0 + depth_pix[2] * 1.0 + depth_pix[5] * 2.0 + depth_pix[8] * 1.0);

	vec3 normal_sobel_src_y = (normal_pix[0] * -1.0 + normal_pix[1] * -2.0 + normal_pix[2] * -1.0 + normal_pix[6] * 1.0 + normal_pix[7] * 2.0 + normal_pix[8] * 1.0);
	vec3 depth_sobel_src_y = (depth_pix[0] * -1.0 + depth_pix[1] * -2.0 + depth_pix[2] * -1.0 + depth_pix[6] * 1.0 + depth_pix[7] * 2.0 + depth_pix[8] * 1.0);

	vec3 normal_sobel = sqrt( normal_sobel_src_x * normal_sobel_src_x + normal_sobel_src_y * normal_sobel_src_y );
	vec3 depth_sobel = sqrt( depth_sobel_src_x * depth_sobel_src_x + depth_sobel_src_y * depth_sobel_src_y );

	// write fragment
	vec3 sobel = vec3(1.0 - max(step(0.5, length(normal_sobel)), step(0.1, length(depth_sobel))));
	ALBEDO = vec3(diffuse);

	vec2 noisy_uv = SCREEN_UV + (noise(SCREEN_UV, 0.1 * VIEWPORT_SIZE) * 2.0 - 1.0) * 0.001;
	if (diffuse >= 0.8)
		ALBEDO = vec3(min(sobel, 1.0));
	else if (diffuse >= 0.5)
		ALBEDO = vec3(min(sobel, cross_hatch_diagonal(noisy_uv, SCREEN_PIXEL_SIZE)));
	else if (diffuse >= 0.2)
	{
		vec3 ch = min(cross_hatch_vertical(noisy_uv, SCREEN_PIXEL_SIZE), 
			cross_hatch_diagonal(noisy_uv, SCREEN_PIXEL_SIZE));
		ALBEDO = vec3(min(sobel, ch));
	}
	else
	{
		vec3 ch = min(cross_hatch_vertical(noisy_uv, SCREEN_PIXEL_SIZE), 
			min(cross_hatch_diagonal(noisy_uv, SCREEN_PIXEL_SIZE), 
			cross_hatch_horizontal(noisy_uv, SCREEN_PIXEL_SIZE)));
		ALBEDO = vec3(min(sobel, ch));
	}

	ALBEDO = vec3(specular);
}