#ifdef __cplusplus
	#pragma once
#endif
// Integer Gradient Noise (by Olivier St-Laurent)

// #define USE_64_BIT_INTS

#ifdef USE_64_BIT_INTS
	#define INT int64_t
	#define UINT uint64_t
	#define UVEC3 u64vec3
#else
	#define INT int32_t
	#define UINT uint32_t
	#define UVEC3 u32vec3
#endif

UINT perlintHash(UVEC3 p) {
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

UINT perlint(UVEC3 pos, UINT stride, UINT maximum) {
	UVEC3 d = pos % stride;
	pos /= stride;
	UINT p000 = perlintHash(pos) % maximum;
	UINT p001 = perlintHash(pos + UVEC3(0,0,1)) % maximum;
	UINT p010 = perlintHash(pos + UVEC3(0,1,0)) % maximum;
	UINT p011 = perlintHash(pos + UVEC3(0,1,1)) % maximum;
	UINT p100 = perlintHash(pos + UVEC3(1,0,0)) % maximum;
	UINT p101 = perlintHash(pos + UVEC3(1,0,1)) % maximum;
	UINT p110 = perlintHash(pos + UVEC3(1,1,0)) % maximum;
	UINT p111 = perlintHash(pos + UVEC3(1,1,1)) % maximum;
	UINT p00 = (p000 * (stride - d.x) + p100 * d.x) / stride;
	UINT p01 = (p001 * (stride - d.x) + p101 * d.x) / stride;
	UINT p10 = (p010 * (stride - d.x) + p110 * d.x) / stride;
	UINT p11 = (p011 * (stride - d.x) + p111 * d.x) / stride;
	UINT p0 = (p00 * (stride - d.y) + p10 * d.y) / stride;
	UINT p1 = (p01 * (stride - d.y) + p11 * d.y) / stride;
	UINT p = (p0 * (stride - d.z) + p1 * d.z) / stride;
	return min(p, maximum);
}

UINT perlintRidged(UVEC3 pos, UINT stride, UINT maximum) {
	return UINT(abs(INT(perlint(pos, stride, maximum)) - INT(maximum) / 2));
}

UINT perlint(UVEC3 pos, UINT stride, UINT maximum, uint octaves) {
	UINT value = 0;
	for (uint i = 1; i <= octaves; ++i) {
		value += perlint(pos, stride/i, maximum/i);
	}
	return value;
}

UINT perlintRidged(UVEC3 pos, UINT stride, UINT maximum, UINT octaves) {
	UINT value = 0;
	for (UINT i = 1; i <= octaves; ++i) {
		value += perlintRidged(pos, stride/i, maximum/i);
	}
	return value;
}
