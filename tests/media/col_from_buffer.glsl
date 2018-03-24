layout (local_size_x = 32, local_size_y = 32) in;

layout (std140, binding = 2) buffer ColourBlock
{
	vec3 col;
	float scale;
} colour;

layout (binding = 0, rgba8) uniform image2D imgOut;

void main()
{
	imageStore(imgOut, ivec2(gl_LocalInvocationID.xy), vec4(colour.col * colour.scale, 1.0));
}
