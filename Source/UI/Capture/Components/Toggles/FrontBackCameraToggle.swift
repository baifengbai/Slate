//
//  FrontBackCameraToggle.swift
//  Slate
//
//  Created by John Coates on 5/10/17.
//  Copyright © 2017 John Coates. All rights reserved.
//

import Foundation
import Cartography

final class FrontBackCameraToggle: InverseMaskGroupedPathButton {
    
    // MARK: - Init
    
    convenience init() {
        self.init(icon: FlippedCameraIcon())
    }
    
    // MARK: - Setup
    
    override func initialSetup() {
        iconWidthRatio = 0.65
        super.initialSetup()
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        rounding = 1
    }
}
