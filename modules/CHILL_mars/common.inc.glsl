#include "game/graphics/common.inc.glsl"

#define TERRAIN_TILE_COMPUTE_LOCAL_X 16
#define TERRAIN_TILE_COMPUTE_LOCAL_Y 16

BUFFER_REFERENCE_STRUCT(16) TerrainTileData {
	aligned_i32vec3 mapOffset;
	aligned_uint32_t textureIndex;
	aligned_uint32_t tileResolution;
	aligned_uint32_t metersPerPixel;
	aligned_uint32_t heightVariation;
	aligned_uint32_t tileSizeMultiplier;
};

#ifdef GLSL
	BUFFER_REFERENCE_STRUCT(4) MarsBuffer {
		float vertices[];
	};
#endif

BUFFER_REFERENCE_STRUCT(4) ActiveChunks {
	uint8_t chunks[128][128];
};

PUSH_CONSTANT_STRUCT GenerateTerrainTilePushConstant {
	BUFFER_REFERENCE_ADDR(TerrainTileData) tileData;
	BUFFER_REFERENCE_ADDR(MarsBuffer) vertexBuffer;
	BUFFER_REFERENCE_ADDR(ActiveChunks) activeChunks;
	aligned_uint64_t _unused1;
	aligned_i32vec3 playerPosition;
	aligned_uint32_t _unused2;
};
