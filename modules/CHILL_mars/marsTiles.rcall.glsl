#extension GL_EXT_ray_tracing : require

#define SHADER_SURFACE
#include "common.inc.glsl"

// #include "../CHILL_rays/shaders/noise.inc.glsl"
// float NormalDetail(vec3 p) {
// 	return SimplexFractal(p*0.5, 3);
// }

void main() {
	if (surface.renderableData == 0) return;
	
	// Data
	TerrainTileData tileData = TerrainTileData(surface.renderableData);
	
	// Coord / UV
	vec3 pos = surface.localPosition;
	vec3 posPlusX = pos + vec3(tileData.metersPerPixel,0,0);
	vec3 posPlusZ = pos + vec3(0,0,tileData.metersPerPixel);
	vec2 texSizePixels = textureSize(textures[tileData.textureIndex], 0);
	vec2 coordPixels = (pos.xz + vec2(tileData.mapOffset.xz)) / float(tileData.metersPerPixel);
	vec2 coordPixelsPlusX = (posPlusX.xz + vec2(tileData.mapOffset.xz)) / float(tileData.metersPerPixel);
	vec2 coordPixelsPlusZ = (posPlusZ.xz + vec2(tileData.mapOffset.xz)) / float(tileData.metersPerPixel);
	vec2 uv = (coordPixels + 0.5) / texSizePixels + 0.5;
	vec2 uvPlusX = (coordPixelsPlusX + 0.5) / texSizePixels + 0.5;
	vec2 uvPlusZ = (coordPixelsPlusZ + 0.5) / texSizePixels + 0.5;
	
	// // Normal from height map (smooth shading)
	// float height = texture(textures[tileData.textureIndex], uv).r * tileData.heightVariation;
	// float heightPlusX = texture(textures[tileData.textureIndex], uvPlusX).r * tileData.heightVariation;
	// float heightPlusZ = texture(textures[tileData.textureIndex], uvPlusZ).r * tileData.heightVariation;
	// vec3 v0 = vec3(pos.x, height, pos.z);
	// vec3 v1 = vec3(posPlusZ.x, heightPlusZ, posPlusZ.z);
	// vec3 v2 = vec3(posPlusX.x, heightPlusX, posPlusX.z);
	// surface.normal = normalize(cross(v1 - v0, v2 - v0));
	
	// // Disturb normal
	// APPLY_NORMAL_BUMP_NOISE(NormalDetail, pos, surface.normal, 0.1)
	
	// Albedo
	surface.color.rgb = texture(textures[tileData.textureIndex+1], uv).rgb;
	
	// Reverse Gamma correction
	surface.color.rgb = pow(surface.color.rgb, vec3(2.2));
}
