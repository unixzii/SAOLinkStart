//
//  Common.swift
//  SAOLinkStart
//
//  Created by Cyandev on 2022/5/26.
//

import Metal

enum RenderPassCommon {
    
    static func makeQuadTextureVertexBuffer() -> MTLBuffer {
        guard let renderContext = RenderContext.current else {
            fatalError("No active RenderContext.")
        }
        
        let device = renderContext.device
        
        let vertices: [_SAORTextureVertex] = [
            .init(position: .init(x: -1, y: -1, z: 0), texCoords: .init(x: 0, y: 0)),
            .init(position: .init(x: -1, y:  1, z: 0), texCoords: .init(x: 0, y: 1)),
            .init(position: .init(x:  1, y: -1, z: 0), texCoords: .init(x: 1, y: 0)),
            .init(position: .init(x:  1, y:  1, z: 0), texCoords: .init(x: 1, y: 1)),
        ]
        return vertices.withUnsafeBytes {
            guard let vertexBuffer = device.makeBuffer(bytes: $0.baseAddress!,
                                                       length: $0.count, options: []) else {
                fatalError("Failed to create texture vertex buffer.")
            }
            return vertexBuffer
        }
    }
    
}
