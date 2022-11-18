#include "common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

void main() {
	ivec2 compute_size = imageSize(img_resolved);
	if (compute_coord.x >= compute_size.x || compute_coord.y >= compute_size.y) return;
	
	vec4 color = imageLoad(img_resolved, compute_coord);
	
	// Copy to history BEFORE applying Tone Mapping
	imageStore(img_history, compute_coord, color);
	
	// HDR ToneMapping (Reinhard)
	if ((xenonRendererData.config.options & RENDER_OPTION_TONE_MAPPING) != 0) {
		float lumRgbTotal = xenonRendererData.histogram_avg_luminance.r + xenonRendererData.histogram_avg_luminance.g + xenonRendererData.histogram_avg_luminance.b;
		float exposure = lumRgbTotal > 0 ? xenonRendererData.histogram_avg_luminance.a / lumRgbTotal : 1;
		color.rgb = vec3(1.0) - exp(-color.rgb * clamp(exposure, xenonRendererData.config.minExposure, xenonRendererData.config.maxExposure));
	}
	
	// Contrast / Brightness
	if (xenonRendererData.config.contrast != 1.0 || xenonRendererData.config.brightness != 1.0) {
		color.rgb = mix(vec3(0.5), color.rgb, xenonRendererData.config.contrast) * xenonRendererData.config.brightness;
	}
	
	// Gamma correction
	color.rgb = pow(color.rgb, vec3(1.0 / xenonRendererData.config.gamma));
	
	imageStore(img_resolved, compute_coord, vec4(clamp(color.rgb, vec3(0), vec3(1)), 0/*component available for future use*/));
}
