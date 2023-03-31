/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/shadow.glsl:
  Render shadow map

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;

flat out uint material_mask;
flat out vec3 tint;
flat out mat3 tbn;

#ifdef WATER_CAUSTICS
out vec3 scene_pos;
#endif

// --------------
//   Attributes
// --------------

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

// ------------
//   Uniforms
// ------------

uniform sampler2D tex;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 taa_offset;
uniform vec3 light_dir;

// ------------
//   Includes
// ------------

#include "/include/light/distortion.glsl"
#include "/include/vertex/displacement.glsl"

void main() {
	uv            = gl_MultiTexCoord0.xy;
	material_mask = uint(mc_Entity.x - 10000.0);
	tint          = gl_Color.rgb;

	tbn[0] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbn[2] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

	bool is_top_vertex = uv.y < mc_midTexCoord.y;

	vec3 pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	     pos = transform(shadowModelViewInverse, pos);
	     pos = pos + cameraPosition;
	     pos = animate_vertex(pos, is_top_vertex, clamp01(rcp(240.0) * gl_MultiTexCoord1.y), material_mask);
		 pos = pos - cameraPosition;

#ifdef WATER_CAUSTICS
	scene_pos = pos;
#endif

	vec3 shadow_view_pos = transform(shadowModelView, pos);
	vec3 shadow_clip_pos = project_ortho(gl_ProjectionMatrix, shadow_view_pos);
	     shadow_clip_pos = distort_shadow_space(shadow_clip_pos);

	gl_Position = vec4(shadow_clip_pos, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 shadowcolor0_out;

/* DRAWBUFFERS:0 */

in vec2 uv;
in vec3 world_pos;

flat in uint material_mask;
flat in vec3 tint;
flat in mat3 tbn;

#ifdef WATER_CAUSTICS
in vec3 scene_pos;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D tex;
uniform sampler2D noisetex;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 taa_offset;
uniform vec3 light_dir;

#include "/include/misc/water_normal.glsl"
#include "/include/utility/color.glsl"

const float air_n = 1.000293; // for 0°C and 1 atm
const float water_n = 1.333;  // for 20°C
const float distance_through_water = 5.0;

const vec3 water_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
const vec3 water_scattering_coeff = vec3(WATER_SCATTERING);
const vec3 water_extinction_coeff = water_absorption_coeff + water_scattering_coeff;

// using the built-in GLSL refract() seems to cause NaNs on Intel drivers, but with this
// function, which does the exact same thing, it's fine
vec3 refract_safe(vec3 I, vec3 N, float eta) {
	float NoI = dot(N, I);
	float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
	if (k < 0.0) {
		return vec3(0.0);
	} else {
		return eta * I - (eta * NoI + sqrt(k)) * N;
	}
}

float get_water_caustics() {
#ifndef WATER_CAUSTICS
	return 1.0;
#else
	vec3 world_pos = scene_pos + cameraPosition;
	vec2 coord = world_pos.xz;

	bool flowing_water = abs(tbn[2].y) < 0.99;
	vec2 flow_dir = flowing_water ? normalize(tbn[2].xz) : vec2(0.0);

	vec3 normal = tbn * get_water_normal(world_pos, tbn[2], coord, flow_dir, 1.0, flowing_water);

	vec3 old_pos = world_pos;
	vec3 new_pos = world_pos + refract_safe(light_dir, normal, air_n / water_n) * distance_through_water;

	float old_area = length_squared(dFdx(old_pos)) * length_squared(dFdy(old_pos));
	float new_area = length_squared(dFdx(new_pos)) * length_squared(dFdy(new_pos));

	if (old_area == 0.0 || new_area == 0.0) return 1.0;

	return inversesqrt(old_area / new_area);
#endif
}

void main() {
#ifdef SHADOW_COLOR
	if (material_mask == 1) { // Water
		shadowcolor0_out = clamp01(0.25 * exp(-water_extinction_coeff * distance_through_water) * get_water_caustics());
	} else {
		vec4 base_color = textureLod(tex, uv, 0);
		if (base_color.a < 0.1) discard;

		shadowcolor0_out  = mix(vec3(1.0), base_color.rgb * tint, base_color.a);
		shadowcolor0_out  = 0.25 * srgb_eotf_inv(shadowcolor0_out) * rec709_to_rec2020;
		shadowcolor0_out *= step(base_color.a, 1.0 - rcp(255.0));
	}
#else
	if (texture(tex, uv).a < 0.1) discard;
#endif
}

#endif
//----------------------------------------------------------------------------//
