layout (local_size_x = 32, local_size_y = 32) in;

layout (location = 0) uniform vec4 colour;
layout (binding = 0, rgba8) uniform image2D imgOut;

void main()
{
	imageStore(imgOut, ivec2(gl_LocalInvocationID.xy), colour);
}
