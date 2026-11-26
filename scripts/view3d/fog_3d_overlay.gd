# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name Fog3DOverlay
extends Node3D


const CELL_UNITS: float = 1.5
const FLOOR_RISE: float = 3.2
const SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D live_tex;
uniform sampler2D memory_tex;
uniform float fog_strength = 1.0;
uniform vec3 fog_color : source_color = vec3(0.02, 0.04, 0.07);
void fragment() {
	float live = texture(live_tex, UV).r;
	float memory = texture(memory_tex, UV).r;
	float seen = max(live, memory * 0.5);
	ALBEDO = fog_color;
	ALPHA = (1.0 - seen) * fog_strength * 0.86;
}
"""


var plane: MeshInstance3D = null
var material: ShaderMaterial = null


func _ready() -> void:
	var sh := Shader.new()
	sh.code = SHADER_CODE
	material = ShaderMaterial.new()
	material.shader = sh
	plane = MeshInstance3D.new()
	plane.name = "FogProjection"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.0, 1.0)
	plane.mesh = pm
	plane.material_override = material
	add_child(plane)


func configure(fog: FogLayer, m: GreyboxMap, floor: int) -> void:
	if fog == null or fog.live_vp == null or fog.memory_vp == null or plane == null:
		return
	material.set_shader_parameter("live_tex", fog.live_vp.get_texture())
	material.set_shader_parameter("memory_tex", fog.memory_vp.get_texture())
	var w := float(m.width_cells) * CELL_UNITS
	var h := float(m.height_cells) * CELL_UNITS
	plane.scale = Vector3(w, h, 1.0)
	plane.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	plane.position = Vector3(w * 0.5, float(floor) * FLOOR_RISE + 0.05, h * 0.5)
