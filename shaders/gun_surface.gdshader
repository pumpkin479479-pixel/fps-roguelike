shader_type spatial;
// 銃の素材: 単色の部品に、角の擦れ・細かい傷・色むら・木目を自動で付ける。
// 模様は銃自身の座標で決まるので、銃を動かしても模様は滑らない。
// kind: 0 = 金属, 1 = 木, 2 = 樹脂

uniform vec3 base_color : source_color = vec3(0.08);
uniform float metallic_value = 0.55;
uniform float roughness_value = 0.45;
uniform int kind = 0;
uniform float wear : hint_range(0.0, 1.0) = 0.5;        // 使い込み(擦れと傷の量)
uniform vec3 edge_color : source_color = vec3(0.42, 0.42, 0.44); // 擦れて出た地金
uniform float pattern_scale = 1.0;
uniform float seed = 0.0;

varying vec3 obj_pos;
varying vec3 obj_nrm;

void vertex() {
	obj_pos = VERTEX * pattern_scale + vec3(seed * 13.1, seed * 7.3, seed * 3.7);
	obj_nrm = NORMAL;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
	               mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
	               mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// 細い線状の傷: 引き伸ばしたノイズの谷を線として拾う(使い込むほど本数が増える)
float scratches(vec3 p, float w) {
	float s = 0.0;
	for (int k = 0; k < 3; k++) {
		float ang = float(k) * 2.1 + seed;
		vec3 q = vec3(p.x * cos(ang) - p.z * sin(ang), p.y, p.x * sin(ang) + p.z * cos(ang));
		float n = noise(vec3(q.x * 4.0, q.y * 260.0, q.z * 4.0) + float(k) * 11.0);
		float line = smoothstep(0.035, 0.0, abs(n - 0.5));
		float mask = smoothstep(0.75 - w * 0.3, 0.9 - w * 0.25, noise(q * 18.0 + float(k) * 5.0));
		s = max(s, line * mask);
	}
	return s;
}

void fragment() {
	vec3 col = base_color;
	float rough = roughness_value;
	float metal = metallic_value;
	float big = fbm(obj_pos * 9.0);       // 大きな色むら
	float fine = fbm(obj_pos * 80.0);     // 細かいざらつき

	// 角の検出: 画面上で法線が急に変わる所(面取りした角)を角とみなす
	vec3 n = normalize(obj_nrm);
	float edge = clamp(length(fwidth(n)) * 10.0, 0.0, 1.0);
	edge *= smoothstep(0.55, 0.75, fbm(obj_pos * 40.0) + wear * 0.45);

	if (kind == 1) {
		// 木: 銃の長さ方向(Z)に流れる木目
		float grain = fbm(vec3(obj_pos.x * 60.0, obj_pos.y * 60.0, obj_pos.z * 6.0));
		float rings = sin((obj_pos.y * 90.0 + obj_pos.x * 40.0 + grain * 9.0)) * 0.5 + 0.5;
		col *= mix(0.72, 1.12, rings * 0.6 + grain * 0.4);
		col *= mix(0.9, 1.08, big);
		col = mix(col, col * 1.5 + 0.03, edge * 0.6);       // 角のニスがはげて明るい
		rough = mix(rough, 0.8, edge * 0.7);
		col = mix(col, col * 0.55, scratches(obj_pos, wear) * wear); // 木の傷は暗い
	} else if (kind == 2) {
		col *= mix(0.88, 1.08, big);
		col = mix(col, col * 1.6 + 0.02, edge * 0.5);
		rough = mix(rough, 0.7, fine * 0.4);
	} else {
		// 金属: 黒染めのむら、角の擦れで地金、細かい傷は明るく光る
		col *= mix(0.8, 1.2, big);
		col *= mix(0.92, 1.05, fine);
		col = mix(col, edge_color, edge * (0.4 + wear * 0.6));
		metal = mix(metal, 0.9, edge);
		rough = mix(rough, 0.28, edge);
		float sc = scratches(obj_pos, wear) * wear;
		col = mix(col, edge_color * 0.8, sc * 0.7);
		rough = mix(rough, 0.3, sc);
		rough = mix(rough, rough + 0.12, fine);
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
}
