shader_type spatial;
// Fachada de prédio com janelas procedurais: cada célula da grade decide, por
// hash, se está acesa, de que cor e se pisca. Um prédio inteiro custa uma malha.

uniform vec3 base_color : source_color = vec3(0.035, 0.045, 0.06);
uniform vec3 day_color : source_color = vec3(0.42, 0.44, 0.46);
uniform vec3 warm : source_color = vec3(1.0, 0.70, 0.38);
uniform vec3 cool : source_color = vec3(0.55, 0.80, 1.0);
uniform float lit_ratio = 0.32;          // fração de janelas acesas
uniform float night = 1.0;               // 0 dia, 1 noite
uniform float glow = 3.2;                // força da emissão das janelas
uniform vec2 cell = vec2(0.42, 0.55);    // tamanho de um andar/janela em metros
uniform float seed = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnorm);
	vec2 uv = n.x > n.z ? wpos.zy : wpos.xy;
	vec3 col = base_color;
	vec3 emit = vec3(0.0);
	if (n.y < 0.5) {
		vec2 g = uv / cell;
		vec2 id = floor(g);
		vec2 f = fract(g);
		float in_win = step(0.18, f.x) * step(f.x, 0.82) * step(0.22, f.y) * step(f.y, 0.78);
		float h = hash(id + seed * 13.7);
		// Algumas janelas mudam de estado devagar (gente acendendo e apagando a luz).
		float slot = floor(TIME / 9.0 + h * 40.0);
		float h2 = hash(id * 1.7 + slot);
		float lit = step(h, lit_ratio) * step(0.04, h2);
		lit = max(lit, step(0.985, h2) * step(lit_ratio, h)); // poucas acendem
		vec3 tone = mix(warm, cool, step(0.72, hash(id + 3.1)));
		tone *= 0.55 + 0.45 * hash(id + 9.3);
		// Escritórios vazios: luz fria e fraca de dia, quase nada.
		emit = tone * lit * in_win * glow * mix(0.08, 1.0, night);
		// De dia: concreto claro e vidro escuro que reflete o céu.
		vec3 wall_c = mix(day_color, base_color, night);
		vec3 glass_c = mix(vec3(0.10, 0.13, 0.17), base_color * 1.6 + vec3(0.02, 0.03, 0.04), night);
		col = mix(wall_c * (0.85 + 0.3 * hash(floor(uv / 23.0))), glass_c, in_win);
		ROUGHNESS = mix(0.9, 0.15, in_win);
		METALLIC = in_win * 0.4;
	} else {
		col = mix(day_color * 0.7, base_color, night);
		ROUGHNESS = 0.95;
	}
	ALBEDO = col;
	EMISSION = emit;
}
