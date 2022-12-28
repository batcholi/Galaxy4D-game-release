#include "common.inc.glsl"
#include "xenon/renderer/shaders/perlint.glsl"

#define KM *TERRAIN_INT_MULTIPLIER*1000
#define M *TERRAIN_INT_MULTIPLIER

double moutainStep(double start, double end, double value) {
	if (value > start && value < end) return mix(start, value, smoothstep(start, end, value));
	if (value < start && value > end) return mix(start, value, smoothstep(start, end, value));
	return value;
}

#ifdef GLSL
	#define PLANET_BASE_RADIUS_INT chunk.baseRadiusInt
	#define PLANET_HEIGHT_VARIATION_INT chunk.heightVariationInt
	double getPolarity(dvec3 normalizedPos) {
		return clamp(abs(dot(normalizedPos, dvec3(0,0,1))-0.2)-0.2, 0.0, 1.0);
	}
	double TerrainHeightMap(dvec3 normalizedPos)
#else
	#define PLANET_BASE_RADIUS_INT (terrainRadius * TERRAIN_INT_MULTIPLIER)
	#define PLANET_HEIGHT_VARIATION_INT (terrainHeightVariation * TERRAIN_INT_MULTIPLIER)
	double getPolarity(const dvec3& normalizedPos) {
		return clamp(abs(dot(normalizedPos, dvec3(0,0,1))-0.2)-0.2, 0.0, 1.0);
	}
	static double TerrainHeightMap(const dvec3& normalizedPos, double terrainRadius, double terrainHeightVariation)
#endif
/*double TerrainHeightMap(normalizedPos)*/{
	u64vec3 pos = u64vec3(normalizedPos * PLANET_BASE_RADIUS_INT + 200000000000.0);
	uint64_t variation = uint64_t(PLANET_HEIGHT_VARIATION_INT);
	double variationf = double(variation);
	
	const uint64_t warpMaximum = 200 KM;
	const uint64_t warpStride = 400 KM;
	const uint warpOctaves = 3;
	const uint64_t continentStride = 2000 KM;
	
	u64vec3 warp = u64vec3(perlint64(pos + uint64_t(6546495), warpStride, warpMaximum, warpOctaves), perlint64(pos + uint64_t(516556), warpStride, warpMaximum, warpOctaves), perlint64(pos - uint64_t(897178), warpStride, warpMaximum, warpOctaves));
	double polarity = getPolarity(normalizedPos);
	double continents = slerp(slerp(slerp(slerp(perlint64f(pos + warp, continentStride, variation)) * (slerp(perlint64f(pos + warp, continentStride/2, variation))))) + (polarity*polarity));
	double coasts = continents * clamp((1.0-continents)*2.0 * (perlint64f(pos, continentStride, variation, 2) * 4.0 - 2.0) + 0.03, 0.0, 1.0);
	
	double peaks1 = 1.0 - perlint64fRidged(pos + warp/uint64_t(2) + uint64_t(49783892), 50 KM, variation, 4);
	double peaks2 = perlint64f(pos+warp/uint64_t(4) + uint64_t(87457641), 8 KM, variation/8, 2);
	double peaks3 = perlint64f(pos+warp/uint64_t(4) + uint64_t(276537654), 2 KM, variation/32, 2);
	
	double mountains = 0
		+ continents * variationf * 0.5
		- variationf * 0.2
		+ coasts * peaks1 * variation
		+ coasts * peaks2*peaks2 * variation/4
		+ coasts * peaks3*peaks3 * variation/8
		+ perlint64f(pos+warp/uint64_t(4) + uint64_t(176989876), 400 M, 200 M, 3) * 100 M
		+ perlint64f(pos, 50 M, 20 M, 3) * 5 M
	;
	
	mountains = moutainStep(variationf * 0.2001, variationf * 0.1995, mountains);
	mountains = moutainStep(variationf * 0.2001, variationf * 0.3, mountains);
	mountains = moutainStep(variationf * 0.5, variationf * 0.6, mountains);
	mountains = moutainStep(variationf * 0.8, variationf * 0.85, mountains);
	
	double detail = perlint64f(pos, 1 M, 1 M, 6) * 0.05 M;
	
	double height = double(PLANET_BASE_RADIUS_INT)
		+ mountains
		+ detail
	;
	
	return height / double(TERRAIN_INT_MULTIPLIER);
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
			double heightRatio = (height - double(chunk.baseRadiusInt)/TERRAIN_INT_MULTIPLIER) / double(PLANET_HEIGHT_VARIATION_INT) * TERRAIN_INT_MULTIPLIER;
			// colors[currentIndex].color = vec4(vec3(heightRatio), 1);
			const vec3 snowColor = vec3(0.8, 0.9, 1.0);
			const vec3 rockColor = vec3(0.2, 0.2, 0.2);
			const vec3 dirtColor = vec3(0.2, 0.1, 0.07);
			const vec3 clayColor = vec3(0.8, 0.6, 0.3);
			const vec3 sandColor = vec3(0.9, 0.5, 0.2);
			const vec3 underwaterColor = vec3(0.3, 0.7, 0.5);
			vec3 color = vec3(mix(rockColor, snowColor, clamp(smoothstep(0.4, 0.6, getPolarity(posNorm)) + smoothstep(0.5, 0.6, heightRatio), 0.0, 1.0)));
			color = mix(dirtColor, color, smoothstep(0.4, 0.6, float(heightRatio)));
			color = mix(clayColor, color, smoothstep(0.25, 0.4, float(heightRatio)));
			color = mix(sandColor, color, smoothstep(0.19, 0.25, float(heightRatio)));
			color = mix(underwaterColor, color, smoothstep(0.199, 0.2002, float(heightRatio)));
			u64vec3 pos = u64vec3(posNorm * PLANET_BASE_RADIUS_INT + 200000000000.0);
			color *= mix(float(perlint64f(pos, 1 M / 8, 1 M / 8, 2)), 1.0, 0.7);
			colors[currentIndex].color = vec4(color, 1);
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
