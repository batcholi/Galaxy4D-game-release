#include "common.inc.glsl"
#include "xenon/renderer/shaders/GradUint.glsl"

#ifdef GLSL
	#define PLANET_BASE_RADIUS_INT chunk.baseRadiusInt
	#define PLANET_HEIGHT_VARIATION_INT chunk.heightVariationInt
double TerrainHeightMap(dvec3 normalizedPos)
#else
	#define PLANET_BASE_RADIUS_INT (terrainRadius * TERRAIN_INT_MULTIPLIER)
	#define PLANET_HEIGHT_VARIATION_INT (terrainHeightVariation * TERRAIN_INT_MULTIPLIER)
static double TerrainHeightMap(const dvec3& normalizedPos, double terrainRadius, double terrainHeightVariation)
#endif
/*double TerrainHeightMap(normalizedPos)*/{
	UVEC3 pos = UVEC3(normalizedPos * PLANET_BASE_RADIUS_INT + 2000000000.0);
	
	INT baseHeight = INT(PLANET_BASE_RADIUS_INT + PLANET_HEIGHT_VARIATION_INT);
	
	UVEC3 warp = UVEC3(GradUint(pos, 65000, 65000, 8), GradUint(pos, 65000, 65000, 8), GradUint(pos, 65000, 65000, 8));
	
	INT mountains = INT(RidgedGradUint(pos + warp, 100000, 10000, 4));
	INT detail = INT(GradUint(pos, 400, 160, 4));
	
	INT heightInt = baseHeight
		+ mountains
		+ detail
	;
	return double(heightInt) / double(TERRAIN_INT_MULTIPLIER);
}

#ifdef GLSL
	#extension GL_EXT_buffer_reference2 : require

	layout(local_size_x = COMPUTE_SIZE_X, local_size_y = COMPUTE_SIZE_Y) in;
	
	vec3 GetVertex(in uint index) {
		return vec3(vertices[index*3].vertex, vertices[index*3+1].vertex, vertices[index*3+2].vertex);
	}
	
	uint32_t computeSize = gl_NumWorkGroups.x*gl_WorkGroupSize.x;
	uint32_t vertexSubdivisionsPerChunk = computeSize - 1;
	uint32_t genCol = gl_GlobalInvocationID.x;
	uint32_t genRow = gl_GlobalInvocationID.y;
	uint32_t currentIndex = computeSize * genRow + genCol;
	uint32_t Yindex = currentIndex*3+1;
	
	void main() {
		// #ifdef SHADER_COMPUTE_TERRAIN_NORMAL
		// 	// Normal
		// 	vec3 normal = ComputeNormal();
		// 	normals[currentIndex*3].normal = normal.x;
		// 	normals[currentIndex*3+1].normal = normal.y;
		// 	normals[currentIndex*3+2].normal = normal.z;
		// #else
			// Vertex
			dvec3 posNorm = normalize((chunk.transform * dvec4(GetVertex(currentIndex), 1)).xyz);
			dvec3 finalPos = (chunk.inverseTransform * dvec4(posNorm * TerrainHeightMap(posNorm), 1)).xyz;
			vertices[Yindex].vertex = float(finalPos.y);
			// Skirt
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
				// normals[(computeSize*computeSize + skirtIndex) * 3 + 0].normal = 0.0f;
				// normals[(computeSize*computeSize + skirtIndex) * 3 + 1].normal = 1.0f;
				// normals[(computeSize*computeSize + skirtIndex) * 3 + 2].normal = 0.0f;
			}
		// #endif
	}
#endif
