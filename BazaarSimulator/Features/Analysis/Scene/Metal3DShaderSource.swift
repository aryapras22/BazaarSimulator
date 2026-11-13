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
    };

    struct MeshVertex {
        float3 position;
        float3 normal;
    };

    struct Instance {
        float4 positionRotation; // xyz: where, w: turn about the vertical axis
        float4 scale;            // xyz: size
        float4 color;
    };

    struct SolidOut {
        float4 position [[position]];
        float3 normal;
        float4 color;
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
        return out;
    }

    fragment float4 solidFragment(SolidOut in [[stage_in]], constant Uniforms &u [[buffer(2)]]) {
        float ambient = u.lightDirection.w;
        float diffuse = max(dot(normalize(in.normal), -normalize(u.lightDirection.xyz)), 0.0);
        float light = min(ambient + (1.0 - ambient) * 1.4 * diffuse, 1.15);
        float3 rgb = in.color.rgb * light;
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
