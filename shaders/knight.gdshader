shader_type canvas_item;

uniform bool unarmed = false;
uniform int walk_frame = 0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (unarmed) {
		ivec2 pixel = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
		int offsets[6] = {0, 2, 1, 0, 2, 1};
		int row = pixel.y - 27 - offsets[clamp(walk_frame, 0, 5)];
		int left[6] = {17, 17, 19, 20, 25, 28};
		int right[6] = {20, 23, 26, 29, 32, 33};
		bool blade = row >= 0 && row < 6;
		if (blade) {
			blade = pixel.x >= left[row] && pixel.x <= right[row];
		}
		bool grip = pixel.x >= 13 && pixel.x < 17 && row >= -1 && row <= 1;
		if (blade || grip) {
			color = vec4(0.0);
			if (blade && pixel.x >= 23 && pixel.x <= 26 && row < 4) {
				color = vec4(0.18, 0.20, 0.22, 1.0);
				if (pixel.x == 25) {
					color.rgb = vec3(0.30, 0.33, 0.35);
				}
			}
		}
	}
	COLOR = color;
}
