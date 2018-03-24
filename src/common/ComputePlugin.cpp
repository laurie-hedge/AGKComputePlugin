#include <cstdio>
#include <cstdarg>
#include <cstdlib>
#include <cstring>
#include <unordered_map>
#ifdef WIN32
#define WINDOWS_LEAN_AND_MEAN
#include <Windows.h>
#include <GL/gl.h>
#include "glext.h"
#endif
#include "cImage.h"
#include "AGKLibraryCommands.h"

#define MAX_IMAGE_BINDINGS 8
#define MAX_BUFFER_BINDINGS 8

static char const shaderVersion[] = "#version 440 core\n";

#ifdef WIN32
PFNGLCREATESHADERPROC glCreateShader;
PFNGLSHADERSOURCEPROC glShaderSource;
PFNGLCOMPILESHADERPROC glCompileShader;
PFNGLCREATEPROGRAMPROC glCreateProgram;
PFNGLATTACHSHADERPROC glAttachShader;
PFNGLLINKPROGRAMPROC glLinkProgram;
PFNGLDELETESHADERPROC glDeleteShader;
PFNGLGETSHADERIVPROC glGetShaderiv;
PFNGLGETSHADERINFOLOGPROC glGetShaderInfoLog;
PFNGLDELETEPROGRAMPROC glDeleteProgram;
PFNGLGETPROGRAMIVPROC glGetProgramiv;
PFNGLGETPROGRAMINFOLOGPROC glGetProgramInfoLog;
PFNGLUSEPROGRAMPROC glUseProgram;
PFNGLDISPATCHCOMPUTEPROC glDispatchCompute;
PFNGLGETINTEGERI_VPROC glGetIntegeri_v;
PFNGLBINDIMAGETEXTUREPROC glBindImageTexture;
PFNGLUNIFORM4FPROC glUniform4f;
PFNGLUNIFORM4IPROC glUniform4i;
PFNGLUNIFORM1FVPROC glUniform1fv;
PFNGLUNIFORM2FVPROC glUniform2fv;
PFNGLUNIFORM3FVPROC glUniform3fv;
PFNGLUNIFORM4FVPROC glUniform4fv;
PFNGLUNIFORM1IVPROC glUniform1iv;
PFNGLUNIFORM2IVPROC glUniform2iv;
PFNGLUNIFORM3IVPROC glUniform3iv;
PFNGLUNIFORM4IVPROC glUniform4iv;
PFNGLGETUNIFORMLOCATIONPROC glGetUniformLocation;
PFNGLGETACTIVEUNIFORMPROC glGetActiveUniform;
PFNGLGENBUFFERSPROC glGenBuffers;
PFNGLDELETEBUFFERSPROC glDeleteBuffers;
PFNGLBINDBUFFERPROC glBindBuffer;
PFNGLBINDBUFFERBASEPROC glBindBufferBase;
PFNGLBUFFERDATAPROC glBufferData;
PFNGLMAPBUFFERPROC glMapBuffer;
PFNGLUNMAPBUFFERPROC glUnmapBuffer;
PFNGLGETINTEGER64VPROC glGetInteger64v;
#endif

void PluginError(char const *format, ...);

enum ErrorMode {
	ERROR_MODE_IGNORE = 0,
	ERROR_MODE_REPORT_FIRST,
	ERROR_MODE_REPORT_ALL,
	ERROR_MODE_STOP
};

enum PluginState {
	PLUGIN_STATE_UNINITIALISED,
	PLUGIN_STATE_READY,
	PLUGIN_STATE_UNSUPPORTED
};

struct Uniform
{
	GLenum type;
	GLint size;
	GLint vecSize;
	GLint location;
	bool dirty;
	void *data;

	char *getName()
	{
		return (char *)this + sizeof(Uniform);
	}

	template<typename T>
	void set(int index, T v1, T v2, T v3, T v4)
	{
		if (index < 0) {
			PluginError("Failed to set shader constant '%s' at index %d. Negative indices are not permitted.", getName(), index, size);
			return;
		}

		if (index >= size) {
			PluginError("Failed to set shader constant '%s' at index %d. Uniform only has %d elements.", getName(), index, size);
			return;
		}

		if (vecSize == 0) {
			PluginError("Failed to set shader constant '%s', as it is of an unsupported type. Only float, vec, int and ivec uniforms are supported.", getName());
			return;
		}

		T *elem = (T *)data + (index * vecSize);
		if (vecSize > 0) {
			elem[0] = v1;
			if (vecSize > 1) {
				elem[1] = v2;
				if (vecSize > 2) {
					elem[2] = v3;
					if (vecSize > 3) {
						elem[3] = v4;
					}
				}
			}
		}

		dirty = true;
	}

	void apply()
	{
		switch (type) {
			case GL_FLOAT:
				glUniform1fv(location, size, (GLfloat *)data);
				break;
			case GL_FLOAT_VEC2:
				glUniform2fv(location, size, (GLfloat *)data);
				break;
			case GL_FLOAT_VEC3:
				glUniform3fv(location, size, (GLfloat *)data);
				break;
			case GL_FLOAT_VEC4:
				glUniform4fv(location, size, (GLfloat *)data);
				break;
			case GL_INT:
				glUniform1iv(location, size, (GLint *)data);
				break;
			case GL_INT_VEC2:
				glUniform2iv(location, size, (GLint *)data);
				break;
			case GL_INT_VEC3:
				glUniform3iv(location, size, (GLint *)data);
				break;
			case GL_INT_VEC4:
				glUniform4iv(location, size, (GLint *)data);
				break;
			default:
				PluginError("Shader constant '%s' has unsupported type. Only float, vec, int and ivec uniforms are supported.", getName());
				return;
		}
		dirty = false;
	}

	template <typename T>
	bool matchesIdentifier(T identifier);

	template<>
	bool matchesIdentifier<unsigned int>(unsigned int identifier)
	{
		return location == identifier;
	}

	template<>
	bool matchesIdentifier<char *>(char *identifier)
	{
		return strcmp(identifier, getName()) == 0;
	}
};

struct UniformBufferBinding {
	unsigned int bufferID;
	unsigned int bindingPoint;
};

struct ComputeShader
{
	GLuint programName;
	GLuint imageBindings[MAX_IMAGE_BINDINGS];
	UniformBufferBinding bufferBindings[MAX_BUFFER_BINDINGS];
	GLuint numUniforms;
	GLuint uniformSize;
	unsigned char *uniforms;

	ComputeShader(GLuint program) {
		programName = program;
		memset(imageBindings, 0, sizeof(imageBindings));
		memset(bufferBindings, 0, sizeof(bufferBindings));

		GLint maxNameSize;
		glGetProgramiv(program, GL_ACTIVE_UNIFORM_MAX_LENGTH, &maxNameSize);
		uniformSize = sizeof(Uniform) + maxNameSize;

		glGetProgramiv(program, GL_ACTIVE_UNIFORMS, (GLint *)&numUniforms);
		uniforms = (unsigned char *)malloc(uniformSize * numUniforms);

		unsigned char *next = uniforms;
		for (GLuint i = 0; i < numUniforms; ++i) {
			Uniform *uniform = (Uniform *)next;
			glGetActiveUniform(program, i, maxNameSize, NULL, &uniform->size, &uniform->type, uniform->getName());
			for (char *c = uniform->getName(); *c; ++c) {
				if (*c == '[') {
					*c = '\0';
					break;
				}
			}
			uniform->location = glGetUniformLocation(program, uniform->getName());
			uniform->vecSize = 0;
			switch (uniform->type) {
				case GL_FLOAT: case GL_INT:
					uniform->vecSize = 1; break;
				case GL_FLOAT_VEC2: case GL_INT_VEC2:
					uniform->vecSize = 2; break;
				case GL_FLOAT_VEC3: case GL_INT_VEC3:
					uniform->vecSize = 3; break;
				case GL_FLOAT_VEC4: case GL_INT_VEC4:
					uniform->vecSize = 4; break;
			}
			if (uniform->vecSize > 0) {
				uniform->data = malloc(sizeof(float) * uniform->size * uniform->vecSize);
				uniform->dirty = true;
			}
			else {
				uniform->data = NULL;
				uniform->dirty = false;
			}
			next += uniformSize;
		}
	}

	~ComputeShader()
	{
		for (GLuint i = 0; i < numUniforms; ++i) {
			free(getUniform(i)->data);
		}
		free(uniforms);
	}

	Uniform *getUniform(unsigned int index)
	{
		return (Uniform *)&uniforms[index * uniformSize];
	}
};

struct BufferObject {
	GLuint bufferName;
	GLsizei bufferSize;

	BufferObject(GLuint name, GLsizei size)
	{
		bufferName = name;
		bufferSize = size;
	}

	~BufferObject()
	{
		glDeleteBuffers(1, &bufferName);
	}
};

typedef std::unordered_map<unsigned int, ComputeShader *> ComputerShaderMap;
typedef std::unordered_map<unsigned int, BufferObject *> BufferObjectMap;

ErrorMode errorMode = ERROR_MODE_REPORT_FIRST;
PluginState pluginState = PLUGIN_STATE_UNINITIALISED;
unsigned int nextShaderID = 1;
ComputerShaderMap computeShaders;
unsigned int nextBufferID = 1;
BufferObjectMap bufferObjects;
bool errorReported;

void PluginError(char const *format, ...)
{
	if (ERROR_MODE_IGNORE == errorMode) {
		return;
	}

	if (errorReported) {
		if (ERROR_MODE_REPORT_FIRST == errorMode) {
			return;
		}
	}
	else {
		errorReported = true;
	}

	char str[512];

	va_list args;
	va_start(args, format);

	vsnprintf(str, 512, format, args);
	agk::PluginError(str);

	va_end(args);

	if (ERROR_MODE_STOP == errorMode) {
		exit(-1);
	}
}

bool CheckInit()
{
	switch (pluginState) {
		case PLUGIN_STATE_UNINITIALISED: {
#ifdef WIN32
			glCreateShader = (PFNGLCREATESHADERPROC)wglGetProcAddress("glCreateShader");
			glShaderSource = (PFNGLSHADERSOURCEPROC)wglGetProcAddress("glShaderSource");
			glCompileShader = (PFNGLCOMPILESHADERPROC)wglGetProcAddress("glCompileShader");
			glCreateProgram = (PFNGLCREATEPROGRAMPROC)wglGetProcAddress("glCreateProgram");
			glAttachShader = (PFNGLATTACHSHADERPROC)wglGetProcAddress("glAttachShader");
			glLinkProgram = (PFNGLLINKPROGRAMPROC)wglGetProcAddress("glLinkProgram");
			glDeleteShader = (PFNGLDELETESHADERPROC)wglGetProcAddress("glDeleteShader");
			glGetShaderiv = (PFNGLGETSHADERIVPROC)wglGetProcAddress("glGetShaderiv");
			glGetShaderInfoLog = (PFNGLGETSHADERINFOLOGPROC)wglGetProcAddress("glGetShaderInfoLog");
			glDeleteProgram = (PFNGLDELETEPROGRAMPROC)wglGetProcAddress("glDeleteProgram");
			glGetProgramiv = (PFNGLGETPROGRAMIVPROC)wglGetProcAddress("glGetProgramiv");
			glGetProgramInfoLog = (PFNGLGETPROGRAMINFOLOGPROC)wglGetProcAddress("glGetProgramInfoLog");
			glUseProgram = (PFNGLUSEPROGRAMPROC)wglGetProcAddress("glUseProgram");
			glDispatchCompute = (PFNGLDISPATCHCOMPUTEPROC)wglGetProcAddress("glDispatchCompute");
			glGetIntegeri_v = (PFNGLGETINTEGERI_VPROC)wglGetProcAddress("glGetIntegeri_v");
			glBindImageTexture = (PFNGLBINDIMAGETEXTUREPROC)wglGetProcAddress("glBindImageTexture");
			glUniform4f = (PFNGLUNIFORM4FPROC)wglGetProcAddress("glUniform4f");
			glUniform4i = (PFNGLUNIFORM4IPROC)wglGetProcAddress("glUniform4i");
			glGetUniformLocation = (PFNGLGETUNIFORMLOCATIONPROC)wglGetProcAddress("glGetUniformLocation");
			glGetActiveUniform = (PFNGLGETACTIVEUNIFORMPROC)wglGetProcAddress("glGetActiveUniform");
			glUniform1fv = (PFNGLUNIFORM1FVPROC)wglGetProcAddress("glUniform1fv");
			glUniform2fv = (PFNGLUNIFORM2FVPROC)wglGetProcAddress("glUniform2fv");
			glUniform3fv = (PFNGLUNIFORM3FVPROC)wglGetProcAddress("glUniform3fv");
			glUniform4fv = (PFNGLUNIFORM4FVPROC)wglGetProcAddress("glUniform4fv");
			glUniform1iv = (PFNGLUNIFORM1IVPROC)wglGetProcAddress("glUniform1iv");
			glUniform2iv = (PFNGLUNIFORM2IVPROC)wglGetProcAddress("glUniform2iv");
			glUniform3iv = (PFNGLUNIFORM3IVPROC)wglGetProcAddress("glUniform3iv");
			glUniform4iv = (PFNGLUNIFORM4IVPROC)wglGetProcAddress("glUniform4iv");
			glGenBuffers = (PFNGLGENBUFFERSPROC)wglGetProcAddress("glGenBuffers");
			glDeleteBuffers = (PFNGLDELETEBUFFERSPROC)wglGetProcAddress("glDeleteBuffers");
			glBindBuffer = (PFNGLBINDBUFFERPROC)wglGetProcAddress("glBindBuffer");
			glBindBufferBase = (PFNGLBINDBUFFERBASEPROC)wglGetProcAddress("glBindBufferBase");
			glBufferData = (PFNGLBUFFERDATAPROC)wglGetProcAddress("glBufferData");
			glMapBuffer = (PFNGLMAPBUFFERPROC)wglGetProcAddress("glMapBuffer");
			glUnmapBuffer = (PFNGLUNMAPBUFFERPROC)wglGetProcAddress("glUnmapBuffer");
			glGetInteger64v = (PFNGLGETINTEGER64VPROC)wglGetProcAddress("glGetInteger64v");
			if (!glCreateShader || !glShaderSource || !glCompileShader ||
				!glCreateProgram || !glAttachShader || !glLinkProgram ||
				!glDeleteShader || !glGetShaderiv || !glGetShaderInfoLog ||
				!glDeleteProgram || !glGetProgramiv || !glGetProgramInfoLog ||
				!glUseProgram || !glDispatchCompute || !glGetIntegeri_v ||
				!glBindImageTexture || !glUniform4f || !glGetUniformLocation ||
				!glUniform4i || !glGetActiveUniform || !glUniform1fv ||
				!glUniform2fv || !glUniform3fv || !glUniform4fv ||
				!glUniform1iv || !glUniform2iv || !glUniform3iv ||
				!glUniform4iv || !glGenBuffers || !glDeleteBuffers ||
				!glBindBuffer || !glBindBufferBase || !glBufferData ||
				!glMapBuffer || !glUnmapBuffer || !glGetInteger64v) {
				pluginState = PLUGIN_STATE_UNSUPPORTED;
				return false;
			}
#endif

			GLint majorVersion, minorVersion;
			glGetIntegerv(GL_MAJOR_VERSION, &majorVersion);
			glGetIntegerv(GL_MINOR_VERSION, &minorVersion);
			if (majorVersion < 4 || minorVersion < 4) {
				pluginState = PLUGIN_STATE_UNSUPPORTED;
				return false;
			}

			pluginState = PLUGIN_STATE_READY;
			errorReported = false;

			return true;
		}

		case PLUGIN_STATE_READY:
			return true;

		case PLUGIN_STATE_UNSUPPORTED:
			return false;
	}

	return false;
}

template <typename V>
unsigned int NextID(unsigned int &nextID, std::unordered_map<unsigned int, V> lookupTable)
{
	while (lookupTable.find(nextID) != lookupTable.end() || nextID == 0) {
		nextID += 1;
	}
	return nextID;
}

unsigned int NextShaderID()
{
	return NextID(nextShaderID, computeShaders);
}

unsigned int NextBufferID()
{
	return NextID(nextBufferID, bufferObjects);
}

char *GenerateFullShaderSource(char *sourceCode)
{
	size_t len = strlen(sourceCode);
	bool prependVersion = false;
	char *c = sourceCode;
	while (*c && (*c == '\n' || *c == ' ' || *c == '\t' || *c == '\r')) c++;
	if (!c || memcmp(c, "#version", 8) != 0) {
		len += strlen(shaderVersion);
		prependVersion = true;
	}
	char *sourceBuffer = (char *)malloc(len + 1);
	if (prependVersion) {
		strcpy(sourceBuffer, shaderVersion);
		strcat(sourceBuffer, sourceCode);
	}
	else {
		strcpy(sourceBuffer, sourceCode);
	}
	return sourceBuffer;
}

unsigned int CreateBuffer(GLsizei size, void *data)
{
	GLuint bufferName;
	glGenBuffers(1, &bufferName);
	if (glGetError() == GL_INVALID_VALUE) {
		PluginError("Failed to create buffer.");
		return 0;
	}

	glBindBuffer(GL_SHADER_STORAGE_BUFFER, bufferName);
	switch (glGetError()) {
		case GL_INVALID_ENUM: {
			PluginError("Failed to create buffer. Invalid target.");
			return 0;
		}
		case GL_INVALID_VALUE: {
			PluginError("Failed to create buffer. Unknown buffer name.");
			return 0;
		}
	}

	glBufferData(GL_SHADER_STORAGE_BUFFER, size, data, GL_STATIC_COPY);
	switch (glGetError()) {
		case GL_INVALID_ENUM: {
			PluginError("Failed to create buffer. Invalid target or usage.");
			return 0;
		}
		case GL_INVALID_VALUE: {
			PluginError("Failed to create buffer. Invalid memblock size.");
			return 0;
		}
		case GL_INVALID_OPERATION: {
			PluginError("Failed to create buffer. Unknown or immutable buffer object used.");
			return 0;
		}
		case GL_OUT_OF_MEMORY: {
			PluginError("Failed to create buffer. Insufficient memory available.");
			return 0;
		}
	}

	unsigned int id = NextBufferID();
	bufferObjects[id] = new BufferObject(bufferName, size);
	return id;
}

template <typename I> struct SetShaderConstantError { static char const *format; };
char const *SetShaderConstantError<unsigned int>::format = "Failed to find shader constant at location %u in shader %u.";
char const *SetShaderConstantError<char *>::format = "Failed to find shader constant '%s' in shader %u.";

template <typename T, typename I>
void SetShaderConstant(unsigned int shaderID, I identifier, int index, T v1, T v2, T v3, T v4)
{
	ComputerShaderMap::iterator iter = computeShaders.find(shaderID);
	if (iter == computeShaders.end()) {
		PluginError("Attempting to set constant on unknown shader %u.", shaderID);
		return;
	}

	ComputeShader *computeShader = iter->second;

	for (GLuint i = 0; i < computeShader->numUniforms; ++i) {
		Uniform *uniform = computeShader->getUniform(i);
		if (uniform->matchesIdentifier(identifier)) {
			uniform->set(index, v1, v2, v3, v4);
			return;
		}
	}

	PluginError(SetShaderConstantError<I>::format, identifier, shaderID);
}

extern "C"
{
	DLL_EXPORT int Compute_IsSupportedCompute()
	{
		CheckInit();

		if (PLUGIN_STATE_UNSUPPORTED == pluginState) {
			return 0;
		}
		return 1;
	}

	DLL_EXPORT void Compute_SetErrorMode(int mode)
	{
		switch (mode) {
			case ERROR_MODE_IGNORE:
			case ERROR_MODE_REPORT_FIRST:
			case ERROR_MODE_REPORT_ALL:
			case ERROR_MODE_STOP:
				errorMode = (ErrorMode)mode;
				break;

			default:
				PluginError("Invalid error mode %d.", mode);
				break;
		}
	}

	DLL_EXPORT unsigned int Compute_LoadShaderFromString(char *shaderSource)
	{
		GLuint shaderName = glCreateShader(GL_COMPUTE_SHADER);
		if (!shaderName) {
			switch (glGetError()) {
				case GL_INVALID_ENUM: {
					PluginError("Failed to create computer shader. Invalid shader type.");
				}
				default: {
					PluginError("Failed to create computer shader. Unknown error.");
				}
			}
			return 0;
		}

		char *fullShaderSource = GenerateFullShaderSource(shaderSource);

		glShaderSource(shaderName, 1, &fullShaderSource, NULL);
		switch (glGetError()) {
			default: break;
			case GL_INVALID_VALUE: {
				PluginError("Failed to load shader source. Invalid shader name.");
			}
			case GL_INVALID_OPERATION: {
				PluginError("Failed to load shader source. Non-shader object provided as shader.");
			}
			free(fullShaderSource);
			return 0;
		}

		glCompileShader(shaderName);
		switch (glGetError()) {
			default: break;
			case GL_INVALID_VALUE: {
				PluginError("Failed to load shader source. Invalid shader name.");
			}
			case GL_INVALID_OPERATION: {
				PluginError("Failed to load shader source. Non-shader object provided as shader.");
			}
			free(fullShaderSource);
			return 0;
		}
		GLint compileStatus;
		glGetShaderiv(shaderName, GL_COMPILE_STATUS, &compileStatus);
		if (compileStatus != GL_TRUE) {
			GLint logLen;
			glGetShaderiv(shaderName, GL_INFO_LOG_LENGTH, &logLen);
			char *infoLogBuffer = (char *)malloc(logLen);
			glGetShaderInfoLog(shaderName, logLen, NULL, infoLogBuffer);
			PluginError("%s", infoLogBuffer);
			free(infoLogBuffer);
			glDeleteShader(shaderName);
			free(fullShaderSource);
			return 0;
		}

		GLuint programName = glCreateProgram();
		if (!programName) {
			PluginError("Failed to create shader program.");
			glDeleteShader(shaderName);
			free(fullShaderSource);
			return 0;
		}

		glAttachShader(programName, shaderName);
		switch (glGetError()) {
			default: break;
			case GL_INVALID_VALUE: {
				PluginError("Failed to attach shader. Invalid shader or program name.");
			}
			case GL_INVALID_OPERATION: {
				PluginError("Failed to attach shader. Non-program or non-shader object used, shader already attached, or shader of same type already attached.");
			}
			glDeleteShader(shaderName);
			glDeleteProgram(programName);
			free(fullShaderSource);
			return 0;
		}

		glLinkProgram(programName);
		GLint linkStatus;
		glGetProgramiv(programName, GL_LINK_STATUS, &linkStatus);
		if (linkStatus != GL_TRUE) {
			GLint logLen;
			glGetProgramiv(programName, GL_INFO_LOG_LENGTH, &logLen);
			char *infoLogBuffer = (char *)malloc(logLen);
			glGetProgramInfoLog(programName, logLen, NULL, infoLogBuffer);
			PluginError("%s", infoLogBuffer);
			free(infoLogBuffer);
			glDeleteShader(shaderName);
			glDeleteProgram(programName);
			free(fullShaderSource);
			return 0;
		}
		
		glDeleteShader(shaderName);
		free(fullShaderSource);

		unsigned int id = NextShaderID();
		computeShaders[id] = new ComputeShader(programName);
		return id;
	}

	DLL_EXPORT unsigned int Compute_LoadShader(char *shaderFile)
	{
		if (!agk::GetFileExists(shaderFile)) {
			PluginError("Unable to load shader file '%s'.", shaderFile);
			return 0;
		}

		unsigned file = agk::OpenToRead(shaderFile);
		int size = agk::GetFileSize(file);
		char *sourceCode = (char *)malloc(size + 1);
		*sourceCode = '\0';
		while (!agk::FileEOF(file)) {
			char *line = agk::ReadLine(file);
			strcat(sourceCode, line);
			strcat(sourceCode, "\n");
			agk::DeleteString(line);
		}
		agk::CloseFile(file);
		unsigned int shaderID = Compute_LoadShaderFromString(sourceCode);
		free(sourceCode);
		return shaderID;
	}

	DLL_EXPORT void Compute_DeleteShader(unsigned int shaderID)
	{
		ComputerShaderMap::iterator iter = computeShaders.find(shaderID);
		if (iter == computeShaders.end()) {
			PluginError("Attempting to delete non-existent shader %u.", shaderID);
			return;
		}

		delete iter->second;
		computeShaders.erase(iter);
	}

	DLL_EXPORT void Compute_SetShaderImage(unsigned int shaderID, unsigned int imageID, unsigned int attachPoint)
	{
		ComputerShaderMap::iterator iter = computeShaders.find(shaderID);
		if (iter == computeShaders.end()) {
			PluginError("Failed to set shader image on unknown shader %u.", shaderID);
			return;
		}

		if (!agk::GetImageExists(imageID) && imageID != 0) {
			PluginError("Invalid image ID %u in SetShaderImage.", imageID);
			return;
		}

		if (attachPoint >= MAX_IMAGE_BINDINGS) {
			PluginError("Invalid attach point %u in SetShaderImage. Valid attach points are 0-%u.", attachPoint, MAX_IMAGE_BINDINGS - 1);
			return;
		}

		ComputeShader *computeShader = iter->second;
		computeShader->imageBindings[attachPoint] = imageID;

		if (imageID == 0) {
			glBindImageTexture(attachPoint, 0, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA8);
			switch (glGetError()) {
				case GL_INVALID_VALUE: {
					PluginError("Failed to clear image from attach point %u on compute shader %u. Invalid attach point, texture name, level, or layer.", attachPoint, shaderID);
					return;
				}
				case GL_INVALID_ENUM: {
					PluginError("Failed to clear image from attach point %u on computer shader %u. Invalid format or access settings.", attachPoint, shaderID);
					return;
				}
			}
		}
	}

	DLL_EXPORT void Compute_SetShaderConstantByLocation(unsigned int shaderID, unsigned int location, float v1, float v2, float v3, float v4)
	{
		SetShaderConstant(shaderID, location, 0, v1, v2, v3, v4);
	}

	DLL_EXPORT void Compute_SetShaderConstantByName(unsigned int shaderID, char *name, float v1, float v2, float v3, float v4)
	{
		SetShaderConstant(shaderID, name, 0, v1, v2, v3, v4);
	}

	DLL_EXPORT void Compute_SetShaderConstantIntByLocation(unsigned int shaderID, unsigned int location, int v1, int v2, int v3, int v4)
	{
		SetShaderConstant(shaderID, location, 0, v1, v2, v3, v4);
	}

	DLL_EXPORT void Compute_SetShaderConstantIntByName(unsigned int shaderID, char *name, int v1, int v2, int v3, int v4)
	{
		SetShaderConstant(shaderID, name, 0, v1, v2, v3, v4);
	}

	DLL_EXPORT void Compute_SetShaderConstantArrayByLocation(unsigned int shaderID, unsigned int location, int index, float v1, float v2, float v3, float v4)
	{
		SetShaderConstant(shaderID, location, index, v1, v2, v3, v4);
	}

	DLL_EXPORT void Compute_SetShaderConstantArrayByName(unsigned int shaderID, char *name, int index, float v1, float v2, float v3, float v4)
	{
		SetShaderConstant(shaderID, name, index, v1, v2, v3, v4);
	}

	DLL_EXPORT void Compute_SetShaderConstantArrayIntByLocation(unsigned int shaderID, unsigned int location, int index, int v1, int v2, int v3, int v4)
	{
		SetShaderConstant(shaderID, location, index, v1, v2, v3, v4);
	}

	DLL_EXPORT void Compute_SetShaderConstantArrayIntByName(unsigned int shaderID, char *name, int index, int v1, int v2, int v3, int v4)
	{
		SetShaderConstant(shaderID, name, index, v1, v2, v3, v4);
	}

	DLL_EXPORT void Compute_RunShader(unsigned int shaderID, int numGroupsX, int numGroupsY, int numGroupsZ)
	{
		ComputerShaderMap::iterator iter = computeShaders.find((unsigned)shaderID);
		if (iter == computeShaders.end()) {
			PluginError("Attempting to run unknown shader %u.", shaderID);
			return;
		}

		ComputeShader *computeShader = iter->second;

		if (numGroupsX <= 0 || numGroupsY <= 0 || numGroupsZ <= 0) {
			PluginError("Invalid work group sizes specifed (%d, %d, %d) for running compute shader %u. Each dimension must be >= 1.", numGroupsX, numGroupsY, numGroupsZ, shaderID);
			return;
		}

		GLint agkProgramName;
		glGetIntegerv(GL_CURRENT_PROGRAM, &agkProgramName);

		glUseProgram(computeShader->programName);
		switch (glGetError()) {
			case GL_INVALID_VALUE: {
				PluginError("Failed to run shader. Unknown program.");
				goto exit_run_shader;
			}
			case GL_INVALID_OPERATION: {
				PluginError("Failed to run shader. Non-program object used, or unable to make program part of current state.");
				goto exit_run_shader;
			}
		}

		for (GLuint attachPoint = 0; attachPoint < MAX_IMAGE_BINDINGS; ++attachPoint) {
			if (computeShader->imageBindings[attachPoint] != 0) {
				unsigned int imageID = computeShader->imageBindings[attachPoint];
				AGK::cImage *image = agk::GetImagePtr(imageID);
				if (!image) {
					PluginError("Failed to attach image %u to computer shader. Has this image been deleted?", imageID);
					goto exit_run_shader;
				}

				glBindImageTexture(attachPoint, image->m_iTextureID, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA8);
				switch (glGetError()) {
					case GL_INVALID_VALUE: {
						PluginError("Failed to attach image %u to computer shader. Invalid attach point, texture name, level, or layer.", imageID);
						goto exit_run_shader;
					}
					case GL_INVALID_ENUM: {
						PluginError("Failed to attach image %u to computer shader. Invalid format or access settings.", imageID);
						goto exit_run_shader;
					}
				}
			}
		}

		for (unsigned int i = 0; i < MAX_BUFFER_BINDINGS; ++i) {
			if (computeShader->bufferBindings[i].bufferID == 0) {
				break;
			}

			BufferObjectMap::iterator iter = bufferObjects.find(computeShader->bufferBindings[i].bufferID);
			if (iter == bufferObjects.end()) {
				PluginError("Failed to bind non-existent buffer %u. Has this buffer been deleted?", computeShader->bufferBindings[i].bufferID);
				goto exit_run_shader;
			}

			BufferObject *bufferObject = iter->second;

			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, computeShader->bufferBindings[i].bindingPoint, bufferObject->bufferName);
			switch (glGetError()) {
				case GL_INVALID_ENUM: {
					PluginError("Failed to bind buffer. Invalid target.");
					goto exit_run_shader;
				}
				case GL_INVALID_VALUE: {
					PluginError("Failed to bind buffer. Invalid binding point or empty buffer used.");
					goto exit_run_shader;
				}
			}
		}

		for (GLuint i = 0; i < computeShader->numUniforms; ++i) {
			Uniform *uniform = computeShader->getUniform(i);
			if (uniform->dirty) {
				uniform->apply();
			}
		}

		glDispatchCompute(numGroupsX, numGroupsY, numGroupsZ);
		switch (glGetError()) {
			case GL_INVALID_VALUE: {
				PluginError("Failed to run shader. Too many global work groups requested.");
				goto exit_run_shader;
			}
			case GL_INVALID_OPERATION: {
				PluginError("Failed to run shader. No active compute shader found.");
				goto exit_run_shader;
			}
		}

exit_run_shader:
		glUseProgram(agkProgramName);
	}

	DLL_EXPORT unsigned int Compute_CreateBuffer(int size)
	{
		if (size <= 0) {
			PluginError("Failed to create buffer of size %d. Buffer size must be greater than 0.", size);
			return 0;
		}
		return CreateBuffer((GLsizei)size, NULL);
	}

	DLL_EXPORT unsigned int Compute_CreateBufferFromMemblock(unsigned int memblockID)
	{
		unsigned char *data = agk::GetMemblockPtr(memblockID);
		if (!data) {
			PluginError("Failed to create buffer from unknown memblock %u.", memblockID);
			return 0;
		}

		GLsizei size = (GLsizei)agk::GetMemblockSize(memblockID);
		if (size == 0) {
			PluginError("Failed to create buffer from a memblock with size 0.");
			return 0;
		}

		return CreateBuffer(size, data);
	}

	DLL_EXPORT void Compute_DeleteBuffer(unsigned int bufferID)
	{
		BufferObjectMap::iterator iter = bufferObjects.find(bufferID);
		if (iter == bufferObjects.end()) {
			PluginError("Attempting to delete non-existent buffer %u.", bufferID);
			return;
		}

		delete iter->second;
		
		bufferObjects.erase(iter);
	}

	DLL_EXPORT int Compute_GetBufferSize(unsigned int bufferID)
	{
		BufferObjectMap::iterator iter = bufferObjects.find(bufferID);
		if (iter == bufferObjects.end()) {
			PluginError("Attempting to get size of non-existent buffer %u.", bufferID);
			return 0;
		}

		return iter->second->bufferSize;
	}

	DLL_EXPORT void Compute_SetShaderBuffer(unsigned int shaderID, unsigned int bufferID, unsigned int bindingPoint)
	{
		ComputerShaderMap::iterator iter = computeShaders.find(shaderID);
		if (iter == computeShaders.end()) {
			PluginError("Failed to set shader buffer on unknown shader %u.", shaderID);
			return;
		}

		ComputeShader *computeShader = iter->second;

		if (bufferID) {
			BufferObjectMap::iterator iter = bufferObjects.find(bufferID);
			if (iter == bufferObjects.end()) {
				PluginError("Failed to set unknown buffer %u on shader %u.", bufferID);
				return;
			}

			for (unsigned int i = 0; i < MAX_BUFFER_BINDINGS; ++i) {
				if (computeShader->bufferBindings[i].bindingPoint == bindingPoint) {
					computeShader->bufferBindings[i].bufferID = bufferID;
					return;
				}
				if (computeShader->bufferBindings[i].bufferID == 0) {
					computeShader->bufferBindings[i].bindingPoint = bindingPoint;
					computeShader->bufferBindings[i].bufferID = bufferID;
					return;
				}
			}
			PluginError("Failed to bind buffer %u to shader %u at binding point %u as there are no binding points available. Max binding points are %u.", bufferID, shaderID, bindingPoint, MAX_BUFFER_BINDINGS);
		}
		else {
			for (unsigned int i = 0; i < MAX_BUFFER_BINDINGS; ++i) {
				if (computeShader->bufferBindings[i].bindingPoint == bindingPoint) {
					unsigned int j;
					for (j = i + 1; j < MAX_BUFFER_BINDINGS && computeShader->bufferBindings[j].bufferID > 0; ++j);
					if (j > i + 1) {
						computeShader->bufferBindings[i].bindingPoint = computeShader->bufferBindings[j - 1].bindingPoint;
						computeShader->bufferBindings[i].bufferID = computeShader->bufferBindings[j - 1].bufferID;
						computeShader->bufferBindings[j - 1].bufferID = 0;
					}
					else {
						computeShader->bufferBindings[i].bufferID = 0;
					}
					glBindBufferBase(GL_SHADER_STORAGE_BUFFER, computeShader->bufferBindings[i].bindingPoint, 0);
					switch (glGetError()) {
						case GL_INVALID_ENUM: {
							PluginError("Failed to clear buffer from binding point %u on shader %u. Invalid target.", bindingPoint, shaderID);
							return;
						}
						case GL_INVALID_VALUE: {
							PluginError("Failed to clear buffer from binding point %u on shader %u. Invalid binding point or empty buffer used.", bindingPoint, shaderID);
							return;
						}
					}
					return;
				}
				if (computeShader->bufferBindings[i].bufferID == 0) {
					return;
				}
			}
		}
	}

	DLL_EXPORT unsigned int Compute_CreateMemblockFromBuffer(unsigned int bufferID)
	{
		BufferObjectMap::iterator iter = bufferObjects.find(bufferID);
		if (iter == bufferObjects.end()) {
			PluginError("Failed to create memblock from unknown buffer %u.", bufferID);
			return 0;
		}

		BufferObject *bufferObject = iter->second;

		glBindBuffer(GL_SHADER_STORAGE_BUFFER, bufferObject->bufferName);
		switch (glGetError()) {
			case GL_INVALID_ENUM: {
				PluginError("Failed to create memblock from buffer. Invalid target.");
				return 0;
			}
			case GL_INVALID_VALUE: {
				PluginError("Failed to create memblock from buffer. Unknown buffer name.");
				return 0;
			}
		}

		void *data = glMapBuffer(GL_SHADER_STORAGE_BUFFER, GL_READ_ONLY);
		switch (glGetError()) {
			case GL_INVALID_ENUM: {
				PluginError("Failed to create memblock from buffer. Invalid target or access type.");
				return 0;
			}
			case GL_INVALID_OPERATION: {
				PluginError("Failed to create memblock from buffer. Target not bound to buffer or already mapped.");
				return 0;
			}
			case GL_OUT_OF_MEMORY: {
				PluginError("Failed to create memblock from buffer. Insufficient memory available.");
				return 0;
			}
		}

		unsigned int memblockID = agk::CreateMemblock(bufferObject->bufferSize);
		void *memblockPtr = (void *)agk::GetMemblockPtr(memblockID);

		memcpy(memblockPtr, data, bufferObject->bufferSize);

		glUnmapBuffer(GL_SHADER_STORAGE_BUFFER);
		switch (glGetError()) {
			case GL_INVALID_ENUM: {
				agk::DeleteMemblock(memblockID);
				PluginError("Failed to create memblock from buffer. Invalid target.");
				return 0;
			}
			case GL_INVALID_OPERATION: {
				agk::DeleteMemblock(memblockID);
				PluginError("Failed to create memblock from buffer. Target not bound, or is not mapped.");
				return 0;
			}
		}

		return memblockID;
	}

	DLL_EXPORT void Compute_UpdateBufferFromMemblock(unsigned int bufferID, unsigned int memblockID)
	{
		BufferObjectMap::iterator iter = bufferObjects.find(bufferID);
		if (iter == bufferObjects.end()) {
			PluginError("Failed to update unknown buffer %u.", bufferID);
			return;
		}

		BufferObject *bufferObject = iter->second;

		unsigned char *data = agk::GetMemblockPtr(memblockID);
		if (!data) {
			PluginError("Failed to update buffer from unknown memblock %u.", memblockID);
			return;
		}

		GLsizei size = (GLsizei)agk::GetMemblockSize(memblockID);
		if (size == 0) {
			PluginError("Failed to update buffer from a memblock with size 0.");
			return;
		}

		glBindBuffer(GL_SHADER_STORAGE_BUFFER, bufferObject->bufferName);
		switch (glGetError()) {
			case GL_INVALID_ENUM: {
				PluginError("Failed to update buffer. Invalid target.");
				return;
			}
			case GL_INVALID_VALUE: {
				PluginError("Failed to update buffer. Unknown buffer name.");
				return;
			}
		}

		glBufferData(GL_SHADER_STORAGE_BUFFER, size, data, GL_STATIC_COPY);
		switch (glGetError()) {
			case GL_INVALID_ENUM: {
				PluginError("Failed to update buffer. Invalid target or usage.");
				return;
			}
			case GL_INVALID_VALUE: {
				PluginError("Failed to update buffer. Invalid memblock size.");
				return;
			}
			case GL_INVALID_OPERATION: {
				PluginError("Failed to update buffer. Unknown or immutable buffer object used.");
				return;
			}
			case GL_OUT_OF_MEMORY: {
				PluginError("Failed to update buffer. Insufficient memory available.");
				return;
			}
		}

		bufferObject->bufferSize = size;
	}

	DLL_EXPORT void Compute_CopyBufferToMemblock(unsigned int bufferID, unsigned int memblockID)
	{
		BufferObjectMap::iterator iter = bufferObjects.find(bufferID);
		if (iter == bufferObjects.end()) {
			PluginError("Failed to copy unknown buffer %u to memblock %u.", bufferID, memblockID);
			return;
		}

		BufferObject *bufferObject = iter->second;

		unsigned char *memblockPtr = agk::GetMemblockPtr(memblockID);
		if (!memblockPtr) {
			PluginError("Failed to copy buffer %u to unknown memblock %u.", bufferID, memblockID);
			return;
		}

		GLsizei size = (GLsizei)agk::GetMemblockSize(memblockID);
		if (size < bufferObject->bufferSize) {
			PluginError("Insufficient space in memblock to copy from buffer. Memblock is %u bytes and buffer is %u bytes.", size, bufferObject->bufferSize);
			return;
		}

		glBindBuffer(GL_SHADER_STORAGE_BUFFER, bufferObject->bufferName);
		switch (glGetError()) {
			case GL_INVALID_ENUM: {
				PluginError("Failed to copy buffer to memblock. Invalid target.");
				return;
			}
			case GL_INVALID_VALUE: {
				PluginError("Failed to copy buffer to memblock. Unknown buffer name.");
				return;
			}
		}

		void *data = glMapBuffer(GL_SHADER_STORAGE_BUFFER, GL_READ_ONLY);
		switch (glGetError()) {
			case GL_INVALID_ENUM: {
				PluginError("Failed to copy buffer to memblock. Invalid target or access type.");
				return;
			}
			case GL_INVALID_OPERATION: {
				PluginError("Failed to copy buffer to memblock. Target not bound to buffer or already mapped.");
				return;
			}
			case GL_OUT_OF_MEMORY: {
				PluginError("Failed to copy buffer to memblock. Insufficient memory available.");
				return;
			}
		}

		memcpy(memblockPtr, data, bufferObject->bufferSize);

		glUnmapBuffer(GL_SHADER_STORAGE_BUFFER);
		switch (glGetError()) {
			case GL_INVALID_ENUM: {
				agk::DeleteMemblock(memblockID);
				PluginError("Failed to copy buffer to memblock. Invalid target.");
				return;
			}
			case GL_INVALID_OPERATION: {
				agk::DeleteMemblock(memblockID);
				PluginError("Failed to copy buffer to memblock. Target not bound, or is not mapped.");
				return;
			}
		}
	}

	DLL_EXPORT int Compute_GetMaxNumWorkGroupsX()
	{
		GLint max;
		glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 0, &max);
		return (int)max;
	}

	DLL_EXPORT int Compute_GetMaxNumWorkGroupsY()
	{
		GLint max;
		glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 1, &max);
		return (int)max;
	}

	DLL_EXPORT int Compute_GetMaxNumWorkGroupsZ()
	{
		GLint max;
		glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 2, &max);
		return (int)max;
	}

	DLL_EXPORT int Compute_GetMaxWorkGroupSizeX()
	{
		GLint max;
		glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 0, &max);
		return (int)max;
	}

	DLL_EXPORT int Compute_GetMaxWorkGroupSizeY()
	{
		GLint max;
		glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 1, &max);
		return (int)max;
	}

	DLL_EXPORT int Compute_GetMaxWorkGroupSizeZ()
	{
		GLint max;
		glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 2, &max);
		return (int)max;
	}

	DLL_EXPORT int Compute_GetMaxWorkGroupSizeTotal()
	{
		GLint max;
		glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS, &max);
		return (int)max;
	}

	DLL_EXPORT int Compute_GetMaxSharedMemory()
	{
		GLint max;
		glGetIntegerv(GL_MAX_COMPUTE_SHARED_MEMORY_SIZE, &max);
		return (int)max;
	}

	DLL_EXPORT int Compute_GetMaxBufferSize()
	{
		GLint64 maxSize;
		glGetInteger64v(GL_MAX_SHADER_STORAGE_BLOCK_SIZE, &maxSize);
		if (maxSize > INT_MAX) {
			return INT_MAX;
		}
		return (int)maxSize;
	}
}
