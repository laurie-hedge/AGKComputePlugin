// Import the plugin.
#import_plugin Compute

// Settings for the simulation.
#constant NUM_AGENTS 100
#constant MOVE_SPEED 200
#constant ROTATION_SPEED (3.14159265359 * 4.0)

// Setup error handling.
SetErrorMode(2)
Compute.SetErrorMode(3)

// Check that compute is supported.
if not Compute.IsSupportedCompute()
	Message("Compute shaders are not supported on this platform.")
	end
endif

// Setup the window.
SetWindowTitle("Flocking Example")
SetWindowSize(1024, 768, 0)
SetWindowAllowResize(0)
SetVirtualResolution(1024, 768)

// Load assets.
arrowImage = LoadImage("arrow.png")

// Load shader.
flockingShader = Compute.LoadShader("flocking.glsl")
Compute.SetShaderConstantByName(flockingShader, "weights", 0.5, 0.8, 1.0, 1.0)

// Create agents.
agentSprites as Integer[NUM_AGENTS]
for i = 0 to NUM_AGENTS - 1
	sprite = CreateSprite(arrowImage)
	agentSprites[i] = sprite
next i

// Initialise agent buffers.
agentDataMemblock as Integer
agentDataBuffers as Integer[1]
readBuffer = 0
writeBuffer = 1
bufferSize = 4 * 4 * NUM_AGENTS

offset = 0
agentDataMemblock = CreateMemblock(bufferSize)
agentData as AgentDataType
for i = 0 to NUM_AGENTS - 1
	InitAgentData(agentData)
	offset = WriteAgentData(agentData, agentDataMemblock, offset)
next i

agentDataBuffers[readBuffer] = Compute.CreateBufferFromMemblock(agentDataMemblock)
agentDataBuffers[writeBuffer] = Compute.CreateBuffer(bufferSize)

do
	Compute.SetShaderConstantByLocation(flockingShader, 0, GetPointerX(), GetPointerY(), 0.0, 0.0)
	Compute.SetShaderConstantByLocation(flockingShader, 1, GetFrameTime() * MOVE_SPEED, 0.0, 0.0, 0.0)
	Compute.SetShaderConstantByLocation(flockingShader, 2, GetFrameTime() * ROTATION_SPEED, 0.0, 0.0, 0.0)
	Compute.SetShaderBuffer(flockingShader, agentDataBuffers[readBuffer], 0)
	Compute.SetShaderBuffer(flockingShader, agentDataBuffers[writeBuffer], 1)
	Compute.RunShader(flockingShader, NUM_AGENTS, 1, 1)
	Compute.CopyBufferToMemblock(agentDataBuffers[writeBuffer], agentDataMemblock)

	offset = 0
	for i = 0 to NUM_AGENTS - 1
		offset = ReadAgentData(agentData, agentDataMemblock, offset)
		SetSpritePositionByOffset(agentSprites[i], agentData.x, agentData.y)
		SetSpriteAngle(agentSprites[i], ATan2(agentData.dy, agentData.dx) + 90.0)
	next i

	readBuffer = not readBuffer
	writeBuffer = not writeBuffer

	Sync()
loop

type AgentDataType
	x as Float
	y as Float
	dx as Float
	dy as Float
endtype

function InitAgentData(agentData ref as AgentDataType)
	agentData.x = Random2(0, GetVirtualWidth())
	agentData.y = Random2(0, GetVirtualHeight())
	angle = Random2(0, 359)
	agentData.dx = Sin(angle)
	agentData.dy = -Cos(angle)
endfunction

function WriteAgentData(agentData ref as AgentDataType, memblock as Integer, offset as Integer)
	SetMemblockFloat(memblock, offset, agentData.x)
	SetMemblockFloat(memblock, offset + 4, agentData.y)
	SetMemblockFloat(memblock, offset + 8, agentData.dx)
	SetMemblockFloat(memblock, offset + 12, agentData.dy)
endfunction offset + 16

function ReadAgentData(agentData ref as AgentDataType, memblock as Integer, offset as Integer)
	agentData.x = GetMemblockFloat(memblock, offset)
	agentData.y = GetMemblockFloat(memblock, offset + 4)
	agentData.dx = GetMemblockFloat(memblock, offset + 8)
	agentData.dy = GetMemblockFloat(memblock, offset + 12)
endfunction offset + 16
