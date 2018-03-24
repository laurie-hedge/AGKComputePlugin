layout (local_size_x = 32, local_size_y = 32) in;

layout (location = 0) uniform ivec4 coords;
layout(binding = 0, rgba8) uniform image2D imgIn;
layout(binding = 1, rgba8) uniform image2D imgOut;

void main()
{
	vec4 colour = imageLoad(imgIn, coords.xy);
	imageStore(imgOut, ivec2(gl_LocalInvocationID.xy), colour);
}
