layout (local_size_x = 32, local_size_y = 32) in;

layout(location = 0) uniform vec4 drawColour;
layout(location = 1) uniform vec2 start;
layout(location = 2) uniform vec2 stop;

layout(binding = 0, rgba8) uniform image2D imgIn;
layout(binding = 1, rgba8) uniform image2D imgOut;

#define RADIUS 3.0
#define BLUR_RADIUS 1.5

void main()
{
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	vec2 point = vec2(coords);
	vec2 lineDir = normalize(stop - start);
	vec2 startToPoint = point - start;
	vec2 nearest;
	if (dot(lineDir, normalize(startToPoint)) <= 0.0) {
		nearest = start;
	}
	else if (dot(normalize(start - stop), normalize(point - stop)) <= 0.0) {
		nearest = stop;
	}
	else {
		nearest = start + (dot(lineDir, startToPoint) * lineDir);
	}
	float distFromLine = length(point - nearest);
	float alpha = min(max(0.0, distFromLine - (RADIUS - BLUR_RADIUS)) / BLUR_RADIUS, 1.0);
	vec4 baseColour = imageLoad(imgIn, coords);
	vec4 colour = mix(drawColour, baseColour, alpha);
	imageStore(imgOut, coords, colour);
}
