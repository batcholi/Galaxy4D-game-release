#ifdef __cplusplus
	#pragma once
#endif
#include "game/graphics/common.inc.glsl"

#define COMPUTE_SIZE_X 16
#define COMPUTE_SIZE_Y 16

BUFFER_REFERENCE_STRUCT(4) ChunkBuffer {
	aligned_f64mat4 transform;
	aligned_f64mat4 inverseTransform;
	aligned_int32_t baseRadiusCm;
	aligned_int32_t heightVariationCm;
	aligned_i32vec4 topLeftCm;
	aligned_i32vec4 topRightCm;
	aligned_i32vec4 bottomLeftCm;
	aligned_i32vec4 bottomRightCm;
};

BUFFER_REFERENCE_STRUCT(4) VertexBuffer {
	float vertex;
};

BUFFER_REFERENCE_STRUCT(4) UvBuffer {
	vec2 uv;
};

PUSH_CONSTANT_STRUCT TerrainChunkPushConstant {
	BUFFER_REFERENCE_ADDR(ChunkBuffer) chunk;
	BUFFER_REFERENCE_ADDR(VertexBuffer) vertices;
	BUFFER_REFERENCE_ADDR(UvBuffer) uvs;
};
