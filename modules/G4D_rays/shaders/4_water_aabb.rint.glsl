#define SHADER_RINT
#define SHADER_ATMOSPHERE
#include "common.inc.glsl"

hitAttributeEXT hit {
	float t1;
	float t2;
};

void main() {
	WaterData water = WaterData(AABB.data);
	if (uint64_t(water) == 0) return;
	const float r = water.radius;
	const vec3 oc = gl_WorldRayOriginEXT - water.center;
	const float a = dot(gl_WorldRayDirectionEXT, gl_WorldRayDirectionEXT);
	const float b = dot(oc, gl_WorldRayDirectionEXT);
	const float c = dot(oc, oc) - r*r;
	const float discriminantSqr = b * b - a * c;
	
	if (discriminantSqr >= 0) {
		const float det = sqrt(discriminantSqr);
		const float SPHERE_T1 = (-b - det) / a;
		const float SPHERE_T2 = (-b + det) / a;
		
		COMPUTE_BOX_INTERSECTION
		
		if (RAY_STARTS_OUTSIDE_T1_T2 || RAY_STARTS_BETWEEN_T1_T2) {
			float MIN_T1 = min(SPHERE_T1, T1);
			float MAX_T1 = max(SPHERE_T1, T1);
			
			// Outside of sphere
			if (gl_RayTminEXT < MAX_T1 && MIN_T1 < gl_RayTmaxEXT) {
				t1 = SPHERE_T1;
				t2 = SPHERE_T2;
				reportIntersectionEXT(MAX_T1, 0);
			}
			
			// Inside of sphere
			if (MAX_T1 <= gl_RayTminEXT && SPHERE_T2 >= gl_RayTminEXT) {
				t1 = SPHERE_T1;
				t2 = SPHERE_T2;
				reportIntersectionEXT(gl_RayTminEXT, 1);
			}
		}
	}
	DEBUG_RAY_INT_TIME
}
