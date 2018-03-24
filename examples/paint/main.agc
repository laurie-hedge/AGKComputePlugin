// Import the plugin.
#import_plugin Compute

// Types.
type ColourType
	sprite as Integer
	red as Float
	green as Float
	blue as Float
endtype

// Constants.
#constant WIDTH 1024
#constant HEIGHT 768

#constant DRAW_LINE 0
#constant DRAW_CIRCLE 1
#constant DRAW_RECTANGLE 2

// Globals.
global baseImage as Integer
global previewImage as Integer

global drawingMode as Integer

global currentColour as Integer
global colourPallet as ColourType[]

global copyShader as Integer
global uploadShader as Integer
global lineShader as Integer
global circleShader as Integer
global rectangleShader as Integer

// Setup error handling.
SetErrorMode(2)
Compute.SetErrorMode(3)

// Check that compute is supported.
if not Compute.IsSupportedCompute()
	Message("Compute shaders are not supported on this platform.")
	end
endif

// Setup the window.
SetWindowTitle("Paint Example")
SetWindowSize(WIDTH, HEIGHT, 0)
SetWindowAllowResize(0)
SetVirtualResolution(WIDTH, HEIGHT)

// Setup text input.
SetCursorBlinkTime(0.5)
SetTextInputMaxChars(20)

// Load the compute shaders.
uploadShader = Compute.LoadShader("upload.glsl")
copyShader = Compute.LoadShader("copy.glsl")
lineShader = Compute.LoadShader("line.glsl")
circleShader = Compute.LoadShader("circle.glsl")
rectangleShader = Compute.LoadShader("rectangle.glsl")

// Create on-screen instructions.
UseNewDefaultFonts(1)
instructionsText = CreateText("left - prev col, right, next col, c - circle, r - rectangle, l - line, s - save, o - open, n - new")
SetTextColor(instructionsText, 0, 0, 0, 255)
SetTextSize(instructionsText, 18)
SetTextPosition(instructionsText, WIDTH - GetTextTotalWidth(instructionsText) - 5, 5)

// Create colour pallet.
nextX# = GetVirtualWidth() - 16.0 - 5.0
palletY# = GetTextTotalHeight(instructionsText) + 16.0 + 5.0
for red = 0 to 1
	for green = 0 to 1
		for blue = 0 to 1
			col as ColourType
			col.sprite = CreateSprite(CreateImageColor(red * 255, green * 255, blue * 255, 255))
			SetSpriteSize(col.sprite, 32, 32)
			SetSpritePositionByOffset(col.sprite, nextX#, palletY#)
			SetSpriteDepth(col.sprite, 8)
			col.red = red
			col.green = green
			col.blue = blue
			colourPallet.insert(col)
			nextX# = nextX# - 32.0 - 10.0
		next blue
	next green
next red
selectedColourSprite = LoadSprite("dot.png")
SetSpritePositionByOffset(selectedColourSprite, GetSpriteXByOffset(colourPallet[0].sprite), GetSpriteYByOffset(colourPallet[0].sprite))
SetSpriteDepth(selectedColourSprite, 6)

// Create images.
baseImage = CreateRenderImage(WIDTH, HEIGHT, 0, 0)
previewImage = CreateRenderImage(WIDTH, HEIGHT, 0, 0)

// Create screen sprite.
screenSprite = CreateSprite(baseImage)
SetSpriteSize(screenSprite, WIDTH, HEIGHT)

// Setup initial setting.
drawingMode = DRAW_LINE
currentColour = 0

// Create new image on opening.
New()

do
	if GetRawKeyReleased(83)
		Save()
	elseif GetRawKeyReleased(79)
		Open()
	elseif GetRawKeyReleased(78)
		New()
	elseif GetRawKeyReleased(76)
		drawingMode = DRAW_LINE
	elseif GetRawKeyReleased(67)
		drawingMode = DRAW_CIRCLE
	elseif GetRawKeyReleased(82)
		drawingMode = DRAW_RECTANGLE
	elseif GetRawKeyReleased(37)
		currentColour = currentColour + 1
		if currentColour > colourPallet.length
			currentColour = 0
		endif
		SetSpritePositionByOffset(selectedColourSprite, GetSpriteXByOffset(colourPallet[currentColour].sprite), GetSpriteYByOffset(colourPallet[currentColour].sprite))
	elseif GetRawKeyReleased(39)
		currentColour = currentColour - 1
		if currentColour < 0
			currentColour = colourPallet.length
		endif
		SetSpritePositionByOffset(selectedColourSprite, GetSpriteXByOffset(colourPallet[currentColour].sprite), GetSpriteYByOffset(colourPallet[currentColour].sprite))
	endif

	if GetPointerPressed()
		startX# = GetPointerX()
		startY# = GetPointerY()
		SetSpriteImage(screenSprite, previewImage)
	endif

	if GetPointerState()
		curX# = GetPointerX()
		curY# = GetPointerY()
		select drawingMode
			case DRAW_LINE
				PreviewLine(startX#, startY#, curX#, curY#)
			endcase
			case DRAW_CIRCLE
				diffX# = curX# - startX#
				diffY# = curY# - startY#
				radius# = Sqrt((diffX# * diffX#) + (diffY# * diffY#))
				PreviewCircle(startX#, startY#, radius#)
			endcase
			case DRAW_RECTANGLE
				PreviewRectangle(Min(startX#, curX#), Min(startY#, curY#), Max(startX#, curX#), Max(startY#, curY#))
			endcase
		endselect
	endif

	if GetPointerReleased()
		AcceptPreview()
		SetSpriteImage(screenSprite, baseImage)
	endif

	Sync()
loop

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

function Save()
	StartTextInput()
	do
		if GetTextInputCompleted()
			if not GetTextInputCancelled()
				fileName$ = GetTextInput()
				if fileName$ <> ""
					SaveImage(baseImage, fileName$ + ".jpg")
				endif
			endif
			StopTextInput()
			exit
		endif
		Sync()
	loop
endfunction

function Open()
	StartTextInput()
	do
		if GetTextInputCompleted()
			if not GetTextInputCancelled()
				fileName$ = GetTextInput()
				if GetFileExists(fileName$ + ".jpg")
					image = LoadImage(fileName$ + ".jpg")
					if GetImageWidth(image) = WIDTH and GetImageHeight(image) = HEIGHT
						UploadImage(image)
					endif
					DeleteImage(image)
				endif
			endif
			StopTextInput()
			exit
		endif
		Sync()
	loop
endfunction

function New()
	SetClearColor(255, 255, 255)
	SetRenderToImage(baseImage, 0)
	ClearScreen()
	SetRenderToImage(previewImage, 0)
	ClearScreen()
	SetRenderToScreen()
endfunction

function UploadImage(image)
	Compute.SetShaderImage(uploadShader, image, 0)
	Compute.SetShaderImage(uploadShader, baseImage, 1)
	Compute.SetShaderImage(uploadShader, previewImage, 2)
	Compute.RunShader(uploadShader, WIDTH / 32, HEIGHT / 32, 1)
endfunction

function AcceptPreview()
	Compute.SetShaderImage(copyShader, previewImage, 0)
	Compute.SetShaderImage(copyShader, baseImage, 1)
	Compute.RunShader(copyShader, WIDTH / 32, HEIGHT / 32, 1)
endfunction

function PreviewLine(startX as Float, startY as Float, stopX as Float, stopY as Float)
	Compute.SetShaderConstantByName(lineShader, "drawColour", colourPallet[currentColour].red, colourPallet[currentColour].green, colourPallet[currentColour].blue, 1.0)
	Compute.SetShaderConstantByName(lineShader, "start", startX, startY, 0, 0)
	Compute.SetShaderConstantByName(lineShader, "stop", stopX, stopY, 0, 0)
	Compute.SetShaderImage(lineShader, baseImage, 0)
	Compute.SetShaderImage(lineShader, previewImage, 1)
	Compute.RunShader(lineShader, WIDTH / 32, HEIGHT / 32, 1)
endfunction

function PreviewCircle(origX as Float, origY as Float, radius as Float)
	Compute.SetShaderConstantByName(circleShader, "drawColour", colourPallet[currentColour].red, colourPallet[currentColour].green, colourPallet[currentColour].blue, 1.0)
	Compute.SetShaderConstantByName(circleShader, "origin", origX, origY, 0, 0)
	Compute.SetShaderConstantByName(circleShader, "radius", radius, 0, 0, 0)
	Compute.SetShaderImage(circleShader, baseImage, 0)
	Compute.SetShaderImage(circleShader, previewImage, 1)
	Compute.RunShader(circleShader, WIDTH / 32, HEIGHT / 32, 1)
endfunction

function PreviewRectangle(leftX as Float, topY as Float, rightX as Float, bottomY as Float)
	Compute.SetShaderConstantByName(rectangleShader, "drawColour", colourPallet[currentColour].red, colourPallet[currentColour].green, colourPallet[currentColour].blue, 1.0)
	Compute.SetShaderConstantByName(rectangleShader, "topLeft", leftX, topY, 0, 0)
	Compute.SetShaderConstantByName(rectangleShader, "bottomRight", rightX, bottomY, 0, 0)
	Compute.SetShaderImage(rectangleShader, baseImage, 0)
	Compute.SetShaderImage(rectangleShader, previewImage, 1)
	Compute.RunShader(rectangleShader, WIDTH / 32, HEIGHT / 32, 1)
endfunction
