#include "common.inc.glsl"
#include "xenon/renderer/shaders/perlint.glsl"

#define KM *TERRAIN_INT_MULTIPLIER*1000

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
	u64vec3 pos = u64vec3(normalizedPos * PLANET_BASE_RADIUS_INT + 200000000000.0);
	
	u64vec3 warp = u64vec3(perlint64(pos + uint64_t(65464915), 100 KM, 200 KM, 8), perlint64(pos + uint64_t(516556), 100 KM, 200 KM, 8), perlint64(pos - uint64_t(8971178), 100 KM, 200 KM, 8));
	
	int64_t continents = int64_t(
		+perlint64Ridged(pos + warp, 2000 KM, uint64_t(PLANET_HEIGHT_VARIATION_INT), 3)*2u
		-perlint64(pos + warp, 2000 KM, uint64_t(PLANET_HEIGHT_VARIATION_INT) / 4u, 3)
		-PLANET_HEIGHT_VARIATION_INT/3u
	);
	int64_t bigMountains = int64_t(perlint64(pos + warp + uint64_t(622349564), uint64_t(PLANET_HEIGHT_VARIATION_INT), uint64_t(PLANET_HEIGHT_VARIATION_INT)/8, 8))/2;
	
	int64_t heightInt = 
		+ continents
		+ bigMountains
	;
	
	// Clamp
	heightInt = int64_t(PLANET_BASE_RADIUS_INT) + clamp(heightInt, int64_t(0), int64_t(PLANET_HEIGHT_VARIATION_INT));
	
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
			double height = TerrainHeightMap(posNorm);
			dvec3 finalPos = (chunk.inverseTransform * dvec4(posNorm * height, 1)).xyz;
			vertices[Xindex].vertex = float(finalPos.x);
			vertices[Yindex].vertex = float(finalPos.y);
			vertices[Zindex].vertex = float(finalPos.z);
			colors[currentIndex].color = vec4(vec3((height - double(chunk.baseRadiusInt)/TERRAIN_INT_MULTIPLIER) / double(PLANET_HEIGHT_VARIATION_INT) * TERRAIN_INT_MULTIPLIER), 1);
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
