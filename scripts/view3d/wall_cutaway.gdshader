shader_type spatial;
render_mode cull_back, blend_mix;

uniform vec3 wall_tint : source_color = vec3(0.12, 0.17, 0.24);
uniform vec3 plate_tint : source_color = vec3(0.10, 0.15, 0.21);
uniform float waist_height = 0.45;
uniform float wall_height = 2.6;

varying float v_cutaway;
varying vec3 v_world;
uniform vec3 focus_pos = vec3(0.0, 0.0, 0.0);

void vertex() {
	v_cutaway = INSTANCE_CUSTOM.x;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = UV.y * wall_height;
	float alpha = 1.0;
	if (v_cutaway > 0.5) {
		alpha = mix(0.10, 1.0, smoothstep(waist_height - 0.2, waist_height + 0.2, h));
		float near_focus = 1.0 - smoothstep(1.2, 3.6, length(v_world.xz - focus_pos.xz));
		alpha = min(alpha, mix(1.0, 0.16, near_focus));
	}
	ALBEDO = mix(plate_tint, wall_tint, v_cutaway);
	ALPHA = alpha;
}
