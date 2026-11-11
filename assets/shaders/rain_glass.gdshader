shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Vidro da janela: refrata o que está atrás com gotas paradas e filetes que
// escorrem. rain = 0 deixa o vidro limpo (só um reflexo leve).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float rain = 1.0;
uniform vec3 tint : source_color = vec3(0.86, 0.92, 0.98);
uniform float blur = 1.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Gotas paradas: uma por célula, posição e tamanho aleatórios.
vec2 static_drops(vec2 uv, float scale) {
	vec2 g = uv * scale;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	vec2 c = vec2(hash(id + 1.3), hash(id + 7.1)) - 0.5;
	c *= 0.6;
	float r = mix(0.06, 0.18, h) * step(0.45, hash(id + 2.2));
	float fade = fract(TIME * 0.05 + h); // gotas surgem e secam devagar
	r *= smoothstep(0.0, 0.15, fade) * smoothstep(1.0, 0.7, fade);
	vec2 d = f - c;
	// Célula sem gota (r = 0): smoothstep com bordas iguais não é definido.
	float rr = max(r, 0.001);
	float m = (1.0 - smoothstep(rr * 0.6, rr, length(d))) * step(0.002, r);
	return d * m * 2.0;
}

// Filetes: colunas em que uma gota grande desce deixando rastro.
vec2 streaks(vec2 uv, float scale) {
	vec2 g = vec2(uv.x * scale, uv.y * scale * 0.25);
	float col = floor(g.x);
	float h = hash(vec2(col, 4.0));
	float speed = mix(0.08, 0.22, h);
	float y = fract(uv.y * 0.6 + TIME * speed + h * 10.0);
	float fx = fract(g.x) - 0.5 + 0.08 * sin(uv.y * 30.0 + h * 6.28);
	float head = smoothstep(0.10, 0.0, length(vec2(fx, (y - 0.5) * 3.0)));
	float trail = smoothstep(0.035, 0.0, abs(fx)) * smoothstep(0.5, 1.0, y) * 0.35;
	float active = step(0.55, h);
	return vec2(fx, y - 0.5) * (head + trail) * active;
}

void fragment() {
	vec2 uv = UV * vec2(3.0, 2.2);
	vec2 off = vec2(0.0);
	off += static_drops(uv, 9.0) * 0.6;
	off += static_drops(uv + 3.7, 17.0) * 0.4;
	off += streaks(uv, 7.0) * 1.2;
	off *= rain;
	float wet = clamp(length(off) * 6.0, 0.0, 1.0);
	vec2 suv = SCREEN_UV + off * 0.025;
	// Vidro molhado fora das gotas fica levemente embaçado; dentro, nítido.
	// Desfoque com poucas amostras (o mipmap da tela fica quadriculado).
	float r = blur * 0.0018 * rain * (1.0 - wet);
	vec3 bg = textureLod(screen_tex, suv, 0.0).rgb * 0.36;
	bg += textureLod(screen_tex, suv + vec2(r, r * 0.6), 0.0).rgb * 0.16;
	bg += textureLod(screen_tex, suv + vec2(-r, r * 0.6), 0.0).rgb * 0.16;
	bg += textureLod(screen_tex, suv + vec2(r * 0.6, -r), 0.0).rgb * 0.16;
	bg += textureLod(screen_tex, suv + vec2(-r * 0.6, -r), 0.0).rgb * 0.16;
	vec3 col = bg * tint;
	col += vec3(0.6, 0.7, 0.8) * wet * 0.04;
	// Reflexo fraco e frio, mais forte em ângulo rasante.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col += vec3(0.08, 0.10, 0.13) * fres;
	ALBEDO = col;
}
