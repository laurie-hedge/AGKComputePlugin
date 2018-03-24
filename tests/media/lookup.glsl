layout (local_size_x = 4) in;

layout (location = 0) uniform int colIndices[4];
layout (location = 4) uniform vec4 colours[8];
layout (binding = 0, rgba8) uniform image2D imgOut;

void main()
{
	vec4 colour = colours[colIndices[gl_LocalInvocationID.x]];
	imageStore(imgOut, ivec2(gl_LocalInvocationID.xy), vec4(colour.rgb, 1.0));
}
