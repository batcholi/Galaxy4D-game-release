#include "xenon/renderer/shaders/perlint.inc.glsl"

#define TERRAIN_UNIT_MULTIPLIER 1000
#define M *TERRAIN_UNIT_MULTIPLIER
#define KM *TERRAIN_UNIT_MULTIPLIER*1000

BUFFER_REFERENCE_STRUCT(4) CelestialConfig {
	aligned_float64_t baseRadiusMillimeters;
	aligned_float64_t heightVariationMillimeters;
	aligned_float32_t hydrosphere;
	aligned_float32_t continent_ratio;
};
#ifdef GLSL
	#define config CelestialConfig(celestial_configs) // from the push_constant
#else
	CelestialConfig config;
#endif

double _getPolarity(dvec3 posNorm) {
	return clamp(abs(dot(posNorm, dvec3(0,0,1))-0.2)-0.2, 0.0, 1.0);
}

double _moutainStep(double start, double end, double value) {
	if (value > start && value < end) return mix(start, value, smoothstep(start, end, value));
	if (value < start && value > end) return mix(start, value, smoothstep(start, end, value));
	return value;
}

double Crater(u64vec3 pos, uint64_t stride, uint64_t variation) {
	double t = smoothstep(0.96, 0.995, perlint64f(pos, stride, variation));
	return max(smoothstep(0.0, 0.5, t * (0.9 + perlint64f(pos, stride / 25, variation, 3))), step(0.5, 1 - t) * 0.75) * smoothstep(1.0, 0.5, t * (0.9 + perlint64f(pos, stride / 10, variation, 3))) - 0.7;
}

double GetHeightMap(dvec3 posNorm) {
	u64vec3 pos = u64vec3(posNorm * config.baseRadiusMillimeters + 10000000000.0); // this supports planets with a maximum radius of 10'000 km and ground precision of 1 cm
	
	uint64_t variation = uint64_t(config.heightVariationMillimeters);
	double variationf = double(variation);
	
	double continents = (perlint64f(pos, 1200 KM, variation, 2) * 2 - 1) * -5 KM;
	double detail = (perlint64f(pos, 2000 KM, variation, 12) * 2 - 1) * 2 KM + perlint64f(pos, 300 M, variation, 3) * 50 M + perlint64f(pos, 25 M, variation, 2) * 10 M + perlint64f(pos, 5 M, variation, 2) * 1 M + perlint64f(pos, 1 M, variation, 2) * 0.25 M;
	
	double height = variationf * 0.3;
	height += Crater(pos, 1200 KM, variation) * 12 KM;
	height += Crater(pos, 900 KM, variation) * 9 KM;
	height += Crater(pos, 800 KM, variation) * 8 KM;
	height += Crater(pos, 600 KM, variation) * 6 KM;
	height += Crater(pos, 500 KM, variation) * 5 KM;
	height += Crater(pos, 300 KM, variation) * 3 KM;
	height += Crater(pos, 200 KM, variation) * 2 KM;
	height += Crater(pos, 100 KM, variation) * 1 KM;
	height += Crater(pos, 60 KM, variation) * 1 KM;
	height += Crater(pos, 40 KM, variation) * 1 KM;
	height += Crater(pos, 30 KM, variation) * 0.5 KM;
	height += Crater(pos, 12 KM, variation) * 0.25 KM;
	height += Crater(pos, 9 KM, variation) * 0.25 KM;
	height += Crater(pos, 6 KM, variation) * 0.1 KM;
	height += Crater(pos, 2 KM, variation) * 0.05 KM;
	height += Crater(pos, 1 KM, variation) * 0.05 KM;
	
	return (config.baseRadiusMillimeters + clamp(continents + height + detail, 0.0, variationf)) / double(TERRAIN_UNIT_MULTIPLIER);
}

#ifdef GLSL
	vec4 GetSplat(dvec3 posNorm, double height) {
		return vec4(0);
	}
	vec3 GetColor(dvec3 posNorm, double height, vec4 splat) {
		u64vec3 pos = u64vec3(posNorm * config.baseRadiusMillimeters + 10000000000.0); // this supports planets with a maximum radius of 10'000 km and ground precision of 1 cm
		uint64_t variation = uint64_t(config.heightVariationMillimeters);
		double heightRatio = (height - double(config.baseRadiusMillimeters)/TERRAIN_UNIT_MULTIPLIER) / config.heightVariationMillimeters * TERRAIN_UNIT_MULTIPLIER;
		float continents = float(perlint64f(pos, 1000 KM, variation, 2)) * 0.6 - float(perlint64f(pos, 250 KM, variation, 2)) * 0.2 + float(perlint64f(pos, 50 KM, variation, 4)) * 0.4;
		vec3 color = vec3(continents * 0.8 + 0.1);
		color = mix(vec3(0.2,0.18,0.17), color, smoothstep(0.2, 0.3, float(heightRatio)));
		color = mix(vec3(0.2,0.205,0.22), color, smoothstep(0.05, 0.2, float(heightRatio)));
		color = mix(vec3(0.1), color, smoothstep(0.0, 0.05, float(heightRatio)));
		color *= mix(float(perlint64f(pos, 1 M / 8, 1 M / 8, 6)), 1.0, 0.7);
		return clamp(mix(vec3(1), color, 1.1) * 0.7, vec3(0.05), vec3(1.0));
		// return HeatmapClamped(float(heightRatio));
	}
	float GetClutterDensity(dvec3 posNorm, double height) {
		return 0;
	}
#endif
