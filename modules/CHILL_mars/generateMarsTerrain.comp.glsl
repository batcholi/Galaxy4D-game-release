#define SHADER_COMP
#include "common.inc.glsl"

layout(local_size_x = TERRAIN_TILE_COMPUTE_LOCAL_X, local_size_y = TERRAIN_TILE_COMPUTE_LOCAL_Y) in;

void main() {
	ivec2 computeCoord = ivec2(gl_GlobalInvocationID.xy);
	uint index = computeCoord.y * tileData.tileResolution + computeCoord.x;
	vec2 texSizePixels = textureSize(textures[tileData.textureIndex], 0);
	vec2 coordPixels = vec2(computeCoord) * tileData.tileSizeMultiplier + tileData.mapOffset.xz / float(tileData.metersPerPixel);
	vec2 uv = (coordPixels + 0.5) / texSizePixels + 0.5;
	float height = texture(textures[tileData.textureIndex], uv).r;
	
	vec2 posDiff = (playerPosition.xz - coordPixels * tileData.metersPerPixel);
	float distSqr = dot(posDiff,posDiff);
	float roundness = distSqr * 0.000001;
	
	vertexBuffer.vertices[index * 3 + 0] = computeCoord.x * tileData.metersPerPixel * tileData.tileSizeMultiplier;
	vertexBuffer.vertices[index * 3 + 1] = (height * tileData.heightVariation - tileData.mapOffset.y - roundness);
	vertexBuffer.vertices[index * 3 + 2] = computeCoord.y * tileData.metersPerPixel * tileData.tileSizeMultiplier;
}
