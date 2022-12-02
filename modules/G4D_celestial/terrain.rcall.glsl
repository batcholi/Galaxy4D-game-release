#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"
#include "xenon/renderer/shaders/perlint.glsl"

float BumpMap(vec3 pos) {
	return SimplexFractal(pos*5, 4) + abs(SimplexFractal(pos*0.2, 3)) * 10;
}

void main() {
	surface.color.rgb = vec3(224.0/255, 185.0/255, 120.0/255);
	if (surface.distance < 500) {
		float strength = 0.003 * smoothstep(500, 0, surface.distance);
		APPLY_NORMAL_BUMP_NOISE(BumpMap, surface.localPosition, surface.normal, strength)
	}
}
