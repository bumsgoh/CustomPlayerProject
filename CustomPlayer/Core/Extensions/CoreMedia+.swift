//
//  CoreMedia+.swift
//  CustomPlayer
//
//  Created by USER on 04/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import CoreMedia

extension CMSampleBuffer {
    var numSamples: CMItemCount {
        return CMSampleBufferGetNumSamples(self)
    }
    var duration: CMTime {
        return CMSampleBufferGetDuration(self)
    }
    var formatDescription: CMFormatDescription? {
        return CMSampleBufferGetFormatDescription(self)
    }
    var decodeTimeStamp: CMTime {
        return CMSampleBufferGetDecodeTimeStamp(self)
    }
    var presentationTimeStamp: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
}

extension Array where Element == CMSampleBuffer {
    mutating func copyNextSample() -> CMSampleBuffer? {
        if self.isEmpty {
            return nil
        }
        let item = self.first
        self.remove(at: 0)
        return item
    }
}

extension CMSampleTimingInfo {
    init(pts: Int64, dts: Int64, fps: Int64) {
        self.init()
        self.presentationTimeStamp = CMTime(value: pts, timescale: 1000)
        self.decodeTimeStamp = CMTime(value: dts, timescale: 1000)
        self.duration = CMTime(value: fps, timescale: 1000)
    }
}
