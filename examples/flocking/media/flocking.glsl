#define NUM_NEIGHBOURS 6
#define FLT_MAX 3.402823466e+38

layout (local_size_x = 1) in;

layout (std430, binding = 0) buffer AgentDataBlockIn
{
	vec4 agents[]; 
} dataIn;

layout (std430, binding = 1) buffer AgentDataBlockOut
{
	vec4 agents[]; 
} dataOut;

layout (location = 0) uniform vec2 targetPos;
layout (location = 1) uniform float maxMoveDist;
layout (location = 2) uniform float maxRotation;
layout (location = 3) uniform vec4 weights;

void main()
{
	vec2 agentPos = dataIn.agents[gl_GlobalInvocationID.x].xy;
	vec2 agentDir = dataIn.agents[gl_GlobalInvocationID.x].zw;

	int neighbourIndices[NUM_NEIGHBOURS];
	float neighbourDistsSquared[NUM_NEIGHBOURS];
	for (int i = 0; i < NUM_NEIGHBOURS; ++i) {
		neighbourDistsSquared[i] = FLT_MAX;
	}

	for (int i = 0; i < gl_NumWorkGroups.x; ++i) {
		if (i != gl_GlobalInvocationID.x) {
			vec2 neighbourPos = dataIn.agents[i].xy;
			vec2 toNeighbour = neighbourPos - agentPos;
			float neighbourDistSquared = dot(toNeighbour, toNeighbour);
			if (neighbourDistsSquared[NUM_NEIGHBOURS - 1] > neighbourDistSquared) {
				for (int j = NUM_NEIGHBOURS - 2; j >= 0; --j) {
					if (neighbourDistsSquared[j] > neighbourDistSquared) {
						neighbourDistsSquared[j + 1] = neighbourDistsSquared[j];
						neighbourIndices[j + 1] = neighbourIndices[j];
						if (j == 0) {
							neighbourIndices[j] = i;
							neighbourDistsSquared[j] = neighbourDistSquared;
						}
					}
					else {
						neighbourIndices[j + 1] = i;
						neighbourDistsSquared[j + 1] = neighbourDistSquared;
						break;
					}
				}
			}
		}
	}

	vec2 averagePos = vec2(0.0);
	vec2 alignment = vec2(0.0);
	vec2 separation = vec2(0.0);
	for (int i = 0; i < NUM_NEIGHBOURS; ++i) {
		averagePos += dataIn.agents[neighbourIndices[i]].xy;
		alignment += dataIn.agents[neighbourIndices[i]].zw;
		vec2 fromNeighbour = agentPos - dataIn.agents[neighbourIndices[i]].xy;
		separation += normalize(fromNeighbour) * (1.0 - (min(length(fromNeighbour), 200.0) / 200.0));
	}
	averagePos /= NUM_NEIGHBOURS;
	alignment /= NUM_NEIGHBOURS;
	separation = normalize(separation);
	vec2 cohesion = normalize(averagePos - agentPos);
	vec2 toTarget = normalize(targetPos - agentPos);
	vec2 dir = normalize(cohesion * weights.x + alignment * weights.y + separation * weights.z + toTarget * weights.w);

	float angle = atan(dir.y, dir.x) - atan(agentDir.y, agentDir.x);
	if (abs(angle) > maxRotation) {
		if (angle > 0.0) {
			angle = maxRotation;
		}
		else {
			angle = -maxRotation;
		}
		float s = sin(angle);
		float c = cos(angle);
		float nx = agentDir.x * c - agentDir.y * s;
		float ny = agentDir.x * s + agentDir.y * c;
		dir.x = nx;
		dir.y = ny;
	}

	dataOut.agents[gl_GlobalInvocationID.x].xy = agentPos + (dir * maxMoveDist);
	dataOut.agents[gl_GlobalInvocationID.x].zw = dir;
}
