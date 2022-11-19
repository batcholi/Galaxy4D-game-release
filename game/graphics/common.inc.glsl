#ifdef __cplusplus
	#pragma once
#endif

#include "xenon/renderer/shaders/common.inc.glsl"

#define RENDERABLE_TYPE_TERRAIN 0
#define RENDERABLE_TYPE_ENTITY 1
// #define RENDERABLE_TYPE_BUILD 2
// #define RENDERABLE_TYPE_CLUTTER 3
// #define RENDERABLE_TYPE_WATER 4
// #define RENDERABLE_TYPE_FOG 5
// #define RENDERABLE_TYPE_PLASMA 6
// #define RENDERABLE_TYPE_OVERLAY 7

#define RAYTRACE_TYPE_TERRAIN (1u << RENDERABLE_TYPE_TERRAIN)
#define RAYTRACE_TYPE_ENTITY (1u << RENDERABLE_TYPE_ENTITY)
// // #define RAYTRACE_TYPE_BUILD (1u << RENDERABLE_TYPE_BUILD)
// #define RAYTRACE_TYPE_CLUTTER (1u << RENDERABLE_TYPE_CLUTTER)
// #define RAYTRACE_TYPE_WATER (1u << RENDERABLE_TYPE_WATER)
// #define RAYTRACE_TYPE_FOG (1u << RENDERABLE_TYPE_FOG)
// #define RAYTRACE_TYPE_PLASMA (1u << RENDERABLE_TYPE_PLASMA)
// #define RAYTRACE_TYPE_OVERLAY (1u << RENDERABLE_TYPE_OVERLAY)

#define SURFACE_CALLABLE_PAYLOAD 0

BUFFER_REFERENCE_STRUCT_READONLY(16) AabbData {
	aligned_float32_t aabb[6];
	aligned_uint64_t data; // Arbitrary data defined per-shader
};
STATIC_ASSERT_ALIGNED16_SIZE(AabbData, 32)

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
#endif
