shader_type spatial;
// 弾の見た目。常にカメラを向く板に、芯が白い光の玉を描く。
// 光源は持たず、明るさ1以上の色と画面のグローで光って見せる。
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

varying vec3 v_color;

void vertex() {
	v_color = COLOR.rgb;
	float s = INSTANCE_CUSTOM.x;
	vec3 center = MODEL_MATRIX[3].xyz;
	// カメラの向きの軸をそのまま使って板をカメラに向ける
	mat4 bb = mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, vec4(center, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float body = 1.0 - smoothstep(0.55, 1.0, d);
	float core = 1.0 - smoothstep(0.0, 0.45, d);
	ALBEDO = v_color * body + vec3(1.0) * core * 1.5;
	ALPHA = body;
}
