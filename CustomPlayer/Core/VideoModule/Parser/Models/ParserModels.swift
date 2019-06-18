//
//  Models.swift
//  CustomPlayer
//
//  Created by USER on 04/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class DataStream: Comparable {
    static func == (lhs: DataStream, rhs: DataStream) -> Bool {
        return lhs.actualData == rhs.actualData
    }
    
    static func < (lhs: DataStream, rhs: DataStream) -> Bool {
        return lhs.pts[0] < rhs.pts[0]
    }
    var type: MediaType = .unknown
    var pts: [Int] = [0]
    var dts: [Int] = [0]
    var actualData: [UInt8] = []
}



struct Chunk {
    var sampleDescriptionIndex: Int = 0
    var firstSample: Int = 0
    var sampleCount: Int = 0
    var startSample: Int = 0
    var offset: Int = 0
    
    init() {}
}

struct Sample {
    var size: Int = 0
    var offset: Int = 0
    var startTime: Int = 0
    var duration: Int = 0
    var compositionTimeOffset: Int = 0
    
    init() {}
}

struct MP4MetaData {
    var totalDuration: Double = 0
    var sampleSizeArray: [Int] = []
    var sequenceParameterSet: Data = Data()
    var sequenceParameters: [Data] = []

    var pictureParameterSet: Data = Data()
    var pictureParameters: [Data] = []
}
