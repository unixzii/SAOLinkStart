//
//  RenderTypes.h
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/24.
//

#pragma once

#include <simd/simd.h>

typedef struct _SAORVertex {
    simd_float3 position;
    simd_float3 normal;
} SAORVertex;

typedef struct _SAORUniforms {
    simd_float4x4 mvpMatrix;
    simd_float4x4 mvMatrix;
    simd_float4 color;
    float alpha;
} SAORUniforms;

typedef struct _SAORTextureVertex {
    simd_float3 position;
    simd_float2 texCoords;
} SAORPostFXVertex;
