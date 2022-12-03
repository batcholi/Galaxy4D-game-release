#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "game/graphics/common.inc.glsl"
#include "xenon/renderer/shaders/perlint.glsl"

const vec3 sandColor = vec3(224.0/255, 185.0/255, 120.0/255);
const vec3 rockColor = vec3(184.0/255, 175.0/255, 160.0/255);

float Sand(vec3 pos) {
	return SimplexFractal(pos*5, 4) + abs(SimplexFractal(pos*0.2, 3)) * 10;
}

float Rock(vec3 pos) {
	return 
	 + (1 - clamp(pow(abs(SimplexFractal(pos*2, 4)), 0.8), 0.2, 0.4)) * (1 - clamp(abs(SimplexFractal(pos*2+16.26, 2)), 0.2, 0.5)) * 6
	 + SimplexFractal(pos*12, 2) * 0.2
	;
}

#define BUMP(_noiseFunc, _position, _normal, _waveHeight) {\
	vec3 _tangentX = normalize(cross(normalize(vec3(0.356,1.2145,0.24537))/* fixed arbitrary vector in object space */, _normal));\
	vec3 _tangentY = normalize(cross(_normal, _tangentX));\
	mat3 _TBN = mat3(_tangentX, _tangentY, _normal);\
	float _altitudeTop = _noiseFunc(_position + _tangentY*_waveHeight);\
	float _altitudeBottom = _noiseFunc(_position - _tangentY*_waveHeight);\
	float _altitudeRight = _noiseFunc(_position + _tangentX*_waveHeight);\
	float _altitudeLeft = _noiseFunc(_position - _tangentX*_waveHeight);\
	vec3 _bump = normalize(vec3((_altitudeRight-_altitudeLeft), (_altitudeBottom-_altitudeTop), 2));\
	_normal = normalize(_TBN * _bump);\
}

void main() {
	surface.color.rgb = rockColor;
	if (surface.distance < 500) {
		float strength = 0.003 * smoothstep(500, 0, surface.distance);
		BUMP(Rock, surface.localPosition, surface.normal, strength)
	}
}
