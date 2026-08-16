shader_type canvas_item;
render_mode blend_add;

// Drives the whole animation - 0 at the instant of detonation, 1 once the
// ring has fully expanded and faded. Animated externally by
// shockwave_vfx.gd via a Tween, not by TIME, so its speed is easy to tune
// from one place (duration) without touching the shader.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ring_color : source_color = vec4(1.0, 0.65, 0.15, 1.0);
uniform float ring_width : hint_range(0.01, 0.5) = 0.12;

// The sprite this shader is attached to only exists to give the quad a size
// and UVs to work with - TEXTURE is never sampled, COLOR is built entirely
// from distance-from-center, so the source texture's own pixels never show.
void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0; // 0 at center, 1 at the quad's edge

	// The ring itself: a thin band that expands outward with progress and
	// thins/fades as it goes, reading as a shockwave sweeping outward.
	float dist_from_ring = abs(dist - progress);
	float ring = smoothstep(ring_width, 0.0, dist_from_ring) * (1.0 - progress);

	// A bright core flash at the moment of detonation, gone within the
	// first quarter of the animation.
	float flash = smoothstep(0.4, 0.0, dist) * smoothstep(0.25, 0.0, progress);

	float alpha = clamp(ring + flash, 0.0, 1.0);
	COLOR = vec4(ring_color.rgb, alpha * ring_color.a);
}
