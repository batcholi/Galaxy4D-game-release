#include "common.inc.glsl"
#include "xenon/renderer/shaders/GradUint.glsl"

#ifdef GLSL
	#define PLANET_BASE_RADIUS_MM chunk.baseRadiusMm
	#define PLANET_HEIGHT_VARIATION_MM chunk.heightVariationMm
double TerrainHeightMap(dvec3 normalizedPos)
#else
	#define PLANET_BASE_RADIUS_MM (terrainRadius * 1000.0)
	#define PLANET_HEIGHT_VARIATION_MM (terrainHeightVariation * 1000.0)
static double TerrainHeightMap(const dvec3& normalizedPos, double terrainRadius, double terrainHeightVariation)
#endif
/*double TerrainHeightMap(normalizedPos)*/{
	UVEC3 pos = UVEC3(normalizedPos * PLANET_BASE_RADIUS_MM + 20000000000.0);
	
	INT baseHeight = INT(PLANET_BASE_RADIUS_MM);
	
	UVEC3 warp = UVEC3(GradUint(pos, 20000000, 20000000, 8), GradUint(pos, 20000000, 20000000, 8), GradUint(pos, 20000000, 20000000, 8));
	
	INT mountains = INT(RidgedGradUint(pos + warp, UINT(PLANET_HEIGHT_VARIATION_MM*8), UINT(PLANET_HEIGHT_VARIATION_MM/2), 24));
	INT detail = INT(GradUint(pos + warp, 600, 200, 3));
	
	INT heightMm = baseHeight
		+ mountains
		+ detail
	;
	return double(heightMm) / 1000.0;
}

#ifdef GLSL
	#extension GL_EXT_buffer_reference2 : require

	layout(local_size_x = COMPUTE_SIZE_X, local_size_y = COMPUTE_SIZE_Y) in;

	void main() {
		uint32_t computeSize = gl_NumWorkGroups.x*gl_WorkGroupSize.x;
		uint32_t vertexSubdivisionsPerChunk = computeSize - 1;
		uint32_t genCol = gl_GlobalInvocationID.x;
		uint32_t genRow = gl_GlobalInvocationID.y;
		uint32_t currentIndex = computeSize * genRow + genCol;
		uint32_t Xindex = currentIndex*3;
		uint32_t Yindex = currentIndex*3+1;
		uint32_t Zindex = currentIndex*3+2;
		
		dvec3 posNorm = normalize((chunk.transform * dvec4(vertices[Xindex].vertex, vertices[Yindex].vertex, vertices[Zindex].vertex, 1)).xyz);
		dvec3 finalPos = (chunk.inverseTransform * dvec4(posNorm * TerrainHeightMap(posNorm), 1)).xyz;
		vertices[Yindex].vertex = float(finalPos.y);
		
		int32_t skirtIndex = -1;
		if (genCol == 0) {
			skirtIndex = int(genRow);
		} else if (genCol == vertexSubdivisionsPerChunk) {
			skirtIndex = int(vertexSubdivisionsPerChunk*4 - vertexSubdivisionsPerChunk - genRow);
		} else if (genRow == 0) {
			skirtIndex = int(vertexSubdivisionsPerChunk*4 - genCol);
		} else if (genRow == vertexSubdivisionsPerChunk) {
			skirtIndex = int(vertexSubdivisionsPerChunk + genCol);
		}
		if (skirtIndex != -1) {
			vertices[(computeSize*computeSize + skirtIndex) * 3 + 1].vertex = vertices[Yindex].vertex - chunk.skirtOffset;
		}
	}
#endif
