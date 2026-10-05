shader_type canvas_item;
// The Gridlock beat's frozen frame (#43): the capture washed out, mostly grey and lifted toward white.

uniform float grey = 0.75;  // share of the colour drained to grey
uniform float lift = 0.22;  // share lifted toward white

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(mix(c.rgb, vec3(g), grey), vec3(1.0), lift);
	COLOR = vec4(c.rgb, 1.0);
}
