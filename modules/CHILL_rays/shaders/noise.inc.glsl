// vec4 _permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);} // used for Simplex
// dvec4 _permute(dvec4 x){return mod(((x*34.0)+1.0)*x, 289.0);} // used for Simplex

// // simple-precision Simplex noise, suitable for pos range (-1M, +1M) with a step of 0.001 and gradient of 1.0
// // Returns a float value between -1.000 and +1.000 with a distribution that strongly tends towards the center (0.5)
// float Simplex(vec3 pos){
// 	const vec2 C = vec2(1.0/6.0, 1.0/3.0);
// 	const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

// 	vec3 i = floor(pos + dot(pos, C.yyy));
// 	vec3 x0 = pos - i + dot(i, C.xxx);

// 	vec3 g = step(x0.yzx, x0.xyz);
// 	vec3 l = 1.0 - g;
// 	vec3 i1 = min( g.xyz, l.zxy);
// 	vec3 i2 = max( g.xyz, l.zxy);

// 	vec3 x1 = x0 - i1 + 1.0 * C.xxx;
// 	vec3 x2 = x0 - i2 + 2.0 * C.xxx;
// 	vec3 x3 = x0 - 1. + 3.0 * C.xxx;

// 	i = mod(i, 289.0); 
// 	vec4 p = _permute(_permute(_permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));

// 	float n_ = 1.0/7.0;
// 	vec3  ns = n_ * D.wyz - D.xzx;

// 	vec4 j = p - 49.0 * floor(p * ns.z *ns.z);

// 	vec4 x_ = floor(j * ns.z);
// 	vec4 y_ = floor(j - 7.0 * x_);

// 	vec4 x = x_ *ns.x + ns.yyyy;
// 	vec4 y = y_ *ns.x + ns.yyyy;
// 	vec4 h = 1.0 - abs(x) - abs(y);

// 	vec4 b0 = vec4(x.xy, y.xy);
// 	vec4 b1 = vec4(x.zw, y.zw);

// 	vec4 s0 = floor(b0)*2.0 + 1.0;
// 	vec4 s1 = floor(b1)*2.0 + 1.0;
// 	vec4 sh = -step(h, vec4(0.0));

// 	vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
// 	vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;

// 	vec3 p0 = vec3(a0.xy,h.x);
// 	vec3 p1 = vec3(a0.zw,h.y);
// 	vec3 p2 = vec3(a1.xy,h.z);
// 	vec3 p3 = vec3(a1.zw,h.w);

// 	vec4 norm = 1.79284291400159 - 0.85373472095314 * vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3));
// 	p0 *= norm.x;
// 	p1 *= norm.y;
// 	p2 *= norm.z;
// 	p3 *= norm.w;

// 	vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
// 	return 42.0 * dot(m*m*m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
// }

// float SimplexFractal(vec3 pos, int octaves) {
// 	float amplitude = 0.533333333333333;
// 	float frequency = 1.0;
// 	float f = Simplex(pos * frequency);
// 	for (int i = 1; i < octaves; ++i) {
// 		amplitude /= 2.0;
// 		frequency *= 2.0;
// 		f += amplitude * Simplex(pos * frequency);
// 	}
// 	return f;
// }

// #define APPLY_NORMAL_BUMP_NOISE(_noiseFunc, _position, _normal, _waveHeight) {\
// 	vec3 _tangentX = normalize(cross(normalize(vec3(0.356,1.2145,0.24537))/* fixed arbitrary vector in object space */, _normal));\
// 	vec3 _tangentY = normalize(cross(_normal, _tangentX));\
// 	mat3 _TBN = mat3(_tangentX, _tangentY, _normal);\
// 	float _altitudeTop = _noiseFunc(_position + _tangentY*_waveHeight);\
// 	float _altitudeBottom = _noiseFunc(_position - _tangentY*_waveHeight);\
// 	float _altitudeRight = _noiseFunc(_position + _tangentX*_waveHeight);\
// 	float _altitudeLeft = _noiseFunc(_position - _tangentX*_waveHeight);\
// 	vec3 _bump = normalize(vec3((_altitudeRight-_altitudeLeft), (_altitudeBottom-_altitudeTop), 2));\
// 	_normal = normalize(_TBN * _bump);\
// }


// //////////////////////////////////////
// // Random

// #extension GL_EXT_control_flow_attributes : require
// // Generates a seed for a random number generator from 2 inputs plus a backoff
// // https://github.com/nvpro-samples/optix_prime_baking/blob/332a886f1ac46c0b3eea9e89a59593470c755a0e/random.h
// // https://github.com/nvpro-samples/vk_raytracing_tutorial_KHR/tree/master/ray_tracing_jitter_cam
// // https://en.wikipedia.org/wiki/Tiny_Encryption_Algorithm
// uint InitRandomSeed(uint val0, uint val1) {
// 	uint v0 = val0, v1 = val1, s0 = 0;
// 	[[unroll]]
// 	for (uint n = 0; n < 16; n++) {
// 		s0 += 0x9e3779b9;
// 		v0 += ((v1 << 4) + 0xa341316c) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4);
// 		v1 += ((v0 << 4) + 0xad90777d) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761e);
// 	}
// 	return v0;
// }
// uint RandomInt(inout uint seed) {
// 	return (seed = 1664525 * seed + 1013904223);
// }
// float RandomFloat(inout uint seed) {
// 	return (float(RandomInt(seed) & 0x00FFFFFF) / float(0x01000000));
// }
// vec2 RandomInUnitDisk(inout uint seed) {
// 	for (;;) {
// 		const vec2 p = 2 * vec2(RandomFloat(seed), RandomFloat(seed)) - 1;
// 		if (dot(p, p) < 1) {
// 			return p;
// 		}
// 	}
// }
// vec3 RandomInUnitSphere(inout uint seed) {
// 	for (;;) {
// 		const vec3 p = 2 * vec3(RandomFloat(seed), RandomFloat(seed), RandomFloat(seed)) - 1;
// 		if (dot(p, p) < 1) {
// 			return p;
// 		}
// 	}
// }
