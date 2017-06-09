//
//  VectorImage.swift
//  Slate
//
//  Created by John Coates on 6/8/17.
//  Copyright © 2017 John Coates. All rights reserved.
//

import CoreGraphics

protocol VectorImageAsset: class {
    var name: String { get }
    var section: String { get }
    var width: CGFloat { get }
    var height: CGFloat { get }
    
    func simulateDraw()
}

class VectorImage {
}

extension VectorImageAsset {
    var identifier: String {
        return "\(section).\(self.name)"
    }
}
