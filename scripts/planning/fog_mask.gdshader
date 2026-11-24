shader_type canvas_item;

uniform sampler2D live_tex;
uniform sampler2D memory_tex;
uniform vec4 unseen_color = vec4(0.04, 0.06, 0.08, 0.85);
uniform vec4 memory_color = vec4(0.04, 0.06, 0.08, 0.5);

void fragment() {
	vec4 live = texture(live_tex, UV);
	vec4 mem = texture(memory_tex, UV);
	if (live.a > 0.5) {
		COLOR = vec4(0.0);
	} else if (mem.a > 0.5) {
		COLOR = memory_color;
	} else {
		COLOR = unseen_color;
	}
}
