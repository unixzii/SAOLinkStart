//
//  GeometryShaders.metal
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/24.
//

#include <metal_stdlib>

#include "../RenderTypes.h"

using namespace metal;

struct RasterizerData {
    float4 position [[position]];
    float3 normal;
};

struct LightParameters {
    float3 direction;
    float3 ambientColor;
    float3 diffuseColor;
};

constant LightParameters defaultLight = {
    .direction = { 0, -0.2, 1 },
    .ambientColor = { 0.9, 0.9, 0.9 },
    .diffuseColor = { 0.9, 0.9, 0.9 },
};

vertex RasterizerData
geometryVertex(const device SAORVertex *vertices [[buffer(0)]],
               const constant SAORUniforms *uniforms [[buffer(1)]],
               uint vid [[vertex_id]]) {
    const device auto &vertice = vertices[vid];
    
    const constant auto &mvMatrix = uniforms->mvMatrix;
    const float3x3 mvMatrix3x3 = float3x3(mvMatrix.columns[0].xyz,
                                          mvMatrix.columns[1].xyz,
                                          mvMatrix.columns[2].xyz);
    
    RasterizerData out;
    out.position = uniforms->mvpMatrix * float4(vertice.position, 1.0);
    out.normal = mvMatrix3x3 * vertice.normal;
    return out;
}

fragment float4
geometryFragment(RasterizerData in [[stage_in]],
                 const constant SAORUniforms *uniforms [[buffer(1)]]) {
    const float3 ambientColor = uniforms->color.rgb * defaultLight.ambientColor;
    
    const float3 normal = normalize(in.normal);
    const float intensityDiffuse = saturate(dot(normal, defaultLight.direction));
    const float3 diffuse = intensityDiffuse * (defaultLight.diffuseColor * float3(1.0));
    
    return float4(ambientColor + diffuse, uniforms->alpha);
}
