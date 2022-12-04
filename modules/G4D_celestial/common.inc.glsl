#ifdef __cplusplus
	#pragma once
#endif
#include "game/graphics/common.inc.glsl"

#define COMPUTE_SIZE_X 16
#define COMPUTE_SIZE_Y 16

BUFFER_REFERENCE_STRUCT(4) ChunkBuffer {
	aligned_f64mat4 transform;
	aligned_f64mat4 inverseTransform;
	aligned_int64_t baseRadiusMm;
	aligned_int64_t heightVariationMm;
	aligned_float32_t skirtOffset;
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
