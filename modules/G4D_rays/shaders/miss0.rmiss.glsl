#define SHADER_RMISS
#include "common.inc.glsl"

layout(location = 0) rayPayloadInEXT RayPayload ray;

void main() {
	bool rayIsGi = RAY_IS_GI;
	bool rayIsShadow = RAY_IS_SHADOW;
	ray.normal = vec3(0);
	ray.hitDistance = -1;
	ray.t2 = xenonRendererData.config.zFar;
	ray.id = -1;
	ray.renderableIndex = -1;
	ray.geometryIndex = -1;
	ray.primitiveIndex = -1;
	
	vec3 sunColor = GetSunColor();
	ray.color = vec4(sunColor, 1);
	
	// SUN
	const float sunGlowAngle = 0.003;
	const float sunSolidAngle = 0.0001;
	ray.color.rgb += ray.color.rgb * pow(smoothstep(0.8, 1, dot(gl_WorldRayDirectionEXT, renderer.sunDir)), 8) * 0.4;
	ray.color.rgb += ray.color.rgb * pow(smoothstep(1-sunGlowAngle, 1.002, dot(gl_WorldRayDirectionEXT, renderer.sunDir)), 2) * 0.5;
	if (!rayIsGi && !rayIsShadow) ray.color.rgb += sunColor * 0.5 * smoothstep(1-sunSolidAngle, 1, dot(gl_WorldRayDirectionEXT, renderer.sunDir)) * 100;
	
	// MOON
	const float moonSolidAngle = 0.0005;
	const vec3 moonRelPos = -renderer.sunDir - gl_WorldRayDirectionEXT;
	ray.color.rgb += pow(smoothstep(1-moonSolidAngle, 1, dot(gl_WorldRayDirectionEXT, -renderer.sunDir)), 0.25) * pow(SimplexFractal(moonRelPos*32+2.516, 3)*0.4+0.5, 1.5);
	
	// Sunset
	if (!rayIsGi) ray.color.rgb += GetSunset() * pow(clamp(dot(gl_WorldRayDirectionEXT, renderer.sunDir), 0, 1), 2) * pow(1-abs(dot(gl_WorldRayDirectionEXT, vec3(0,1,0))), 4);
}
