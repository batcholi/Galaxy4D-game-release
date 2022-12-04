#define SHADER_COMPUTE_TERRAIN_NORMAL
vec3 ComputeNormal();
#include "terrain.comp.glsl"

vec3 ComputeNormal() {
	vec3 currentVertex = GetVertex(currentIndex);
	dvec3 posNormRight = normalize((chunk.transform * dvec4(currentVertex + vec3(chunk.triangleSize,0,0), 1)).xyz);
	dvec3 posNormBottom = normalize((chunk.transform * dvec4(currentVertex + vec3(0,0,chunk.triangleSize), 1)).xyz);
	vec3 right = vec3((chunk.inverseTransform * dvec4(posNormRight * TerrainHeightMap(posNormRight), 1)).xyz);
	vec3 bottom = vec3((chunk.inverseTransform * dvec4(posNormBottom * TerrainHeightMap(posNormBottom), 1)).xyz);
	return cross(normalize(right - currentVertex), normalize(currentVertex - bottom));
}
