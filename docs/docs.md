# AppGameKit Compute Shader Plugin #

## Overview ##

Compute shaders are a feature of OpenGL that allow you to run stand alone shaders outside of the normal rendering
pipeline. This allows you to you more easily write arbitrary programs that can leverage the power of the GPU, even when
those programs are not graphical in nature. In games, this can be extremely useful for things like physics, collision
detection, and AI.

Compute shaders were introduced in OpenGL 4.3, meaning that this plugin requires version 4.3 or better to work. As such,
the plugin is only currently supported on Windows and Linux, as macOS machines don't support any features after OpenGL
4.1.

This plugin is provided freely for commercial and non-commercial use. The source code is available on
[GitHub](https://github.com/laurie-hedge/AGKComputePlugin) under the MIT license.

## Installation ##

### Windows ###

Copy the Compute folder alongside this file into the AppGameKit plugins folder. If you installed AppGameKit through
Steam, this would typically be something like:
> C:\Program Files (x86)\Steam\steamapps\common\App Game Kit 2\Tier 1\Compiler\Plugins

### Linux ###

Copy the Compute folder alongside this file into the AppGameKit plugins folder. If you installed AppGameKit through
Steam, this would typically be something like:
> /home/<username>/.steam/steam/steamapps/common/App Game Kit 2/Tier1/Compiler/Plugins

## Usage ##

Once installed, to start using the plugin, you need to import it using the import_plugin directive somewhere in your
project.
`#import_plugin Compute`

You can then call any of the functions documented here. Typically you should start by checking that compute shaders are
supported on the platform.
```
if not Compute.IsSupportedCompute()
	Message("Sorry, compute shaders are not supported on your machine.")
	end
endif
```

Assuming compute shaders are supported, you can create a compute shader using the LoadShader or LoadShaderFromString
commands.
`computeShader = Compute.LoadShader("create_image.glsl")`

Compute shaders are written in standard GLSL. In order for them to do anything useful, you need to provide them with
both sources of data to use as inputs and storage to save the results to. These take the form of shader uniforms for
inputs, and buffers and images as inputs or outputs. The following example shows a compute shader with inputs from a
uniform and a buffer, and an image as the output.
```
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
```

Once the shader is loaded, it needs to be setup with the inputs and outputs discussed. There are a range of
SetShaderConstant commands available in the plugin for setting shader uniforms.
```
for i = 0 to 15
	Compute.SetShaderConstantArrayByLocation(computeShader, 0, i, i * (1.0 / 16.0), 0.0, 0.0, 0.0)
next i
```

Images can be created using any of the standard AppGameKit image functions such as LoadImage or CreateRenderImage. These
can then be connected up to a shader using the SetShaderImage command.
`Compute.SetShaderImage(computeShader, image, 1)`

Buffers can either be created as empty storage or created from memblocks.
`buffer = Compute.CreateBufferFromMemblock(srcMemblock)`

They can then be attached to a shader for use using the SetShaderBuffer command.
`Compute.SetShaderBuffer(computeShader, buffer, 0)`

Once everything is ready, the shader can be run across a specified number of work groups.
`Compute.RunShader(computeShader, 1, 1, 1)`

The results can then be used, for example by using the image in AppGameKit's standard rendering or image commands, or in
the case of buffers, by copying the buffer back into a memblock for easy access using AppGameKit's memblock commands.

For some full example applications, see the examples folder alongside this file.

## Examples ##

### Flocking Example ###

The flocking example demonstrates the use of compute shaders to simulate flocking behaviour using buffers.

The app starts by creating two buffers and a memblock. The memblock is filled with the starting positions and directions
of all the agents in the scene. These are then copied into one of the two buffers. Each frame, the application runs the
compute shader to calculate the new positions and directions of the agents, based on their previous positions and
direction and the current target. The buffer containing the current positions and directions is used as the input, along
with a uniform specifying the current target. The second buffer is used as the output. Once the compute shader has run,
the data from the buffer is copied into a memblock and read back by the application, which uses the data to update the
position and orientation of the sprites representing the agents in the game. The two buffers are then swapped for the
next iteration, so that the output from this frame is used as the input into the next frame.

You can find the full source code for this example in the flocking folder inside the examples folder alongside this
file.

### Paint Example ###

The paint example demonstrates the use of compute shaders to dynamically generate images which can then be used for
rendering.

The app starts by creating two images. The first is the current state of the image. The other is a temporary image for
use when the user is manipulating the basic shapes used for drawing such as lines, rectangles, and circles. A full
screen sprite is used to display the image to the user. To start with, the current state of the image is displayed on
the sprite. When the user starts drawing, the full screen sprite starts rendering the dynamic version of the image. The
dynamic version of the image takes the current image as well as the basic parameters of the user's input and renders a
new image to the dynamic version of the image including what the user is in the process of drawing. Once the user
releases the pointer indicating that they have finished adding an element to the image, the dynamic image is written
back to the other image thereby updating the current state of the image, and the full screen sprite reverts to
displaying that image instead.

You can find the full source code for this example in the paint folder inside the examples folder alongside this file.

## Commands ##

### CopyBufferToMemblock ###

`Compute.CopyBufferToMemblock(bufferID, memblockID)`

Copy the contents of the buffer specified by bufferID into the memblock specified by memblockID. This can be used to
fetch data written by a compute shader into a buffer for use directly in your application.

The function requires that the memblock be at least as large as the buffer so that all of the data may be copied across.
If the memblock is to small to receive all the data, the plugin will report an error and no data will be copied.

### CreateBuffer ###

`integer Compute.CreateBuffer(bufferSize)`

Creates a buffer of bufferSize bytes and returns an ID which can be used to refer to the buffer in future.

A buffer corresponds to an OpenGL Shader Buffer Storage Object. It can be used as either an input or an output (or both)
from a compute shader by attaching it to the compute shader using the SetShaderBuffer function.

### CreateBufferFromMemblock ###

`integer Compute.CreateBufferFromMemblock(memblockID)`

Creates a buffer of the same size as the memblock specified, and immediately copies all of the data in the memblock into
the new buffer, returning an ID that can be used to refer to the buffer in future.

### CreateMemblockFromBuffer ###

`integer Compute.CreateMemblockFromBuffer(bufferID)`

Creates a memblock of the same size as the buffer specified, and immediately copies all of the data in the buffer into
the new memblock, returning an ID that can be used to refer to the memblock in future.

### DeleteBuffer ###

`Compute.DeleteBuffer(bufferID)`

Free the memory used by the buffer specified and destroy the buffer. After this function is called, the buffer specified
by bufferID cannot be used in any way.

### DeleteShader ###

`Compute.DeleteShader(shaderID)`

Free the memory used by the shader specified and destroy the shader. After this function is called, the shader specified
by shaderID may not be used in any way.

### GetBufferSize ###

`integer Compute.GetBufferSize(bufferID)`

Returns the size in bytes of the buffer specified by bufferID.

### GetMaxBufferSize ###

`integer Compute.GetMaxBufferSize()`

The maximum size of a buffer in bytes. This will be at least 16777216 bytes on any platform that supports compute
shaders, but could be more. Due to the limitations of AGK integers, if buffer sizes of over 2147483647 bytes are
supported, 2147483647 will be returned.

### GetMaxSharedMemory ###

`integer Compute.GetMaxSharedMemory()`

The maximum size in bytes of all the variables declared as shared in a single compute shader. This is guaranteed to be
at least 32768 bytes.

### GetMaxNumWorkGroupsX ###

`integer Compute.GetMaxNumWorkGroupsX()`

The upper bound of the numGroupsX argument to RunShader. It is guaranteed to be at least 65535.

### GetMaxNumWorkGroupsY ###

`integer Compute.GetMaxNumWorkGroupsY()`

The upper bound of the numGroupsY argument to RunShader. It is guaranteed to be at least 65535.

### GetMaxNumWorkGroupsZ ###

`integer Compute.GetMaxNumWorkGroupsZ()`

The upper bound of the numGroupsZ argument to RunShader. It is guaranteed to be at least 65535.

### GetMaxWorkGroupSizeTotal ###

`integer Compute.GetMaxWorkGroupSizeTotal()`

The maximum number of instances of a shader that may be run within a single work group. As such, local_size_x *
local_size_y * local_size_z must be <= GetMaxWorkGroupSizeTotal. This is guaranteed to be at least 1024.

### GetMaxWorkGroupSizeX ###

`integer Compute.GetMaxWorkGroupSizeX()`

The maximum number of instances of a shader in the x dimension that may be run within a single work group. As such,
local_size_x must be <= GetMaxWorkGroupSizeX. It is guaranteed to be at least 1024.

### GetMaxWorkGroupSizeY ###

`integer Compute.GetMaxWorkGroupSizeY()`

The maximum number of instances of a shader in the y dimension that may be run within a single work group. As such,
local_size_y must be <= GetMaxWorkGroupSizeY. It is guaranteed to be at least 1024.

### GetMaxWorkGroupSizeZ ###

`integer Compute.GetMaxWorkGroupSizeZ()`

The maximum number of instances of a shader in the z dimension that may be run within a single work group. As such,
local_size_z must be <= GetMaxWorkGroupSizeZ. It is guaranteed to be at least 64.

### IsSupportedCompute ###

`integer Compute.IsSupportedCompute()`

Returns 1 if the platform support compute shaders, and 0 if it does not.

Running other Compute commands on a platform without compute shader support will do nothing. Therefore your app will
continue to run but may not behave correctly, so you may wish to branch on this result to provide an alternative option
or an error message on platforms that don't support compute shaders.

### LoadShader ###

`integer Compute.LoadShader(fileName)`

Creates a compute shader from the GLSL source code inside the file specified, and returns a shader ID that can be used
to refer to this shader in future commands.

### LoadShaderFromString ###

`integer Compute.LoadShaderFromString(glslSourceCode)`

Creates a compute shader from the GLSL source code provided as a string to the function, and returns a shader ID that
can be used to refer to this shader in future commands.

### RunShader ###

`Compute.RunShader(shaderID, numGroupsX, numGroupsY, numGroupsZ)`

Run the specified compute shader with the number of work groups specified in each dimension.

numGroupsX, numGroupsY, and numGroupsZ must be at least 1, and less than or equal to the corresponding
GetMaxNumWorkGroups function.

Note that the arguments specify the number of work groups, which is different to the local size of each work group
specified within the compute shader itself. Each invokation of a work group will run the compute shader local_size_x *
local_size_y * local_size_z times.

Prior to running the shader, it is necessary to provide the shader with all of the data is requires, such as images,
buffers, and shader constants.

### SetErrorMode ###

`Compute.SetErrorMode(mode)`

Set how the plugin handles errors. This needs to be done separately from AppGameKit's own SetErrorMode function as
AppGameKit doesn't apply the same rules to plugin errors.

The following values are valid error modes. By default, error mode 1 is used.

| Mode | Name         | Behaviour                                                                                      |
|:----:|:------------:|:----------------------------------------------------------------------------------------------:|
| 0    | Ignore       | Ignore errors and carry on. In most cases, the command will simply return after the error      |
|      |              | occurs. Silently ignoring errors is generally undesirable during development, but you may wish |
|      |              | to use this mode for the version to release to customers so that they never see errors.        |
| 1    | Report First | Report the first error to occur using AppGameKit's default error handling, which usually       |
|      |              | displays a native dialogue box with the error message. After the first error, other errors are |
|      |              | ignored silently until the app restarts. This can be desirable if the error occurs every frame |
|      |              | so that the app does not spam message boxes and make itself difficult to close in the case of  |
|      |              | an error.                                                                                      |
| 2    | Report All   | Report all errors using AppGameKit's default error handling, which usually displays a native   |
|      |              | dialogue box with the error message.                                                           |
| 3    | Stop         | Report the first error to occur using AppGameKit's default error handling, which usually       |
|      |              | displays a native dialogue box with the error message. Once the dialogue is closed, the app    |
|      |              | will close immediately.                                                                        |

### SetShaderBuffer ###

`Compute.SetShaderBuffer(shaderID, bufferID, bindingPoint)`

Connect the buffer specified by bufferID to the shader specified by shaderID at the specified binding point so that the
buffer may be read from and written to by the compute shader. The binding point should correspond to the binding
attribute specified for the buffer in the GLSL shader.

For example, this buffer would need to have a bindingPoint of 2.
```
layout (std430, binding = 2) buffer MyBuffer
{
	float numbers[1000];
} myBuffer;
```

The contents of the buffer also needs to match the layout and contents of the description of the buffer in the shader.
Therefore in the above example, the buffer specified by bufferID should be at least 4000 bytes in size (4 bytes for each
of the 1000 floats).

Be aware that GLSL does not always tightly pack all of the elements of a buffer, meaning that the buffer can be larger
than it appears by simply adding together the size of all of the explicitly declared components. You can control the
packing using one of the GLSL packing specifiers (in the above example, the packing specifier is std430). Each has a
different set of layout rules. You can find more information about the packing roles on the [Khronos OpenGL
Wiki](https://www.khronos.org/opengl/wiki/Interface_Block_(GLSL)#Memory_layout). It is important to make sure that you
understand the packing rules so that you can make sure that the buffer you provide is of sufficient size, and also so
that you know how to read and write data to and from the buffer.

### SetShaderConstantArrayByLocation ###

`Compute.SetShaderConstantArrayByLocation(shaderID, location, index, v1, v2, v3, v4)`

Set the value of the array element index of the uniform array at location in the shader specified to the values of v1,
v2, v3, and v4. If the uniform is an array of vec4s, then all the values are used. If the array is of something smaller
like vec3s or floats, then only the required number of values are used, and the rest are ignored.

For example given the following uniform
`layout (location = 0) uniform vec2 myArray[2];`

and the following commands
```
Compute.SetShaderConstantArrayByLocation(myShader, 0, 0, 1.0, 2.0, 3.0, 4.0)
Compute.SetShaderConstantArrayByLocation(myShader, 0, 1, 5.0, 6.0, 7.0, 8.0)
```

the values of myArray would be
> myArray[0].x == 1.0
> myArray[0].y == 2.0
> myArray[1].x == 5.0
> myArray[1].y == 6.0

This function is for use on float or vec types only.

Note that if the uniform is not used in the shader, it may be optimised away by the GLSL compiler, meaning that this
command will fail as the uniform will not be found in the shader.

### SetShaderConstantArrayByName ###

`Compute.SetShaderConstantArrayByName(shaderID, name, index, v1, v2, v3, v4)`

Set the value of the array element index of the uniform array name in the shader specified to the values of v1, v2, v3,
and v4. If the uniform is an array of vec4s, then all the values are used. If the array is of something smaller like
vec3s or floats, then only the required number of values are used, and the rest are ignored.

For example given the following uniform
`layout (location = 0) uniform vec2 myArray[2];`

and the following commands
```
Compute.SetShaderConstantArrayByName(myShader, "myArray", 0, 1.0, 2.0, 3.0, 4.0)
Compute.SetShaderConstantArrayByName(myShader, "myArray", 1, 5.0, 6.0, 7.0, 8.0)
```

the values of myArray would be
> myArray[0].x == 1.0
> myArray[0].y == 2.0
> myArray[1].x == 5.0
> myArray[1].y == 6.0

This function is for use on float and vec types only.

Note that if the uniform is not used in the shader, it may be optimised away by the GLSL compiler, meaning that this
command will fail as the uniform will not be found in the shader.

### SetShaderConstantArrayIntByLocation ###

`Compute.SetShaderConstantArrayIntByLocation(shaderID, location, index, v1, v2, v3, v4)`

Set the value of the array element index of the uniform array at location in the shader specified to the values of v1,
v2, v3, and v4. If the uniform is an array of ivec4s, then all the values are used. If the array is of something smaller
like ivec3s or ints, then only the required number of values are used, and the rest are ignored.

For example given the following uniform
`layout (location = 0) uniform ivec2 myArray[2];`

and the following commands
```
Compute.SetShaderConstantArrayIntByLocation(myShader, 0, 0, 1, 2, 3, 4)
Compute.SetShaderConstantArrayIntByLocation(myShader, 0, 1, 5, 6, 7, 8)
```

the values of myArray would be
> myArray[0].x == 1
> myArray[0].y == 2
> myArray[1].x == 5
> myArray[1].y == 6

This function is for use on int and ivec types only.

Note that if the uniform is not used in the shader, it may be optimised away by the GLSL compiler, meaning that this
command will fail as the uniform will not be found in the shader.

### SetShaderConstantArrayIntByName ###

`Compute.SetShaderConstantArrayIntByName(shaderID, name, index, v1, v2, v3, v4)`

Set the value of the array element index of the uniform array name in the shader specified to the values of v1, v2, v3,
and v4. If the uniform is an array of ivec4s, then all the values are used. If the array is of something smaller like
ivec3s or ints, then only the required number of values are used, and the rest are ignored.

For example given the following uniform
`layout (location = 0) uniform ivec2 myArray[2];`

and the following commands
```
Compute.SetShaderConstantArrayIntByName(myShader, "myArray", 0, 1, 2, 3, 4)
Compute.SetShaderConstantArrayIntByName(myShader, "myArray", 1, 5, 6, 7, 8)
```

the values of myArray would be
> myArray[0].x == 1
> myArray[0].y == 2
> myArray[1].x == 5
> myArray[1].y == 6

This function is for use on int and ivec types only.

Note that if the uniform is not used in the shader, it may be optimised away by the GLSL compiler, meaning that this
command will fail as the uniform will not be found in the shader.

### SetShaderConstantByLocation ###

`Compute.SetShaderConstantByLocation(shaderID, location, v1, v2, v3, v4)`

Set the value of the uniform at location in the shader specified to the values of v1, v2, v3, and v4. If the uniform is
a vec4, then all the values are used. If it is something smaller like a vec3 or a float, then only the required number
of values are used, and the rest are ignored.

This function is for use on float and vec types only.

Note that if the uniform is not used in the shader, it may be optimised away by the GLSL compiler, meaning that this
command will fail as the uniform will not be found in the shader.

### SetShaderConstantByName ###

`Compute.SetShaderConstantByName(shaderID, name, v1, v2, v3, v4)`

Set the value of the uniform name in the shader specified to the values of v1, v2, v3, and v4. If the uniform is a vec4,
then all the values are used. If it is something smaller like a vec3 or a float, then only the required number of values
are used, and the rest are ignored.

This function is for use on float and vec types only.

Note that if the uniform is not used in the shader, it may be optimised away by the GLSL compiler, meaning that this
command will fail as the uniform will not be found in the shader.

### SetShaderConstantIntByLocation ###

`Compute.SetShaderConstantIntByLocation(shaderID, location, v1, v2, v3, v4)`

Set the value of the uniform at location in the shader specified to the values of v1, v2, v3, and v4. If the uniform is
an ivec4, then all the values are used. If it is something smaller like a ivec3 or an int, then only the required number
of values are used, and the rest are ignored.

This function is for use on int and ivec types only.

Note that if the uniform is not used in the shader, it may be optimised away by the GLSL compiler, meaning that this
command will fail as the uniform will not be found in the shader.

### SetShaderConstantIntByName ###

`Compute.SetShaderConstantIntByName(shaderID, name, v1, v2, v3, v4)`

Set the value of the uniform name in the shader specified to the values of v1, v2, v3, and v4. If the uniform is an
ivec4, then all the values are used. If it is something smaller like a ivec3 or an int, then only the required number of
values are used, and the rest are ignored.

This function is for use on int and ivec types only.

Note that if the uniform is not used in the shader, it may be optimised away by the GLSL compiler, meaning that this
command will fail as the uniform will not be found in the shader.

### SetShaderImage ###

`Compute.SetShaderImage(shaderID, imageID, attachPoint)`

Attach the image specified by imageID to the shader specified by shaderID at the given attachment point so that it can
be read from and written to within the GLSL shader. The image may have been created either as a standard AppGameKit
image or as a render image. The attach point should correspond to the binding attribute in the GLSL shader.

For example, this image would need to have an attachPoint of 2.
`layout(binding = 2, rgba8) uniform image2D myImage;`

The format of images should be specified in the GLSL layout attributes as rgba8, as shown above.

### UpdateBufferFromMemblock ###

`Compute.UpdateBufferFromMemblock(bufferID, memblockID)`

Copy the contents of the memblock specified by memblockID into the buffer specified by bufferID. The buffer must be at
least as large as the memblock in order to receive the data from the memblock. If the buffer is too small, an error will
occur and no data will be copied.
