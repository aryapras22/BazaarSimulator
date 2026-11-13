/// The shaders for the 3D simulator, compiled when the renderer starts.
///
/// They are kept as source text so the app builds without the Metal Toolchain component. Move them to
/// a `.metal` file if the toolchain is installed everywhere the app is built.
enum Metal3DShaderSource {
    static let text = """
    #include <metal_stdlib>
    using namespace metal;

    struct Uniforms {
        float4x4 viewProjection;
        float4 lightDirection;   // xyz: which way the light travels, w: ambient light
        float4 cameraRight;
        float4 cameraUp;
        float4 overlayRect;      // x0, z0, x1, z1 of the plan, in meters
        float4 overlayHeight;    // x: how high above the floor the overlay lies
        float4 cameraPosition;
        float4 inkColor;         // rgb: the outline color, w: outline width in pixels
    };

    struct MeshVertex {
        float3 position;
        float3 normal;
    };

    struct Instance {
        float4 positionRotation; // xyz: where, w: turn about the vertical axis
        float4 scale;            // xyz: size, w: how it is outlined (0 box, 1 can, 2 figure, 3 not at all)
        float4 color;
    };

    struct SolidOut {
        float4 position [[position]];
        float3 normal;
        float4 color;
        float3 world;
        float3 local;            // where on the unit shape, before it is sized
        float3 localNormal;
        float4 scale [[flat]];
    };

    // Solid things: the venue, the visitors, and the glow markers. One draw call per shape, however many.
    vertex SolidOut solidVertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                                constant MeshVertex *vertices [[buffer(0)]],
                                constant Instance *instances [[buffer(1)]],
                                constant Uniforms &u [[buffer(2)]]) {
        Instance inst = instances[iid];
        MeshVertex v = vertices[vid];
        float c = cos(inst.positionRotation.w);
        float s = sin(inst.positionRotation.w);
        float3 scaled = v.position * inst.scale.xyz;
        float3 turned = float3(scaled.x * c + scaled.z * s, scaled.y, -scaled.x * s + scaled.z * c);
        float3 normal = float3(v.normal.x * c + v.normal.z * s, v.normal.y, -v.normal.x * s + v.normal.z * c);
        SolidOut out;
        out.position = u.viewProjection * float4(turned + inst.positionRotation.xyz, 1.0);
        out.normal = normal;
        out.color = inst.color;
        out.world = turned + inst.positionRotation.xyz;
        out.local = v.position;
        out.localNormal = v.normal;
        out.scale = inst.scale;
        return out;
    }

    // How strongly this point of a box is inked: 1 on an edge, 0 away from one. Each axis measures the
    // distance to its pair of faces, in meters, then divides by how many meters one pixel covers. The axis
    // the face itself looks along is always at zero, so it is left out. A face only a few pixels across
    // would be all line, so its lines are thinned to let its color show.
    float boxLine(SolidOut in, float width) {
        float3 perPixel = max(fwidth(in.local * in.scale.xyz), 1e-5);
        float3 away = abs(in.localNormal) * 1e5;
        float3 pixels = (0.5 - abs(in.local)) * in.scale.xyz / perPixel + away;
        float3 across = in.scale.xyz / perPixel + away;
        float narrowest = min(across.x, min(across.y, across.z));
        float line = 1.0 - smoothstep(width - 0.5, width + 0.5, min(pixels.x, min(pixels.y, pixels.z)));
        return line * mix(0.35, 1.0, smoothstep(2.0 * width, 5.0 * width, narrowest));
    }

    // How many pixels this point of a round shape is from its outline, which is where the surface turns
    // away from the eye. A can also has a rim around each end.
    float roundEdgeDistance(SolidOut in, float3 normal, float3 cameraPosition, bool rimmed) {
        float turning = abs(dot(normal, normalize(cameraPosition - in.world)));
        float pixels = turning / max(fwidth(turning), 1e-5);
        if (!rimmed) { return pixels; }
        float rim;
        if (abs(in.localNormal.y) > 0.5) {
            float radius = length(in.local.xz) * in.scale.x;
            rim = (0.5 * in.scale.x - radius) / max(fwidth(radius), 1e-5);
        } else {
            float height = in.local.y * in.scale.y;
            rim = (0.5 * in.scale.y - abs(height)) / max(fwidth(height), 1e-5);
        }
        return min(pixels, rim);
    }

    // Drawn like an ink illustration: each face is one flat tone, faces turned from the light are hatched,
    // and every edge is a line.
    fragment float4 solidFragment(SolidOut in [[stage_in]], constant Uniforms &u [[buffer(2)]]) {
        float3 normal = normalize(in.normal);
        float outline = in.scale.w;
        if (outline > 2.5) {
            return float4(in.color.rgb * in.color.a, in.color.a);
        }
        bool top = normal.y > 0.5;
        bool lit = dot(normal, -normalize(u.lightDirection.xyz)) > 0.0;
        float3 rgb = in.color.rgb * (top ? 1.0 : (lit ? 0.93 : 0.82));

        if (!top && !lit) {
            // Slanted lines 0.3 m apart, fading to a plain tone when they would be closer than the pixels.
            float stripe = (in.world.x + in.world.z + in.world.y) / 0.3;
            float spacing = fwidth(stripe);
            float hatch = 1.0 - smoothstep(0.12, 0.12 + spacing, abs(fract(stripe) - 0.5));
            rgb = mix(rgb, u.inkColor.rgb, 0.45 * hatch * (1.0 - smoothstep(0.25, 0.6, spacing)));
        }

        float width = u.inkColor.w;
        float line;
        if (outline < 0.5) {
            line = boxLine(in, width);
        } else {
            float edge = roundEdgeDistance(in, normal, u.cameraPosition.xyz, outline < 1.5);
            line = 1.0 - smoothstep(width - 0.5, width + 0.5, edge);
        }
        rgb = mix(rgb, u.inkColor.rgb, line);
        return float4(rgb * in.color.a, in.color.a);
    }

    // The heat or path image, lying flat over the plan.
    struct FlatOut {
        float4 position [[position]];
        float2 uv;
    };

    constant float2 corners[4] = { float2(0, 0), float2(1, 0), float2(0, 1), float2(1, 1) };

    vertex FlatOut overlayVertex(uint vid [[vertex_id]], constant Uniforms &u [[buffer(0)]]) {
        float2 corner = corners[vid];
        float x = mix(u.overlayRect.x, u.overlayRect.z, corner.x);
        float z = mix(u.overlayRect.y, u.overlayRect.w, corner.y);
        FlatOut out;
        out.position = u.viewProjection * float4(x, u.overlayHeight.x, z, 1.0);
        out.uv = corner;
        return out;
    }

    fragment float4 flatFragment(FlatOut in [[stage_in]], texture2d<float> image [[texture(0)]]) {
        constexpr sampler smooth(filter::linear, address::clamp_to_edge);
        return image.sample(smooth, in.uv);
    }

    // Labels: a picture of text that always faces the camera.
    vertex FlatOut labelVertex(uint vid [[vertex_id]],
                               constant float4 &center [[buffer(0)]],
                               constant Uniforms &u [[buffer(1)]]) {
        float2 corner = corners[vid];
        float2 offset = float2(corner.x - 0.5, 0.5 - corner.y) * float2(\(Metal3DRenderer.labelSize.x), \(Metal3DRenderer.labelSize.y));
        float3 world = center.xyz + u.cameraRight.xyz * offset.x + u.cameraUp.xyz * offset.y;
        FlatOut out;
        out.position = u.viewProjection * float4(world, 1.0);
        out.uv = corner;
        return out;
    }
    """
}
