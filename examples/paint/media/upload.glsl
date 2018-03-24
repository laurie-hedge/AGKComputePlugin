layout (local_size_x = 32, local_size_y = 32) in;

layout(binding = 0, rgba8) uniform image2D imgIn;
layout(binding = 1, rgba8) uniform image2D imgOutBase;
layout(binding = 2, rgba8) uniform image2D imgOutPreview;

void main()
{
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	vec4 colour = imageLoad(imgIn, coords);
	imageStore(imgOutBase, coords, colour);
	imageStore(imgOutPreview, coords, colour);
}
