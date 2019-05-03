//
//  Models.swift
//  CustomPlayer
//
//  Created by USER on 03/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

enum FileContainerType {
    case mp4
}


class TrackItem {
    var sampleDuration: Int = 0
    var startTime: Int = 0
    var size: Int = 0
}

class Track {
    var chunks: [Chunk] = []
    var samples: [Sample] = []
    
    var sequenceParameterSet: Data = Data()
    var sequenceParameters: [Data] = []
    
    var pictureParameterSet: Data = Data()
    var pictureParams: [Data] = []
    
    
    var sampleCount: Int = 0
    var sampleTimingEntryCount: Int = 0
    var sampleSizeEntryCount: Int = 0
    var sampleRate: Int = 0
    
}
