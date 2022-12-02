#ifdef __cplusplus
	#pragma once
#endif
#include "game/graphics/common.inc.glsl"

#define COMPUTE_SIZE_X 16
#define COMPUTE_SIZE_Y 16

#define TERRAIN_INT_MULTIPLIER 10

BUFFER_REFERENCE_STRUCT(4) ChunkBuffer {
	aligned_f64mat4 transform;
	aligned_f64mat4 inverseTransform;
	aligned_int32_t baseRadiusInt;
	aligned_int32_t heightVariationInt;
	aligned_float32_t skirtOffset;
};

BUFFER_REFERENCE_STRUCT(4) VertexBuffer {
	float vertex;
};

PUSH_CONSTANT_STRUCT TerrainChunkPushConstant {
	BUFFER_REFERENCE_ADDR(ChunkBuffer) chunk;
	BUFFER_REFERENCE_ADDR(VertexBuffer) vertices;
};
