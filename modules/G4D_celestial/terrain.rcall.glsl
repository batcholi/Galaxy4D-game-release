#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"
#include "xenon/renderer/shaders/perlint.glsl"

const vec3 sandColor = vec3(224.0/255, 185.0/255, 120.0/255);
const vec3 rockColor = vec3(184.0/255, 175.0/255, 160.0/255);

float Sand(vec3 pos) {
	return SimplexFractal(pos*5, 6) + abs(SimplexFractal(pos*0.2, 3)) * 10;
}

float Rock(vec3 pos) {
	return clamp(
		+ (clamp(pow(abs(SimplexFractal(pos*2, 4)), 0.8), 0.2, 0.4)) * (clamp(abs(SimplexFractal(pos*2+16.26, 3)), 0.2, 0.5)) * 6
		+ SimplexFractal(pos*10, 4) * 0.2
		- 0.5
	, -0.3, 0.8)*5;
}

#define BUMP(_noiseFunc, _position, _normal, _waveLength) {\
	vec3 _tangentY = normalize(cross(_normal, vec3(1,0,0)));\
	vec3 _tangentX = cross(_normal, _tangentY);\
	float _altitudeTop = _noiseFunc(_position + _tangentY*_waveLength);\
	float _altitudeBottom = _noiseFunc(_position - _tangentY*_waveLength);\
	float _altitudeRight = _noiseFunc(_position + _tangentX*_waveLength);\
	float _altitudeLeft = _noiseFunc(_position - _tangentX*_waveLength);\
	vec3 _bump = normalize(vec3((_altitudeRight-_altitudeLeft), 2, (_altitudeBottom-_altitudeTop)));\
	_normal = normalize(_bump);\
}

void main() {
	surface.color.rgb = rockColor;
	if (surface.distance < 500) {
		float strength = smoothstep(500, 0, surface.distance);
		float waveLength = 0.003 * strength;
		float height = Rock(surface.localPosition);
		if (height > 0.0) {
			BUMP(Rock, surface.localPosition, surface.normal, waveLength)
		} else {
			surface.color.rgb = mix(surface.color.rgb, sandColor, strength);
			BUMP(Sand, surface.localPosition, surface.normal, waveLength)
		}
	}
}
