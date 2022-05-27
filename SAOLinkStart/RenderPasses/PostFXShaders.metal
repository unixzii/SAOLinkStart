//
//  PostFXShaders.metal
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
postFXVertex(const device SAORPostFXVertex *vertices [[buffer(0)]],
             uint vid [[vertex_id]]) {
    const device auto &vertice = vertices[vid];
    
    RasterizerData out;
    out.position = float4(vertice.position, 1);
    out.texCoords = vertice.texCoords;
    return out;
}

fragment float4
postFXFragment(RasterizerData in [[stage_in]],
               texture2d<float> input1 [[texture(0)]],
               texture2d<float> input2 [[texture(1)]]) {
    sampler samplr;
    
    const float4 baseColor = input1.sample(samplr, in.texCoords);
    
    const float4 overlayColor = input2.sample(samplr, in.texCoords);
    const float2 displaceOffset = in.texCoords + clamp(abs((in.texCoords - float2(0.5))) / 2 * 0.03, 0, 0.1);
    const float4 displacedOverlayColor = input2.sample(samplr, displaceOffset);
    
    return mix(baseColor,
               float4(displacedOverlayColor.r, overlayColor.g, overlayColor.b, overlayColor.a),
               0.6);
}
