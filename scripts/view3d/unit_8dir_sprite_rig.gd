class_name Unit8DirSpriteRig
extends Node3D

const FRIENDLY_ATLAS_PATH := "res://addons/godot4-asset-vault/tacplanshooter_hd/sprites/units_8dir/operative_carbine_8dir.png"
const HOSTILE_ATLAS_PATH := "res://addons/godot4-asset-vault/tacplanshooter_hd/sprites/units_8dir/opfor_enforcer_8dir.png"

@export var pixel_size: float = 0.0085
@export var y_offset: float = 1.05

var sprite: Sprite3D = null
var _facing_yaw_rad: float = 0.0
var _base_modulate: Color = Color.WHITE
var _flash_timer: float = 0.0

func _ready() -> void:
	if sprite == null:
		_ensure_sprite()

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		if sprite != null:
			sprite.modulate = Color(1.6, 0.45, 0.45, 1.0) if _flash_timer > 0.0 else _base_modulate

func configure(is_friendly: bool, tint: Color = Color.WHITE) -> bool:
	_ensure_sprite()
	_base_modulate = tint
	sprite.modulate = tint
	var atlas_path := FRIENDLY_ATLAS_PATH if is_friendly else HOSTILE_ATLAS_PATH
	if not ResourceLoader.exists(atlas_path):
		sprite.visible = false
		return false
	sprite.texture = load(atlas_path) as Texture2D
	sprite.visible = true
	return true

func update_from_sim(world_pos: Vector3, facing_yaw_rad: float, cam: Camera3D) -> void:
	global_position = world_pos
	_facing_yaw_rad = facing_yaw_rad
	if sprite == null or not sprite.visible or cam == null:
		return
	var cam_fwd := Vector2(cam.global_basis.z.x, cam.global_basis.z.z).normalized()
	var unit_fwd := Vector2(sin(_facing_yaw_rad), cos(_facing_yaw_rad)).normalized()
	var rel_angle := atan2(
		cam_fwd.x * unit_fwd.y - cam_fwd.y * unit_fwd.x,
		cam_fwd.x * unit_fwd.x + cam_fwd.y * unit_fwd.y
	)
	var sector := int(round(rad_to_deg(rel_angle) / 45.0))
	sprite.frame = posmod(sector, 8)

func trigger_hit_flash(duration: float = 0.12) -> void:
	_flash_timer = duration
	if sprite != null:
		sprite.modulate = Color(1.6, 0.45, 0.45, 1.0)

func _ensure_sprite() -> void:
	if sprite != null:
		return
	sprite = Sprite3D.new()
	sprite.name = "UnitSprite3D"
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.pixel_size = pixel_size
	sprite.position = Vector3(0.0, y_offset, 0.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	sprite.shaded = true
	add_child(sprite)
