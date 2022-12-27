#extension GL_EXT_ray_tracing : require

#define SHADER_VOXEL_SURFACE
#include "game/graphics/common.inc.glsl"
#include "game/graphics/voxel.inc.glsl"

void main() {

	// Dirt texture
	voxelSurface.color = SampleTexture(0) * vec4(0.9, 0.45, 0.40, 1);
	
}
