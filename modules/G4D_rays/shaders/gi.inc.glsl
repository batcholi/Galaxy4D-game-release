#define MAX_GI_ACCUMULATION 400
#define GI_PROBE_SIZE 1.0
#define ACCUMULATOR_MAX_FRAME_INDEX_DIFF 2000

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
	uvec3 p = uvec3(ivec3(round(worldPosition / GI_PROBE_SIZE) - vec3(renderer.worldOrigin)/GI_PROBE_SIZE) + ivec3(1<<30));
	return (HashGlobalPosition(p) % halfCount) + level * halfCount;
}
#define GetGi(i) renderer.globalIllumination[i]

float sdfSphere(vec3 p, float r) {
	return length(p) - r;
}


const int nbAdjacentSides = 26;
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
	
	ivec3(-1,-1,-1),
	ivec3(-1,-1,+1),
	ivec3(-1,+1,-1),
	ivec3(-1,+1,+1),
	ivec3(+1,-1,-1),
	ivec3(+1,-1,+1),
	ivec3(+1,+1,-1),
	ivec3(+1,+1,+1),
};

bool LockAmbientLighting(in uint giIndex) {
	return atomicExchange(GetGi(giIndex).lock, 1) != 1;
}
void UnlockAmbientLighting(in uint giIndex) {
	GetGi(giIndex).lock = 0;
}

void WriteAmbientLighting(in uint giIndex, in vec3 worldPosition, in vec3 color) {
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
		GetGi(level1GiIndex).radiance = vec4(l, 1);
	} else {
		GetGi(level1GiIndex).radiance = vec4(mix(level1Radiance.rgb, l, 0.5/accumulation), accumulation);
	}
	GetGi(level1GiIndex).iteration = renderer.giIteration;
	GetGi(level1GiIndex).frameIndex = int64_t(xenonRendererData.frameIndex);
	for (int i = 0; i < nbAdjacentSides; ++i) {
		uint adjacentGiIndex = GetGiIndex(worldPosition + adjacentSides[i] * GI_PROBE_SIZE, 1);
		vec4 level1AdjacentRadiance = GetGi(adjacentGiIndex).radiance;
		accumulation = clamp(level1AdjacentRadiance.a + 1, 1, MAX_GI_ACCUMULATION/4);
		if (abs(GetGi(adjacentGiIndex).frameIndex - int64_t(xenonRendererData.frameIndex)) >= ACCUMULATOR_MAX_FRAME_INDEX_DIFF || GetGi(adjacentGiIndex).iteration != renderer.giIteration) {
			GetGi(adjacentGiIndex).radiance = vec4(l, 1);
		} else {
			GetGi(adjacentGiIndex).radiance = vec4(mix(level1AdjacentRadiance.rgb, l, 0.5/accumulation), accumulation);
		}
		GetGi(adjacentGiIndex).iteration = renderer.giIteration;
		GetGi(adjacentGiIndex).frameIndex = int64_t(xenonRendererData.frameIndex);
	}
}

float slerp(float x) {return smoothstep(0.0f,1.0f,x);}

vec3 GetAmbientLighting(in vec3 worldPosition) {
	vec3 d = worldPosition/GI_PROBE_SIZE - round(worldPosition/GI_PROBE_SIZE) + 0.5;
	vec3 p000 = GetGi(GetGiIndex(worldPosition, 1)).radiance.rgb;
	vec3 p001 = GetGi(GetGiIndex(worldPosition + vec3(0,0,1)*GI_PROBE_SIZE, 1)).radiance.rgb;
	vec3 p010 = GetGi(GetGiIndex(worldPosition + vec3(0,1,0)*GI_PROBE_SIZE, 1)).radiance.rgb;
	vec3 p011 = GetGi(GetGiIndex(worldPosition + vec3(0,1,1)*GI_PROBE_SIZE, 1)).radiance.rgb;
	vec3 p100 = GetGi(GetGiIndex(worldPosition + vec3(1,0,0)*GI_PROBE_SIZE, 1)).radiance.rgb;
	vec3 p101 = GetGi(GetGiIndex(worldPosition + vec3(1,0,1)*GI_PROBE_SIZE, 1)).radiance.rgb;
	vec3 p110 = GetGi(GetGiIndex(worldPosition + vec3(1,1,0)*GI_PROBE_SIZE, 1)).radiance.rgb;
	vec3 p111 = GetGi(GetGiIndex(worldPosition + vec3(1,1,1)*GI_PROBE_SIZE, 1)).radiance.rgb;
	vec3 p00 = (p000 * slerp(1.0f - d.x) + p100 * slerp(d.x));
	vec3 p01 = (p001 * slerp(1.0f - d.x) + p101 * slerp(d.x));
	vec3 p10 = (p010 * slerp(1.0f - d.x) + p110 * slerp(d.x));
	vec3 p11 = (p011 * slerp(1.0f - d.x) + p111 * slerp(d.x));
	vec3 p0 = (p00 * slerp(1.0f - d.y) + p10 * slerp(d.y));
	vec3 p1 = (p01 * slerp(1.0f - d.y) + p11 * slerp(d.y));
	return (p0 * slerp(1.0f - d.z) + p1 * slerp(d.z)) * 0.25 + 0.01;
}

void ApplyDefaultLighting() {
	bool rayIsShadow = RAY_IS_SHADOW;
	uint recursions = RAY_RECURSIONS;
	bool rayIsGi = RAY_IS_GI;
	bool rayIsUnderWater = RAY_IS_UNDERWATER;
	
	if (rayIsShadow) {
		ray.color = surface.color;
		return;
	}
	
	vec3 albedo = surface.color.rgb;
	
	// Fresnel
	float fresnel = Fresnel((renderer.viewMatrix * vec4(ray.worldPosition, 1)).xyz, normalize(WORLD2VIEWNORMAL * ray.normal), surface.ior);
	
	// Direct Lighting
	vec3 directLighting = vec3(0);
	if (recursions < RAY_MAX_RECURSION) {
		directLighting = GetDirectLighting(ray.worldPosition, ray.normal) * (albedo + fresnel * surface.specular) * (RAY_IS_UNDERWATER? 0.5:1);
	}
	ray.color = vec4(directLighting, 1);
	
	{// Global Illumination
		bool useGi = !rayIsUnderWater;
		const float GI_DRAW_MAX_DISTANCE = 100;
		const float GI_RAY_MAX_DISTANCE = 200;
		const vec3 rayOrigin = ray.worldPosition + ray.normal * 0.001;
		const vec3 facingWorldPosition = ray.worldPosition + ray.normal * GI_PROBE_SIZE * 0.5;
		const uint giIndex = GetGiIndex(facingWorldPosition, 0);
		const uint giIndex1 = GetGiIndex(facingWorldPosition, 1);
		seed += recursions * RAY_MAX_RECURSION;
		if (useGi && ray.hitDistance < GI_DRAW_MAX_DISTANCE && recursions < RAY_MAX_RECURSION && LockAmbientLighting(giIndex)) {
			RayPayload originalRay = ray;
			ray.color.rgb = vec3(0);
			vec3 bounceDirection = normalize(originalRay.normal + RandomInUnitSphere(seed));
			float nDotL = clamp(dot(originalRay.normal, bounceDirection), 0, 1);
			RAY_RECURSION_PUSH
				RAY_GI_PUSH
					traceRayEXT(tlas, 0, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_VOXEL|RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, bounceDirection, GI_RAY_MAX_DISTANCE, 0);
				RAY_GI_POP
			RAY_RECURSION_POP
			WriteAmbientLighting(giIndex, facingWorldPosition, ray.color.rgb * nDotL);
			UnlockAmbientLighting(giIndex);
			ray = originalRay;
		}
		if (!rayIsGi && (xenonRendererData.config.options & RENDER_OPTION_ACCUMULATE) == 0) {
			float giFactor = useGi ? smoothstep(GI_DRAW_MAX_DISTANCE, 0, ray.hitDistance) : 0;
			if (useGi && ray.hitDistance < GI_DRAW_MAX_DISTANCE) {
				vec3 ambient = GetAmbientLighting(facingWorldPosition);
				ray.color.rgb += albedo * ambient * giFactor;
				if (recursions == 0 && xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_GLOBAL_ILLUMINATION) {
					imageStore(img_normal_or_debug, COORDS, vec4(ambient, 1));
				}
			}
			if (recursions < RAY_MAX_RECURSION) {
				RayPayload originalRay = ray;
				ray.color.rgb = vec3(0);
				RAY_RECURSION_PUSH
					RAY_GI_PUSH
						traceRayEXT(tlas, 0, RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, originalRay.normal, 10000, 0);
					RAY_GI_POP
				RAY_RECURSION_POP
				originalRay.color.rgb += albedo * ray.color.rgb * (1-giFactor) / 3.14159265;
				ray = originalRay;
			}
		}
	}
	
	// Debug UV1
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_UVS) {
		if (RAY_RECURSIONS == 0) imageStore(img_normal_or_debug, COORDS, vec4(surface.uv1, 0, 1));
	}
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
