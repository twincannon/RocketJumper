#ifdef GL_ES
	precision highp float;
#endif


varying vec2 vTexCoord;
uniform vec2 uResolution;
uniform sampler2D uImage0;

const float scale = 1.0;

uint hash( uint x ) {
    x += ( x << 10u );
    x ^= ( x >>  6u );
    x += ( x <<  3u );
    x ^= ( x >> 11u );
    x += ( x << 15u );
    return x;
}

uint hash( uvec2 v ) {
    return hash( v.x ^ hash(v.y) );
}

uint hash( uvec3 v ) {
    return hash( v.x ^ hash(v.y) ^ hash(v.z) );
}

uint hash( uvec4 v ) {
    return hash( v.x ^ hash(v.y) ^ hash(v.z) ^ hash(v.w) );
}

float rand( float f ) {
    const uint mantissaMask = 0x007FFFFFu;
    const uint one          = 0x3F800000u;
    
    uint h = hash( floatBitsToUint( f ) );
    h &= mantissaMask;
    h |= one;
    
    float  r2 = uintBitsToFloat( h );
    return r2 - 1.0;
}

void main()
{
    if (mod(floor(vTexCoord.y * uResolution.y / scale), 2.0) == 0.0)
	{
		
		gl_FragColor = vec4(rand( vec3(gl_FragCoord.xy,time) ) * 0.25, 0.0, 0.0, 1.0);
		
		float r = rand( vec3(gl_FragCoord.xy, time) );
		gl_FragColor = vec4( r,r,r, 1.0 );
	}
    else
        gl_FragColor = texture2D(uImage0, vTexCoord);
}

