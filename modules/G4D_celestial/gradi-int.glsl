uint GradUintHash(uvec3 p) {
	uint h = 8u, _;
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

uint GradUint(in uvec3 pos, in uint stride, in uint maximum) {
	uvec3 d = pos % stride;
	pos /= stride;
	uint p000 = GradUintHash(pos) % maximum;
	uint p001 = GradUintHash(pos + uvec3(0,0,1)) % maximum;
	uint p010 = GradUintHash(pos + uvec3(0,1,0)) % maximum;
	uint p011 = GradUintHash(pos + uvec3(0,1,1)) % maximum;
	uint p100 = GradUintHash(pos + uvec3(1,0,0)) % maximum;
	uint p101 = GradUintHash(pos + uvec3(1,0,1)) % maximum;
	uint p110 = GradUintHash(pos + uvec3(1,1,0)) % maximum;
	uint p111 = GradUintHash(pos + uvec3(1,1,1)) % maximum;
	uint p00 = (p000 * (stride - d.x) + p100 * d.x) / stride;
	uint p01 = (p001 * (stride - d.x) + p101 * d.x) / stride;
	uint p10 = (p010 * (stride - d.x) + p110 * d.x) / stride;
	uint p11 = (p011 * (stride - d.x) + p111 * d.x) / stride;
	uint p0 = (p00 * (stride - d.y) + p10 * d.y) / stride;
	uint p1 = (p01 * (stride - d.y) + p11 * d.y) / stride;
	uint p = (p0 * (stride - d.z) + p1 * d.z) / stride;
	return min(p, maximum);
}

uint RidgedGradUint(in uvec3 pos, in uint stride, in uint maximum) {
	return uint(abs(int(GradUint(pos, stride, maximum)) - int(maximum) / 2));
}

void main() {
	uint warpX = GradUint(uvec3(gl_FragCoord.xy, 0), 16u, 48u);
	uint warpY = GradUint(uvec3(gl_FragCoord.xy, 0), 16u, 35u);
	uint warpZ = GradUint(uvec3(gl_FragCoord.xy, 0), 16u, 41u);
	uint value =
		+ RidgedGradUint(uvec3(gl_FragCoord.xy + vec2(warpX, warpY), warpZ), 64u, 128u)
		+ RidgedGradUint(uvec3(gl_FragCoord.xy + vec2(warpX, warpY)*1.5, warpZ), 32u, 64u)
		+ RidgedGradUint(uvec3(gl_FragCoord.xy + vec2(warpX, warpY)*6.5, warpZ), 16u, 32u)
		+ RidgedGradUint(uvec3(gl_FragCoord.xy, iGlobalTime*0.), 8u, 16u)
		+ RidgedGradUint(uvec3(gl_FragCoord.xy, iGlobalTime*0.), 4u, 8u)
		+ RidgedGradUint(uvec3(gl_FragCoord.xy, iGlobalTime*0.), 2u, 4u)
	;

	gl_FragColor = vec4(vec3(value) / float(
		// +128
		+64
		+32
		+16
		// +8
		// +4
	), 1);
}
