#define SHADER_COMP
#include "common.inc.glsl"

layout(local_size_x = TERRAIN_TILE_COMPUTE_LOCAL_X, local_size_y = TERRAIN_TILE_COMPUTE_LOCAL_Y) in;

void main() {
	if (uint64_t(activeChunks) == 0) return;
	ivec2 computeCoord = ivec2(gl_GlobalInvocationID.xy) + 1;
	if (computeCoord.x < 127 && computeCoord.y < 127) {
		if (activeChunks.chunks[computeCoord.x][computeCoord.y] == 1) {
			uint index = (computeCoord.y + 66) * tileData.tileResolution + computeCoord.x + 66;
			if (true
			 && activeChunks.chunks[computeCoord.x  ][computeCoord.y+1] == 1
			 && activeChunks.chunks[computeCoord.x  ][computeCoord.y-1] == 1
			 && activeChunks.chunks[computeCoord.x-1][computeCoord.y  ] == 1
			 && activeChunks.chunks[computeCoord.x+1][computeCoord.y  ] == 1
			 && activeChunks.chunks[computeCoord.x+1][computeCoord.y+1] == 1
			 && activeChunks.chunks[computeCoord.x-1][computeCoord.y-1] == 1
			 && activeChunks.chunks[computeCoord.x-1][computeCoord.y+1] == 1
			 && activeChunks.chunks[computeCoord.x+1][computeCoord.y-1] == 1
			) {
				vertexBuffer.vertices[index * 3 + 1] = 0;
			} else {
				vertexBuffer.vertices[index * 3 + 1] -= 8;
			}
		}
	}
}
