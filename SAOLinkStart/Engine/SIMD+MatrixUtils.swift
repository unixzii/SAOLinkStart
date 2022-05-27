//
//  SIMD+MatrixUtils.swift
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/24.
//

import simd

extension simd_float4 {
    
    var xyz: simd_float3 {
        return .init(x: x, y: y, z: z)
    }
    
}

extension simd_float4x4 {
    
    init(translation v: simd_float3) {
        let baseX = simd_float4(x: 1, y: 0, z: 0, w: 0)
        let baseY = simd_float4(x: 0, y: 1, z: 0, w: 0)
        let baseZ = simd_float4(x: 0, y: 0, z: 1, w: 0)
        let baseW = simd_float4(x: v.x, y: v.y, z: v.z, w: 1)
        self.init(baseX, baseY, baseZ, baseW)
    }
    
    init(scale s: simd_float3) {
        let baseX = simd_float4(x: s.x, y: 0, z: 0, w: 0)
        let baseY = simd_float4(x: 0, y: s.y, z: 0, w: 0)
        let baseZ = simd_float4(x: 0, y: 0, z: s.z, w: 0)
        let baseW = simd_float4(x: 0, y: 0, z: 0, w: 1)
        self.init(baseX, baseY, baseZ, baseW)
    }
    
    init(rotation v: simd_float3, angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        let cm = 1 - c
        
        let x0 = v.x * v.x + (1 - v.x * v.x) * c
        let x1 = v.x * v.y * cm - v.z * s
        let x2 = v.x * v.z * cm + v.y * s

        let y0 = v.x * v.y * cm + v.z * s
        let y1 = v.y * v.y + (1 - v.y * v.y) * c
        let y2 = v.y * v.z * cm - v.x * s

        let z0 = v.x * v.z * cm - v.y * s
        let z1 = v.y * v.z * cm + v.x * s
        let z2 = v.z * v.z + (1 - v.z * v.z) * c
        
        let baseX = simd_float4(x: x0, y: x1, z: x2, w: 0)
        let baseY = simd_float4(x: y0, y: y1, z: y2, w: 0)
        let baseZ = simd_float4(x: z0, y: z1, z: z2, w: 0)
        let baseW = simd_float4(x: 0, y: 0, z: 0, w: 1)
        self.init(baseX, baseY, baseZ, baseW)
    }

    init(perspectiveWithAspect aspect: Float, fovy: Float, near: Float, far: Float) {
        let yScale = 1 / tan(fovy * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange
        
        let vectorP = simd_float4(x: xScale, y: 0, z: 0, w: 0)
        let vectorQ = simd_float4(x: 0, y: yScale, z: 0, w: 0)
        let vectorR = simd_float4(x: 0, y: 0, z: zScale, w: -1)
        let vectorS = simd_float4(x: 0, y: 0, z: wzScale, w: 0)
        self.init(vectorP, vectorQ, vectorR, vectorS)
    }
    
}
