#ifdef __cplusplus
	#pragma once
#endif

#include "xenon/renderer/shaders/common.inc.glsl"

#define RENDERABLE_TYPE_TERRAIN 0
#define RENDERABLE_TYPE_ENTITY 1
#define RENDERABLE_TYPE_VOXEL 2
#define RENDERABLE_TYPE_ATMOSPHERE 3
#define RENDERABLE_TYPE_WATER 4
#define RENDERABLE_TYPE_CLUTTER 5
// #define RENDERABLE_TYPE_PLASMA 6
// #define RENDERABLE_TYPE_OVERLAY 7

#define RAYTRACE_TYPE_TERRAIN (1u << RENDERABLE_TYPE_TERRAIN)
#define RAYTRACE_TYPE_ENTITY (1u << RENDERABLE_TYPE_ENTITY)
#define RAYTRACE_TYPE_VOXEL (1u << RENDERABLE_TYPE_VOXEL)
#define RAYTRACE_TYPE_ATMOSPHERE (1u << RENDERABLE_TYPE_ATMOSPHERE)
#define RAYTRACE_TYPE_WATER (1u << RENDERABLE_TYPE_WATER)
#define RAYTRACE_TYPE_CLUTTER (1u << RENDERABLE_TYPE_CLUTTER)
// #define RAYTRACE_TYPE_PLASMA (1u << RENDERABLE_TYPE_PLASMA)
// #define RAYTRACE_TYPE_OVERLAY (1u << RENDERABLE_TYPE_OVERLAY)

#define SURFACE_CALLABLE_PAYLOAD 0
#define VOXEL_SURFACE_CALLABLE_PAYLOAD 1

BUFFER_REFERENCE_STRUCT_READONLY(16) AabbData {
	aligned_float32_t aabb[6];
	aligned_uint64_t data; // Arbitrary data defined per-shader
};
STATIC_ASSERT_ALIGNED16_SIZE(AabbData, 32)

BUFFER_REFERENCE_STRUCT_READONLY(16) AtmosphereData {
	aligned_f32vec4 rayleigh;
	aligned_f32vec4 mie;
	aligned_float32_t outerRadius;
	aligned_float32_t innerRadius;
	aligned_float32_t sunGlow;
	aligned_float32_t temperature;
};
STATIC_ASSERT_ALIGNED16_SIZE(AtmosphereData, 48)

BUFFER_REFERENCE_STRUCT_READONLY(16) WaterData {
	aligned_f64vec3 center;
	aligned_float64_t radius;
};
STATIC_ASSERT_ALIGNED16_SIZE(AtmosphereData, 48)

struct GeometryInfo {
	aligned_f32vec4 color;
	aligned_uint64_t data;
	aligned_uint32_t surfaceIndex;
	aligned_uint32_t textureIndex;
};
STATIC_ASSERT_ALIGNED16_SIZE(GeometryInfo, 32)

BUFFER_REFERENCE_STRUCT_READONLY(16) GeometryData {
	BUFFER_REFERENCE_ADDR(AabbData) aabbs;
	aligned_VkDeviceAddress vertices;
	aligned_VkDeviceAddress indices16;
	aligned_VkDeviceAddress indices32;
	aligned_VkDeviceAddress normals;
	aligned_VkDeviceAddress colors;
	aligned_VkDeviceAddress uv1;
	aligned_VkDeviceAddress uv2;
	GeometryInfo info;
};
STATIC_ASSERT_ALIGNED16_SIZE(GeometryData, 96)

BUFFER_REFERENCE_STRUCT_READONLY(16) RenderableInstanceData {
	BUFFER_REFERENCE_ADDR(GeometryData) geometries;
	aligned_uint64_t data; // custom data defined per-shader
};
STATIC_ASSERT_ALIGNED16_SIZE(RenderableInstanceData, 16)

BUFFER_REFERENCE_STRUCT(16) AimBuffer {
	aligned_f32vec3 localPosition;
	aligned_uint32_t aimID;
	aligned_f32vec3 worldSpaceHitNormal;
	aligned_uint32_t primitiveIndex;
	aligned_f32vec3 worldSpacePosition; // MUST COMPENSATE FOR ORIGIN RESET
	aligned_float32_t hitDistance;
	aligned_f32vec4 color;
	aligned_f32vec3 viewSpaceHitNormal;
	aligned_uint32_t tlasInstanceIndex;
	aligned_f32vec3 _unused;
	aligned_uint32_t geometryIndex;
};
STATIC_ASSERT_ALIGNED16_SIZE(AimBuffer, 96)

#ifdef GLSL
	struct Surface {
		vec4 color;
		vec3 normal;
		float distance;
		vec3 emission;
		float specular;
		vec3 localPosition;
		float ior;
		GeometryInfo geometryInfo;
		uint64_t renderableData;
		uint64_t aabbData;
		uint32_t renderableIndex;
		uint32_t geometryIndex;
		uint32_t primitiveIndex;
		uint32_t aimID;
		vec2 uv1;
		vec2 uv2;
	};
	#if defined(SHADER_RCHIT)
		layout(location = SURFACE_CALLABLE_PAYLOAD) callableDataEXT Surface surface;
	#endif
	#if defined(SHADER_SURFACE)
		layout(location = SURFACE_CALLABLE_PAYLOAD) callableDataInEXT Surface surface;
	#endif
	
	float STEFAN_BOLTZMANN_CONSTANT = 5.670374419184429E-8;
	float GetSunRadiationAtDistanceSqr(float temperature, float radius, float distanceSqr) {
		float radiusSqr = pow(radius, 2.0);
		return radiusSqr * STEFAN_BOLTZMANN_CONSTANT * pow(temperature, 4.0) / distanceSqr;
	}
	float GetRadiationAtTemperatureForWavelength(float temperature_kelvin, float wavelength_nm) {
		float hcltkb = 14387769.6 / (wavelength_nm * temperature_kelvin);
		float w = wavelength_nm / 1000.0;
		return 119104.2868 / (w * w * w * w * w * (exp(hcltkb) - 1.0));
	}
	vec3 GetEmissionColor(float temperatureKelvin) {
		return vec3(
			GetRadiationAtTemperatureForWavelength(temperatureKelvin, 680.0),
			GetRadiationAtTemperatureForWavelength(temperatureKelvin, 550.0),
			GetRadiationAtTemperatureForWavelength(temperatureKelvin, 440.0)
		);
	}
	vec3 GetEmissionColor(vec4 emission_temperature) {
		return emission_temperature.rgb + GetEmissionColor(emission_temperature.a);
	}

#endif
