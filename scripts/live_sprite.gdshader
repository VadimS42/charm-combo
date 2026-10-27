// live_sprite.gdshader — brings a character's main sprite to life (round 20,
// first Hazel). Drawn by LiveSprite.gd, which sets every uniform each frame.
//
// The sprite comes as three pictures of the same size (ArtAssets.live_rig()):
//   TEXTURE   base: her body, head and tree, with the free-hanging hair cut out
//   hair_tex  just that hair (continued a little under her arm and thigh)
//   mask_tex  R = how much a pixel rises when she breathes in, G = head sway
//             weight, B = "in front of the hair" (arm, dress, thigh),
//             A = how freely the hair swings there (tips resting on the branch
//             swing less)
// and an optional blink_tex: [half-shut | shut] patches of her eye area.
//
// Every effect is a small sideways/upward resample of those pictures, so
// she stays exactly the drawn art at rest and never "snaps" between frames.
shader_type canvas_item;

uniform sampler2D hair_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D blink_tex : filter_linear_mipmap, repeat_disable;

uniform float lift_px = 0.0;      // breathing: how far her shoulders rise (sprite px)
uniform float head_px = 0.0;      // head drift / shake, sideways (sprite px)
uniform float sway_phase = 0.0;   // hair sway, radians
uniform float sway_px = 0.0;      // hair sway at the tips (sprite px)
uniform float swish_phase = 0.0;  // a quick extra swing (reactions)
uniform float swish_px = 0.0;
uniform float wave_k = 0.009;     // how much the sway lags down the hair (rad/px)
uniform float hair_root_y = 128.0;
uniform float hair_tip_y = 610.0;
uniform vec4 blink_rect = vec4(0.0);   // sprite px: x, y, w, h
uniform float blink_frame = 0.0;       // 0 open, 1 half-shut, 2 shut
uniform float blink_frames = 2.0;

varying vec4 v_color;

void vertex() {
	v_color = COLOR;  // modulate / self_modulate (the red flash on a cursed gem)
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = UV * size;

	// Body: rises with each breath (fading out toward where she sits), head
	// drifts. Sampling from below/beside is what moves the picture.
	vec4 m = texture(mask_tex, UV);
	vec2 pb = p + vec2(-head_px * m.g, lift_px * m.r);
	vec2 uvb = pb / size;
	vec4 base = texture(TEXTURE, uvb);

	if (blink_frame > 0.5 && blink_rect.z > 0.0) {
		vec2 lp = (pb - blink_rect.xy) / blink_rect.zw;
		if (lp.x >= 0.0 && lp.y >= 0.0 && lp.x < 1.0 && lp.y < 1.0) {
			vec4 e = texture(blink_tex, vec2((lp.x + blink_frame - 1.0) / blink_frames, lp.y));
			base.rgb = mix(base.rgb, e.rgb, e.a);
		}
	}

	// Hair: still at the roots, swinging more toward the tips, as a slow wave
	// travelling down the strands (and a beat later on her other side).
	float r = clamp((p.y - hair_root_y) / (hair_tip_y - hair_root_y), 0.0, 1.0);
	float bend = r * r * (0.65 + 0.35 * (3.0 - 2.0 * r));
	float w1 = sin(sway_phase - wave_k * p.y + p.x * 0.0035);
	float w2 = sin(1.83 * sway_phase - 1.7 * wave_k * p.y + 1.3);
	float dx = (sway_px * (w1 + 0.28 * w2) + swish_px * sin(swish_phase - 1.6 * wave_k * p.y)) * bend * m.a;
	float hl = lift_px * (1.0 - 0.5 * smoothstep(230.0, 600.0, p.y));
	vec4 hair = texture(hair_tex, (p + vec2(-dx, hl)) / size);

	// The hair hangs behind her arm and thigh: hidden wherever they are.
	float front = texture(mask_tex, uvb).b;
	float ha = hair.a * (1.0 - front);
	float oa = ha + base.a * (1.0 - ha);
	vec3 oc = (hair.rgb * ha + base.rgb * base.a * (1.0 - ha)) / max(oa, 0.0001);
	COLOR = vec4(oc, oa) * v_color;
}
