#include "gi.inc.glsl"

void main() {
	
	ray.hitDistance = gl_HitTEXT;
	ray.id = gl_InstanceCustomIndexEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	ray.t2 = 0;
	ray.ssao = 0;
	
	ENTITY_COMPUTE_SURFACE_NORMAL
	
	surface.color = ComputeSurfaceColor(ray.localPosition);
	surface.uv1 = ComputeSurfaceUV1(ray.localPosition);
	surface.uv2 = ComputeSurfaceUV2(ray.localPosition);
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
	vec3 directLighting = vec3(0);
	if (RAY_RECURSIONS < RAY_MAX_RECURSION) {
		directLighting = GetDirectLighting(ray.worldPosition, ray.normal) * (albedo + fresnel * surface.specular) * (RAY_IS_UNDERWATER? 0.5:1);
	}
	ray.color = vec4(directLighting, 1);
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
