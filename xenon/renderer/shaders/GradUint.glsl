#ifdef __cplusplus
	#pragma once
#endif
// Integer Gradient Noise (by Olivier St-Laurent)

uint32_t GradUintHash(uvec3 p) {
	uint32_t h = 8u, _;
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

uint32_t GradUint(uvec3 pos, uint32_t stride, uint32_t maximum) {
	uvec3 d = pos % stride;
	pos /= stride;
	uint32_t p000 = GradUintHash(pos) % maximum;
	uint32_t p001 = GradUintHash(pos + uvec3(0,0,1)) % maximum;
	uint32_t p010 = GradUintHash(pos + uvec3(0,1,0)) % maximum;
	uint32_t p011 = GradUintHash(pos + uvec3(0,1,1)) % maximum;
	uint32_t p100 = GradUintHash(pos + uvec3(1,0,0)) % maximum;
	uint32_t p101 = GradUintHash(pos + uvec3(1,0,1)) % maximum;
	uint32_t p110 = GradUintHash(pos + uvec3(1,1,0)) % maximum;
	uint32_t p111 = GradUintHash(pos + uvec3(1,1,1)) % maximum;
	uint32_t p00 = (p000 * (stride - d.x) + p100 * d.x) / stride;
	uint32_t p01 = (p001 * (stride - d.x) + p101 * d.x) / stride;
	uint32_t p10 = (p010 * (stride - d.x) + p110 * d.x) / stride;
	uint32_t p11 = (p011 * (stride - d.x) + p111 * d.x) / stride;
	uint32_t p0 = (p00 * (stride - d.y) + p10 * d.y) / stride;
	uint32_t p1 = (p01 * (stride - d.y) + p11 * d.y) / stride;
	uint32_t p = (p0 * (stride - d.z) + p1 * d.z) / stride;
	return min(p, maximum);
}

uint32_t RidgedGradUint(uvec3 pos, uint32_t stride, uint32_t maximum) {
	return uint32_t(abs(int(GradUint(pos, stride, maximum)) - int(maximum) / 2));
}

uint32_t GradUint(uvec3 pos, uint32_t stride, uint32_t maximum, uint32_t octaves) {
	uint32_t value = 0;
	for (uint32_t i = 1; i <= octaves; ++i) {
		value += GradUint(pos, stride/i, maximum/i) - maximum/i/2;
	}
	return value;
}
