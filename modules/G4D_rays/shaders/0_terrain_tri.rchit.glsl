#define SHADER_RCHIT
#include "common.inc.glsl"
#include "gi.inc.glsl"

layout(location = 0) rayPayloadInEXT RayPayload ray;

hitAttributeEXT vec3 hitAttribs;

// float NormalDetail(in vec3 pos) {
// 	return SimplexFractal(pos * 0.3, 2);
// }

void main() {
	bool rayIsShadow = RAY_IS_SHADOW;
	uint recursions = RAY_RECURSIONS;
	bool rayIsGi = RAY_IS_GI;
	bool rayIsUnderWater = RAY_IS_UNDERWATER;
	
	ray.hitDistance = gl_HitTEXT;
	ray.id = gl_InstanceCustomIndexEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	ray.t2 = 0;
	ray.ssao = 0;
	
	vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);
	surface.normal = ComputeSurfaceNormal(barycentricCoords);
	surface.color = ComputeSurfaceColor(barycentricCoords);
	surface.uv1 = ComputeSurfaceUV1(barycentricCoords);
	surface.uv2 = ComputeSurfaceUV2(barycentricCoords);
	surface.distance = ray.hitDistance;
	surface.localPosition = ray.localPosition;
	surface.specular = 0;
	surface.emission = vec3(0);
	surface.ior = 1.45;
	surface.geometryInfo = GEOMETRY.info;
	surface.renderableData = INSTANCE.data;
	surface.aabbData = 0;
	surface.renderableIndex = gl_InstanceID;
	surface.geometryIndex = gl_GeometryIndexEXT;
	surface.primitiveIndex = gl_PrimitiveID;
	surface.aimID = gl_InstanceCustomIndexEXT;
	
	// if (OPTION_TEXTURES) {
		executeCallableEXT(GEOMETRY.info.surfaceIndex, SURFACE_CALLABLE_PAYLOAD);
	// }
	
	vec3 albedo = surface.color.rgb;
	
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);

	// Fresnel
	float fresnel = Fresnel((renderer.viewMatrix * vec4(ray.worldPosition, 1)).xyz, normalize(WORLD2VIEWNORMAL * ray.normal), surface.ior);
	
	
	// Direct Lighting
	vec3 directSunLight = vec3(0);
	if (recursions < RAY_MAX_RECURSION) {
		vec3 color = ray.color.rgb;
		ray.color = vec4(0);
		vec3 sunDir = normalize(renderer.sunDir);
		float nDotL = dot(ray.normal, sunDir);
		if (nDotL > 0) {
			const vec3 rayOrigin = ray.worldPosition + ray.normal * ray.hitDistance * 0.001;
			
			
			// // Using Ray Tracing Pipeline (more compatible)
			// 	RAY_RECURSION_PUSH
			// 		RAY_SHADOW_PUSH
			// 			RayPayload originalRay = ray;
			// 			traceRayEXT(tlas, gl_RayFlagsTerminateOnFirstHitEXT, ~(/* RAYTRACE_TYPE_WATER | */ RAYTRACE_TYPE_ATMOSPHERE), 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, xenonRendererData.config.zNear, sunDir, xenonRendererData.config.zFar, 0);
			// 			// lit
			// 			if (RAY_IS_UNDERWATER) {
			// 				directSunLight =  GetSunColor() * albedo * (1-ray.color.a);
			// 			} else {
			// 				directSunLight = GetSunColor() * (1-ray.color.a) * (albedo + fresnel * surface.specular) * nDotL;
			// 			}
			// 			ray = originalRay;
			// 		RAY_SHADOW_POP
			// 	RAY_RECURSION_POP
			
			
			// Using Ray Query (faster)
				if (rayQuerySunlight(rayOrigin, sunDir)) {
					directSunLight = GetSunColor() * (albedo + fresnel * surface.specular) * nDotL * (rayIsUnderWater? 0.5:1);
				}
			
			
			// // Using Ray Query with Soft Shadows
			// 	int shadowRaySamples = 16;
			// 	float sunLight = 0;
			// 	const float sunSolidAngle = 0.05;
			// 	for (int s = 0; s < shadowRaySamples; ++s) {
			// 		float pointRadius = sunSolidAngle * RandomFloat(seed);
			// 		float pointAngle = RandomFloat(seed) * 2.0 * 3.1415926535;
			// 		vec2 diskPoint = vec2(pointRadius * cos(pointAngle), pointRadius * sin(pointAngle));
			// 		vec3 lightTangent = normalize(cross(sunDir, ray.normal));
			// 		vec3 lightBitangent = normalize(cross(lightTangent, sunDir));
			// 		vec3 shadowRayDir = normalize(sunDir + diskPoint.x * lightTangent + diskPoint.y * lightBitangent);
			// 		if (rayQuerySunlight(rayOrigin, shadowRayDir)) {
			// 			++sunLight;
			// 		}
			// 	}
			// 	directSunLight = GetSunColor() * (albedo + fresnel * surface.specular) * nDotL * pow(sunLight/shadowRaySamples, 2);
			
			
		}
	}
	ray.color = vec4(directSunLight, 1);
	
	bool useGi = true;
	
	// Global Illumination
	const float GI_DRAW_MAX_DISTANCE = 200;
	const float GI_RAY_MAX_DISTANCE = 2000;
	const vec3 rayOrigin = ray.worldPosition + ray.normal * 0.001;
	const vec3 facingWorldPosition = ray.worldPosition + ray.normal * 0.5;
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
				traceRayEXT(tlas, 0, ~(RAYTRACE_TYPE_WATER | RAYTRACE_TYPE_CLUTTER), 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, bounceDirection, GI_RAY_MAX_DISTANCE, 0);
			RAY_GI_POP
		RAY_RECURSION_POP
		ray.color.rgb *= nDotL / 3.1415;
		WriteAmbientLighting(giIndex, facingWorldPosition, originalRay.normal, ray.color.rgb / 4);
		UnlockAmbientLighting(giIndex);
		ray = originalRay;
	}
	if (!rayIsGi && (xenonRendererData.config.options & RENDER_OPTION_ACCUMULATE) == 0) {
		float giFactor = useGi ? smoothstep(GI_DRAW_MAX_DISTANCE, 0, ray.hitDistance) : 0;
		if (useGi && ray.hitDistance < GI_DRAW_MAX_DISTANCE) ray.color.rgb += albedo * GetAmbientLighting(giIndex1, facingWorldPosition, vec3(0)/*thisSurface.posInVoxel*/, ray.normal) * giFactor;
		if (recursions < RAY_MAX_RECURSION) {
			RayPayload originalRay = ray;
			ray.color.rgb = vec3(0);
			RAY_RECURSION_PUSH
				RAY_GI_PUSH
					traceRayEXT(tlas, 0, RAYTRACE_TYPE_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, rayOrigin, 0, originalRay.normal, 10000, 0);
				RAY_GI_POP
			RAY_RECURSION_POP
			originalRay.color.rgb += albedo * ray.color.rgb * (1-giFactor) / 3.1415;
			ray = originalRay;
		}
	}
	
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
