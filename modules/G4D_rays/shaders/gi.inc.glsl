#define MAX_GI_ACCUMULATION 400
#define ACCUMULATOR_MAX_FRAME_INDEX_DIFF 500

uint HashGlobalPosition(uvec3 data) {
	uint hash = 8u, tmp;

	hash += data.x & 0xffffu;
	tmp = (((data.x >> 16) & 0xffffu) << 11) ^ hash;
	hash = (hash << 16) ^ tmp;
	hash += hash >> 11;

	hash += data.y & 0xffffu;
	tmp = (((data.y >> 16) & 0xffffu) << 11) ^ hash;
	hash = (hash << 16) ^ tmp;
	hash += hash >> 11;

	hash += data.z & 0xffffu;
	tmp = (((data.z >> 16) & 0xffffu) << 11) ^ hash;
	hash = (hash << 16) ^ tmp;
	hash += hash >> 11;

	hash ^= hash << 3;
	hash += hash >> 5;
	hash ^= hash << 4;
	hash += hash >> 17;
	hash ^= hash << 25;
	hash += hash >> 6;

	return hash;
}

uvec3 HashGlobalPosition3(uvec3 v) {

	v = v * 1664525u + 1013904223u;

	v.x += v.y*v.z;
	v.y += v.z*v.x;
	v.z += v.x*v.y;

	v ^= v >> 16u;

	v.x += v.y*v.z;
	v.y += v.z*v.x;
	v.z += v.x*v.y;

	return v;
}

uint GetGiIndex(in vec3 worldPosition, uint level) {
	uint halfCount = renderer.globalIlluminationTableCount / 2;
	uvec3 p = uvec3(ivec3(round(worldPosition)) - renderer.worldOrigin + ivec3(1<<30));
	return (HashGlobalPosition(p) % halfCount) + level * halfCount;
}
#define GetGi(i) renderer.globalIllumination[i]

float sdfSphere(vec3 p, float r) {
	return length(p) - r;
}


const int nbAdjacentSides = 18;
const ivec3 adjacentSides[nbAdjacentSides] = {
	ivec3( 0, 0, 1),
	ivec3( 0, 1, 0),
	ivec3( 0, 1, 1),
	ivec3( 1, 0, 0),
	ivec3( 1, 0, 1),
	ivec3( 1, 1, 0),

	ivec3( 0, 0,-1),
	ivec3( 0,-1, 0),
	ivec3( 0,-1,-1),
	ivec3(-1, 0, 0),
	ivec3(-1, 0,-1),
	ivec3(-1,-1, 0),

	ivec3( 0,-1, 1),
	ivec3(-1, 0, 1),
	ivec3(-1, 1, 0),

	ivec3( 0, 1,-1),
	ivec3( 1, 0,-1),
	ivec3( 1,-1, 0),
};

bool LockAmbientLighting(in uint giIndex) {
	return atomicExchange(GetGi(giIndex).lock, 1) != 1;
}
void UnlockAmbientLighting(in uint giIndex) {
	GetGi(giIndex).lock = 0;
}
void WriteAmbientLighting(in uint giIndex, in vec3 worldPosition, in vec3 normal, in vec3 color) {
	vec4 radiance = GetGi(giIndex).radiance;
	float accumulation = clamp(radiance.a + 1, 1, MAX_GI_ACCUMULATION);
	if (abs(GetGi(giIndex).frameIndex - int64_t(xenonRendererData.frameIndex)) >= ACCUMULATOR_MAX_FRAME_INDEX_DIFF || GetGi(giIndex).iteration != renderer.giIteration) {
		accumulation = 1;
	}
	GetGi(giIndex).iteration = renderer.giIteration;
	GetGi(giIndex).frameIndex = int64_t(xenonRendererData.frameIndex);
	vec3 l = mix(radiance.rgb, color, clamp(1.0/accumulation, 0, 1));
	if (isnan(l.r) || isnan(l.g) || isnan(l.b) || isnan(accumulation)) {
		l = vec3(0);
		accumulation = 1;
	}
	GetGi(giIndex).radiance = vec4(l, accumulation);
	
	uint level1GiIndex = GetGiIndex(worldPosition, 1);
	vec4 level1Radiance = GetGi(level1GiIndex).radiance;
	accumulation = clamp(level1Radiance.a + 1, 1, MAX_GI_ACCUMULATION/2);
	if (abs(GetGi(level1GiIndex).frameIndex - int64_t(xenonRendererData.frameIndex)) >= ACCUMULATOR_MAX_FRAME_INDEX_DIFF || GetGi(level1GiIndex).iteration != renderer.giIteration) {
		accumulation = 1;
	}
	GetGi(level1GiIndex).radiance = vec4(mix(level1Radiance.rgb, l, 0.5/accumulation), accumulation);
	GetGi(level1GiIndex).iteration = renderer.giIteration;
	GetGi(level1GiIndex).frameIndex = int64_t(xenonRendererData.frameIndex);
	for (int i = 0; i < nbAdjacentSides; ++i) {
		if (abs(dot(vec3(adjacentSides[i]), normal)) < 0.01) {
			uint adjacentGiIndex = GetGiIndex(worldPosition + adjacentSides[i], 1);
			vec4 level1AdjacentRadiance = GetGi(adjacentGiIndex).radiance;
			accumulation = clamp(level1AdjacentRadiance.a + 1, 1, MAX_GI_ACCUMULATION/4);
			if (abs(GetGi(adjacentGiIndex).frameIndex - int64_t(xenonRendererData.frameIndex)) >= ACCUMULATOR_MAX_FRAME_INDEX_DIFF || GetGi(adjacentGiIndex).iteration != renderer.giIteration) {
				accumulation = 1;
			}
			GetGi(adjacentGiIndex).radiance = vec4(mix(level1AdjacentRadiance.rgb, l, 0.5/accumulation), accumulation);
			GetGi(adjacentGiIndex).iteration = renderer.giIteration;
			GetGi(adjacentGiIndex).frameIndex = int64_t(xenonRendererData.frameIndex);
		}
	}
}
vec3 GetAmbientLighting(in uint giIndex, in vec3 worldPosition, in vec3 posInVoxel, in vec3 normal) {
	if (abs(GetGi(giIndex).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi(giIndex).radiance.a > 1) {
		vec4 lighting = vec4(GetGi(giIndex).radiance.rgb, 1);
		// for (int i = 0; i < nbAdjacentSides; ++i) {
		// 	if (abs(dot(vec3(adjacentSides[i]), normal)) < 0.01) {
		// 		uint adjacentGiIndex = GetGiIndex(worldPosition + adjacentSides[i], 1);
		// 		if (abs(GetGi(adjacentGiIndex).frameIndex - int64_t(xenonRendererData.frameIndex)) < ACCUMULATOR_MAX_FRAME_INDEX_DIFF && GetGi(adjacentGiIndex).radiance.a > 1) {
		// 			vec3 p = posInVoxel - vec3(adjacentSides[i]);
		// 			lighting += vec4(GetGi(adjacentGiIndex).radiance.rgb * (1 - clamp(sdfSphere(p, 0.667), 0, 1)), 1);
		// 		}
		// 	}
		// }
		return pow(lighting.rgb / lighting.a, vec3(2.0)) + 0.0003;
	}
	return vec3(0.0007);
}
