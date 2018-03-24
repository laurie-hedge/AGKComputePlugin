layout (local_size_x = 32, local_size_y = 32) in;

layout(location = 0) uniform vec4 drawColour;
layout(location = 1) uniform vec2 topLeft;
layout(location = 2) uniform vec2 bottomRight;

layout(binding = 0, rgba8) uniform image2D imgIn;
layout(binding = 1, rgba8) uniform image2D imgOut;

void main()
{
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	vec4 colour = imageLoad(imgIn, coords);
	if (float(coords.x) >= topLeft.x && float(coords.x) <= bottomRight.x
		&& float(coords.y) >= topLeft.y && float(coords.y) <= bottomRight.y) {
		colour = drawColour;
	}
	imageStore(imgOut, coords, colour);
}
