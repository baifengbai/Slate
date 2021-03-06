//
//  TestCamera
//  Created on 4/11/18.
//  Copyright © 2018 John Coates. All rights reserved.
//

import Foundation

class TestCamera: Camera {
    
    let position: CameraPosition
    init(position: CameraPosition) {
        self.position = position
    }
    
    var description: String {
        switch position {
        case .back:
            return "Back Camera"
        case .front:
            return "Front Camera"
        }
    }
    
    lazy var maximumResolution: IntSize = {
        switch position {
        case .back:
            return IntSize(width: 4032, height: 3024)
        case .front:
            return IntSize(width: 3088, height: 2320)
        }
    }()
    
    lazy var maximumFrameRate: Int = {
        switch position {
        case .back:
            return 120
        case .front:
            return 60
        }
    }()
    
    var highestResolutionForFrameRateClosure: ((Int) -> IntSize?)?
    
    func highestResolution(forFrameRate targetFrameRate: Int) -> IntSize? {
        let closure = Critical.unwrap(highestResolutionForFrameRateClosure)
        return closure(targetFrameRate)
    }
    
    var highestFrameRateForResolutionClosure: ((IntSize) -> Int?)?
    
    func highestFrameRate(forResolution targetResolution: IntSize) -> Int? {
        let closure = Critical.unwrap(highestFrameRateForResolutionClosure)
        return closure(targetResolution)
    }
    
}
