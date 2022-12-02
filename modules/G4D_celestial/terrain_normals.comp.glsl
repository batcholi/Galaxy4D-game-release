#define SHADER_COMPUTE_TERRAIN_NORMAL
vec3 ComputeNormal();
#include "terrain.comp.glsl"

vec3 ComputeNormal() {
	vec3 currentVertex = GetVertex(currentIndex);
	vec3 tangentX, tangentY;
	
	if (genRow < vertexSubdivisionsPerChunk && genCol < vertexSubdivisionsPerChunk) {
		// For full face (generate top left)
		uint32_t topLeftIndex = currentIndex;
		uint32_t topRightIndex = topLeftIndex+1;
		uint32_t bottomLeftIndex = (vertexSubdivisionsPerChunk+1) * (genRow+1) + genCol;
		tangentX = normalize(GetVertex(topRightIndex) - currentVertex);
		tangentY = normalize(currentVertex - GetVertex(bottomLeftIndex));
	} else if (genCol > 0 && genRow > 0) {
			// Bottom Right
			
			// 	dvec3 topOffset = mix(chunk->topLeft - chunk->center, chunk->bottomLeft - chunk->center, double(genRow+1)/vertexSubdivisionsPerChunk);
			// 	dvec3 rightOffset = mix(chunk->topLeft - chunk->center, chunk->topRight - chunk->center, double(genCol)/vertexSubdivisionsPerChunk);
			// 	dvec3 pos = Spherify(chunk->center + topDir*topOffset + rightDir*rightOffset, chunk->face);
			// 	vec3 bottomLeftPos = chunk->inverseTransform * dvec4{pos * chunk->celestial->GetTerrainHeightAtPos(pos), 1};

			// 	dvec3 topOffset = mix(chunk->topLeft - chunk->center, chunk->bottomLeft - chunk->center, double(genRow)/vertexSubdivisionsPerChunk);
			// 	dvec3 rightOffset = mix(chunk->topLeft - chunk->center, chunk->topRight - chunk->center, double(genCol+1)/vertexSubdivisionsPerChunk);
			// 	dvec3 pos = Spherify(chunk->center + topDir*topOffset + rightDir*rightOffset, chunk->face);
			// 	vec3 topRightPos = chunk->inverseTransform * dvec4{pos * chunk->celestial->GetTerrainHeightAtPos(pos), 1};
			
			// tangentX = normalize(topRightPos - currentVertex);
			// tangentY = normalize(currentVertex - bottomLeftPos);
			
			uint32_t topIndex = currentIndex - vertexSubdivisionsPerChunk - 1;
			uint32_t leftIndex = currentIndex - 1;
			tangentX = normalize(currentVertex - GetVertex(leftIndex));
			tangentY = normalize(GetVertex(topIndex) - currentVertex);
			
	} else if (genCol == 0) {
			// Right Col
			
			// uint32_t bottomRightIndex = currentIndex+vertexSubdivisionsPerChunk+1;
			
			// 	dvec3 topOffset = mix(chunk->topLeft - chunk->center, chunk->bottomLeft - chunk->center, double(genRow)/vertexSubdivisionsPerChunk);
			// 	dvec3 rightOffset = mix(chunk->topLeft - chunk->center, chunk->topRight - chunk->center, double(genCol+1)/vertexSubdivisionsPerChunk);
			// 	dvec3 pos = Spherify(chunk->center + topDir*topOffset + rightDir*rightOffset, chunk->face);
			// 	vec3 topRightPos = chunk->inverseTransform * dvec4{pos * chunk->celestial->GetTerrainHeightAtPos(pos), 1};

			// tangentX = normalize(topRightPos - currentVertex);
			// tangentY = normalize(currentVertex - GetVertex(bottomRightIndex));
			
			// uint32_t topIndex = currentIndex - vertexSubdivisionsPerChunk - 1;
			// uint32_t leftIndex = currentIndex - 1;
			// tangentX = normalize(currentVertex - GetVertex(leftIndex));
			// tangentY = normalize(GetVertex(topIndex) - currentVertex);
			
			return vec3(0,1,0);
			
	} else if (genRow == 0) {
			// Bottom Row
			
			// 	dvec3 topOffset = mix(chunk->topLeft - chunk->center, chunk->bottomLeft - chunk->center, double(genRow+1)/vertexSubdivisionsPerChunk);
			// 	dvec3 rightOffset = mix(chunk->topLeft - chunk->center, chunk->topRight - chunk->center, double(genCol)/vertexSubdivisionsPerChunk);
			// 	dvec3 pos = Spherify(chunk->center + topDir*topOffset + rightDir*rightOffset, chunk->face);
			// 	vec3 bottomLeftPos = chunk->inverseTransform * dvec4{pos * chunk->celestial->GetTerrainHeightAtPos(pos), 1};

			// tangentX = normalize(currentVertex]) - currentVertex);
			// tangentY = normalize(currentVertex - bottomLeftPos);
			
			return vec3(0,1,0);
			
	}
	
	tangentX = normalize(tangentX * float(chunk.rightSign));
	tangentY = normalize(tangentY * float(chunk.topSign));
	
	return normalize(cross(tangentX, tangentY));
}
