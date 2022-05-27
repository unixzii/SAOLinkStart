//
//  BackgroundShaders.metal
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/25.
//

#include <metal_stdlib>

#include "../RenderTypes.h"

using namespace metal;

struct RasterizerData {
    float4 position [[position]];
    float2 texCoords;
};

vertex RasterizerData
backgroundVertex(const device SAORPostFXVertex *vertices [[buffer(0)]],
                 uint vid [[vertex_id]]) {
    const device auto &vertice = vertices[vid];
    
    RasterizerData out;
    out.position = float4(vertice.position, 1);
    out.texCoords = vertice.texCoords;
    return out;
}

fragment float4
backgroundFragment(RasterizerData in [[stage_in]],
                   texture2d<float> input [[texture(0)]],
                   constant float *alpha [[buffer(0)]]) {
    sampler samplr;
    const float4 inputColor = input.sample(samplr, in.texCoords);
    const float3 backgroundColor = float3(0.9);
    return float4(mix(backgroundColor, inputColor.rgb, inputColor.a), max(*alpha, inputColor.a));
}
