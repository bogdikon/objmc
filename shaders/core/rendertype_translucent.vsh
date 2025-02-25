#version 440

#moj_import <light.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;
uniform float GameTime;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec2 texCoord02;
out vec4 normal;
out float transition;

ivec2 getp(ivec2 topleft, ivec2 size, int yoffset, int index, int offset) {
    int i = (index * 5) + offset;
    return topleft + ivec2(i % size.x, int(i / size.x) + yoffset);
}

void main() {
    vec3 Pos = Position + ChunkOffset;
    vertexColor = Color;
    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);
    texCoord0 = UV0;

    //some basic data
    int corner = gl_VertexID % 4;
    ivec2 atlasSize = textureSize(Sampler0, 0);
    vec2 onepixel = 1./atlasSize;
    ivec2 uv = ivec2((UV0 * atlasSize));
    vec3 posoffset = vec3(0.0);
    //read uv offset
    ivec4 metauvoffset = ivec4(texelFetch(Sampler0, uv, 0) * 255);
    ivec2 uvoffset = ivec2(metauvoffset.r*256 + metauvoffset.g,
                           metauvoffset.b*256 + metauvoffset.a);
    //find and read topleft pixel
    ivec2 topleft = uv - uvoffset;
    ivec4 markerpix = ivec4(texelFetch(Sampler0, topleft, 0) * 255);
    //if marker is correct at topleft
    if (markerpix == ivec4(12,34,56,0)) {
        //grab metadata: marker, size, nvertices, nframes
        //size
        ivec4 metasize = ivec4(texelFetch(Sampler0, topleft + ivec2(1,0), 0) * 255);
        ivec2 size = ivec2(metasize.r*256 + metasize.g,
                           metasize.b*256 + metasize.a);
        //nvertices
        ivec4 metanvertices = ivec4(texelFetch(Sampler0, topleft + ivec2(2,0), 0) * 255);
        int nvertices = metanvertices.r*16777216 + metanvertices.g*65536 + metanvertices.b*256 + metanvertices.a;
        //nframes
        ivec4 metaframes = ivec4(texelFetch(Sampler0, topleft + ivec2(3,0), 0) * 255);
        int nframes = max(metaframes.r, 1);
        int ntextures = max(metaframes.g, 1);
        float duration = float(metaframes.b + 1) * 0.05; // /20ticks
        //time in seconds
        float time = GameTime * 1200;
        int frame = int(time * 1/duration) % nframes;

        //calculate height offsets
        int headerheight = 1 + int(ceil(nvertices*0.25/size.x));
        int yoffset = headerheight + (ntextures * size.y);
        //relative vertex id from unique face uv
        int id = (((uvoffset.y-1) * size.x) + uvoffset.x) * 4 + corner;
        id += frame * nvertices;
        //read data
        //meta = rgba: textureid, easing, scale?, unused
        //position = xyz: rgb, rgb, rgb
        //normal = xyz: aaa of the prev pixels
        //uv = rg,ba
        vec4 datameta = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 0), 0);
        vec4 datax = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 1), 0);
        vec4 datay = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 2), 0);
        vec4 dataz = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 3), 0);
        vec4 datauv = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 4), 0);
        //position
        posoffset = vec3(
            ((datax.r*255*256)+(datax.g*256)+(datax.b))/256,
            ((datay.r*255*256)+(datay.g*256)+(datay.b))/256,
            ((dataz.r*255*256)+(dataz.g*256)+(dataz.b))/256
        ) - 128;
        //normal
        vec3 norm = vec3(datax.a + int(datax.a == 0), datay.a + int(datay.a == 0), dataz.a + int(dataz.a == 0));
        //uv
        vec2 texuv = vec2(
            ((datauv.r*256) + datauv.g)/atlasSize.x/256*size.x,
            ((datauv.b*256) + datauv.a)/atlasSize.y/256*size.y
        );

        int easing = int(datameta.g * 255);
        if (nframes > 1) {
            //next frame
            id = (id + nvertices) % (nframes * nvertices);
            vec4 datameta2 = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 0), 0);
            vec4 datax2 = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 1), 0);
            vec4 datay2 = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 2), 0);
            vec4 dataz2 = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 3), 0);
            vec4 datauv2 = texelFetch(Sampler0, getp(topleft, size, yoffset, id, 4), 0);
            //position
            vec3 posoffset2 = vec3(
                ((datax2.r*255*256)+(datax2.g*256)+(datax2.b))/256,
                ((datay2.r*255*256)+(datay2.g*256)+(datay2.b))/256,
                ((dataz2.r*255*256)+(dataz2.g*256)+(dataz2.b))/256
            ) - 128;
            //normal
            vec3 norm2 = vec3(datax2.a + int(datax2.a == 0), datay2.a + int(datay2.a == 0), dataz2.a + int(dataz2.a == 0));
            //uv
            //vec2 texuv2 = vec2(
            //    ((datauv.r*256) + datauv.g)/atlasSize.x/256*size.x,
            //    ((datauv.b*256) + datauv.a)/atlasSize.y/256*size.y
            //);
            //texCoord02 = (vec2(topleft.x, topleft.y+headerheight)/atlasSize) + texuv2;

            transition = fract(time * 1/duration);
            switch (easing) {
                case 1: { //linear
                    posoffset = mix(posoffset, posoffset2, transition);
                    norm = mix(norm, norm2, transition);
                    break;}
                case 2: { //cubic
                    transition = transition < 0.5 ? 4 * transition * transition * transition : 1 - pow(-2 * transition + 2, 3) * 0.5;
                    posoffset = mix(posoffset, posoffset2, transition);
                    norm = mix(norm, norm2, transition);
                    break;}
            }
        }

        //real uv
        texCoord0 = (vec2(topleft.x, topleft.y+headerheight)/atlasSize) + texuv;
        //normal and shading
        normal = vec4(normalize(norm), 0.0);
        vertexColor = vec4(vec3(max(dot(normal.xyz, vec3(0,1,0)), 0.0)) * 0.8 + 0.2, 1.0);
    }
    //debug
    //else {
    //    gl_Position = ProjMat * ModelViewMat * vec4(Pos + vec3(gl_VertexID % 4 - 2, gl_VertexID % 4 / 2 * 2, -(gl_VertexID % 4) + 2 * 2), 1.0);
    //    vertexColor = vec4(1.0,0.0,0.0,1.0);
    //}
    vertexColor *= minecraft_sample_lightmap(Sampler2, UV2);
    gl_Position = ProjMat * ModelViewMat * vec4(Pos + posoffset, 1.0);
    vertexDistance = length((ModelViewMat * vec4(Pos + posoffset, 1.0)).xyz);
}