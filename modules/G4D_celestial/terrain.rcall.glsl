#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"

void main() {
	surface.color.rgb = vec3(224.0/255, 185.0/255, 120.0/255);
}
