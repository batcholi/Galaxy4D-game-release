#include "xenon/graphics/interface.glsl"
#ifdef __cplusplus
	#pragma once
	using namespace glm;
#endif

// up to 32 render options
#define RENDER_OPTION_TONE_MAPPING (1u<< 0)
#define RENDER_OPTION_TAA (1u<< 1)
#define RENDER_OPTION_TEMPORAL_UPSCALING (1u<< 2)
#define RENDER_OPTION_ACCUMULATE (1u<< 3)

// Debug view modes
#define RENDER_DEBUG_VIEWMODE_NONE 0

struct XenonRendererConfig {
	aligned_f32mat4 projectionMatrix;
	aligned_f32mat4 projectionMatrixWithTAA;
	aligned_float32_t renderScale;
	aligned_float32_t zNear;
	aligned_float32_t zFar;
	aligned_float32_t cameraFov;
	aligned_float32_t smoothFov;
	aligned_uint32_t debugViewMode;
	aligned_float32_t debugViewScale;
	aligned_uint32_t options;
	aligned_float32_t brightness;
	aligned_float32_t contrast;
	aligned_float32_t gamma;
	// Tone Mapping
	aligned_float32_t minExposure;
	aligned_float32_t maxExposure;
	
	aligned_float32_t _unused1;
	aligned_float32_t _unused2;
	aligned_float32_t _unused3;
	
	#ifdef __cplusplus
		XenonRendererConfig()
		: renderScale(1.0f)
		, zNear(0.001f) // 1 mm
		, zFar(1e13f) // 10 billion km
		, cameraFov(80)
		, debugViewMode(RENDER_DEBUG_VIEWMODE_NONE)
		, debugViewScale(1.0f)
		, options(0)
		, brightness(1.0f)
		, contrast(1.0f)
		, gamma(1.0f)
		, minExposure(0.001f)
		, maxExposure(10.0f)
		{}
	#endif
};
STATIC_ASSERT_ALIGNED16_SIZE(XenonRendererConfig, 64*2 + 16*4)

BUFFER_REFERENCE_STRUCT(16) HistogramTotalLuminance {
	aligned_float32_t r;
	aligned_float32_t g;
	aligned_float32_t b;
	aligned_float32_t a;
};

struct XenonRendererData {
	aligned_f32vec4 histogram_avg_luminance;
	BUFFER_REFERENCE_ADDR(HistogramTotalLuminance) histogram_total_luminance;
	aligned_uint64_t _unused;
	aligned_uint64_t frameIndex;
	aligned_float64_t deltaTime;
	XenonRendererConfig config;
};
STATIC_ASSERT_ALIGNED16_SIZE(XenonRendererData, 16 + 8*4 + sizeof(XenonRendererConfig))

struct FSRPushConstant {
	aligned_u32vec4 Const0;
	aligned_u32vec4 Const1;
	aligned_u32vec4 Const2;
	aligned_u32vec4 Const3;
	aligned_u32vec4 Sample;
};
STATIC_ASSERT_SIZE(FSRPushConstant, 80)

#define XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X 8
#define XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y 8

#define XENON_RENDERER_TEXTURE_INDEX_T uint16_t
#define XENON_RENDERER_MAX_TEXTURES 65536
#define XENON_RENDERER_TAA_SAMPLES 16

#define XENON_RENDERER_SET0_IMG_SWAPCHAIN 0
#define XENON_RENDERER_SET0_IMG_POST 1
#define XENON_RENDERER_SET0_IMG_RESOLVED 2
#define XENON_RENDERER_SET0_IMG_HISTORY 3
#define XENON_RENDERER_SET0_IMG_THUMBNAIL 4
#define XENON_RENDERER_SET0_IMG_COMPOSITE 5
#define XENON_RENDERER_SET0_IMG_DEPTH 6
#define XENON_RENDERER_SET0_IMG_MOTION 7
#define XENON_RENDERER_SET0_IMG_NORMAL_OR_DEBUG 8
#define XENON_RENDERER_SET0_SAMPLER_HISTORY 9
#define XENON_RENDERER_SET0_SAMPLER_COMPOSITE 10
#define XENON_RENDERER_SET0_SAMPLER_DEPTH 11
#define XENON_RENDERER_SET0_SAMPLER_MOTION 12
#define XENON_RENDERER_SET0_SAMPLER_RESOLVED 13
#define XENON_RENDERER_SET0_RENDERER_DATA 14
#define XENON_RENDERER_SET0_TEXTURES 15

#ifdef GLSL
	
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_SWAPCHAIN, rgba8) uniform image2D img_swapchain;
	
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_POST, rgba8) uniform image2D img_post;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_RESOLVED, rgba32f) uniform image2D img_resolved;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_HISTORY, rgba32f) uniform image2D img_history;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_THUMBNAIL, rgba32f) uniform image2D img_thumbnail;
	
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_COMPOSITE, rgba32f) uniform image2D img_composite;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_DEPTH, r32f) uniform image2D img_depth;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_MOTION, rgba32f) uniform image2D img_motion;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_NORMAL_OR_DEBUG, rgba32f) uniform image2D img_normal_or_debug;
	
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_HISTORY) uniform sampler2D sampler_history;
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_COMPOSITE) uniform sampler2D sampler_composite;
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_DEPTH) uniform sampler2D sampler_depth;
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_MOTION) uniform sampler2D sampler_motion;
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_RESOLVED) uniform sampler2D sampler_resolved;
	
	layout(set = 0, binding = XENON_RENDERER_SET0_RENDERER_DATA, std430) uniform XenonRendererDataStorageBuffer {
		XenonRendererData xenonRendererData;
	};
	
	layout(set = 0, binding = XENON_RENDERER_SET0_TEXTURES) uniform sampler2D textures[];
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helper Functions
	
	float Fresnel(const vec3 position, const vec3 normal, const float indexOfRefraction) {
		vec3 incident = normalize(position);
		float cosi = clamp(dot(incident, normal), -1, 1);
		float etai;
		float etat;
		if (cosi > 0) {
			etat = 1;
			etai = indexOfRefraction;
		} else {
			etai = 1;
			etat = indexOfRefraction;
		}
		// Compute sini using Snell's law
		float sint = etai / etat * sqrt(max(0.0, 1.0 - cosi * cosi));
		if (sint >= 1) {
			// Total internal reflection
			return 1.0;
		} else {
			float cost = sqrt(max(0.0, 1.0 - sint * sint));
			cosi = abs(cosi);
			float Rs = ((etat * cosi) - (etai * cost)) / ((etat * cosi) + (etai * cost));
			float Rp = ((etai * cosi) - (etat * cost)) / ((etai * cosi) + (etat * cost));
			return (Rs * Rs + Rp * Rp) / 2;
		}
	}

	bool Refract(inout vec3 rayDirection, in vec3 surfaceNormal, in float iOR) {
		const float vDotN = dot(rayDirection, surfaceNormal);
		const float niOverNt = vDotN > 0 ? iOR : 1.0 / iOR;
		vec3 dir = rayDirection;
		rayDirection = refract(rayDirection, -sign(vDotN) * surfaceNormal, niOverNt);
		if (dot(rayDirection,rayDirection) > 0) {
			rayDirection = normalize(rayDirection);
			return true;
		} else {
			rayDirection = normalize(reflect(dir, -sign(vDotN) * surfaceNormal));
		}
		return false;
	}

	vec3 Heatmap(float t) {
		if (t <= 0) return vec3(0);
		if (t >= 1) return vec3(1);
		const vec3 c[10] = {
			vec3(0.0f / 255.0f,   2.0f / 255.0f,  91.0f / 255.0f),
			vec3(0.0f / 255.0f, 108.0f / 255.0f, 251.0f / 255.0f),
			vec3(0.0f / 255.0f, 221.0f / 255.0f, 221.0f / 255.0f),
			vec3(51.0f / 255.0f, 221.0f / 255.0f,   0.0f / 255.0f),
			vec3(255.0f / 255.0f, 252.0f / 255.0f,   0.0f / 255.0f),
			vec3(255.0f / 255.0f, 180.0f / 255.0f,   0.0f / 255.0f),
			vec3(255.0f / 255.0f, 104.0f / 255.0f,   0.0f / 255.0f),
			vec3(226.0f / 255.0f,  22.0f / 255.0f,   0.0f / 255.0f),
			vec3(191.0f / 255.0f,   0.0f / 255.0f,  83.0f / 255.0f),
			vec3(145.0f / 255.0f,   0.0f / 255.0f,  65.0f / 255.0f)
		};

		const float s = t * 10.0f;

		const int cur = int(s) <= 9 ? int(s) : 9;
		const int prv = cur >= 1 ? cur - 1 : 0;
		const int nxt = cur < 9 ? cur + 1 : 9;

		const float blur = 0.8f;

		const float wc = smoothstep(float(cur) - blur, float(cur) + blur, s) * (1.0f - smoothstep(float(cur + 1) - blur, float(cur + 1) + blur, s));
		const float wp = 1.0f - smoothstep(float(cur) - blur, float(cur) + blur, s);
		const float wn = smoothstep(float(cur + 1) - blur, float(cur + 1) + blur, s);

		const vec3 r = wc * c[cur] + wp * c[prv] + wn * c[nxt];
		return vec3(clamp(r.x, 0.0f, 1.0f), clamp(r.y, 0.0f, 1.0f), clamp(r.z, 0.0f, 1.0f));
	}

	vec3 VarianceClamp5(in vec3 color, in sampler2D tex, in vec2 uv) {
		vec3 nearColor0 = texture(tex, uv).rgb;
		vec3 nearColor1 = textureLodOffset(tex, uv, 0.0, ivec2( 1,  0)).rgb;
		vec3 nearColor2 = textureLodOffset(tex, uv, 0.0, ivec2( 0,  1)).rgb;
		vec3 nearColor3 = textureLodOffset(tex, uv, 0.0, ivec2(-1,  0)).rgb;
		vec3 nearColor4 = textureLodOffset(tex, uv, 0.0, ivec2( 0, -1)).rgb;
		vec3 m1 = nearColor0
				+ nearColor1
				+ nearColor2
				+ nearColor3
				+ nearColor4
		; m1 /= 5;
		vec3 m2 = nearColor0*nearColor0
				+ nearColor1*nearColor1
				+ nearColor2*nearColor2
				+ nearColor3*nearColor3
				+ nearColor4*nearColor4
		; m2 /= 5;
		vec3 sigma = sqrt(m2 - m1*m1);
		const float sigmaNoVarianceThreshold = 0.0001;
		if (abs(sigma.r) < sigmaNoVarianceThreshold || abs(sigma.g) < sigmaNoVarianceThreshold || abs(sigma.b) < sigmaNoVarianceThreshold) {
			return nearColor0;
		}
		vec3 boxMin = m1 - sigma;
		vec3 boxMax = m1 + sigma;
		return clamp(color, boxMin, boxMax);
	}

#endif
