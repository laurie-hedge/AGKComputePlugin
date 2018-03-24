#import_plugin Compute

#include "tests.agc"

#constant MARGINS 10.0
#constant FONT_SIZE 16

type ResultType
	resultMessage as String
	pass as Integer
endtype

global results as ResultType[]
global resultTextLines as Integer[]

// Stop on any AGK error.
SetErrorMode(2)

// Setup window.
SetWindowTitle("Compute Unit Tests")
SetWindowSize(1024, 768, 0)
SetVirtualResolution(1024, 768)
UseNewDefaultFonts(1)

// Check that the platform has Compute shader support.
if Compute.IsSupportedCompute()
	// Make sure errors fail silently, as some tests expect errors and these should not interrupt the app.
	Compute.SetErrorMode(0)
	
	// Run positive tests.
	TestCopyBufferToMemblock()
	TestCreateBufferFromMemblock()
	TestGlobalWorkGroups()
	TestLoadShaderFromFile()
	TestLoadShaderFromString()
	TestNamedShaderArrayConstants()
	TestNamedShaderConstants()
	TestNamedShaderIntConstants()
	TestNotPrependShaderVersion()
	TestPrependShaderVersion()
	TestQueryBufferSize()
	TestQueryMaxBufferSize()
	TestQueryMemorySize()
	TestQueryNumWorkGroups()
	TestQueryWorkGroupSize()
	TestReadBufferInShader()
	TestReadFromImage()
	TestReadFromRenderImage()
	TestRenderAfterCompute()
	TestRunComputeShader()
	TestShaderArrayConstants()
	TestShaderConstants()
	TestShaderIntConstants()
	TestSwapBuffers()
	TestSwapImages()
	TestUnbindBuffer()
	TestUnbindBufferAfterRun()
	TestUnbindImage()
	TestUnbindImageAfterRun()
	TestUpdateBufferFromMemblock()
	TestUpdateBufferWithLargerMemblock()
	TestUsingConstantBuffersAndImagesTogether()
	TestWriteToBufferFromShader()
	TestWriteToImage()
	TestWriteToMipmappedRenderImage()
	TestWriteToRenderImage()
	
	// Run negative tests.
	TestAttachDeletedBuffer()
	TestAttachDeletedImage()
	TestAttachNonExistentBuffer()
	TestAttachNonExistentImage()
	TestAttachToInvalidAttachPoint()
	TestCopyDataFromNonExistentBuffer()
	TestCopyDataToNonExistentMemblock()
	TestCopyDataToTooSmallMemblock()
	TestCreateBufferFromDeletedMemblock()
	TestCreateBufferFromEmptyMemblock()
	TestCreateBufferFromNonExistentMemblock()
	TestCreateMemblockFromDeletedBuffer()
	TestCreateMemblockFromNotExistentBuffer()
	TestCreateZeroSizedBuffer()
	TestDeleteNonExistentBuffer()
	TestDeleteNonExistentShader()
	TestInvalidWorkGroupSizes()
	TestLoadInvalidShader()
	TestLoadNonExistentShaderFile()
	TestRunNonExistentShader()
	TestRunOnDeletedBuffer()
	TestRunOnDeletedImage()
	TestRunOversizedWorkGroup()
	TestSetNonExistentShaderConstant()
	TestSetNonExistentShaderConstantArray()
	TestSetOutOfBoundsShaderConstantArrayElement()
	TestUpdateBufferFromNonExistentMemblock()
	TestUseDeletedShader()
	
	// Display results.
	SetupResults()
else
	// Display error.
	SetClearColor(255, 255, 255)
	errorText = CreateText("Compute shaders are not supported on this platform. No tests run.")
	SetTextSize(errorText, FONT_SIZE)
	SetTextColor(errorText, 0, 0, 0, 255)
	SetTextPosition(errorText, MARGINS, 0.0)
endif

do
	if resultTextLines.length >= 0
		textMoveY# = 0.0
		if GetRawKeyPressed(38) or GetRawMouseWheelDelta() > 0.0
			if GetTextY(resultTextLines[0]) < 0.0
				textMoveY# = Min(FONT_SIZE, Abs(GetTextY(resultTextLines[0])))
			endif
		elseif GetRawKeyPressed(40) or GetRawMouseWheelDelta() < 0.0
			textEndY# = GetTextY(resultTextLines[resultTextLines.length]) + GetTextTotalHeight(resultTextLines[resultTextLines.length])
			if textEndY# > GetVirtualHeight()
				textMoveY# = -Min(FONT_SIZE, textEndY# - GetVirtualHeight())
			endif
		endif

		if textMoveY# <> 0.0
			for i = 0 to resultTextLines.length
				SetTextY(resultTextLines[i], GetTextY(resultTextLines[i]) + textMoveY#)
			next i
		endif
	endif

    Sync()
loop

function StartTest(testName as String)
	result as ResultType
	result.resultMessage = "Testing " + testName + "...  "
	result.pass = 0
	results.insert(result)
endfunction

function EndTest(pass as Integer)
	results[results.length].pass = pass
	if pass
		results[results.length].resultMessage = results[results.length].resultMessage + "Pass."
	else
		results[results.length].resultMessage = results[results.length].resultMessage + "Fail."
	endif
endfunction

function SetupResults()
	SetClearColor(255, 255, 255)
	SetRenderToScreen()

	nextY# = 0.0
	passing = 0
	failing = 0
	for i = 0 to results.length
		resultText = CreateText(results[i].resultMessage)
		SetTextSize(resultText, FONT_SIZE)
		SetTextPosition(resultText, MARGINS, nextY#)
		if results[i].pass
			SetTextColor(resultText, 0, 0, 0, 255)
			passing = passing + 1
		else
			SetTextColor(resultText, 255, 0, 0, 255)
			failing = failing + 1
		endif
		resultTextLines.insert(resultText)
		nextY# = nextY# + GetTextTotalHeight(resultText)
	next i
	resultText = CreateText("------------------------------" + Chr(10) + "Passing: " + Str(passing) + Chr(10) + "Failing: " + Str(failing))
	SetTextSize(resultText, FONT_SIZE)
	SetTextPosition(resultText, MARGINS, nextY#)
	SetTextColor(resultText, 0, 0, 0, 255)
	resultTextLines.insert(resultText)
	nextY# = nextY# + GetTextTotalHeight(resultText)
	if failing = 0
		resultText = CreateText("*** TESTS PASSED ***")
		SetTextColor(resultText, 0, 0, 0, 255)
	else
		resultText = CreateText("*** TESTS FAILED ***")
		SetTextColor(resultText, 255, 0, 0, 255)
	endif
	SetTextSize(resultText, FONT_SIZE)
	SetTextPosition(resultText, MARGINS, nextY#)
	resultTextLines.insert(resultText)
endfunction

function ImageMatchesColour(img, red, green, blue)
	mem = CreateMemblockFromImage(img)
	width = GetMemblockInt(mem, 0)
	height = GetMemblockInt(mem, 4)
	pixelOffset = 12
	bufferEnd = 12 + (width * height * 4)
	while pixelOffset < bufferEnd
		if GetMemblockByte(mem, pixelOffset) <> red or GetMemblockByte(mem, pixelOffset + 1) <> green or GetMemblockByte(mem, pixelOffset + 2) <> blue
			DeleteMemblock(mem)
			exitfunction 0
		endif
		pixelOffset = pixelOffset + 4
	endwhile
	DeleteMemblock(mem)
endfunction 1

function ImagesMatch(img0, img1)
	width = GetImageWidth(img0)
	height = GetImageHeight(img0)
	if width <> GetImageWidth(img1) or height <> GetImageHeight(img1)
		exitfunction 0
	endif
	
	mem0 = CreateMemblockFromImage(img0)
	mem1 = CreateMemblockFromImage(img1)
	
	pixelOffset = 12
	bufferEnd = 12 + (width * height * 4)
	while pixelOffset < bufferEnd
		if GetMemblockByte(mem0, pixelOffset) <> GetMemblockByte(mem1, pixelOffset) or GetMemblockByte(mem0, pixelOffset + 1) <> GetMemblockByte(mem1, pixelOffset + 1) or GetMemblockByte(mem0, pixelOffset + 2) <> GetMemblockByte(mem1, pixelOffset + 2) or GetMemblockByte(mem0, pixelOffset + 3) <> GetMemblockByte(mem1, pixelOffset + 3)
			DeleteMemblock(mem0)
			DeleteMemblock(mem1)
			exitfunction 0
		endif
		pixelOffset = pixelOffset + 4
	endwhile
	
	DeleteMemblock(mem0)
	DeleteMemblock(mem1)
endfunction 1

function CreateImageFromColor(width, height, red, green, blue)
	memblockSize = (width * height * 4) + 12
	mem = CreateMemblock(memblockSize)
	SetMemblockInt(mem, 0, width)
	SetMemblockInt(mem, 4, height)
	SetMemblockInt(mem, 8, 32)
	pixelOffset = 12
	while pixelOffset < memblockSize
		SetMemblockByte(mem, pixelOffset, red)
		SetMemblockByte(mem, pixelOffset + 1, green)
		SetMemblockByte(mem, pixelOffset + 2, blue)
		SetMemblockByte(mem, pixelOffset + 3, 255)
		pixelOffset = pixelOffset + 4
	endwhile
	img = CreateImageFromMemblock(mem)
	DeleteMemblock(mem)
endfunction img

function Min(a as Float, b as Float)
	if a < b
		exitfunction a
	endif
endfunction b

function Max(a as Float, b as Float)
	if a > b
		exitfunction a
	endif
endfunction b
