layout (local_size_x = 32, local_size_y = 32) in;

layout(location = 0) uniform vec4 drawColour;
layout(location = 1) uniform vec2 origin;
layout(location = 2) uniform float radius;

layout(binding = 0, rgba8) uniform image2D imgIn;
layout(binding = 1, rgba8) uniform image2D imgOut;

#define BLUR_RADIUS 2.0

void main()
{
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	vec4 baseColour = imageLoad(imgIn, coords);
	float distFromOrigin = length(vec2(coords) - origin);
	float alpha = min(max(0.0, distFromOrigin - (radius - BLUR_RADIUS)) / BLUR_RADIUS, 1.0);
	vec4 colour = mix(drawColour, baseColour, alpha);
	imageStore(imgOut, coords, colour);
}
