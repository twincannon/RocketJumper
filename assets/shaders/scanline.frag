#ifdef GL_ES
    precision mediump float;
#endif

varying vec2 vTexCoord;
uniform vec2 uResolution;
uniform sampler2D uImage0;

const float scale = 1.0;

vec4 toGrayscale(in vec4 color)
{
  float average = (color.r + color.g + color.b) / 3.0;
  return vec4(average, average, average, 1.0);
}

void main()
{
	vec4 color = texture2D(uImage0, vTexCoord);
	
    if (mod(floor(vTexCoord.y * uResolution.y / scale), 2.0) == 0.0)
	{
		vec4 gray = toGrayscale(color);
		gl_FragColor = gray;
	}
    else
        gl_FragColor = texture2D(uImage0, vTexCoord);
}

