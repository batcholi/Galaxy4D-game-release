#ifdef __cplusplus
	#pragma once
#endif
// Integer Gradient Noise (by Olivier St-Laurent)

#define USE_64_BIT_INTS

#ifdef USE_64_BIT_INTS
	#define INT int64_t
	#define UINT uint64_t
	#define UVEC3 u64vec3
#else
	#define INT int32_t
	#define UINT uint32_t
	#define UVEC3 u32vec3
#endif

UINT GradUintHash(UVEC3 p) {
	UINT h = 8u, _;
	h += p.x & 0xffffu;
	_ = (((p.x >> 16) & 0xffffu) << 11) ^ h;
	h = (h << 16) ^ _;
	h += h >> 11;
	h += p.y & 0xffffu;
	_ = (((p.y >> 16) & 0xffffu) << 11) ^ h;
	h = (h << 16) ^ _;
	h += h >> 11;
	h += p.z & 0xffffu;
	_ = (((p.z >> 16) & 0xffffu) << 11) ^ h;
	h = (h << 16) ^ _;
	h += h >> 11;
	h ^= h << 3;
	h += h >> 5;
	h ^= h << 4;
	h += h >> 17;
	h ^= h << 25;
	h += h >> 6;
	return h;
}

UINT GradUint(UVEC3 pos, UINT stride, UINT maximum) {
	UVEC3 d = pos % stride;
	pos /= stride;
	UINT p000 = GradUintHash(pos) % maximum;
	UINT p001 = GradUintHash(pos + UVEC3(0,0,1)) % maximum;
	UINT p010 = GradUintHash(pos + UVEC3(0,1,0)) % maximum;
	UINT p011 = GradUintHash(pos + UVEC3(0,1,1)) % maximum;
	UINT p100 = GradUintHash(pos + UVEC3(1,0,0)) % maximum;
	UINT p101 = GradUintHash(pos + UVEC3(1,0,1)) % maximum;
	UINT p110 = GradUintHash(pos + UVEC3(1,1,0)) % maximum;
	UINT p111 = GradUintHash(pos + UVEC3(1,1,1)) % maximum;
	UINT p00 = (p000 * (stride - d.x) + p100 * d.x) / stride;
	UINT p01 = (p001 * (stride - d.x) + p101 * d.x) / stride;
	UINT p10 = (p010 * (stride - d.x) + p110 * d.x) / stride;
	UINT p11 = (p011 * (stride - d.x) + p111 * d.x) / stride;
	UINT p0 = (p00 * (stride - d.y) + p10 * d.y) / stride;
	UINT p1 = (p01 * (stride - d.y) + p11 * d.y) / stride;
	UINT p = (p0 * (stride - d.z) + p1 * d.z) / stride;
	return min(p, maximum);
}

UINT RidgedGradUint(UVEC3 pos, UINT stride, UINT maximum) {
	return UINT(abs(INT(GradUint(pos, stride, maximum)) - INT(maximum) / 2));
}

UINT GradUint(UVEC3 pos, UINT stride, UINT maximum, uint octaves) {
	UINT value = 0;
	for (uint i = 1; i <= octaves; ++i) {
		value += GradUint(pos, stride/i, maximum/i);
	}
	return value;
}

UINT RidgedGradUint(UVEC3 pos, UINT stride, UINT maximum, UINT octaves) {
	UINT value = 0;
	for (UINT i = 1; i <= octaves; ++i) {
		value += RidgedGradUint(pos, stride/i, maximum/i);
	}
	return value;
}
