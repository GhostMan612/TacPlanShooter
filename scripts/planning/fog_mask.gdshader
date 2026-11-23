shader_type canvas_item;

uniform sampler2D live_tex;
uniform sampler2D memory_tex;

void fragment() {
	vec4 live = texture(live_tex, UV);
	vec4 mem = texture(memory_tex, UV);
	if (live.r > 0.5) {
		COLOR = vec4(0.0);
	} else if (mem.r > 0.5) {
		COLOR = vec4(0.55, 0.45, 0.24, 0.50);
	} else {
		COLOR = vec4(0.10, 0.11, 0.14, 0.85);
	}
}
