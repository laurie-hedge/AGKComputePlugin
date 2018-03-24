layout (local_size_x = 16, local_size_y = 16) in;

layout (binding = 0, std430) buffer TexelData
{
	vec4 texels[16 * 16];
} dataIn;

layout (binding = 1, rgba8) uniform image2D imgOut;

layout (location = 0) uniform float colMultipliers[16];

void main()
{
	vec3 baseColour = dataIn.texels[(16 * gl_LocalInvocationID.y) + gl_LocalInvocationID.x].rgb;
	vec3 colour = baseColour * colMultipliers[gl_LocalInvocationID.x];
	imageStore(imgOut, ivec2(gl_LocalInvocationID.xy), vec4(colour, 1.0));
}
