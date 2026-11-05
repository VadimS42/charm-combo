// fade_bottom.gdshader — fades the bottom `fade` of a picture to nothing
// (VNScreen: a portrait whose art is cut off at the bottom).
shader_type canvas_item;

uniform float fade = 0.15;

void fragment() {
	// COLOR already holds the texture times modulate here.
	COLOR.a *= 1.0 - smoothstep(1.0 - fade, 1.0, UV.y);
}
