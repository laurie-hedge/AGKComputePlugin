layout (local_size_x = 12, local_size_y = 12) in;

layout (std430, binding = 0) buffer MultTable
{
	uint elems[144];
} table;

void main()
{
	uint index = gl_LocalInvocationID.x + (gl_LocalInvocationID.y * 12);
	table.elems[index] = (gl_LocalInvocationID.x + 1) * (gl_LocalInvocationID.y + 1);
}
