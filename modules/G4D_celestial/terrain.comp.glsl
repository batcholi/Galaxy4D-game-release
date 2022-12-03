#include "common.inc.glsl"
#include "xenon/renderer/shaders/perlint.glsl"

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
	u32vec3 pos = u32vec3(normalizedPos * PLANET_BASE_RADIUS_INT + 2000000000.0);
	
	int32_t baseHeight = int32_t(PLANET_BASE_RADIUS_INT);
	
	u32vec3 warp = u32vec3(perlint64(pos, 800000, 3000000, 7), perlint64(pos, 800000, 3000000, 7), perlint64(pos, 800000, 3000000, 7));
	
	int32_t continents = int32_t(perlint64Ridged(pos + warp*2u, 30000000, 500000, 4) + perlint64Ridged(pos - warp*3u, 280000000, 700000, 3)) - 80000;
	int32_t bigMountains = int32_t(perlint64Ridged(pos + warp*2u, PLANET_HEIGHT_VARIATION_INT*8, PLANET_HEIGHT_VARIATION_INT/2, 5)) / 4 - 80000;
	int32_t smallMountains = int32_t(perlint32(pos + warp/10u, 25500, 2000, 3));
	
	int32_t heightInt = baseHeight
		+ continents
		+ bigMountains
		+ smallMountains
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
	uint32_t Xindex = currentIndex*3;
	uint32_t Yindex = currentIndex*3+1;
	uint32_t Zindex = currentIndex*3+2;
	
	void main() {
		#ifdef SHADER_COMPUTE_TERRAIN_NORMAL
			// Normal
			vec3 normal = ComputeNormal();
			normals[Xindex].normal = normal.x;
			normals[Yindex].normal = normal.y;
			normals[Zindex].normal = normal.z;
		#else
			// Vertex
			dvec3 posNorm = normalize((chunk.transform * dvec4(GetVertex(currentIndex), 1)).xyz);
			dvec3 finalPos = (chunk.inverseTransform * dvec4(posNorm * TerrainHeightMap(posNorm), 1)).xyz;
			vertices[Xindex].vertex = float(finalPos.x);
			vertices[Yindex].vertex = float(finalPos.y);
			vertices[Zindex].vertex = float(finalPos.z);
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
				normals[(computeSize*computeSize + skirtIndex) * 3 + 0].normal = 0.0f;
				normals[(computeSize*computeSize + skirtIndex) * 3 + 1].normal = 1.0f;
				normals[(computeSize*computeSize + skirtIndex) * 3 + 2].normal = 0.0f;
			}
		#endif
	}
#endif
