//
//  GeometryRenderers.swift
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/24.
//

import Metal

class GeometryRenderer {
    
    func prepareResources() {
        // Implement me.
    }
    
    func render(with transform: Transform, into encoder: MTLRenderCommandEncoder) {
        // Implement me.
    }
    
}

/// A geometry renderer that renders an optimized cylinder, which only draws two
/// surfaces, eliminating the cost of drawing invisible back surfaces.
class OptimizedCylinderRenderer: GeometryRenderer {
    
    var radius: Float = 1
    var height: Float = 1
    var segments: Int = 36
    
    private var sideVertexBuffer: MTLBuffer?
    private var topVertexBuffer: MTLBuffer?
    
    override func prepareResources() {
        super.prepareResources()
        
        guard let device = RenderContext.current?.device else {
            fatalError("No active RenderContext.")
        }
        
        let angleStep = Float.pi * 2 / Float(segments)
        let vectors = (0..<segments).map { index -> simd_float3 in
            let currentAngle = angleStep * Float(index)
            let x = cos(currentAngle) * radius
            let z = sin(currentAngle) * radius
            return .init(x: x, y: 0, z: z)
        }
        
        // Build side vertex buffer.
        let numberOfSideVertices = (vectors.count + 1) * 2
        guard let sideVertexBuffer = device.makeBuffer(
            length: MemoryLayout<SAORVertex>.stride * numberOfSideVertices,
            options: .cpuCacheModeWriteCombined
        ) else {
            fatalError("Failed to create vertex buffer.")
        }
        let sideVertices = sideVertexBuffer.contents().assumingMemoryBound(to: SAORVertex.self)
        let topY = height / 2
        let bottomY = -topY
        for vid in 0..<(vectors.count + 1) {
            let vectorIndex = vid % segments
            let vector = vectors[vectorIndex]
            sideVertices.advanced(by: vid * 2).pointee = .init(
                position: .init(vector.x, topY, vector.z),
                normal: .init(x: vector.x, y: 0, z: vector.z)
            )
            sideVertices.advanced(by: vid * 2 + 1).pointee = .init(
                position: .init(vector.x, bottomY, vector.z),
                normal: .init(x: vector.x, y: 0, z: vector.z)
            )
        }
        self.sideVertexBuffer = sideVertexBuffer
        
        // Build top-surface vertex buffer.
        let numberOfTopVertices = vectors.count * 3
        guard let topVertexBuffer = device.makeBuffer(
            length: MemoryLayout<SAORVertex>.stride * numberOfTopVertices,
            options: .cpuCacheModeWriteCombined
        ) else {
            fatalError("Failed to create vertex buffer.")
        }
        let topVertices = topVertexBuffer.contents().assumingMemoryBound(to: SAORVertex.self)
        let center = simd_float3(x: 0, y: topY, z: 0)
        let normal = simd_float3(x: 0, y: 1, z: 0)
        for vid in 0..<vectors.count {
            topVertices.advanced(by: vid * 3).pointee = .init(
                position: center,
                normal: normal
            )
            var vector = vectors[vid]
            topVertices.advanced(by: vid * 3 + 1).pointee = .init(
                position: .init(vector.x, topY, vector.z),
                normal: normal
            )
            vector = vectors[(vid + 1) % segments]
            topVertices.advanced(by: vid * 3 + 2).pointee = .init(
                position: .init(vector.x, topY, vector.z),
                normal: normal
            )
        }
        self.topVertexBuffer = topVertexBuffer
    }
    
    override func render(with transform: Transform, into encoder: MTLRenderCommandEncoder) {
        // Emit draw call of side surfaces.
        encoder.setVertexBuffer(sideVertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: (segments + 1) * 2)
        
        // Emit draw call of top surface.
        encoder.setVertexBuffer(topVertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: segments * 3)
    }
    
}
