// Di
#define NB_LIGHTS 16
#define SORT_LIGHTS
#define USE_SOFT_SHADOWS
// Gi
#define MAX_GI_ACCUMULATION 400
#define GI_PROBE_SIZE 1.0
#define ACCUMULATOR_MAX_FRAME_INDEX_DIFF 2000
#define USE_PATH_TRACED_GI
#define USE_BLUE_NOISE
#define PATH_TRACED_GI_MAX_BOUNCES 2


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

uint BLUE_NOISE_NB_TEXTURES = 64;

bool GetBlueNoiseBool() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_unitvec1;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).r == 1;
}

float GetBlueNoiseFloat() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_scalar;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).r;
}

vec2 GetBlueNoiseFloat2() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_vec2;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).rg;
}

vec3 GetBlueNoiseUnitSphere() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_unitvec3;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	return texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord).rgb * 2 - 1;
}

vec4 GetBlueNoiseUnitCosine() {
	uint BLUE_NOISE_TEXTURES_OFFSET = renderer.bluenoise_unitvec3_cosine;
	uint noiseTexIndex = uint(xenonRendererData.frameIndex % BLUE_NOISE_NB_TEXTURES);
	vec2 texSize = vec2(textureSize(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], 0).st);
	vec2 noiseTexCoord = (vec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y) + 0.5) / texSize;
	vec4 tex = texture(textures[nonuniformEXT(noiseTexIndex+BLUE_NOISE_TEXTURES_OFFSET)], noiseTexCoord);
	return vec4(tex.rgb * 2 - 1, tex.a);
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
	return p0 * slerp(1.0f - d.z) + p1 * slerp(d.z);
}

vec3 GetDirectLighting(in vec3 position, in vec3 normal) {
	position += normal * gl_HitTEXT * EPSILON;
	vec3 directLighting = vec3(0);
	
	rayQueryEXT q;
	rayQueryInitializeEXT(q, tlas_lights, 0, 0xff, position, 0, vec3(0,1,0), 0);
	
	vec3 lightsDir[NB_LIGHTS];
	float lightsDistance[NB_LIGHTS];
	vec3 lightsColor[NB_LIGHTS];
	float lightsPower[NB_LIGHTS];
	float lightsRadius[NB_LIGHTS];
	// uint32_t lightsID[NB_LIGHTS];
	uint32_t nbLights = 0;
	
	while (rayQueryProceedEXT(q)) {
		vec3 lightPosition = rayQueryGetIntersectionObjectToWorldEXT(q, false)[3].xyz; // may be broken on AMD...
		int lightID = rayQueryGetIntersectionInstanceIdEXT(q, false);
		vec3 relativeLightPosition = lightPosition - position;
		vec3 lightDir = normalize(relativeLightPosition);
		float nDotL = dot(normal, lightDir);
		LightSourceInstanceData lightSource = renderer.lightSources[lightID].instance;
		float distanceToLightSurface = length(relativeLightPosition) - lightSource.innerRadius - gl_HitTEXT * EPSILON;
		if (distanceToLightSurface <= 0.001) {
			directLighting += lightSource.color * lightSource.power;
		} else if (nDotL > 0 && distanceToLightSurface < lightSource.maxDistance) {
			float effectiveLightIntensity = max(0, lightSource.power / (4.0 * PI * distanceToLightSurface*distanceToLightSurface + 1) - LIGHT_LUMINOSITY_VISIBLE_THRESHOLD) * clamp(nDotL, 0, 1);
			uint index = nbLights;
			#ifdef SORT_LIGHTS
				for (index = 0; index < nbLights; ++index) {
					if (effectiveLightIntensity > lightsPower[index]) {
						for (int i = min(NB_LIGHTS-1, int(nbLights)); i > int(index); --i) {
							lightsDir[i] = lightsDir[i-1];
							lightsDistance[i] = lightsDistance[i-1];
							lightsColor[i] = lightsColor[i-1];
							lightsPower[i] = lightsPower[i-1];
							lightsRadius[i] = lightsRadius[i-1];
							// lightsID[i] = lightsID[i-1];
						}
						break;
					}
				}
				if (index == NB_LIGHTS) continue;
			#endif
			lightsDir[index] = lightDir;
			lightsDistance[index] = distanceToLightSurface;
			lightsColor[index] = lightSource.color;
			lightsPower[index] = effectiveLightIntensity;
			lightsRadius[index] = lightSource.innerRadius;
			// lightsID[index] = lightID;
			if (nbLights < NB_LIGHTS) ++nbLights;
			#ifndef /*NOT*/SORT_LIGHTS
				else {
					rayQueryTerminateEXT(rayQuery);
					break;
				}
			#endif
		}
	}
	
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_LIGHTS) {
		imageStore(img_normal_or_debug, COORDS, vec4(Heatmap(float(nbLights) / float(NB_LIGHTS)), 1));
	}
	
	RayPayload originalRay = ray;
	int usefulLights = 0;
	for (uint i = 0; i < nbLights; ++i) {
		vec3 shadowRayDir = lightsDir[i];
		float shadowRayStart = 0;
		vec3 colorFilter = vec3(1);
		float opacity = 0;
		const float MAX_SHADOW_TRANSPARENCY_RAYS = 2;
		for (int j = 0; j < MAX_SHADOW_TRANSPARENCY_RAYS; ++j) {
			if ((xenonRendererData.config.options & RENDER_OPTION_GROUND_TRUTH) != 0) { // #ifdef USE_SOFT_SHADOWS
				#ifdef USE_BLUE_NOISE
					vec2 rnd = GetBlueNoiseFloat2();
				#else
					vec2 rnd = vec2(RandomFloat(seed), RandomFloat(seed));
				#endif
				float pointRadius = lightsRadius[i] / lightsDistance[i] * rnd.x;
				float pointAngle = rnd.y * 2.0 * PI;
				vec2 diskPoint = vec2(pointRadius * cos(pointAngle), pointRadius * sin(pointAngle));
				vec3 lightTangent = normalize(cross(shadowRayDir, normal));
				vec3 lightBitangent = normalize(cross(lightTangent, shadowRayDir));
				shadowRayDir = normalize(shadowRayDir + diskPoint.x * lightTangent + diskPoint.y * lightBitangent);
			} // #endif
			RAY_RECURSION_PUSH
				RAY_SHADOW_PUSH
					ray.color = vec4(0);
					traceRayEXT(tlas, 0, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_VOXEL|RAYTRACE_MASK_CLUTTER, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, position, shadowRayStart, shadowRayDir, lightsDistance[i], 0);
				RAY_SHADOW_POP
			RAY_RECURSION_POP
			if (ray.hitDistance == -1) {
				// lit
				directLighting += lightsColor[i] * lightsPower[i] * colorFilter * (1 - clamp(opacity,0,1));
				#ifdef SORT_LIGHTS
					ray = originalRay;
					return directLighting;
				#else
					break;
				#endif
			} else {
				colorFilter *= ray.color.rgb;
				opacity += max(0.05, ray.color.a);
				shadowRayStart = max(ray.hitDistance, ray.t2) * 1.001;
			}
			if (opacity > 0.95) break;
		}
	}
	ray = originalRay;
	return directLighting;
}

#ifdef USE_BLUE_NOISE
	vec3 RandomPointOnHemisphere(in vec3 normal) {
		vec3 tangentX = normalize(cross(normalize(vec3(0.356,1.2145,0.24537))/* fixed arbitrary vector in object space */, normal));
		vec3 tangentY = normalize(cross(normal, tangentX));
		mat3 TBN = mat3(tangentX, tangentY, normal);
		return normalize(TBN * GetBlueNoiseUnitCosine().rgb);
	}
#else
	vec3 RandomPointOnHemisphere(in vec3 normal) {
		return normalize(normal + RandomInUnitSphere(seed));
	}
#endif

void ApplyDefaultLighting() {
	bool rayIsShadow = RAY_IS_SHADOW;
	uint recursions = RAY_RECURSIONS;
	bool rayIsGi = RAY_IS_GI;
	bool rayIsUnderWater = RAY_IS_UNDERWATER;
	
	if (rayIsShadow) {
		ray.color = surface.color;
		return;
	}
	
	// Fresnel
	float fresnel = Fresnel((renderer.viewMatrix * vec4(ray.worldPosition, 1)).xyz, normalize(WORLD2VIEWNORMAL * ray.normal), surface.ior);
	
	// // Ground Truth
	// if ((xenonRendererData.config.options & RENDER_OPTION_GROUND_TRUTH) != 0) {
	// 	ray.color = surface.color;
	// 	if (recursions < RAY_MAX_RECURSION) {
	// 		// float directLightingProbabilities = 0.5;
	// 		// if (GetBlueNoiseFloat() < directLightingProbabilities) {
	// 		// 	ray.color.rgb *= GetDirectLighting(ray.worldPosition, ray.normal);
	// 		// } else {
	// 			RayPayload originalRay = ray;
	// 			vec3 rayOrigin = originalRay.worldPosition + originalRay.normal * originalRay.hitDistance * EPSILON;
	// 			vec3 bounceDirection = RandomPointOnHemisphere(originalRay.normal);
	// 			RAY_RECURSION_PUSH
	// 				traceRayEXT(tlas, 0, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_VOXEL|RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, bounceDirection, xenonRendererData.config.zFar, 0);
	// 			RAY_RECURSION_POP
	// 			originalRay.color.rgb *= ray.color.rgb;
	// 			ray = originalRay;
	// 		// }
	// 	}
	// 	return;
	// }
	
	vec3 albedo = surface.color.rgb;
	
	// Direct Lighting
	vec3 directLighting = vec3(0);
	if (recursions < RAY_MAX_RECURSION) {
		directLighting = GetDirectLighting(ray.worldPosition, ray.normal) * (albedo + fresnel * surface.specular) * (RAY_IS_UNDERWATER? 0.5:1);
	}
	ray.color = vec4(directLighting, 1);
	
	if ((xenonRendererData.config.options & RENDER_OPTION_GROUND_TRUTH) != 0) { // #ifdef USE_PATH_TRACED_GI
		// Path Tracing Gi
		if (recursions < PATH_TRACED_GI_MAX_BOUNCES) {
			RayPayload originalRay = ray;
			vec3 rayOrigin = originalRay.worldPosition + originalRay.normal * originalRay.hitDistance * EPSILON;
			vec3 bounceDirection = RandomPointOnHemisphere(originalRay.normal);
			RAY_RECURSION_PUSH
				RAY_GI_PUSH
					traceRayEXT(tlas, 0, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_VOXEL|RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, bounceDirection, xenonRendererData.config.zFar, 0);
				RAY_GI_POP
			RAY_RECURSION_POP
			originalRay.color.rgb += ray.color.rgb * albedo;
			ray = originalRay;
		}
	} else { // #else
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
				vec3 bounceDirection = normalize(originalRay.normal + RandomInUnitHemiSphere(seed, originalRay.normal));
				// float nDotL = clamp(dot(originalRay.normal, bounceDirection), 0, 1);
				RAY_RECURSION_PUSH
					RAY_GI_PUSH
						traceRayEXT(tlas, 0, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY|RAYTRACE_MASK_VOXEL|RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, bounceDirection, GI_RAY_MAX_DISTANCE, 0);
					RAY_GI_POP
				RAY_RECURSION_POP
				WriteAmbientLighting(giIndex, facingWorldPosition, ray.color.rgb);
				UnlockAmbientLighting(giIndex);
				ray = originalRay;
			}
			if (!rayIsGi) {
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
					originalRay.color.rgb += albedo * ray.color.rgb * (1-giFactor);
					ray = originalRay;
				}
			}
		}
	} // #endif
	
	// Debug UV1
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_UVS) {
		if (RAY_RECURSIONS == 0) imageStore(img_normal_or_debug, COORDS, vec4(surface.uv1, 0, 1));
	}
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
