#include "common.inc.glsl"
#include "xenon/renderer/shaders/GradUint.glsl"

#ifdef GLSL
	#define PLANET_BASE_RADIUS_CM chunk.baseRadiusCm
	#define PLANET_HEIGHT_VARIATION_CM chunk.heightVariationCm
double TerrainHeightMap(dvec3 normalizedPos)
#else
	#define PLANET_BASE_RADIUS_CM (terrainRadius * 100.0)
	#define PLANET_HEIGHT_VARIATION_CM (terrainHeightVariation * 100.0)
static double TerrainHeightMap(const dvec3& normalizedPos, double terrainRadius, double terrainHeightVariation)
#endif
/*double TerrainHeightMap(normalizedPos)*/{
	uvec3 pos = uvec3(normalizedPos * PLANET_BASE_RADIUS_CM + 800000000.0);
	
	int32_t baseHeight = int32_t(PLANET_BASE_RADIUS_CM + PLANET_HEIGHT_VARIATION_CM);
	
	uvec3 warp = uvec3(GradUint(pos, 20000, 10000, 2), GradUint(pos, 30000, 10000, 2), GradUint(pos, 40000, 10000, 2));
	int32_t mountains = int(GradUint(pos/9u + warp, 20000, 20000, 16));
	int32_t canyons = 0;// 512 - int(RidgedGradUint(pos, 1024, 1024));
	
	int32_t detail = int(GradUint(pos, 8, 8));
	
	int32_t heightCm = baseHeight + mountains - canyons + detail;
	return double(heightCm) / 100.0;
}

#ifdef GLSL
	#extension GL_EXT_buffer_reference2 : require

	layout(local_size_x = COMPUTE_SIZE_X, local_size_y = COMPUTE_SIZE_Y) in;

	void main() {
		uint32_t genRow = gl_GlobalInvocationID.x;
		uint32_t genCol = gl_GlobalInvocationID.y;
		uint32_t currentIndex = gl_NumWorkGroups.x*gl_WorkGroupSize.x * genRow + genCol;
		uint32_t Xindex = currentIndex*3;
		uint32_t Yindex = currentIndex*3+1;
		uint32_t Zindex = currentIndex*3+2;
		dvec3 posNorm = normalize((chunk.transform * dvec4(vertices[Xindex].vertex, vertices[Yindex].vertex, vertices[Zindex].vertex, 1)).xyz);
		dvec3 finalPos = (chunk.inverseTransform * dvec4(posNorm * TerrainHeightMap(posNorm), 1)).xyz;
		vertices[Yindex].vertex = float(finalPos.y);
	}
#endif
