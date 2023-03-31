/*
--------------------------------------------------------------------------------

  GLSL Debug Text Renderer by SixthSurge

  Character set based on Monocraft by IdreesInc
  https://github.com/IdreesInc/Monocraft

  Usage:

  // Call begin_text to initialize the text renderer. You can scale the fragment position to adjust the size of the text
  begin_text(ivec2(gl_FragCoord.xy), ivec2(0, viewHeight));
            ^ fragment position     ^ text box position (upper left corner)

  // You can print various data types
  print_bool(false);
  print_float(sqrt(-1.0)); // Prints "NaN"
  print_int(42);
  print_vec3(sky_color);

  // ...or arbitrarily long strings
  print((_H, _e, _l, _l, _o, _comma, _space, _w, _o, _r, _l, _d));

  // To start a new line, use
  print_line();

  // You can also configure the text color on the fly
  text.fg_col = vec4(1.0, 0.0, 0.0, 1.0);
  text.bg_col = vec4(0.0, 0.0, 0.0, 1.0);

  // ...as well as the number base and number of decimal places to print
  text.base = 16;
  text.fp_precision = 4;

  // Finally, call end_text to blend the current fragment color with the text
  end_text(scene_color);

  Important: any variables you display must be the same for all fragments, or
  at least all of the fragments that the text covers. Otherwise, different
  fragments will try to print different values, resulting in, well, a mess

--------------------------------------------------------------------------------
*/

#if !defined INCLUDE_UTILITY_TEXT_RENDERING
#define INCLUDE_UTILITY_TEXT_RENDERING

// Characters

const uint _A     = 0x747f18c4;
const uint _B     = 0xf47d18f8;
const uint _C     = 0x746108b8;
const uint _D     = 0xf46318f8;
const uint _E     = 0xfc39087c;
const uint _F     = 0xfc390840;
const uint _G     = 0x7c2718b8;
const uint _H     = 0x8c7f18c4;
const uint _I     = 0x71084238;
const uint _J     = 0x084218b8;
const uint _K     = 0x8cb928c4;
const uint _L     = 0x8421087c;
const uint _M     = 0x8eeb18c4;
const uint _N     = 0x8e6b38c4;
const uint _O     = 0x746318b8;
const uint _P     = 0xf47d0840;
const uint _Q     = 0x74631934;
const uint _R     = 0xf47d18c4;
const uint _S     = 0x7c1c18b8;
const uint _T     = 0xf9084210;
const uint _U     = 0x8c6318b8;
const uint _V     = 0x8c62a510;
const uint _W     = 0x8c635dc4;
const uint _X     = 0x8a88a8c4;
const uint _Y     = 0x8a884210;
const uint _Z     = 0xf844447c;
const uint _a     = 0x0382f8bc;
const uint _b     = 0x85b318f8;
const uint _c     = 0x03a308b8;
const uint _d     = 0x0b6718bc;
const uint _e     = 0x03a3f83c;
const uint _f     = 0x323c8420;
const uint _g     = 0x03e2f0f8;
const uint _h     = 0x842d98c4;
const uint _i     = 0x40308418;
const uint _j     = 0x080218b8;
const uint _k     = 0x4254c524;
const uint _l     = 0x6108420c;
const uint _m     = 0x06ab5ac4;
const uint _n     = 0x07a318c4;
const uint _o     = 0x03a318b8;
const uint _p     = 0x05b31f40;
const uint _q     = 0x03671784;
const uint _r     = 0x05b30840;
const uint _s     = 0x03e0e0f8;
const uint _t     = 0x211c420c;
const uint _u     = 0x046318bc;
const uint _v     = 0x04631510;
const uint _w     = 0x04635abc;
const uint _x     = 0x04544544;
const uint _y     = 0x0462f0f8;
const uint _z     = 0x07c4447c;
const uint _0     = 0x746b58b8;
const uint _1     = 0x23084238;
const uint _2     = 0x744c88fc;
const uint _3     = 0x744c18b8;
const uint _4     = 0x19531f84;
const uint _5     = 0xfc3c18b8;
const uint _6     = 0x3221e8b8;
const uint _7     = 0xfc422210;
const uint _8     = 0x745d18b8;
const uint _9     = 0x745e1130;
const uint _space = 0x0000000;
const uint _dot   = 0x000010;
const uint _minus = 0x0000e000;
const uint _comma = 0x00000220;
const uint _colon = 0x02000020;

const int char_width   = 5;
const int char_height  = 6;
const int char_spacing = 1;
const int line_spacing = 1;

const ivec2 char_size  = ivec2(char_width, char_height);
const ivec2 space_size = char_size + ivec2(char_spacing, line_spacing);

// Text renderer

struct Text {
	vec4 result;     // Output color from the text renderer
	vec4 fg_col;      // Text foreground color
	vec4 bg_col;      // Text background color
	ivec2 frag_pos;   // The position of the fragment (can be scaled to adjust the size of the text)
	ivec2 text_pos;   // The position of the top-left corner of the text
	ivec2 char_pos;   // The position of the next character in the text
	int base;        // Number base
	int fp_precision; // Number of decimal places to print
} text;

// Fills the global text object with default values
void begin_text(ivec2 frag_pos, ivec2 text_pos) {
	text.result      = vec4(0.0);
	text.fg_col       = vec4(1.0);
	text.bg_col       = vec4(0.0, 0.0, 0.0, 0.6);
	text.frag_pos     = frag_pos;
	text.text_pos     = text_pos;
	text.char_pos     = ivec2(0);
	text.base        = 10;
	text.fp_precision = 2;
}

// Applies the rendered text to the fragment
void end_text(inout vec3 scene_color) {
	scene_color = mix(scene_color.rgb, text.result.rgb, text.result.a);
}

void print_char(uint character) {
	ivec2 pos = text.frag_pos - text.text_pos - space_size * text.char_pos * ivec2(1, -1) + ivec2(0, space_size.y);

	uint index = uint(char_width - pos.x + pos.y * char_width + 1u);

	// Draw background
	if (clamp(pos, ivec2(0), space_size - 1) == pos)
		text.result = mix(text.result, text.bg_col, text.bg_col.a);

	// Draw character
	if (clamp(pos, ivec2(0), char_size - 1) == pos)
		text.result = mix(text.result, text.fg_col, text.fg_col.a * float(character >> index & 1u));

	// Advance to next character
	text.char_pos.x++;
}

#define print(string) {                                               \
	uint[] characters = uint[] string;                                     \
	for (int i = 0; i < characters.length(); ++i) print_char(characters[i]); \
}

void print_unsigned_int(uint value, int len) {
	const uint[36] digits = uint[](
		_0, _1, _2, _3, _4, _5, _6, _7, _8, _9,
		_a, _b, _c, _d, _e, _f, _g, _h, _i, _j,
		_k, _l, _m, _n, _o, _p, _q, _r, _s, _t,
		_u, _v, _w, _x, _y, _z
	);

	// Advance to end of the number
	text.char_pos.x += len - 1;

	// Write number backwards
	for (int i = 0; i < len; ++i) {
		print_char(digits[value % text.base]);
		value /= text.base;
		text.char_pos.x -= 2;
	}

	// Return to end of the number
	text.char_pos.x += len + 1;
}

void print_unsigned_int(uint value) {
	float log_value = log(float(value));
	float log_base  = log(float(text.base));

	int len = int(ceil(log_value / log_base));
	    len = max(len, 1);

	print_unsigned_int(value, len);
}

void print_int(int value) {
	if (value < 0) print_char(_minus);
	print_unsigned_int(uint(abs(value)));
}

void print_float(float value) {
	if (value < 0.0) print_char(_minus);

	if (isnan(value)) {
		print((_N, _a, _N));
	} else if (isinf(value)) {
		print((_i, _n, _f));
	} else {
		float i, f = modf(abs(value), i);

		uint integral_part   = uint(i);
		uint fractional_part = uint(f * pow(float(text.base), float(text.fp_precision)) + 0.5);

		print_unsigned_int(integral_part);
		print_char(_dot);
		print_unsigned_int(fractional_part, text.fp_precision);
	}
}

void print_bool(bool value) {
	if (value) {
		print((_t, _r, _u, _e));
	} else {
		print((_f, _a, _l, _s, _e));
	}
}

void print_vec2(vec2 value) {
	print_float(value.x);
	print((_comma, _space));
	print_float(value.y);
}
void print_vec3(vec3 value) {
	print_float(value.x);
	print((_comma, _space));
	print_float(value.y);
	print((_comma, _space));
	print_float(value.z);
}
void print_vec4(vec4 value) {
	print_float(value.x);
	print((_comma, _space));
	print_float(value.y);
	print((_comma, _space));
	print_float(value.z);
	print((_comma, _space));
	print_float(value.w);
}

void print_ivec2(ivec2 value) {
	print_int(value.x);
	print((_comma, _space));
	print_int(value.y);
}
void print_ivec3(ivec3 value) {
	print_int(value.x);
	print((_comma, _space));
	print_int(value.y);
	print((_comma, _space));
	print_int(value.z);
}
void print_ivec4(ivec4 value) {
	print_int(value.x);
	print((_comma, _space));
	print_int(value.y);
	print((_comma, _space));
	print_int(value.z);
	print((_comma, _space));
	print_int(value.w);
}

void print_uvec2(uvec2 value) {
	print_unsigned_int(value.x);
	print((_comma, _space));
	print_unsigned_int(value.y);
}
void print_uvec3(uvec3 value) {
	print_unsigned_int(value.x);
	print((_comma, _space));
	print_unsigned_int(value.y);
	print((_comma, _space));
	print_unsigned_int(value.z);
}
void print_uvec4(uvec4 value) {
	print_unsigned_int(value.x);
	print((_comma, _space));
	print_unsigned_int(value.y);
	print((_comma, _space));
	print_unsigned_int(value.z);
	print((_comma, _space));
	print_unsigned_int(value.w);
}


void print_bvec2(bvec2 value) {
	print_bool(value.x);
	print((_comma, _space));
	print_bool(value.y);
}
void print_bvec3(bvec3 value) {
	print_bool(value.x);
	print((_comma, _space));
	print_bool(value.y);
	print((_comma, _space));
	print_bool(value.z);
}
void print_bvec4(bvec4 value) {
	print_bool(value.x);
	print((_comma, _space));
	print_bool(value.y);
	print((_comma, _space));
	print_bool(value.z);
	print((_comma, _space));
	print_bool(value.w);
}


void print_line() {
	text.char_pos.x = 0;
	++text.char_pos.y;
}

#endif // INCLUDE_UTILITY_TEXT_RENDERING
