# Scenario-independent CRT overlay: a CanvasLayer high above everything with
# a full-rect ColorRect running crt_overlay.gdshader (scanlines + vignette).
# Purely decorative — the rect ignores the mouse, so it never swallows input.
# Instance it once per scenario scene; tune the exports per scenario if a
# phase needs a stronger or weaker effect.
class_name CRTOverlay
extends CanvasLayer

@export_range(0.0, 0.3) var scanline_alpha := 0.07:
	set(value):
		scanline_alpha = value
		_apply_uniforms()

@export_range(60.0, 1080.0) var scanline_count := 360.0:
	set(value):
		scanline_count = value
		_apply_uniforms()

@export_range(0.0, 0.6) var vignette_alpha := 0.22:
	set(value):
		vignette_alpha = value
		_apply_uniforms()

@export_range(0.0, 0.7) var vignette_start := 0.42:
	set(value):
		vignette_start = value
		_apply_uniforms()

@onready var _rect: ColorRect = $Overlay


func _ready() -> void:
	_apply_uniforms()


func _apply_uniforms() -> void:
	if _rect == null:
		return
	var mat := _rect.material as ShaderMaterial
	if mat == null:
		push_error("CRTOverlay: Overlay rect has no ShaderMaterial")
		return
	mat.set_shader_parameter("scanline_alpha", scanline_alpha)
	mat.set_shader_parameter("scanline_count", scanline_count)
	mat.set_shader_parameter("vignette_alpha", vignette_alpha)
	mat.set_shader_parameter("vignette_start", vignette_start)
