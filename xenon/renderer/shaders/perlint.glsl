#ifdef __cplusplus
	#pragma once
#endif
// Integer Gradient Noise (by Olivier St-Laurent)

uint32_t perlint32Hash(u32vec3 p) {
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

uint32_t perlint32(u32vec3 pos, uint32_t stride, uint32_t maximum) {
	u32vec3 d = pos % stride;
	pos /= stride;
	uint32_t p000 = perlint32Hash(pos) % maximum;
	uint32_t p001 = perlint32Hash(pos + u32vec3(0,0,1)) % maximum;
	uint32_t p010 = perlint32Hash(pos + u32vec3(0,1,0)) % maximum;
	uint32_t p011 = perlint32Hash(pos + u32vec3(0,1,1)) % maximum;
	uint32_t p100 = perlint32Hash(pos + u32vec3(1,0,0)) % maximum;
	uint32_t p101 = perlint32Hash(pos + u32vec3(1,0,1)) % maximum;
	uint32_t p110 = perlint32Hash(pos + u32vec3(1,1,0)) % maximum;
	uint32_t p111 = perlint32Hash(pos + u32vec3(1,1,1)) % maximum;
	uint32_t p00 = (p000 * (stride - d.x) + p100 * d.x) / stride;
	uint32_t p01 = (p001 * (stride - d.x) + p101 * d.x) / stride;
	uint32_t p10 = (p010 * (stride - d.x) + p110 * d.x) / stride;
	uint32_t p11 = (p011 * (stride - d.x) + p111 * d.x) / stride;
	uint32_t p0 = (p00 * (stride - d.y) + p10 * d.y) / stride;
	uint32_t p1 = (p01 * (stride - d.y) + p11 * d.y) / stride;
	uint32_t p = (p0 * (stride - d.z) + p1 * d.z) / stride;
	return min(p, maximum);
}

uint32_t perlint32Ridged(u32vec3 pos, uint32_t stride, uint32_t maximum) {
	return uint32_t(abs(int32_t(perlint32(pos, stride, maximum)) - int32_t(maximum) / 2));
}

uint32_t perlint32(u32vec3 pos, uint32_t stride, uint32_t maximum, uint32_t octaves) {
	uint32_t value = 0;
	for (uint32_t i = 1; i <= octaves; ++i) {
		value += perlint32(pos, stride/i, maximum/i);
	}
	return value;
}

uint32_t perlint32Ridged(u32vec3 pos, uint32_t stride, uint32_t maximum, uint32_t octaves) {
	uint32_t value = 0;
	for (uint32_t i = 1; i <= octaves; ++i) {
		value += perlint32Ridged(pos, stride/i, maximum/i);
	}
	return value;
}

uint64_t perlint64Hash(u64vec3 p) {
	uint64_t h = 8u, _;
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

uint64_t perlint64(u64vec3 pos, uint64_t stride, uint64_t maximum) {
	u64vec3 d = pos % stride;
	pos /= stride;
	uint64_t p000 = perlint64Hash(pos) % maximum;
	uint64_t p001 = perlint64Hash(pos + u64vec3(0,0,1)) % maximum;
	uint64_t p010 = perlint64Hash(pos + u64vec3(0,1,0)) % maximum;
	uint64_t p011 = perlint64Hash(pos + u64vec3(0,1,1)) % maximum;
	uint64_t p100 = perlint64Hash(pos + u64vec3(1,0,0)) % maximum;
	uint64_t p101 = perlint64Hash(pos + u64vec3(1,0,1)) % maximum;
	uint64_t p110 = perlint64Hash(pos + u64vec3(1,1,0)) % maximum;
	uint64_t p111 = perlint64Hash(pos + u64vec3(1,1,1)) % maximum;
	uint64_t p00 = (p000 * (stride - d.x) + p100 * d.x) / stride;
	uint64_t p01 = (p001 * (stride - d.x) + p101 * d.x) / stride;
	uint64_t p10 = (p010 * (stride - d.x) + p110 * d.x) / stride;
	uint64_t p11 = (p011 * (stride - d.x) + p111 * d.x) / stride;
	uint64_t p0 = (p00 * (stride - d.y) + p10 * d.y) / stride;
	uint64_t p1 = (p01 * (stride - d.y) + p11 * d.y) / stride;
	uint64_t p = (p0 * (stride - d.z) + p1 * d.z) / stride;
	return min(p, maximum);
}

uint64_t perlint64Ridged(u64vec3 pos, uint64_t stride, uint64_t maximum) {
	return uint64_t(abs(int64_t(perlint64(pos, stride, maximum)) - int64_t(maximum) / 2));
}

uint64_t perlint64(u64vec3 pos, uint64_t stride, uint64_t maximum, uint64_t octaves) {
	uint64_t value = 0;
	for (uint64_t i = 1; i <= octaves; ++i) {
		value += perlint64(pos, stride/i, maximum/i);
	}
	return value;
}

uint64_t perlint64Ridged(u64vec3 pos, uint64_t stride, uint64_t maximum, uint64_t octaves) {
	uint64_t value = 0;
	for (uint64_t i = 1; i <= octaves; ++i) {
		value += perlint64Ridged(pos, stride/i, maximum/i);
	}
	return value;
}
