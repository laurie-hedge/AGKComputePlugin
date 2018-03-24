function TestCopyBufferToMemblock()
	StartTest("CopyBufferToMemblock")
	memSource = CreateMemblock(40)
	for i = 0 to 9
		SetMemblockInt(memSource, i * 4, i + 1)
	next i
	buffer = Compute.CreateBufferFromMemblock(memSource)
	memDest = CreateMemblock(40)
	Compute.CopyBufferToMemblock(buffer, memDest)
	result = 1
	for i = 0 to 9
		if GetMemblockInt(memDest, i * 4) <> i + 1
			result = 0
			exit
		endif
	next i
	EndTest(result)
	DeleteMemblock(memSource)
	DeleteMemblock(memDest)
	Compute.DeleteBuffer(buffer)
endfunction

function TestCreateBufferFromMemblock()
	StartTest("CreateBufferFromMemblock")
	memblock = CreateMemblock(1)
	buffer = Compute.CreateBufferFromMemblock(memblock)
	DeleteMemblock(memblock)
	EndTest(buffer <> 0)
	Compute.DeleteBuffer(buffer)
endfunction

function TestGlobalWorkGroups()
	StartTest("running a compute shader with multiple global work groups")
	imgSource = CreateImageFromColor(32, 32, 0, 0, 255)
	imgDest = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("copy_global.glsl")
	Compute.SetShaderImage(computeShader, imgSource, 0)
	Compute.SetShaderImage(computeShader, imgDest, 1)
	Compute.RunShader(computeShader, 32, 32, 1)
	EndTest(ImagesMatch(imgSource, imgDest))
	Compute.DeleteShader(computeShader)
	DeleteImage(imgSource)
	DeleteImage(imgDest)
endfunction

function TestLoadShaderFromFile()
	StartTest("LoadShader")
	computeShader = Compute.LoadShader("do_nothing.glsl")
	EndTest(computeShader <> 0)
	Compute.DeleteShader(computeShader)
endfunction

function TestLoadShaderFromString()
	StartTest("LoadShaderFromString")
	shaderSource$ = "#version 440 core" + Chr(10) + "layout (local_size_x = 32, local_size_y = 32) in;" + Chr(10) + "void main() { }" + Chr(10)
	computeShader = Compute.LoadShaderFromString(shaderSource$)
	EndTest(computeShader <> 0)
	Compute.DeleteShader(computeShader)
endfunction

function TestNamedShaderArrayConstants()
	StartTest("SetShaderArray[Int]ConstantByName")
	refImage = LoadImage("palette.png")
	imgDest = CreateRenderImage(4, 1, 0, 0)
	computeShader = Compute.LoadShader("lookup.glsl")
	Compute.SetShaderConstantArrayIntByName(computeShader, "colIndices", 0, 6, 0, 0, 0)
	Compute.SetShaderConstantArrayIntByName(computeShader, "colIndices", 1, 2, 0, 0, 0)
	Compute.SetShaderConstantArrayIntByName(computeShader, "colIndices", 2, 0, 0, 0, 0)
	Compute.SetShaderConstantArrayIntByName(computeShader, "colIndices", 3, 5, 0, 0, 0)
	Compute.SetShaderConstantArrayByName(computeShader, "colours", 0, 0.0, 0.0, 1.0, 1.0)
	Compute.SetShaderConstantArrayByName(computeShader, "colours", 1, 0.0, 0.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByName(computeShader, "colours", 2, 0.0, 1.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByName(computeShader, "colours", 3, 0.0, 0.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByName(computeShader, "colours", 4, 0.0, 0.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByName(computeShader, "colours", 5, 1.0, 1.0, 1.0, 1.0)
	Compute.SetShaderConstantArrayByName(computeShader, "colours", 6, 1.0, 0.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByName(computeShader, "colours", 7, 0.0, 0.0, 0.0, 1.0)
	Compute.SetShaderImage(computeShader, imgDest, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImagesMatch(refImage, imgDest))
	Compute.DeleteShader(computeShader)
	DeleteImage(refImage)
	DeleteImage(imgDest)
endfunction

function TestNamedShaderConstants()
	StartTest("SetShaderConstantByName")
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("colour.glsl")
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.SetShaderConstantByName(computeShader, "colour", 1.0, 1.0, 0.0, 1.0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImageMatchesColour(img, 255, 255, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction

function TestNamedShaderIntConstants()
	StartTest("SetShaderShaderConstantIntByName")
	imgPalette = LoadImage("palette.png")
	imgDest = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("copy_texel.glsl")
	Compute.SetShaderImage(computeShader, imgPalette, 0)
	Compute.SetShaderImage(computeShader, imgDest, 1)
	Compute.SetShaderConstantIntByName(computeShader, "coords", 1, 0, 0, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImageMatchesColour(imgDest, 0, 255, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(imgPalette)
	DeleteImage(imgDest)
endfunction

function TestNotPrependShaderVersion()
	StartTest("not adding shader version directive when provided by the user")
	shaderSource$ = Chr(10) + Chr(10) + "  		#version 440 core" + Chr(10) + "layout (local_size_x = 32, local_size_y = 32) in;" + Chr(10) + "void main() { }" + Chr(10)
	computeShader = Compute.LoadShaderFromString(shaderSource$)
	EndTest(computeShader <> 0)
	Compute.DeleteShader(computeShader)
endfunction

function TestPrependShaderVersion()
	StartTest("adding shader version directive automatically")
	shaderSource$ = "layout (local_size_x = 32, local_size_y = 32) in;" + Chr(10) + "void main() { }" + Chr(10)
	computeShader = Compute.LoadShaderFromString(shaderSource$)
	EndTest(computeShader <> 0)
	Compute.DeleteShader(computeShader)
endfunction

function TestQueryBufferSize()
	StartTest("GetBufferSize")
	buffer = Compute.CreateBuffer(123)
	EndTest(Compute.GetBufferSize(buffer) = 123)
	Compute.DeleteBuffer(buffer)
endfunction

function TestQueryMaxBufferSize()
	StartTest("GetMaxBufferSize")
	maxSize = Compute.GetMaxBufferSize()
	EndTest(maxSize >= 16777216)
endfunction

function TestQueryMemorySize()
	StartTest("GetMaxSharedMemory")
	max = Compute.GetMaxSharedMemory()
	EndTest(max >= 32000)
endfunction

function TestQueryNumWorkGroups()
	StartTest("GetMaxNumWorkGroups functions")
	maxX = Compute.GetMaxNumWorkGroupsX()
	maxY = Compute.GetMaxNumWorkGroupsY()
	maxZ = Compute.GetMaxNumWorkGroupsZ()
	EndTest(maxX >= 65535 and maxY >= 65535 and maxZ >= 65535)
endfunction

function TestQueryWorkGroupSize()
	StartTest("GetMaxWorkGroupSize functions")
	maxX = Compute.GetMaxWorkGroupSizeX()
	maxY = Compute.GetMaxWorkGroupSizeY()
	maxZ = Compute.GetMaxWorkGroupSizeZ()
	maxTotal = Compute.GetMaxWorkGroupSizeTotal()
	EndTest(maxX >= 1024 and maxY >= 1024 and maxZ >= 64 and maxTotal >= 1024)
endfunction

function TestReadBufferInShader()
	StartTest("reading a buffer in a compute shader")
	memblock = CreateMemblock(16)
	SetMemblockFloat(memblock, 0, 1.0)
	SetMemblockFloat(memblock, 4, 0.0)
	SetMemblockFloat(memblock, 8, 0.0)
	SetMemblockFloat(memblock, 12, 0.5)
	buffer = Compute.CreateBufferFromMemblock(memblock)
	DeleteMemblock(memblock)
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("col_from_buffer.glsl")
	Compute.SetShaderBuffer(computeShader, buffer, 2)
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImageMatchesColour(img, 128, 0, 0))
	Compute.DeleteBuffer(buffer)
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction

function TestReadFromImage()
	StartTest("reading from an image")
	imgSource = CreateImageFromColor(32, 32, 0, 0, 255)
	imgDest = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("copy.glsl")
	Compute.SetShaderImage(computeShader, imgSource, 0)
	Compute.SetShaderImage(computeShader, imgDest, 1)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImagesMatch(imgSource, imgDest))
	Compute.DeleteShader(computeShader)
	DeleteImage(imgSource)
	DeleteImage(imgDest)
endfunction

function TestReadFromRenderImage()
	StartTest("reading from an image")
	imgSource = CreateRenderImage(32, 32, 0, 0)
	SetRenderToImage(imgSource, 0)
	SetClearColor(0, 0, 255)
	ClearScreen()
	SetRenderToScreen()
	SetClearColor(0, 0, 0)
	imgDest = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("copy.glsl")
	Compute.SetShaderImage(computeShader, imgSource, 0)
	Compute.SetShaderImage(computeShader, imgDest, 1)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImagesMatch(imgSource, imgDest))
	Compute.DeleteShader(computeShader)
	DeleteImage(imgSource)
	DeleteImage(imgDest)
endfunction

function TestRenderAfterCompute()
	StartTest("rendering works after running a compute shader")
	imgDest = CreateRenderImage(32, 32, 0, 0)
	colImage = CreateImageFromColor(32, 32, 255, 0, 0)
	sprite = CreateSprite(colImage)
	SetSpriteSize(sprite, GetVirtualWidth(), GetVirtualHeight())
	computeShader = Compute.LoadShader("do_nothing.glsl")
	Compute.RunShader(computeShader, 1, 1, 1)
	SetClearColor(0, 0, 0)
	SetRenderToImage(imgDest, 0)
	ClearScreen()
	Render()
	EndTest(ImageMatchesColour(imgDest, 255, 0, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(imgDest)
	DeleteImage(colImage)
	DeleteSprite(sprite)
endfunction

function TestRunComputeShader()
	StartTest("RunShader")
	computeShader = Compute.LoadShader("do_nothing.glsl")
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestShaderArrayConstants()
	StartTest("SetShaderConstantArray[Int]ByLocation")
	refImage = LoadImage("palette.png")
	imgDest = CreateRenderImage(4, 1, 0, 0)
	computeShader = Compute.LoadShader("lookup.glsl")
	Compute.SetShaderConstantArrayIntByLocation(computeShader, 0, 0, 6, 0, 0, 0)
	Compute.SetShaderConstantArrayIntByLocation(computeShader, 0, 1, 2, 0, 0, 0)
	Compute.SetShaderConstantArrayIntByLocation(computeShader, 0, 2, 0, 0, 0, 0)
	Compute.SetShaderConstantArrayIntByLocation(computeShader, 0, 3, 5, 0, 0, 0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 4, 0, 0.0, 0.0, 1.0, 1.0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 4, 1, 0.0, 0.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 4, 2, 0.0, 1.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 4, 3, 0.0, 0.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 4, 4, 0.0, 0.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 4, 5, 1.0, 1.0, 1.0, 1.0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 4, 6, 1.0, 0.0, 0.0, 1.0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 4, 7, 0.0, 0.0, 0.0, 1.0)
	Compute.SetShaderImage(computeShader, imgDest, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImagesMatch(refImage, imgDest))
	Compute.DeleteShader(computeShader)
	DeleteImage(refImage)
	DeleteImage(imgDest)
endfunction

function TestShaderConstants()
	StartTest("SetShaderConstantByLocation")
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("colour.glsl")
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.SetShaderConstantByLocation(computeShader, 0, 1.0, 1.0, 0.0, 1.0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImageMatchesColour(img, 255, 255, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction

function TestShaderIntConstants()
	StartTest("SetShaderShaderConstantIntByLocation")
	imgPalette = LoadImage("palette.png")
	imgDest = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("copy_texel.glsl")
	Compute.SetShaderImage(computeShader, imgPalette, 0)
	Compute.SetShaderImage(computeShader, imgDest, 1)
	Compute.SetShaderConstantIntByLocation(computeShader, 0, 1, 0, 0, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImageMatchesColour(imgDest, 0, 255, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(imgPalette)
	DeleteImage(imgDest)
endfunction

function TestSwapBuffers()
	StartTest("swapping buffers on a compute shader")
	computeShader = Compute.LoadShader("mult_tables.glsl")
	buf0 = Compute.CreateBuffer(4 * 12 * 12)
	buf1 = Compute.CreateBuffer(4 * 12 * 12)
	Compute.SetShaderBuffer(computeShader, buf0, 0)
	Compute.SetShaderBuffer(computeShader, buf1, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	mem0 = Compute.CreateMemblockFromBuffer(buf0)
	mem1 = Compute.CreateMemblockFromBuffer(buf1)
	EndTest(GetMemblockInt(mem0, (12 * 11 * 4) + (11 * 4)) <> 144 and GetMemblockInt(mem1, (12 * 11 * 4) + (11 * 4)) = 144)
	DeleteMemblock(mem0)
	DeleteMemblock(mem1)
	Compute.DeleteBuffer(buf0)
	Compute.DeleteBuffer(buf1)
	Compute.DeleteShader(computeShader)
endfunction

function TestSwapImages()
	StartTest("swapping images on a compute shader")
	img0 = CreateRenderImage(32, 32, 0, 0)
	img1 = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("red.glsl")
	Compute.SetShaderImage(computeShader, img0, 0)
	Compute.SetShaderImage(computeShader, img1, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(not ImageMatchesColour(img0, 255, 0, 0) and ImageMatchesColour(img1, 255, 0, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(img0)
	DeleteImage(img1)
endfunction

function TestUnbindBuffer()
	StartTest("unbinding a buffer from a compute shader")
	computeShader = Compute.LoadShader("mult_tables.glsl")
	memSrc = CreateMemblock(4 * 12 * 12)
	for i = 0 to (4 * 12 * 12) - 1 step 4
		SetMemblockInt(memSrc, i, 0)
	next i
	buf = Compute.CreateBufferFromMemblock(memSrc)
	DeleteMemblock(memSrc)
	Compute.SetShaderBuffer(computeShader, buf, 0)
	Compute.SetShaderBuffer(computeShader, 0, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	mem = Compute.CreateMemblockFromBuffer(buf)
	EndTest(GetMemblockInt(mem, (12 * 11 * 4) + (11 * 4)) <> 144)
	DeleteMemblock(mem)
	Compute.DeleteBuffer(buf)
	Compute.DeleteShader(computeShader)
endfunction

function TestUnbindBufferAfterRun()
	StartTest("unbinding a buffer from a compute shader after running the shader with the buffer bound")
	computeShader = Compute.LoadShader("mult_tables.glsl")
	memSrc = CreateMemblock(4 * 12 * 12)
	for i = 0 to (4 * 12 * 12) - 1 step 4
		SetMemblockInt(memSrc, i, 0)
	next i
	buf = Compute.CreateBufferFromMemblock(memSrc)
	Compute.SetShaderBuffer(computeShader, buf, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	Compute.UpdateBufferFromMemblock(buf, memSrc)
	Compute.SetShaderBuffer(computeShader, 0, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	mem = Compute.CreateMemblockFromBuffer(buf)
	EndTest(GetMemblockInt(mem, (12 * 11 * 4) + (11 * 4)) <> 144)
	DeleteMemblock(memSrc)
	DeleteMemblock(mem)
	Compute.DeleteBuffer(buf)
	Compute.DeleteShader(computeShader)
endfunction

function TestUnbindImage()
	StartTest("unbinding an image from a compute shader")
	img = CreateRenderImage(32, 32, 0, 0)
	SetClearColor(0, 0, 0)
	SetRenderToImage(img, 0)
	ClearScreen()
	SetRenderToScreen()
	computeShader = Compute.LoadShader("red.glsl")
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.SetShaderImage(computeShader, 0, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(not ImageMatchesColour(img, 255, 0, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction

function TestUnbindImageAfterRun()
	StartTest("unbinding an image from a compute shader after running the shader with the image bound")
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("red.glsl")
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	SetClearColor(0, 0, 0)
	SetRenderToImage(img, 0)
	ClearScreen()
	SetRenderToScreen()
	Compute.SetShaderImage(computeShader, 0, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(not ImageMatchesColour(img, 255, 0, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction

function TestUpdateBufferFromMemblock()
	StartTest("UpdateBufferFromMemblock")
	memblock = CreateMemblock(16)
	SetMemblockFloat(memblock, 0, 1.0)
	SetMemblockFloat(memblock, 4, 0.0)
	SetMemblockFloat(memblock, 8, 0.0)
	SetMemblockFloat(memblock, 12, 0.5)
	buffer = Compute.CreateBufferFromMemblock(memblock)
	SetMemblockFloat(memblock, 0, 0.0)
	SetMemblockFloat(memblock, 4, 0.0)
	SetMemblockFloat(memblock, 8, 1.0)
	SetMemblockFloat(memblock, 12, 0.5)
	Compute.UpdateBufferFromMemblock(buffer, memblock)
	DeleteMemblock(memblock)
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("col_from_buffer.glsl")
	Compute.SetShaderBuffer(computeShader, buffer, 2)
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImageMatchesColour(img, 0, 0, 128))
	Compute.DeleteBuffer(buffer)
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction

function TestUpdateBufferWithLargerMemblock()
	StartTest("updating a buffer with a memblock increases the size of the buffer")
	mem0 = CreateMemblock(100)
	mem1 = CreateMemblock(500)
	buffer = Compute.CreateBufferFromMemblock(mem0)
	Compute.UpdateBufferFromMemblock(buffer, mem1)
	EndTest(Compute.GetBufferSize(buffer) = 500)
	Compute.DeleteBuffer(buffer)
	DeleteMemblock(mem0)
	DeleteMemblock(mem1)
endfunction

function TestUsingConstantBuffersAndImagesTogether()
	StartTest("using shader constants, buffers, and images together")
	computeShader = Compute.LoadShader("all.glsl")
	srcMemblock = CreateMemblock(16 * 16 * 4 * 4)
	expectedTexels as Integer[15, 15, 2]
	memblockOffset = 0
	for y = 0 to 15
		for x = 0 to 15
			if x < 8 then red# = 1.0 else red# = 0.0
			if y < 8 then blue# = 1.0 else blue# = 0.0
			if x >= 8 and y >= 8 then green# = 1.0 else green# = 0
			SetMemblockFloat(srcMemblock, memblockOffset, red#)
			SetMemblockFloat(srcMemblock, memblockOffset + 4, green#)
			SetMemblockFloat(srcMemblock, memblockOffset + 8, blue#)
			expectedTexels[x, y, 0] = (red# * (x * (1.0 / 16.0))) * 255.0
			expectedTexels[x, y, 1] = (green# * (x * (1.0 / 16.0))) * 255.0
			expectedTexels[x, y, 2] = (blue# * (x * (1.0 / 16.0))) * 255.0
			memblockOffset = memblockOffset + 16
		next x
	next y
	buffer = Compute.CreateBufferFromMemblock(srcMemblock)
	image = CreateRenderImage(16, 16, 0, 0)
	for i = 0 to 15
		Compute.SetShaderConstantArrayByLocation(computeShader, 0, i, i * (1.0 / 16.0), 0.0, 0.0, 0.0)
	next i
	Compute.SetShaderBuffer(computeShader, buffer, 0)
	Compute.SetShaderImage(computeShader, image, 1)
	Compute.RunShader(computeShader, 1, 1, 1)
	resultMemblock = CreateMemblockFromImage(image)
	resultsMatch = 1
	memblockOffset = 12
	for y = 0 to 15
		for x = 0 to 15
			if GetMemblockByte(resultMemblock, memblockOffset) <> expectedTexels[x, y, 0] or GetMemblockByte(resultMemblock, memblockOffset + 1) <> expectedTexels[x, y, 1] or GetMemblockByte(resultMemblock, memblockOffset + 2) <> expectedTexels[x, y, 2]
				resultsMatch = 0
				exit
			endif
			memblockOffset = memblockOffset + 4
		next x
	next y
	EndTest(resultsMatch)
	DeleteShader(computeShader)
	Compute.DeleteBuffer(buffer)
	DeleteImage(image)
	DeleteMemblock(srcMemblock)
	DeleteMemblock(resultMemblock)
endfunction

function TestWriteToBufferFromShader()
	StartTest("writing to a buffer from a computer shader")
	computeShader = Compute.LoadShader("mult_tables.glsl")
	buffer = Compute.CreateBuffer(4 * 12 * 12)
	Compute.SetShaderBuffer(computeShader, buffer, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	memblock = Compute.CreateMemblockFromBuffer(buffer)
	result = 1
	nextOffset = 0
	for y = 1 to 12
		for x = 1 to 12
			if GetMemblockInt(memblock, nextOffset) <> x * y
				result = 0
				goto test_end
			endif
			nextOffset = nextOffset + 4
		next x
	next y
test_end:
	EndTest(result)
	DeleteMemblock(memblock)
	Compute.DeleteBuffer(buffer)
	Compute.DeleteShader(computeShader)
endfunction

function TestWriteToImage()
	StartTest("writing to an image")
	img = CreateImageFromColor(32, 32, 0, 0, 255)
	computeShader = Compute.LoadShader("red.glsl")
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImageMatchesColour(img, 255, 0, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction

function TestWriteToMipmappedRenderImage()
	StartTest("writing to a mipmapped image")
	img = CreateRenderImage(32, 32, 0, 1)
	computeShader = Compute.LoadShader("red.glsl")
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImageMatchesColour(img, 255, 0, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction

function TestWriteToRenderImage()
	StartTest("writing to a render image")
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("red.glsl")
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(ImageMatchesColour(img, 255, 0, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction




function TestAttachDeletedBuffer()
	StartTest("attaching a buffer that has been deleted to a shader fails gracefully")
	computeShader = Compute.LoadShader("mult_tables.glsl")
	buffer = Compute.CreateBuffer(4 * 12 * 12)
	Compute.DeleteBuffer(buffer)
	Compute.SetShaderBuffer(computeShader, buffer, 0)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestAttachDeletedImage()
	StartTest("attaching a deleted image fails gracefully")
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("do_nothing.glsl")
	DeleteImage(img)
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.RunShader(computeShader, Compute.GetMaxWorkGroupSizeX() + 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestAttachNonExistentBuffer()
	StartTest("attaching a non existent buffer to a shader fails gracefully")
	computeShader = Compute.LoadShader("mult_tables.glsl")
	Compute.SetShaderBuffer(computeShader, 1000, 0)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestAttachNonExistentImage()
	StartTest("attaching a non existent image fails gracefully")
	computeShader = Compute.LoadShader("do_nothing.glsl")
	Compute.SetShaderImage(computeShader, 1000, 0)
	Compute.RunShader(computeShader, Compute.GetMaxWorkGroupSizeX() + 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestAttachToInvalidAttachPoint()
	StartTest("attaching to an invalid attach point fails gracefully")
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("red.glsl")
	Compute.SetShaderImage(computeShader, img, 8)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction

function TestCopyDataFromNonExistentBuffer()
	StartTest("copying from a non existent buffer fails gracefully")
	memblock = CreateMemblock(10)
	Compute.CopyBufferToMemblock(1000, memblock)
	EndTest(1)
	DeleteMemblock(memblock)
endfunction

function TestCopyDataToNonExistentMemblock()
	StartTest("copying from buffer into non existent memblock fails gracefully")
	buffer = Compute.CreateBuffer(10)
	Compute.CopyBufferToMemblock(buffer, 1000)
	EndTest(1)
	Compute.DeleteBuffer(buffer)
endfunction

function TestCopyDataToTooSmallMemblock()
	StartTest("copying buffer into a memblock that is too small fails gracefully")
	memSource = CreateMemblock(1000)
	SetMemblockInt(memSource, 0, 100)
	buffer = Compute.CreateBufferFromMemblock(memSource)
	memDest = CreateMemblock(999)
	Compute.CopyBufferToMemblock(buffer, memDest)
	EndTest(GetMemblockInt(memDest, 0) <> 100)
	DeleteMemblock(memSource)
	DeleteMemblock(memDest)
	Compute.DeleteBuffer(buffer)
endfunction

function TestCreateBufferFromDeletedMemblock()
	StartTest("creating a buffer from a memblock that has been deleted fails gracefully")
	memblock = CreateMemblock(10)
	DeleteMemblock(memblock)
	buffer = Compute.CreateBufferFromMemblock(memblock)
	EndTest(buffer = 0)
endfunction

function TestCreateBufferFromEmptyMemblock()
	StartTest("creating a buffer from an empty memblock fails gracefully")
	memblock = CreateMemblock(0)
	buffer = Compute.CreateBufferFromMemblock(memblock)
	EndTest(buffer = 0)
	DeleteMemblock(memblock)
endfunction

function TestCreateBufferFromNonExistentMemblock()
	StartTest("creating a buffer from a non existent memblock fails gracefully")
	buffer = Compute.CreateBufferFromMemblock(1000)
	EndTest(buffer = 0)
endfunction

function TestCreateMemblockFromDeletedBuffer()
	StartTest("creating a memblock from a buffer that has been deleted fails gracefully")
	buffer = Compute.CreateBuffer(10)
	Compute.DeleteBuffer(buffer)
	memblock = Compute.CreateMemblockFromBuffer(buffer)
	EndTest(memblock = 0)
endfunction

function TestCreateMemblockFromNotExistentBuffer()
	StartTest("creating a memblock from a non existent buffer fails gracefully")
	memblock = Compute.CreateMemblockFromBuffer(1000)
	EndTest(memblock = 0)
endfunction

function TestCreateZeroSizedBuffer()
	StartTest("creating a zero sized buffer fails gracefully")
	buffer = Compute.CreateBuffer(0)
	EndTest(buffer = 0)
endfunction

function TestDeleteNonExistentBuffer()
	StartTest("deleting a non existent buffer fails gracefully")
	Compute.DeleteBuffer(2000)
	EndTest(1)
endfunction

function TestDeleteNonExistentShader()
	StartTest("deleting a non existent shader fails gracefully")
	Compute.DeleteShader(1000)
	EndTest(1)
endfunction

function TestInvalidWorkGroupSizes()
	StartTest("running a shader with an invalid work group size fails gracefully")
	computeShader = Compute.LoadShader("do_nothing.glsl")
	Compute.RunShader(computeShader, -1, 1, 1)
	Compute.RunShader(computeShader, Compute.GetMaxNumWorkGroupsX() + 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestLoadInvalidShader()
	StartTest("loading an invalid shader fails gracefully")
	shaderSource$ = "layou (local_size_x = 32, local_size_y = 32) in;" + Chr(10) + "void main() { }" + Chr(10)
	computeShader = Compute.LoadShaderFromString(shaderSource$)
	EndTest(computeShader = 0)
	Compute.DeleteShader(computeShader)
endfunction

function TestLoadNonExistentShaderFile()
	StartTest("loading a non existent shader file fails gracefully")
	computeShader = Compute.LoadShader("non_existent.glsl")
	EndTest(computeShader = 0)
	Compute.DeleteShader(computeShader)
endfunction

function TestRunNonExistentShader()
	StartTest("running a non existent shader fails gracefully")
	Compute.RunShader(1000, 1, 1, 1)
	EndTest(1)
endfunction

function TestRunOnDeletedBuffer()
	StartTest("attaching a buffer that is deleted before the shader is run fails gracefully")
	computeShader = Compute.LoadShader("mult_tables.glsl")
	buffer = Compute.CreateBuffer(4 * 12 * 12)
	Compute.SetShaderBuffer(computeShader, buffer, 0)
	Compute.DeleteBuffer(buffer)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestRunOnDeletedImage()
	StartTest("attaching an image and deleting it before running the shader fails gracefully")
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("do_nothing.glsl")
	Compute.SetShaderImage(computeShader, img, 0)
	DeleteImage(img)
	Compute.RunShader(computeShader, Compute.GetMaxWorkGroupSizeX() + 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestRunOversizedWorkGroup()
	StartTest("running a shader with too large a work group fails gracefully")
	computeShader = Compute.LoadShader("do_nothing.glsl")
	Compute.RunShader(computeShader, Compute.GetMaxWorkGroupSizeX() + 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestSetNonExistentShaderConstant()
	StartTest("setting a non existent shader constant fails gracefully")
	computeShader = Compute.LoadShader("do_nothing.glsl")
	Compute.SetShaderConstantByName(computeShader, "non_existent", 1.0, 1.0, 1.0, 1.0)
	Compute.SetShaderConstantByLocation(computeShader, 1, 1.0, 1.0, 1.0, 1.0)
	Compute.SetShaderConstantIntByName(computeShader, "non_existent", 1, 1, 1, 1)
	Compute.SetShaderConstantIntByLocation(computeShader, 1, 1, 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestSetNonExistentShaderConstantArray()
	StartTest("setting a non existent shader constant array fails gracefully")
	computeShader = Compute.LoadShader("do_nothing.glsl")
	Compute.SetShaderConstantArrayByName(computeShader, "non_existent", 0, 1.0, 1.0, 1.0, 1.0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 0, 1, 1.0, 1.0, 1.0, 1.0)
	Compute.SetShaderConstantArrayIntByName(computeShader, "non_existent", 0, 1, 1, 1, 1)
	Compute.SetShaderConstantArrayIntByLocation(computeShader, 0, 1, 1, 1, 1, 1)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestSetOutOfBoundsShaderConstantArrayElement()
	StartTest("setting an out of bounds element in a constant array fails gracefully")
	computeShader = Compute.LoadShader("lookup.glsl")
	Compute.SetShaderConstantArrayIntByName(computeShader, "colIndices", 4, 0, 0, 0, 0)
	Compute.SetShaderConstantArrayIntByLocation(computeShader, 0, -1, 0, 0, 0, 0)
	Compute.SetShaderConstantArrayByName(computeShader, "colours", 1000, 0, 0, 0, 0)
	Compute.SetShaderConstantArrayByLocation(computeShader, 4, -1000, 0, 0, 0, 0)
	EndTest(1)
	Compute.DeleteShader(computeShader)
endfunction

function TestUpdateBufferFromNonExistentMemblock()
	StartTest("updating a buffer from a non existent memblock fails gracefully")
	buffer = Compute.CreateBuffer(10)
	Compute.UpdateBufferFromMemblock(buffer, -1000)
	EndTest(1)
	Compute.DeleteBuffer(buffer)
endfunction

function TestUseDeletedShader()
	StartTest("using a shader that has already been deleted")
	img = CreateRenderImage(32, 32, 0, 0)
	computeShader = Compute.LoadShader("red.glsl")
	Compute.SetShaderImage(computeShader, img, 0)
	Compute.DeleteShader(computeShader)
	Compute.RunShader(computeShader, 1, 1, 1)
	EndTest(not ImageMatchesColour(img, 255, 0, 0))
	Compute.DeleteShader(computeShader)
	DeleteImage(img)
endfunction
